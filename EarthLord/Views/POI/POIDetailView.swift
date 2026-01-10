//
//  POIDetailView.swift
//  EarthLord
//
//  POI详情页面
//  显示POI的详细信息和操作按钮
//

import SwiftUI

// MARK: - POI详情视图

struct POIDetailView: View {

    // MARK: - 属性

    /// POI数据
    let poi: POI

    /// 是否显示探索结果
    @State private var showExplorationResult = false

    /// 模拟距离（米）
    private let mockDistance: Double = 350.0

    // MARK: - 主视图

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 顶部大图区域
                    headerImageSection

                    // 内容区域
                    VStack(spacing: 16) {
                        // 描述文字
                        if !poi.description.isEmpty {
                            descriptionSection
                        }

                        // 信息区域
                        informationSection

                        // 操作按钮区域
                        actionButtonsSection

                        // 底部占位
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExplorationResult) {
            ExplorationResultView()
        }
    }

    // MARK: - 子视图

    /// 顶部大图区域
    private var headerImageSection: some View {
        let poiStyle = POIStyle.style(for: poi.type)

        return GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 渐变背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        poiStyle.color.opacity(0.8),
                        poiStyle.color.opacity(0.4)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // 大图标
                Image(systemName: poiStyle.iconName)
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 60)

                // 底部遮罩和文字
                VStack(spacing: 8) {
                    // POI名称
                    Text(poi.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    // POI类型
                    HStack(spacing: 6) {
                        Image(systemName: poiStyle.iconName)
                            .font(.system(size: 14))

                        Text(poi.type.rawValue)
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0),
                            Color.black.opacity(0.7)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(height: geometry.size.width * 0.8)
        }
        .frame(height: 300)
    }

    /// 描述文字区域
    private var descriptionSection: some View {
        ELCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.info)

                    Text("地点简介")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                Text(poi.description)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    /// 信息区域
    private var informationSection: some View {
        ELCard {
            VStack(spacing: 16) {
                // 标题
                HStack {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("地点信息")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()
                }

                Divider()

                // 信息列表
                VStack(spacing: 14) {
                    // 距离
                    infoRow(
                        icon: "location.fill",
                        iconColor: ApocalypseTheme.primary,
                        title: "距离",
                        value: String(format: "%.0f 米", mockDistance)
                    )

                    // 物资状态
                    infoRow(
                        icon: "shippingbox.fill",
                        iconColor: poi.hasResources ? ApocalypseTheme.warning : ApocalypseTheme.textSecondary,
                        title: "物资状态",
                        value: poi.hasResources ? "有物资" : "已清空",
                        valueColor: poi.hasResources ? ApocalypseTheme.warning : ApocalypseTheme.textSecondary
                    )

                    // 危险等级
                    let dangerInfo = getDangerLevelInfo(level: poi.dangerLevel)
                    infoRow(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: dangerInfo.color,
                        title: "危险等级",
                        value: dangerInfo.text,
                        valueColor: dangerInfo.color
                    )

                    // 发现状态
                    infoRow(
                        icon: "eye.fill",
                        iconColor: poi.status == .discovered ? ApocalypseTheme.success : ApocalypseTheme.textSecondary,
                        title: "发现状态",
                        value: poi.status.rawValue,
                        valueColor: poi.status == .discovered ? ApocalypseTheme.success : ApocalypseTheme.textSecondary
                    )

                    // 来源
                    infoRow(
                        icon: "mappin.and.ellipse",
                        iconColor: ApocalypseTheme.info,
                        title: "来源",
                        value: "地图数据"
                    )

                    // 搜索时间（如果有）
                    if let searchedAt = poi.searchedAt {
                        infoRow(
                            icon: "clock.fill",
                            iconColor: ApocalypseTheme.textSecondary,
                            title: "搜索时间",
                            value: formatDate(searchedAt)
                        )
                    }
                }
            }
            .padding(16)
        }
    }

    /// 信息行
    private func infoRow(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        valueColor: Color? = nil
    ) -> some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)

            // 标题
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            // 值
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(valueColor ?? ApocalypseTheme.textPrimary)
        }
    }

    /// 操作按钮区域
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // 主按钮：搜寻此POI
            mainActionButton

            // 两个小按钮
            HStack(spacing: 12) {
                // 标记已发现
                secondaryButton(
                    title: "标记已发现",
                    icon: "eye.fill",
                    color: ApocalypseTheme.success
                ) {
                    handleMarkAsDiscovered()
                }

                // 标记无物资
                secondaryButton(
                    title: "标记无物资",
                    icon: "xmark.circle.fill",
                    color: ApocalypseTheme.textSecondary
                ) {
                    handleMarkAsEmpty()
                }
            }
        }
    }

    /// 主操作按钮
    private var mainActionButton: some View {
        let isDisabled = !poi.hasResources
        let buttonColor = isDisabled ? ApocalypseTheme.textSecondary : Color.orange

        return Button(action: {
            if !isDisabled {
                handleExplore()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: isDisabled ? "xmark.circle.fill" : "magnifyingglass.circle.fill")
                    .font(.system(size: 20))

                Text(isDisabled ? "此地点已清空" : "搜寻此POI")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        buttonColor,
                        buttonColor.opacity(0.8)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: isDisabled ? .clear : buttonColor.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isDisabled)
    }

    /// 次要按钮
    private func secondaryButton(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))

                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - 辅助方法

    /// 获取危险等级信息
    private func getDangerLevelInfo(level: Int) -> (text: String, color: Color) {
        switch level {
        case 1:
            return ("安全", ApocalypseTheme.success)
        case 2:
            return ("低危", Color.green)
        case 3:
            return ("中危", ApocalypseTheme.warning)
        case 4:
            return ("高危", Color.orange)
        case 5:
            return ("极危", ApocalypseTheme.danger)
        default:
            return ("未知", ApocalypseTheme.textSecondary)
        }
    }

    /// 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }

    /// 处理探索操作
    private func handleExplore() {
        print("开始搜寻POI: \(poi.name)")
        showExplorationResult = true
    }

    /// 处理标记已发现
    private func handleMarkAsDiscovered() {
        print("标记为已发现: \(poi.name)")
        // TODO: 更新POI状态
    }

    /// 处理标记无物资
    private func handleMarkAsEmpty() {
        print("标记为无物资: \(poi.name)")
        // TODO: 更新POI物资状态
    }
}

// MARK: - 预览

#Preview {
    NavigationView {
        POIDetailView(poi: MockExplorationData.shared.mockPOIs[0])
    }
}

#Preview("已清空POI") {
    NavigationView {
        POIDetailView(poi: MockExplorationData.shared.mockPOIs[1])
    }
}
