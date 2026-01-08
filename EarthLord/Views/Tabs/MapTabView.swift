//
//  MapTabView.swift
//  EarthLord
//
//  地图页面
//  显示真实地图、用户定位、路径追踪、末世废土风格
//

import SwiftUI
import MapKit

// MARK: - 地图标签页视图

struct MapTabView: View {

    // MARK: - 状态属性

    /// 定位管理器（从环境对象获取）
    @EnvironmentObject var locationManager: LocationManager

    /// 用户位置（用于传递给地图）
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser = false

    /// 是否显示权限提示
    @State private var showPermissionAlert = false

    /// 是否显示验证结果横幅
    @State private var showValidationBanner = false

    /// 是否正在上传
    @State private var isUploading = false

    /// 错误信息
    @State private var errorMessage: String?

    /// 是否显示错误提示
    @State private var showErrorAlert = false

    /// 成功信息
    @State private var successMessage: String?

    /// 是否显示成功提示
    @State private var showSuccessAlert = false

    /// 领地管理器
    private let territoryManager = TerritoryManager.shared

    /// 已加载的领地列表
    @State private var territories: [Territory] = []

    /// 领地数据版本号（强制触发地图更新）
    @State private var territoriesVersion: Int = 0

    /// 当前用户 ID（使用设备标识符）
    @State private var currentUserId: String = DeviceIdentifier.shared.getUserId()

    // MARK: - Day 19: 碰撞检测状态

    /// 碰撞检测定时器
    @State private var collisionCheckTimer: Timer?

    /// 碰撞警告消息
    @State private var collisionWarning: String?

    /// 是否显示碰撞警告
    @State private var showCollisionWarning = false

    /// 碰撞警告级别
    @State private var collisionWarningLevel: WarningLevel = .safe

    /// 是否正在刷新数据
    @State private var isRefreshing = false

    // MARK: - 主视图

