//
//  ExplorationManager.swift
//  EarthLord
//
//  探索管理器
//  负责管理探索状态、距离追踪、时长计时、奖励生成
//

import Foundation
import CoreLocation
import Combine

// MARK: - 探索管理器

@MainActor
class ExplorationManager: ObservableObject {

    // MARK: - 单例

    static let shared = ExplorationManager()

    // MARK: - Published 属性

    /// 是否正在探索
    @Published var isExploring: Bool = false

    /// 当前探索距离（米）
    @Published var currentDistance: Double = 0

    /// 当前探索时长（秒）
    @Published var currentDuration: TimeInterval = 0

    /// 探索开始位置
    @Published var startLocation: CLLocationCoordinate2D?

    // MARK: - POI 相关属性

    /// 附近的 POI 列表
    @Published var nearbyPOIs: [POI] = []

    /// 当前接近的 POI（用于弹窗）
    @Published var currentApproachingPOI: POI?

    /// 是否显示搜刮弹窗
    @Published var showScavengePopup: Bool = false

    /// 已搜刮的 POI ID 集合
    private var scavengedPOIIds: Set<String> = []

    /// 地理围栏半径（米）- 改为 100m
    private let geofenceRadius: Double = 100

    /// POI 接近检测定时器
    private var poiProximityTimer: Timer?

    // MARK: - 私有属性

    /// 探索开始时间
    private var startTime: Date?

    /// 探索会话ID
    private var sessionId: UUID?

    /// 时长更新定时器
    private var durationTimer: Timer?

    /// 超速检测定时器
    private var speedCheckTimer: Timer?

    /// 超速开始时间
    private var speedViolationStartTime: Date?

    /// LocationManager 引用
    private let locationManager = LocationManager.shared

    /// Combine 订阅集合
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Supabase 配置

    private let supabaseURL = "https://npmazbowtfowbxvpjhst.supabase.co"
    private let supabaseKey = "sb_publishable_59Pm_KFRXgXJUVYUK0nwKg_RqnVRCKQ"

    // MARK: - 私有初始化

    private init() {
        setupObservers()
    }

    // MARK: - 观察者设置

