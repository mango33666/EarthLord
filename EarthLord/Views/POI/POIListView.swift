//
//  POIListView.swift
//  EarthLord
//
//  附近兴趣点列表页面
//  显示POI列表、筛选、搜索功能
//

import SwiftUI
import CoreLocation

// MARK: - POI 列表视图

struct POIListView: View {

    // MARK: - 状态属性

    /// 测试数据
    private let mockData = MockExplorationData.shared

    /// 所有POI列表
    @State private var allPOIs: [POI] = []

    /// 显示的POI列表（筛选后）
    @State private var displayedPOIs: [POI] = []

    /// 当前选中的筛选类型
    @State private var selectedFilter: POIFilterType = .all

    /// 是否正在搜索
    @State private var isSearching = false

    /// 搜索按钮是否被按下
    @State private var isSearchButtonPressed = false

    /// 模拟GPS坐标
    private let mockGPSCoordinate = (latitude: 31.1866, longitude: 120.6126)

    // MARK: - 主视图

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 状态栏
                statusBar

                // 搜索按钮
                searchButton
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // 筛选工具栏
                filterToolbar
                    .padding(.top, 12)

                // POI列表
                poiListView
                    .padding(.top, 12)
            }
        }
        .navigationTitle("附近地点")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(ApocalypseTheme.cardBackground, for: .navigationBar)
        .onAppear {
            loadPOIs()
        }
    }

    // MARK: - 子视图

    /// 状态栏
    private var statusBar: some View {
        VStack(spacing: 8) {
            // GPS坐标
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(String(format: "%.4f, %.4f", mockGPSCoordinate.latitude, mockGPSCoordinate.longitude))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 发现数量
            Text("附近发现 \(displayedPOIs.count) 个地点")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            ApocalypseTheme.cardBackground
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }

    /// 搜索按钮
    private var searchButton: some View {
        Button(action: {
            performSearch()
        }) {
            HStack(spacing: 12) {
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)

                    Text("搜索中...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("搜索附近POI")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSearching ? ApocalypseTheme.textSecondary : ApocalypseTheme.primary)
            )
            .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .scaleEffect(isSearchButtonPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSearchButtonPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isSearching {
                        isSearchButtonPressed = true
                    }
                }
                .onEnded { _ in
                    isSearchButtonPressed = false
                }
        )
        .disabled(isSearching)
    }

    /// 筛选工具栏
    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(POIFilterType.allCases, id: \.self) { filterType in
                    filterButton(filterType: filterType)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    /// 筛选按钮
    private func filterButton(filterType: POIFilterType) -> some View {
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

    /// POI列表视图
    private var poiListView: some View {
        ScrollView {
            VStack(spacing: 12) {
                if displayedPOIs.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // POI卡片列表
                    ForEach(Array(displayedPOIs.enumerated()), id: \.element.id) { index, poi in
                        NavigationLink(destination: POIDetailView(poi: poi)) {
                            poiCard(poi: poi)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .opacity(1.0)
                        .offset(y: 0)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        ))
                        .animation(
                            .easeOut(duration: 0.4)
                                .delay(Double(index) * 0.1),
                            value: displayedPOIs.count
                        )
                    }
                }

                // 底部占位
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, 16)
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // 图标
            Image(systemName: allPOIs.isEmpty ? "map" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 标题
            Text(allPOIs.isEmpty ? "附近暂无兴趣点" : "没有找到该类型的地点")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 描述
            if allPOIs.isEmpty {
                Text("点击搜索按钮发现周围的废墟")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("试试切换其他分类查看")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
    }

    /// POI卡片
    private func poiCard(poi: POI) -> some View {
        let poiStyle = POIStyle.style(for: poi.category)

        return ELCard {
            HStack(spacing: 16) {
                // 类型图标
                Image(systemName: poiStyle.iconName)
                    .font(.system(size: 28))
                    .foregroundColor(poiStyle.color)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(poiStyle.color.opacity(0.15))
                    )

                // POI信息
                VStack(alignment: .leading, spacing: 6) {
                    // 名称
                    Text(poi.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .lineLimit(1)

                    // 类型
                    Text(poi.category.wastelandName)
                        .font(.system(size: 13))
                        .foregroundColor(poiStyle.color)

                    // 状态标签
                    HStack(spacing: 8) {
                        // 搜刮状态
                        if poi.isScavenged {
                            statusLabel(
                                text: "已搜刮",
                                color: ApocalypseTheme.textSecondary
                            )
                        } else {
                            statusLabel(
                                text: "未搜刮",
                                color: ApocalypseTheme.warning
                            )
                        }
                    }
                }

                Spacer()

                // 箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(12)
        }
    }

    /// 状态标签
    private func statusLabel(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.15))
            )
    }

    // MARK: - 业务逻辑

    /// 加载POI数据
    private func loadPOIs() {
        allPOIs = mockData.mockPOIs
        applyFilter()
    }

    /// 应用筛选
    private func applyFilter() {
        switch selectedFilter {
        case .all:
            displayedPOIs = allPOIs
        case .specific(let category):
            displayedPOIs = allPOIs.filter { $0.category == category }
        }
    }

    /// 执行搜索（模拟网络请求）
    private func performSearch() {
        isSearching = true

        // 模拟1.5秒网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSearching = false
            // 这里可以添加搜索成功后的逻辑
            print("搜索完成")
        }
    }
}

// MARK: - POI 筛选类型

enum POIFilterType: Hashable {
    case all
    case specific(POICategory)

    static var allCases: [POIFilterType] {
        return [
            .all,
            .specific(.hospital),
            .specific(.supermarket),
            .specific(.convenience),
            .specific(.pharmacy),
            .specific(.gasStation)
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
            return POIStyle.style(for: category).iconName
        }
    }
}

// MARK: - POI 样式配置

struct POIStyle {
    let color: Color
    let iconName: String

    static func style(for category: POICategory) -> POIStyle {
        switch category {
        case .hospital:
            return POIStyle(color: .red, iconName: "cross.case.fill")
        case .supermarket:
            return POIStyle(color: .green, iconName: "cart.fill")
        case .pharmacy:
            return POIStyle(color: .purple, iconName: "pills.fill")
        case .gasStation:
            return POIStyle(color: .orange, iconName: "fuelpump.fill")
        case .convenience:
            return POIStyle(color: .blue, iconName: "building.2.fill")
        case .store:
            return POIStyle(color: .cyan, iconName: "storefront")
        case .restaurant:
            return POIStyle(color: .yellow, iconName: "fork.knife")
        case .cafe:
            return POIStyle(color: .brown, iconName: "cup.and.saucer.fill")
        case .other:
            return POIStyle(color: .gray, iconName: "mappin.circle.fill")
        }
    }
}

// MARK: - 预览

#Preview {
    POIListView()
}
