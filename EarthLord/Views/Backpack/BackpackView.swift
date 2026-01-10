//
//  BackpackView.swift
//  EarthLord
//
//  背包管理页面
//  显示物品列表、搜索、筛选、容量管理
//

import SwiftUI

// MARK: - 背包视图

struct BackpackView: View {

    // MARK: - 状态属性

    /// 测试数据
    private let mockData = MockExplorationData.shared

    /// 所有物品列表（带定义）
    @State private var allItems: [(item: InventoryItem, definition: ItemDefinition)] = []

    /// 显示的物品列表（筛选后）
    @State private var displayedItems: [(item: InventoryItem, definition: ItemDefinition)] = []

    /// 搜索文本
    @State private var searchText = ""

    /// 当前选中的筛选类型
    @State private var selectedFilter: ItemFilterType = .all

    /// 背包最大容量（升）
    private let maxCapacity: Double = 100.0

    /// 当前使用容量
    @State private var currentCapacity: Double = 0.0

    // MARK: - 主视图

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 容量状态卡
                capacityCard
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // 搜索框
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // 筛选工具栏
                filterToolbar
                    .padding(.top, 12)

                // 物品列表
                itemListView
                    .padding(.top, 12)
            }
        }
        .navigationTitle("背包")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(ApocalypseTheme.cardBackground, for: .navigationBar)
        .onAppear {
            loadItems()
        }
    }

    // MARK: - 子视图

    /// 容量状态卡
    private var capacityCard: some View {
        let percentage = currentCapacity / maxCapacity
        let capacityColor = getCapacityColor(percentage: percentage)
        let isWarning = percentage > 0.9

        return ELCard {
            VStack(spacing: 12) {
                // 标题和容量
                HStack {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("背包容量")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Text(String(format: "%.1f / %.0f", currentCapacity, maxCapacity))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(capacityColor)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentCapacity)
                }

                // 进度条
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ApocalypseTheme.textSecondary.opacity(0.2))
                            .frame(height: 12)

                        // 进度
                        RoundedRectangle(cornerRadius: 8)
                            .fill(capacityColor)
                            .frame(width: min(geometry.size.width * percentage, geometry.size.width), height: 12)
                            .animation(.easeInOut(duration: 0.3), value: percentage)
                    }
                }
                .frame(height: 12)

                // 警告文字
                if isWarning {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.danger)

                        Text("背包快满了！")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ApocalypseTheme.danger)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
    }

    /// 搜索框
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            TextField("搜索物品名称...", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .onChange(of: searchText) { _ in
                    applyFilter()
                }

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 筛选工具栏
    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ItemFilterType.allCases, id: \.self) { filterType in
                    filterButton(filterType: filterType)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    /// 筛选按钮
    private func filterButton(filterType: ItemFilterType) -> some View {
        let isSelected = selectedFilter == filterType

        return Button(action: {
            selectedFilter = filterType
            applyFilter()
        }) {
            HStack(spacing: 6) {
                Image(systemName: filterType.iconName)
                    .font(.system(size: 14))

                Text(filterType.title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.2), lineWidth: 1)
            )
        }
    }

    /// 物品列表视图
    private var itemListView: some View {
        ScrollView {
            VStack(spacing: 12) {
                if displayedItems.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // 物品卡片列表
                    ForEach(displayedItems, id: \.item.id) { itemPair in
                        itemCard(item: itemPair.item, definition: itemPair.definition)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity
                            ))
                    }
                }

                // 底部占位
                Color.clear.frame(height: 20)
            }
            .animation(.easeInOut(duration: 0.3), value: displayedItems.count)
            .padding(.horizontal, 16)
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // 图标
            Image(systemName: allItems.isEmpty ? "backpack" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 标题
            Text(allItems.isEmpty ? "背包空空如也" : "没有找到相关物品")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 描述
            if allItems.isEmpty {
                Text("去探索收集物资吧")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("试试调整搜索条件或切换分类")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
    }

    /// 物品卡片
    private func itemCard(item: InventoryItem, definition: ItemDefinition) -> some View {
        let categoryStyle = ItemCategoryStyle.style(for: definition.category)
        let rarityStyle = ItemRarityStyle.style(for: definition.rarity)

        return ELCard {
            HStack(spacing: 16) {
                // 左边：圆形图标
                Image(systemName: definition.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(categoryStyle.color)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(categoryStyle.color.opacity(0.15))
                    )

                // 中间：物品信息
                VStack(alignment: .leading, spacing: 6) {
                    // 物品名称
                    Text(definition.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)

                    // 数量和重量
                    HStack(spacing: 12) {
                        // 数量
                        Label(
                            "x\(item.quantity)",
                            systemImage: "number"
                        )
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                        // 重量
                        Label(
                            String(format: "%.1fkg", definition.weight * Double(item.quantity)),
                            systemImage: "scalemass"
                        )
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    // 标签行
                    HStack(spacing: 8) {
                        // 稀有度标签
                        rarityLabel(rarity: definition.rarity, style: rarityStyle)

                        // 品质标签（如果有）
                        if let quality = item.quality, definition.hasQuality {
                            qualityLabel(quality: quality)
                        }
                    }
                }

                Spacer()

                // 右边：操作按钮
                VStack(spacing: 8) {
                    // 使用按钮
                    actionButton(
                        title: "使用",
                        icon: "hand.tap.fill",
                        color: ApocalypseTheme.primary
                    ) {
                        handleUseItem(item: item, definition: definition)
                    }

                    // 存储按钮
                    actionButton(
                        title: "存储",
                        icon: "archivebox.fill",
                        color: ApocalypseTheme.info
                    ) {
                        handleStoreItem(item: item, definition: definition)
                    }
                }
            }
            .padding(12)
        }
    }

    /// 稀有度标签
    private func rarityLabel(rarity: ItemRarity, style: ItemRarityStyle) -> some View {
        Text(rarity.rawValue)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(style.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(style.color.opacity(0.15))
            )
    }

    /// 品质标签
    private func qualityLabel(quality: ItemQuality) -> some View {
        Text(quality.rawValue)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(ApocalypseTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(ApocalypseTheme.textSecondary.opacity(0.15))
            )
    }

    /// 操作按钮
    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))

                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(color)
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - 业务逻辑

    /// 加载物品数据
    private func loadItems() {
        // 从 MockExplorationData 加载物品
        allItems = mockData.mockInventoryItems.compactMap { inventoryItem in
            guard let definition = mockData.getItemDefinition(by: inventoryItem.itemId) else {
                return nil
            }
            return (inventoryItem, definition)
        }

        // 计算总容量
        currentCapacity = mockData.calculateTotalVolume()

        // 应用筛选
        applyFilter()
    }

    /// 应用筛选
    private func applyFilter() {
        var filtered = allItems

        // 分类筛选
        switch selectedFilter {
        case .all:
            break
        case .specific(let category):
            filtered = filtered.filter { $0.definition.category == category }
        }

        // 搜索筛选
        if !searchText.isEmpty {
            filtered = filtered.filter { pair in
                pair.definition.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        displayedItems = filtered
    }

    /// 获取容量颜色
    private func getCapacityColor(percentage: Double) -> Color {
        if percentage > 0.9 {
            return ApocalypseTheme.danger
        } else if percentage > 0.7 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.success
        }
    }

    /// 处理使用物品
    private func handleUseItem(item: InventoryItem, definition: ItemDefinition) {
        print("使用物品: \(definition.name) (x\(item.quantity))")
        // TODO: 实现使用物品逻辑
    }

    /// 处理存储物品
    private func handleStoreItem(item: InventoryItem, definition: ItemDefinition) {
        print("存储物品: \(definition.name) (x\(item.quantity))")
        // TODO: 实现存储物品逻辑
    }
}