    private func setupObservers() {
        // 订阅 LocationManager 的路径坐标变化，实时更新距离
        locationManager.$pathCoordinates
            .sink { [weak self] (coordinates: [CLLocationCoordinate2D]) in
                self?.updateCurrentDistance()
            }
            .store(in: &cancellables)

        // 订阅速度超标状态
        locationManager.$isOverSpeed
            .sink { [weak self] (isOverSpeed: Bool) in
                self?.handleSpeedViolation(isOverSpeed: isOverSpeed)
            }
            .store(in: &cancellables)

        // 订阅 POI 地理围栏进入事件
        NotificationCenter.default.publisher(for: .didEnterPOIRegion)
            .sink { [weak self] notification in
                guard let self = self,
                      let regionId = notification.userInfo?["regionId"] as? String else { return }
                Task { @MainActor in
                    self.handlePOIRegionEntered(regionId: regionId)
                }
            }
            .store(in: &cancellables)

        // ⚠️ 关键：订阅用户位置变化，手动检测 POI 接近
        // iOS 地理围栏只在进入时触发，不会检测已经在范围内的情况
        locationManager.$userLocation
            .sink { [weak self] (location: CLLocationCoordinate2D?) in
                guard let self = self, let location = location else { return }
                Task { @MainActor in
                    self.checkPOIProximity(userLocation: location)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 公开方法

    /// 开始探索
    func startExploration() {
        guard !isExploring else {
            print("⚠️ 探索已在进行中，忽略重复调用")
            return
        }

        // 1. 记录开始时间和位置
        startTime = Date()
        startLocation = locationManager.userLocation
        sessionId = UUID()

        // 2. 重置状态
        currentDistance = 0
        currentDuration = 0
        speedViolationStartTime = nil

        // 3. 开始 GPS 路径追踪
        locationManager.startPathTracking()
        print("📍 GPS 路径追踪已启动")

        // 4. 启动时长计时器（每秒更新）
        startDurationTimer()

        // 5. 更新状态
        isExploring = true

        // 6. 保存探索会话到数据库（状态：active）
        Task {
            await saveExplorationSession(status: "active")
        }

        // 7. 搜索并设置附近 POI，搜索完成后启动定时器
        Task {
            await searchAndSetupPOIs()
            // ⚠️ 关键：必须在 POI 搜索完成后才启动定时器！
            await MainActor.run {
                startPOIProximityTimer()
            }
        }

        let sessionIdStr = sessionId?.uuidString ?? "unknown"
        let startLat = startLocation?.latitude ?? 0
        let startLng = startLocation?.longitude ?? 0
        print("✅ 探索已开始")
        print("   Session ID: \(sessionIdStr)")
        print("   起点坐标: (\(String(format: "%.6f", startLat)), \(String(format: "%.6f", startLng)))")
    }

    /// 结束探索
    /// - Returns: 探索统计数据
    func stopExploration() async -> ExplorationStats? {
        guard isExploring, let startTime = startTime, let sessionId = sessionId else {
            print("❌ 探索未开始或已结束")
            return nil
        }

        print("📊 正在结算探索数据...")

        // 1. 先计算最终数据（在停止追踪前）
        let finalDistance = locationManager.calculateTotalPathDistance()
        let finalDuration = Date().timeIntervalSince(startTime)
        let endLocation = locationManager.userLocation
        let pathPointsCount = locationManager.pathCoordinates.count

        print("   ✓ 最终距离: \(Int(finalDistance))m")
        print("   ✓ 探索时长: \(Int(finalDuration))秒 (\(Int(finalDuration/60))分钟)")
        print("   ✓ 路径点数: \(pathPointsCount)个")

        // 2. 停止 GPS 追踪和计时器（会清空 pathCoordinates）
        locationManager.stopPathTracking()
        stopDurationTimer()
        stopSpeedCheckTimer()
        print("   ✓ GPS 追踪已停止")

        // 3. 生成奖励
        print("   🎁 正在生成奖励...")
        let rewardResult = await RewardGenerator.shared.generateReward(distance: finalDistance)
        print("   ✓ 奖励等级: \(rewardResult.tier.displayName) \(rewardResult.tier.emoji)")
        print("   ✓ 获得物品: \(rewardResult.items.count)个")

        // 4. 将奖励物品添加到背包
        if !rewardResult.items.isEmpty {
            do {
                try await InventoryManager.shared.addItems(rewardResult.items)
                print("   ✓ 物品已添加到背包")
                for item in rewardResult.items {
                    print("      - \(item.itemName) x\(item.quantity)")
                }
            } catch {
                print("   ❌ 添加物品到背包失败：\(error.localizedDescription)")
            }
        } else {
            print("   ℹ️ 距离不足，无奖励物品")
        }

        // 5. 计算验证地点数和经验值
        let validationPoints = pathPointsCount
        let earnedExperience = calculateExperience(distance: finalDistance, tier: rewardResult.tier)
        print("   ✓ 验证地点: \(validationPoints)个")
        print("   ✓ 获得经验: +\(earnedExperience) EXP")

        // 6. 获取累计统计数据
        let totalDistance = await getTotalDistance()
        let distanceRank = await getDistanceRank()
        print("   ✓ 累计行走: \(Int(totalDistance))m")

        // 7. 更新探索会话到数据库（状态：completed）
        print("   💾 正在保存探索记录...")
        await updateExplorationSession(
            sessionId: sessionId,
            distance: finalDistance,
            duration: finalDuration,
            endLocation: endLocation,
            rewardTier: rewardResult.tier,
            items: rewardResult.items
        )

        // 8. 清除 POI 相关状态
        clearPOIData()

        // 9. 重置状态
        isExploring = false
        self.startTime = nil
        self.sessionId = nil
        currentDistance = 0
        currentDuration = 0
        speedViolationStartTime = nil

        // 10. 构建返回数据
        let stats = ExplorationStats(
            currentDistance: finalDistance,
            totalDistance: totalDistance,
            distanceRank: distanceRank,
            duration: finalDuration,
            obtainedItems: rewardResult.items,
            rewardTier: rewardResult.tier,
            validationPoints: validationPoints,
            earnedExperience: earnedExperience
        )

        print("✅ 探索结算完成")

        return stats
    }

    /// 取消探索（不保存）
    func cancelExploration() {
        guard isExploring else { return }

        locationManager.stopPathTracking()
        stopDurationTimer()
        stopSpeedCheckTimer()

        isExploring = false
        startTime = nil
        sessionId = nil
        currentDistance = 0
        currentDuration = 0
        speedViolationStartTime = nil

        print("⚠️ 探索已取消")
    }

    /// 因超速停止探索
    func stopExplorationDueToSpeeding() async -> ExplorationStats? {
        guard isExploring else { return nil }

        print("❌ 探索因超速终止")
        print("   原因：速度持续超过 30 km/h 超过 10 秒")

        // 停止追踪
        locationManager.stopPathTracking()
        stopDurationTimer()
        stopSpeedCheckTimer()

        let finalDistance = locationManager.calculateTotalPathDistance()
        let finalDuration = Date().timeIntervalSince(startTime ?? Date())

        print("   最终距离: \(Int(finalDistance))m")
        print("   探索时长: \(Int(finalDuration))秒")

        // 重置状态
        isExploring = false
        startTime = nil
        sessionId = nil
        currentDistance = 0
        currentDuration = 0
        speedViolationStartTime = nil

        // 返回失败统计（无奖励）
        let stats = ExplorationStats(
            currentDistance: finalDistance,
            totalDistance: await getTotalDistance(),
            distanceRank: 0,
            duration: finalDuration,
            obtainedItems: [],
            rewardTier: RewardTier.none,
            validationPoints: locationManager.pathCoordinates.count,
            earnedExperience: 0
        )

        return stats
    }

    // MARK: - 私有方法

    /// 更新当前距离（从 LocationManager 读取）
    private func updateCurrentDistance() {
        guard isExploring else { return }
        currentDistance = locationManager.calculateTotalPathDistance()
    }

    /// 启动时长计时器
    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let startTime = self.startTime else { return }
                self.currentDuration = Date().timeIntervalSince(startTime)
            }
        }
    }

