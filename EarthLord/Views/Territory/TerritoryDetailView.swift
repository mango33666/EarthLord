//
//  TerritoryDetailView.swift
//  EarthLord
//
//  领地详情页面
//  显示领地地图预览、详细信息、删除功能、未来功能占位
//

import SwiftUI
import MapKit

// MARK: - 领地详情视图

struct TerritoryDetailView: View {

    // MARK: - 属性

    /// 领地数据
    let territory: Territory

    /// 删除回调
    let onDelete: () -> Void

    /// 环境变量：用于关闭页面
    @Environment(\.dismiss) var dismiss

    /// 领地管理器
    private let territoryManager = TerritoryManager.shared

    /// 是否显示删除确认
    @State private var showDeleteConfirmation = false

    /// 是否正在删除
    @State private var isDeleting = false

    /// 错误信息
    @State private var errorMessage: String?

    /// 是否显示错误提示
    @State private var showErrorAlert = false

    /// 地图区域
    @State private var mapRegion: MKCoordinateRegion

    // MARK: - 初始化

    init(territory: Territory, onDelete: @escaping () -> Void) {
        self.territory = territory
        self.onDelete = onDelete

        // 计算领地的中心点和范围
        let coordinates = territory.toCoordinates()
        if let firstCoord = coordinates.first {
            // 计算边界框
            var minLat = firstCoord.latitude
            var maxLat = firstCoord.latitude
            var minLon = firstCoord.longitude
            var maxLon = firstCoord.longitude

            for coord in coordinates {
                minLat = min(minLat, coord.latitude)
                maxLat = max(maxLat, coord.latitude)
                minLon = min(minLon, coord.longitude)
                maxLon = max(maxLon, coord.longitude)
            }

            // 计算中心点
            let centerLat = (minLat + maxLat) / 2
            let centerLon = (minLon + maxLon) / 2

            // 计算跨度（留一些边距）
            let latDelta = (maxLat - minLat) * 1.5
            let lonDelta = (maxLon - minLon) * 1.5

            _mapRegion = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.005), longitudeDelta: max(lonDelta, 0.005))
            ))
        } else {
            // 默认区域
            _mapRegion = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }

    // MARK: - 主视图

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 地图预览
                    mapPreviewSection

                    // 基本信息
                    basicInfoSection

                    // 统计信息
                    statisticsSection

                    // 未来功能占位
                    futureFeaturesSection

                    // 删除按钮
                    deleteButton

                    // 底部占位
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(ApocalypseTheme.background.ignoresSafeArea())
            .navigationTitle(territory.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .alert("删除领地", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    deleteTerritory()
                }
            } message: {
                Text("确定要删除这个领地吗？此操作不可恢复。")
            }
            .alert("删除失败", isPresented: $showErrorAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
        }
    }

    // MARK: - 子视图

    /// 地图预览区域
    private var mapPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            sectionTitle(icon: "map.fill", title: "领地范围")

            // 地图占位图（简化版，避免使用已废弃的 API）
            ZStack {
                // 背景色
                Color.gray.opacity(0.2)

                VStack(spacing: 12) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 50))
                        .foregroundColor(ApocalypseTheme.primary.opacity(0.5))

                    Text("领地地图预览")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Text("中心坐标: \(String(format: "%.4f, %.4f", mapRegion.center.latitude, mapRegion.center.longitude))")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .frame(height: 250)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 1)
            )

            // 地图提示
            Text("提示：完整的领地边界将在地图页面显示")
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.horizontal, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
    }

    /// 基本信息区域
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            sectionTitle(icon: "info.circle.fill", title: "基本信息")

            // 信息列表
            VStack(spacing: 12) {
                infoRow(label: "领地名称", value: territory.displayName)
                infoRow(label: "领地 ID", value: String(territory.id.prefix(8)) + "...")
                infoRow(label: "创建时间", value: territory.formattedCreatedAt)

                if let startedAt = territory.startedAt {
                    infoRow(label: "开始圈地", value: formatDate(startedAt))
                }

                if let completedAt = territory.completedAt {
                    infoRow(label: "完成圈地", value: formatDate(completedAt))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
    }

    /// 统计信息区域
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            sectionTitle(icon: "chart.bar.fill", title: "统计数据")

            // 统计列表
            VStack(spacing: 12) {
                statisticRow(icon: "square.fill", label: "领地面积", value: territory.formattedArea, color: ApocalypseTheme.primary)

                if let pointCount = territory.pointCount {
                    statisticRow(icon: "location.fill", label: "路径点数", value: "\(pointCount) 个", color: ApocalypseTheme.info)
                }

                statisticRow(icon: "flag.fill", label: "领地状态", value: "已激活", color: .green)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
    }

    /// 未来功能区域
    private var futureFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            sectionTitle(icon: "lightbulb.fill", title: "更多功能")

            // 功能列表
            VStack(spacing: 12) {
                featurePlaceholder(icon: "pencil", title: "重命名领地", subtitle: "即将推出")
                featurePlaceholder(icon: "building.2.fill", title: "建筑系统", subtitle: "即将推出")
                featurePlaceholder(icon: "arrow.triangle.2.circlepath", title: "领地交易", subtitle: "即将推出")
                featurePlaceholder(icon: "person.3.fill", title: "联盟系统", subtitle: "即将推出")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
    }

    /// 删除按钮
    private var deleteButton: some View {
        Button(action: {
            showDeleteConfirmation = true
        }) {
            HStack(spacing: 8) {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16))
                }

                Text(isDeleting ? "删除中..." : "删除领地")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            )
        }
        .disabled(isDeleting)
    }

    // MARK: - 辅助视图

    /// 区域标题
    private func sectionTitle(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.primary)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    /// 信息行
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(.horizontal, 8)
    }

    /// 统计行
    private func statisticRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 30)

            Text(label)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding(.horizontal, 8)
    }

    /// 功能占位
    private func featurePlaceholder(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.6))
            }

            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
        }
        .padding(.horizontal, 8)
    }

    // MARK: - 辅助方法

    /// 格式化日期
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "未知" }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return displayFormatter.string(from: date)
    }

    /// 删除领地
    private func deleteTerritory() {
        isDeleting = true

        Task {
            do {
                try await territoryManager.deleteTerritory(territoryId: territory.id)

                // 删除成功，关闭页面并通知父视图
                DispatchQueue.main.async {
                    onDelete()
                    dismiss()
                }
            } catch {
                // 删除失败，显示错误
                DispatchQueue.main.async {
                    errorMessage = "删除失败: \(error.localizedDescription)"
                    showErrorAlert = true
                    isDeleting = false
                }
            }
        }
    }
}

// MARK: - 预览

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: "test-id-123456",
            userId: "test-user",
            name: "测试领地",
            path: [
                ["lat": 39.9, "lon": 116.4],
                ["lat": 39.91, "lon": 116.4],
                ["lat": 39.91, "lon": 116.41],
                ["lat": 39.9, "lon": 116.41]
            ],
            area: 1234.5,
            pointCount: 4,
            isActive: true,
            startedAt: "2024-01-08T10:00:00Z",
            completedAt: "2024-01-08T10:05:00Z",
            createdAt: "2024-01-08T10:05:00Z"
        ),
        onDelete: {}
    )
}