    var body: some View {
        ZStack {
            // 地图视图
            MapViewRepresentable(
                userLocation: $userLocation,
                hasLocatedUser: $hasLocatedUser,
                trackingPath: $locationManager.pathCoordinates,
                pathUpdateVersion: locationManager.pathUpdateVersion,
                isTracking: locationManager.isTracking,
                isPathClosed: locationManager.isPathClosed,
                territories: territories,
                territoriesVersion: territoriesVersion,
                currentUserId: currentUserId
            )
            .ignoresSafeArea()

            // 顶部标题栏和速度警告
            VStack(spacing: 0) {
                headerView

                // 速度警告横幅
                if let warning = locationManager.speedWarning {
                    speedWarningBanner(warning: warning)
                }

                Spacer()
            }

            // 验证结果横幅
            if showValidationBanner {
                validationResultBanner
            }

            // Day 19: 碰撞警告横幅（分级颜色）
            if showCollisionWarning, let warning = collisionWarning {
                collisionWarningBanner(message: warning, level: collisionWarningLevel)
            }

            // 权限被拒绝时显示提示卡片
            if locationManager.isDenied {
                permissionDeniedCard
            }

            // 右下角按钮组
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        // 确认登记按钮（只在验证通过时显示）
                        if locationManager.territoryValidationPassed {
                            confirmTerritoryButton
                        }

                        // 圈地按钮
                        trackingButton

                        // 定位按钮
                        locationButton
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .onAppear {
            // 页面出现时请求权限和开始定位
            setupLocation()

            // 加载所有领地
            Task {
                await loadTerritories()
            }
        }
        .onReceive(locationManager.$isPathClosed) { isClosed in
            // 监听闭环状态，闭环后根据验证结果显示横幅
            if isClosed {
                // 闭环后延迟一点点，等待验证结果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        showValidationBanner = true
                    }
                    // 3 秒后自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showValidationBanner = false
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // 应用恢复到前台时自动刷新领地数据
            TerritoryLogger.shared.log("应用恢复前台，自动刷新数据", type: .info)
            Task {
                await refreshData()
            }
        }
        .alert("上传失败", isPresented: $showErrorAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
        .alert("上传成功", isPresented: $showSuccessAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(successMessage ?? "领地登记成功！")
        }
    }

    // MARK: - 子视图

    /// 顶部标题栏
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("地图")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                if let location = userLocation {
                    // 显示当前坐标
                    Text(String(format: "%.6f, %.6f", location.latitude, location.longitude))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.primary)
                } else {
                    Text("获取位置中...")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            Spacer()

            // 刷新按钮
            Button(action: {
                Task {
                    await refreshData()
                }
            }) {
                if isRefreshing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .disabled(isRefreshing)
            .padding(.trailing, 12)

            // 权限状态指示器
            permissionStatusIndicator
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [
                    ApocalypseTheme.background.opacity(0.95),
                    ApocalypseTheme.background.opacity(0.7),
                    ApocalypseTheme.background.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    /// 权限状态指示器
    private var permissionStatusIndicator: some View {
        Group {
            if locationManager.isAuthorized {
                // 已授权：绿色圆点
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
            } else if locationManager.isDenied {
                // 被拒绝：红色圆点
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
            } else {
                // 未决定：黄色圆点
                Circle()
                    .fill(ApocalypseTheme.warning)
                    .frame(width: 10, height: 10)
            }
        }
    }

    /// 确认登记按钮
    private var confirmTerritoryButton: some View {
        Button(action: {
            Task {
                await uploadCurrentTerritory()
            }
        }) {
            HStack(spacing: 8) {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                }

                Text(isUploading ? "上传中..." : "确认登记领地")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.green)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
        }
        .disabled(isUploading)
    }

    /// 圈地按钮
    private var trackingButton: some View {
        Button(action: {
            toggleTracking()
        }) {
            HStack(spacing: 8) {
                // 图标
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.system(size: 16))

                // 文字
                Text(locationManager.isTracking ? "停止圈地" : "开始圈地")
                    .font(.system(size: 14, weight: .semibold))

                // 点数（追踪中才显示）
                if locationManager.isTracking {
                    Text("(\(locationManager.pathCoordinates.count))")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(locationManager.isTracking ? Color.red : ApocalypseTheme.primary)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
        }
    }

    /// 定位按钮
    private var locationButton: some View {
        Button(action: {
            recenterMap()
        }) {
            Image(systemName: "location.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(ApocalypseTheme.primary)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                )
        }
    }

    /// 权限被拒绝提示卡片
    private var permissionDeniedCard: some View {
        VStack(spacing: 16) {
            // 图标
            Image(systemName: "location.slash.fill")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.warning)

            // 标题
            Text("无法获取位置")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 说明
            Text("《地球新主》需要定位权限来显示您在末日世界中的坐标")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // 前往设置按钮
            Button(action: {
                openSettings()
            }) {
                Text("前往设置")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .padding(.horizontal, 30)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 40)
    }

    /// 速度警告横幅
    private func speedWarningBanner(warning: String) -> some View {
        HStack(spacing: 12) {
            // 警告图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)

            // 警告文字
            Text(warning)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            // 根据是否还在追踪显示不同背景色
            RoundedRectangle(cornerRadius: 0)
                .fill(locationManager.isTracking ? Color.orange : Color.red)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: locationManager.speedWarning != nil)
    }

    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.body)

            if locationManager.territoryValidationPassed {
                Text("圈地成功！领地面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(locationManager.territoryValidationError ?? "验证失败")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(locationManager.territoryValidationPassed ? Color.green : Color.red)
        .padding(.top, 50)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showValidationBanner)
    }

    /// Day 19: 碰撞警告横幅（分级颜色）
    private func collisionWarningBanner(message: String, level: WarningLevel) -> some View {
        // 根据级别确定颜色
        let backgroundColor: Color
        switch level {
        case .safe:
            backgroundColor = .green
        case .caution:
            backgroundColor = .yellow
        case .warning:
            backgroundColor = .orange
        case .danger, .violation:
            backgroundColor = .red
        }

        // 根据级别确定文字颜色（黄色背景用黑字）
        let textColor: Color = (level == .caution) ? .black : .white

        // 根据级别确定图标
        let iconName = (level == .violation) ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return VStack {
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 18))

                Text(message)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(backgroundColor.opacity(0.95))
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .padding(.top, 120)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: showCollisionWarning)
    }

    // MARK: - 辅助方法

    /// 设置定位
    private func setupLocation() {
        // 如果未授权，请求权限
        if !locationManager.isAuthorized && !locationManager.isDenied {
            locationManager.requestPermission()
        }

        // 如果已授权，开始定位
        if locationManager.isAuthorized {
            locationManager.startUpdatingLocation()
        }
    }

    /// 切换追踪状态
    private func toggleTracking() {
        if locationManager.isTracking {
            // Day 19: 停止追踪 + 完全停止碰撞监控
            stopCollisionMonitoring()
            locationManager.stopPathTracking()
        } else {
            // Day 19: 开始圈地前检测起始点
            startClaimingWithCollisionCheck()
        }
    }

    /// 重新居中地图到用户位置
    private func recenterMap() {
        // 如果未授权，提示用户
        if !locationManager.isAuthorized {
            showPermissionAlert = true
            return
        }

        // 重置首次定位标志，允许地图重新居中
        hasLocatedUser = false
    }

    /// 打开系统设置
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    /// 上传当前领地
    private func uploadCurrentTerritory() async {
        // ⚠️ 再次检查验证状态
        guard locationManager.territoryValidationPassed else {
            errorMessage = "领地验证未通过，无法上传"
            showErrorAlert = true
            return
        }

        // 检查路径是否为空
        guard !locationManager.pathCoordinates.isEmpty else {
            errorMessage = "路径数据为空，无法上传"
            showErrorAlert = true
            return
        }

        // 设置上传状态
        isUploading = true

        do {
            // 上传领地
            try await territoryManager.uploadTerritory(
                coordinates: locationManager.pathCoordinates,
                area: locationManager.calculatedArea,
                startTime: Date()
            )

            // 上传成功
            successMessage = "领地登记成功！面积: \(String(format: "%.0f", locationManager.calculatedArea))m²"
            showSuccessAlert = true

            // Day 19: 停止碰撞监控
            stopCollisionMonitoring()

            // ⚠️ 关键：上传成功后必须停止追踪！
            locationManager.stopPathTracking()

            // ⚠️ 关键：刷新领地列表
            await loadTerritories()

        } catch {
            // 上传失败
            errorMessage = "上传失败: \(error.localizedDescription)"
            showErrorAlert = true
        }

        // 恢复上传状态
        isUploading = false
    }

    /// 加载所有领地
    private func loadTerritories() async {
        do {
            territories = try await territoryManager.loadAllTerritories()
            territoriesVersion += 1  // 强制触发地图更新
            TerritoryLogger.shared.log("加载了 \(territories.count) 个领地（版本: \(territoriesVersion)）", type: .info)
        } catch {
            TerritoryLogger.shared.log("加载领地失败: \(error.localizedDescription)", type: .error)
        }
    }

    /// 刷新所有数据（领地列表 + 用户ID）
    private func refreshData() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        TerritoryLogger.shared.log("正在刷新数据...", type: .info)

        // 重新获取用户 ID（虽然通常不变，但以防万一）
        currentUserId = DeviceIdentifier.shared.getUserId()

        // 重新加载领地列表
        await loadTerritories()

        // 添加短暂延迟，让用户看到刷新动画
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒

        isRefreshing = false
        TerritoryLogger.shared.log("数据刷新完成", type: .success)
    }

    // MARK: - Day 19: 碰撞检测方法

    /// Day 19: 带碰撞检测的开始圈地
    private func startClaimingWithCollisionCheck() {
        guard let location = userLocation else {
            TerritoryLogger.shared.log("无法获取当前位置", type: .error)
            return
        }

        // 异步检测起始点是否在他人领地内
        Task {
            do {
                let result = try await territoryManager.checkPointCollision(
                    location: location,
                    currentUserId: currentUserId
                )

                if result.hasCollision {
                    // 起点在他人领地内，显示错误并震动
                    collisionWarning = result.message
                    collisionWarningLevel = .violation
                    showCollisionWarning = true

                    // 错误震动
                    let generator = UINotificationFeedbackGenerator()
                    generator.prepare()
                    generator.notificationOccurred(.error)

                    TerritoryLogger.shared.log("起点碰撞：阻止圈地", type: .error)

                    // 3秒后隐藏警告
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showCollisionWarning = false
                        collisionWarning = nil
                        collisionWarningLevel = .safe
                    }

                    return
                }

                // 起点安全，开始圈地
                TerritoryLogger.shared.log("起始点安全，开始圈地", type: .info)
                locationManager.startPathTracking()
                startCollisionMonitoring()

            } catch {
                TerritoryLogger.shared.log("起点碰撞检测失败: \(error.localizedDescription)", type: .error)
                // 出错时也允许开始圈地（容错）
                locationManager.startPathTracking()
                startCollisionMonitoring()
            }
        }
    }