    /// 停止时长计时器
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    /// 停止超速检测定时器
    private func stopSpeedCheckTimer() {
        speedCheckTimer?.invalidate()
        speedCheckTimer = nil
        speedViolationStartTime = nil
    }

    /// 处理超速事件
    private func handleSpeedViolation(isOverSpeed: Bool) {
        guard isExploring else { return }

        if isOverSpeed {
            // 开始超速
            if speedViolationStartTime == nil {
                speedViolationStartTime = Date()
                print("⚠️ 检测到超速，开始计时...")

                // 启动10秒倒计时检测
                speedCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self = self,
                              let startTime = self.speedViolationStartTime else { return }

                        let elapsed = Date().timeIntervalSince(startTime)
                        let remaining = 10 - Int(elapsed)

                        if remaining > 0 {
                            print("⏱️ 超速警告：请在 \(remaining) 秒内降低速度")
                        } else {
                            print("❌ 超速时间超过 10 秒，停止探索")
                            // 停止探索
                            _ = await self.stopExplorationDueToSpeeding()
                        }
                    }
                }
            }
        } else {
            // 速度恢复正常
            if speedViolationStartTime != nil {
                print("✅ 速度已恢复正常")
                stopSpeedCheckTimer()
            }
        }
    }

    // MARK: - 数据库操作

    /// 保存探索会话到数据库（开始时调用）
    private func saveExplorationSession(status: String) async {
        guard let sessionId = sessionId,
              let startTime = startTime,
              let startLocation = startLocation else { return }

        let userId = DeviceIdentifier.shared.getUserId()

        let sessionData: [String: Any] = [
            "id": sessionId.uuidString,
            "user_id": userId,
            "started_at": ISO8601DateFormatter().string(from: startTime),
            "start_lat": startLocation.latitude,
            "start_lng": startLocation.longitude,
            "status": status
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: sessionData)

            let endpoint = "\(supabaseURL)/rest/v1/exploration_sessions"
            guard let url = URL(string: endpoint) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            request.httpBody = jsonData

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 {
                print("✅ 探索会话已保存到数据库")
            }
        } catch {
            print("❌ 保存探索会话失败：\(error.localizedDescription)")
        }
    }

    /// 更新探索会话到数据库（结束时调用）
    private func updateExplorationSession(
        sessionId: UUID,
        distance: Double,
        duration: TimeInterval,
        endLocation: CLLocationCoordinate2D?,
        rewardTier: RewardTier,
        items: [ObtainedItem]
    ) async {
        let pathCoordinates = locationManager.pathCoordinates
        let pathJSON = pathCoordinates.map { coord in
            ["lat": coord.latitude, "lon": coord.longitude]
        }

        let itemsJSON = items.map { item in
            ["itemId": item.itemId, "itemName": item.itemName, "quantity": item.quantity]
        }

        var updateData: [String: Any] = [
            "ended_at": ISO8601DateFormatter().string(from: Date()),
            "duration": duration,
            "total_distance": distance,
            "path": pathJSON,
            "reward_tier": rewardTier.rawValue,
            "items_rewarded": itemsJSON,
            "status": "completed"
        ]

        if let endLocation = endLocation {
            updateData["end_lat"] = endLocation.latitude
            updateData["end_lng"] = endLocation.longitude
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: updateData)

            let endpoint = "\(supabaseURL)/rest/v1/exploration_sessions?id=eq.\(sessionId.uuidString)"
            guard let url = URL(string: endpoint) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                print("✅ 探索会话已更新到数据库")
            }
        } catch {
            print("❌ 更新探索会话失败：\(error.localizedDescription)")
        }
    }

    /// 获取累计行走距离
    private func getTotalDistance() async -> Double {
        let userId = DeviceIdentifier.shared.getUserId()
        let endpoint = "\(supabaseURL)/rest/v1/exploration_sessions?user_id=eq.\(userId)&status=eq.completed&select=total_distance"

        guard let url = URL(string: endpoint) else { return 0 }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let sessions = try? JSONDecoder().decode([[String: Double]].self, from: data) {
                let total = sessions.compactMap { $0["total_distance"] }.reduce(0, +)
                return total
            }
        } catch {
            print("❌ 获取累计距离失败：\(error.localizedDescription)")
        }

        return 0
    }

    /// 获取距离排名（占位，暂返回固定值）
    private func getDistanceRank() async -> Int {
        // TODO: 实现真实排名逻辑
        return 0
    }

    /// 计算获得的经验值
    /// - Parameters:
    ///   - distance: 行走距离（米）
    ///   - tier: 奖励等级
    /// - Returns: 经验值
    private func calculateExperience(distance: Double, tier: RewardTier) -> Int {
        // 基础经验：每100米获得10点经验
        let baseExp = Int(distance / 100) * 10

        // 等级加成
        let tierBonus: Double = {
            switch tier {
            case .none: return 0
            case .bronze: return 1.0
            case .silver: return 1.5
            case .gold: return 2.0
            case .diamond: return 3.0
            }
        }()

        return Int(Double(baseExp) * tierBonus)
    }

    // MARK: - POI 相关方法

    /// 搜索并设置附近 POI
    private func searchAndSetupPOIs() async {
        guard let location = locationManager.userLocation else {
            print("⚠️ [POI] 无法获取用户位置，跳过 POI 搜索")
            return
        }

        print("🔍 [POI] 开始搜索附近 POI...")
        print("   📍 用户位置: (\(String(format: "%.6f", location.latitude)), \(String(format: "%.6f", location.longitude)))")

        do {
            // 搜索 POI
            let pois = try await POISearchManager.shared.searchNearbyPOIs(center: location)
            nearbyPOIs = pois

            print("✅ [POI] 找到 \(pois.count) 个 POI:")
            for (index, poi) in pois.prefix(5).enumerated() {
                let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
                let userCLLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                let distance = userCLLocation.distance(from: poiLocation)
                print("   \(index + 1). \(poi.name) - \(poi.category.wastelandName) - 距离: \(Int(distance))m")
            }
            if pois.count > 5 {
                print("   ... 还有 \(pois.count - 5) 个 POI")
            }

            // 设置地理围栏（作为备用检测机制）
            setupGeofences(for: pois)

        } catch {
            print("❌ [POI] 搜索失败: \(error.localizedDescription)")
        }
    }

    /// 为 POI 设置地理围栏
    private func setupGeofences(for pois: [POI]) {
        print("📍 [POI] 设置地理围栏...")

        for poi in pois {
            let region = CLCircularRegion(
                center: poi.coordinate,
                radius: geofenceRadius,
                identifier: poi.id
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false

            locationManager.startMonitoringRegion(region)
        }

        print("✅ [POI] 已设置 \(pois.count) 个地理围栏（半径: \(Int(geofenceRadius))m）")
    }

    /// 移除所有地理围栏
    private func removeAllGeofences() {
        locationManager.stopMonitoringAllRegions()
        print("🗑️ [POI] 已移除所有地理围栏")
    }

    /// 清除 POI 相关数据
    private func clearPOIData() {
        // 停止 POI 接近检测定时器
        stopPOIProximityTimer()

        removeAllGeofences()
        nearbyPOIs.removeAll()
        scavengedPOIIds.removeAll()
        currentApproachingPOI = nil
        showScavengePopup = false
        print("🗑️ [POI] 已清除所有 POI 数据")
    }

    // MARK: - POI 接近检测定时器

    /// 启动 POI 接近检测定时器
    private func startPOIProximityTimer() {
        // 先停止已有定时器
        stopPOIProximityTimer()

        print("⏱️ [POI] 启动接近检测定时器（每 2 秒检测一次，范围: \(Int(geofenceRadius))m）")

        // 每 2 秒执行一次接近检测
        poiProximityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performPOIProximityCheck()
            }
        }

        // 立即执行一次检测
        performPOIProximityCheck()
    }

    /// 停止 POI 接近检测定时器
    private func stopPOIProximityTimer() {
        poiProximityTimer?.invalidate()
        poiProximityTimer = nil
        print("⏱️ [POI] 已停止接近检测定时器")
    }

    /// 执行 POI 接近检测（定时器回调）
    private func performPOIProximityCheck() {
        // 检查是否正在探索
        guard isExploring else { return }

        // 如果已有弹窗显示，跳过检测
        guard !showScavengePopup else { return }

        // 如果没有 POI，跳过
        guard !nearbyPOIs.isEmpty else { return }

        // 获取用户当前位置
        guard let userLocation = locationManager.userLocation else {
            print("⚠️ [POI] 无法获取用户位置")
            return
        }

        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)

        // 统计
        var closestPOI: POI?
        var closestDistance: Double = Double.infinity

        // 遍历所有未搜刮的 POI，检查是否有接近的
        for poi in nearbyPOIs where !scavengedPOIIds.contains(poi.id) {
            let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
            let distance = userCLLocation.distance(from: poiLocation)

            // 记录最近的 POI
            if distance < closestDistance {
                closestDistance = distance
                closestPOI = poi
            }

            // 如果在范围内（100米）
            if distance <= geofenceRadius {
                print("🎯 [POI] ✅ 检测到接近！\(poi.name)（距离: \(Int(distance))m ≤ \(Int(geofenceRadius))m）")
                showPOIScavengePopup(poi: poi)
                return
            }
        }

        // 每 10 秒打印一次最近 POI（减少日志）
        if let closest = closestPOI, Int(Date().timeIntervalSince1970) % 10 == 0 {
            print("📍 [POI] 最近: \(closest.name) 距离 \(Int(closestDistance))m（需≤\(Int(geofenceRadius))m）")
        }
    }

    // MARK: - 测试方法（仅调试用）

    /// 强制触发最近 POI 的搜刮弹窗（用于测试）
    func debugTriggerNearestPOI() {
        guard isExploring else {
            print("❌ [DEBUG] 未在探索中")
            return
        }

        guard !nearbyPOIs.isEmpty else {
            print("❌ [DEBUG] POI 列表为空")
            return
        }

        // 找到第一个未搜刮的 POI
        if let poi = nearbyPOIs.first(where: { !scavengedPOIIds.contains($0.id) }) {
            print("🧪 [DEBUG] 强制触发搜刮: \(poi.name)")
            showPOIScavengePopup(poi: poi)
        } else {
            print("❌ [DEBUG] 所有 POI 都已搜刮")
        }
    }

    /// 处理进入 POI 地理围栏
    private func handlePOIRegionEntered(regionId: String) {
        // 检查是否正在探索
        guard isExploring else { return }

        // 检查是否已搜刮
        guard !scavengedPOIIds.contains(regionId) else {
            print("ℹ️ [POI] 该 POI 已搜刮过，跳过")
            return
        }

        // 查找对应的 POI
        guard let poi = nearbyPOIs.first(where: { $0.id == regionId }) else {
            print("⚠️ [POI] 未找到对应的 POI: \(regionId)")
            return
        }

        // 显示搜刮弹窗
        showPOIScavengePopup(poi: poi)
    }

    /// 手动检测 POI 接近（位置更新时触发，作为定时器的补充）
    private func checkPOIProximity(userLocation: CLLocationCoordinate2D) {
        // 已由定时器主导检测，此方法作为位置更新时的快速检测
        // 检查是否正在探索
        guard isExploring else { return }

        // 如果已有弹窗显示，跳过检测
        guard !showScavengePopup else { return }

        // 如果没有 POI，跳过
        guard !nearbyPOIs.isEmpty else { return }

        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)

        // 遍历所有 POI，检查是否有接近的
        for poi in nearbyPOIs {
            // 跳过已搜刮的
            guard !scavengedPOIIds.contains(poi.id) else { continue }

            let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
            let distance = userCLLocation.distance(from: poiLocation)

            // 如果在范围内（100米）
            if distance <= geofenceRadius {
                print("📍 [POI] 位置更新检测到接近: \(poi.name)（距离: \(Int(distance))m）")
                showPOIScavengePopup(poi: poi)
                return  // 一次只显示一个弹窗
            }
        }
    }

    /// 显示 POI 搜刮弹窗
    private func showPOIScavengePopup(poi: POI) {
        // 防止重复显示
        guard currentApproachingPOI?.id != poi.id else { return }

        print("🎯 [POI] 进入 POI 范围: \(poi.name)")

        currentApproachingPOI = poi
        showScavengePopup = true
    }

    /// 关闭搜刮弹窗
    func dismissScavengePopup() {
        showScavengePopup = false
        currentApproachingPOI = nil
    }

    /// 标记 POI 为已搜刮
    func markPOIAsScavenged(_ poiId: String) {
        scavengedPOIIds.insert(poiId)

        // 更新 POI 列表中的状态
        if let index = nearbyPOIs.firstIndex(where: { $0.id == poiId }) {
            nearbyPOIs[index].isScavenged = true
        }

        // 关闭弹窗
        dismissScavengePopup()

        print("✅ [POI] 已标记为已搜刮: \(poiId)")
    }

    /// 生成搜刮物品
    /// - Returns: 获得的物品列表
    func generateScavengeItems() async -> [ObtainedItem] {
        // 随机数量：1-3件
        let count = Int.random(in: 1...3)

        // 使用 RewardGenerator 的物品生成逻辑
        let rewardResult = await RewardGenerator.shared.generateReward(distance: 500)  // 使用银级概率

        // 取前 count 个物品
        let items = Array(rewardResult.items.prefix(count))

        print("🎁 [POI] 生成 \(items.count) 件搜刮物品")
        for item in items {
            print("   - \(item.itemName) x\(item.quantity)")
        }

        return items
    }
}