// MARK: - 物品筛选类型

enum ItemFilterType: Hashable {
    case all
    case specific(ItemCategory)

    static var allCases: [ItemFilterType] {
        return [
            .all,
            .specific(.food),
            .specific(.water),
            .specific(.material),
            .specific(.tool),
            .specific(.medical)
        ]
    }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .specific(let category):
            return category.rawValue
        }
    }

    var iconName: String {
        switch self {
        case .all:
            return "square.grid.2x2.fill"
        case .specific(let category):
            return ItemCategoryStyle.style(for: category).iconName
        }
    }
}

// MARK: - 物品分类样式

struct ItemCategoryStyle {
    let color: Color
    let iconName: String

    static func style(for category: ItemCategory) -> ItemCategoryStyle {
        switch category {
        case .water:
            return ItemCategoryStyle(color: .blue, iconName: "drop.fill")
        case .food:
            return ItemCategoryStyle(color: .orange, iconName: "fork.knife")
        case .medical:
            return ItemCategoryStyle(color: .red, iconName: "cross.case.fill")
        case .material:
            return ItemCategoryStyle(color: .brown, iconName: "cube.box.fill")
        case .tool:
            return ItemCategoryStyle(color: .gray, iconName: "wrench.and.screwdriver.fill")
        case .weapon:
            return ItemCategoryStyle(color: .red, iconName: "shield.fill")
        case .equipment:
            return ItemCategoryStyle(color: .purple, iconName: "backpack.fill")
        }
    }
}

// MARK: - 物品稀有度样式

struct ItemRarityStyle {
    let color: Color

    static func style(for rarity: ItemRarity) -> ItemRarityStyle {
        switch rarity {
        case .common:
            return ItemRarityStyle(color: .gray)
        case .uncommon:
            return ItemRarityStyle(color: .green)
        case .rare:
            return ItemRarityStyle(color: .blue)
        case .epic:
            return ItemRarityStyle(color: .purple)
        case .legendary:
            return ItemRarityStyle(color: .orange)
        }
    }
}

// MARK: - 预览

#Preview {
    BackpackView()
}