    /// Day 19: 启动碰撞检测监控
    private func startCollisionMonitoring() {
        // 先停止已有定时器
        stopCollisionCheckTimer()

        // 每 10 秒检测一次
        collisionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [self] _ in
            performCollisionCheck()
        }

        TerritoryLogger.shared.log("碰撞检测定时器已启动", type: .info)
    }

    /// Day 19: 仅停止定时器（不清除警告状态）
    private func stopCollisionCheckTimer() {
        collisionCheckTimer?.invalidate()
        collisionCheckTimer = nil
        TerritoryLogger.shared.log("碰撞检测定时器已停止", type: .info)
    }

    /// Day 19: 完全停止碰撞监控（停止定时器 + 清除警告）
    private func stopCollisionMonitoring() {
        stopCollisionCheckTimer()
        // 清除警告状态
        showCollisionWarning = false
        collisionWarning = nil
        collisionWarningLevel = .safe
    }

    /// Day 19: 执行碰撞检测
    private func performCollisionCheck() {
        guard locationManager.isTracking else {
            return
        }

        let path = locationManager.pathCoordinates
        guard path.count >= 2 else { return }

        // 异步执行碰撞检测
        Task {
            do {
                let result = try await territoryManager.checkPathCollisionComprehensive(
                    path: path,
                    currentUserId: currentUserId
                )

                // 根据预警级别处理
                switch result.warningLevel {
                case .safe:
                    // 安全，隐藏警告横幅
                    showCollisionWarning = false
                    collisionWarning = nil
                    collisionWarningLevel = .safe

                case .caution:
                    // 注意（50-100m）- 黄色横幅 + 轻震 1 次
                    collisionWarning = result.message
                    collisionWarningLevel = .caution
                    showCollisionWarning = true
                    triggerHapticFeedback(level: .caution)

                case .warning:
                    // 警告（25-50m）- 橙色横幅 + 中震 2 次
                    collisionWarning = result.message
                    collisionWarningLevel = .warning
                    showCollisionWarning = true
                    triggerHapticFeedback(level: .warning)

                case .danger:
                    // 危险（<25m）- 红色横幅 + 强震 3 次
                    collisionWarning = result.message
                    collisionWarningLevel = .danger
                    showCollisionWarning = true
                    triggerHapticFeedback(level: .danger)

                case .violation:
                    // 违规处理 - 必须先显示横幅，再停止！

                    // 1. 先设置警告状态（让横幅显示出来）
                    collisionWarning = result.message
                    collisionWarningLevel = .violation
                    showCollisionWarning = true

                    // 2. 触发震动
                    triggerHapticFeedback(level: .violation)

                    // 3. 只停止定时器，不清除警告状态！
                    stopCollisionCheckTimer()

                    // 4. 停止圈地追踪
                    locationManager.stopPathTracking()

                    TerritoryLogger.shared.log("碰撞违规，自动停止圈地", type: .error)

                    // 5. 5秒后再清除警告横幅
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        showCollisionWarning = false
                        collisionWarning = nil
                        collisionWarningLevel = .safe
                    }
                }

            } catch {
                TerritoryLogger.shared.log("碰撞检测失败: \(error.localizedDescription)", type: .error)
            }
        }
    }

    /// Day 19: 触发震动反馈
    private func triggerHapticFeedback(level: WarningLevel) {
        switch level {
        case .safe:
            // 安全：无震动
            break

        case .caution:
            // 注意：轻震 1 次
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)

        case .warning:
            // 警告：中震 2 次
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }

        case .danger:
            // 危险：强震 3 次
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            generator.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                generator.impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                generator.impactOccurred()
            }

        case .violation:
            // 违规：错误震动
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }
}

// MARK: - 预览

#Preview {
    MapTabView()
        .environmentObject(LocationManager())
}
