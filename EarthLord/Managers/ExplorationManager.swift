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

        // 8. 重置状态
        isExploring = false
        self.startTime = nil
        self.sessionId = nil
        currentDistance = 0
        currentDuration = 0
        speedViolationStartTime = nil

        // 9. 构建返回数据
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
}
