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

    /// 当前用户 ID（使用设备标识符）
    @State private var currentUserId: String = DeviceIdentifier.shared.getUserId()

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
            // 停止追踪
            locationManager.stopPathTracking()
        } else {
            // 开始追踪
            locationManager.startPathTracking()
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
            TerritoryLogger.shared.log("加载了 \(territories.count) 个领地", type: .info)
        } catch {
            TerritoryLogger.shared.log("加载领地失败: \(error.localizedDescription)", type: .error)
        }
    }
}

// MARK: - 预览

#Preview {
    MapTabView()
        .environmentObject(LocationManager())
}
