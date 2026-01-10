//
//  ResourcesTabView.swift
//  EarthLord
//
//  资源模块主入口页面
//  包含POI、背包、已购、领地、交易等功能
//

import SwiftUI

// MARK: - 资源标签页

struct ResourcesTabView: View {

    // MARK: - 状态属性

    /// 当前选中的分段
    @State private var selectedSegment: ResourceSegment = .poi

    /// 交易开关状态（假数据）
    @State private var isTradingEnabled = false

    // MARK: - 主视图

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 交易开关栏
                tradingToggleBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.cardBackground)

                // 分段选择器
                segmentedPicker
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                // 内容区域
                contentView
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("资源")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - 子视图

    /// 交易开关栏
    private var tradingToggleBar: some View {
        HStack(spacing: 12) {
            // 图标和文字
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(isTradingEnabled ? ApocalypseTheme.success : ApocalypseTheme.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("交易功能")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text(isTradingEnabled ? "已开启" : "已关闭")
                        .font(.system(size: 12))
                        .foregroundColor(isTradingEnabled ? ApocalypseTheme.success : ApocalypseTheme.textSecondary)
                }
            }

            Spacer()

            // 开关
            Toggle("", isOn: $isTradingEnabled)
                .labelsHidden()
                .tint(ApocalypseTheme.success)
        }
    }

    /// 分段选择器
    private var segmentedPicker: some View {
        Picker("资源分段", selection: $selectedSegment) {
            ForEach(ResourceSegment.allCases, id: \.self) { segment in
                Text(segment.title)
                    .tag(segment)
            }
        }
        .pickerStyle(.segmented)
    }

    /// 内容视图
    @ViewBuilder
    private var contentView: some View {
        switch selectedSegment {
        case .poi:
            // POI列表页面
            POIListView()

        case .backpack:
            // 背包页面
            BackpackView()

        case .purchased:
            // 已购买（占位）
            placeholderView(
                icon: "bag.fill",
                title: "已购买",
                description: "查看你购买的所有物品"
            )

        case .territory:
            // 领地资源（占位）
            placeholderView(
                icon: "flag.fill",
                title: "领地资源",
                description: "管理你的领地资源"
            )

        case .trading:
            // 交易市场（占位）
            placeholderView(
                icon: "arrow.left.arrow.right",
                title: "交易市场",
                description: "与其他玩家交易物品"
            )
        }
    }

    /// 占位视图
    private func placeholderView(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 20) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 标题
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 描述
            Text(description)
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            // 开发中提示
            Text("功能开发中")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ApocalypseTheme.warning)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ApocalypseTheme.warning.opacity(0.15))
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ApocalypseTheme.background)
    }
}

// MARK: - 资源分段枚举

enum ResourceSegment: String, CaseIterable {
    case poi = "POI"
    case backpack = "背包"
    case purchased = "已购"
    case territory = "领地"
    case trading = "交易"

    var title: String {
        return self.rawValue
    }
}

// MARK: - 预览

#Preview {
    ResourcesTabView()
}
