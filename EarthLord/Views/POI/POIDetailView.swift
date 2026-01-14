//
//  POIDetailView.swift
//  EarthLord
//
//  POI详情页面
//  显示POI的详细信息和操作按钮
//

import SwiftUI
import CoreLocation

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
        let poiStyle = POIStyle.style(for: poi.category)

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

                        Text(poi.category.wastelandName)
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

                    // 类型
                    infoRow(
                        icon: poi.category.systemImage,
                        iconColor: POIStyle.style(for: poi.category).color,
                        title: "类型",
                        value: poi.category.wastelandName
                    )

                    // 搜刮状态
                    infoRow(
                        icon: poi.isScavenged ? "checkmark.circle.fill" : "circle",
                        iconColor: poi.isScavenged ? ApocalypseTheme.textSecondary : ApocalypseTheme.warning,
                        title: "搜刮状态",
                        value: poi.isScavenged ? "已搜刮" : "未搜刮",
                        valueColor: poi.isScavenged ? ApocalypseTheme.textSecondary : ApocalypseTheme.warning
                    )

                    // 来源
                    infoRow(
                        icon: "mappin.and.ellipse",
                        iconColor: ApocalypseTheme.info,
                        title: "来源",
                        value: "地图数据"
                    )

                    // 坐标
                    infoRow(
                        icon: "globe",
                        iconColor: ApocalypseTheme.textSecondary,
                        title: "坐标",
                        value: String(format: "%.4f, %.4f", poi.coordinate.latitude, poi.coordinate.longitude)
                    )
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
            // 主按钮：搜刮此POI
            mainActionButton
        }
    }

    /// 主操作按钮
    private var mainActionButton: some View {
        let isDisabled = poi.isScavenged
        let buttonColor = isDisabled ? ApocalypseTheme.textSecondary : Color.orange

        return Button(action: {
            if !isDisabled {
                handleExplore()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: isDisabled ? "checkmark.circle.fill" : "hand.raised.fingers.spread.fill")
                    .font(.system(size: 20))

                Text(isDisabled ? "此地点已搜刮" : "搜刮此POI")
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

    // MARK: - 辅助方法

    /// 处理探索操作
    private func handleExplore() {
        print("开始搜刮POI: \(poi.name)")
        showExplorationResult = true
    }
}

// MARK: - 预览

#Preview {
    NavigationView {
        POIDetailView(poi: POI(
            id: "test-1",
            name: "沃尔玛超市（测试店）",
            coordinate: CLLocationCoordinate2D(latitude: 31.186565, longitude: 120.612623),
            category: .supermarket
        ))
    }
}

#Preview("已搜刮POI") {
    NavigationView {
        POIDetailView(poi: POI(
            id: "test-2",
            name: "东方医院（废墟）",
            coordinate: CLLocationCoordinate2D(latitude: 31.187000, longitude: 120.613000),
            category: .hospital,
            isScavenged: true
        ))
    }
}
