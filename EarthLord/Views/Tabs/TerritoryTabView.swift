//
//  TerritoryTabView.swift
//  EarthLord
//
//  领地管理页面
//  显示我的领地列表、统计信息、领地详情
//

import SwiftUI
import MapKit

// MARK: - 领地标签页视图

struct TerritoryTabView: View {

    // MARK: - 状态属性

    /// 领地管理器
    private let territoryManager = TerritoryManager.shared

    /// 我的领地列表
    @State private var myTerritories: [Territory] = []

    /// 是否正在加载
    @State private var isLoading = false

    /// 是否正在刷新
    @State private var isRefreshing = false

    /// 错误信息
    @State private var errorMessage: String?

    /// 是否显示错误提示
    @State private var showErrorAlert = false

    /// 是否显示详情页
    @State private var showDetailView = false

    /// 选中的领地
    @State private var selectedTerritory: Territory?

    // MARK: - 主视图

    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if isLoading && myTerritories.isEmpty {
                    // 首次加载中
                    loadingView
                } else if myTerritories.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // 领地列表
                    territoryListView
                }
            }
            .navigationTitle("领地")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadTerritories()
            }
            .refreshable {
                await refreshTerritories()
            }
            .alert("加载失败", isPresented: $showErrorAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
            .sheet(isPresented: $showDetailView) {
                if let territory = selectedTerritory {
                    TerritoryDetailView(
                        territory: territory,
                        onDelete: {
                            // 删除后刷新列表
                            loadTerritories()
                        }
                    )
                }
            }
        }
    }

    // MARK: - 子视图

    /// 加载中视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.5)

            Text("加载中...")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // 图标
            Image(systemName: "flag.slash")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 标题
            Text("暂无领地")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 说明
            Text("前往地图页面开始圈地吧！")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    /// 领地列表视图
    private var territoryListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 统计信息卡片
                statisticsCard

                // 领地列表
                ForEach(myTerritories) { territory in
                    territoryCard(territory: territory)
                        .onTapGesture {
                            selectedTerritory = territory
                            showDetailView = true
                        }
                }

                // 底部占位
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }

    /// 统计信息卡片
    private var statisticsCard: some View {
        VStack(spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.primary)

                Text("统计信息")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }

            // 统计数据
            HStack(spacing: 20) {
                // 领地数量
                statisticItem(
                    icon: "flag.fill",
                    title: "领地数量",
                    value: "\(myTerritories.count)"
                )

                Divider()
                    .frame(height: 40)

                // 总面积
                statisticItem(
                    icon: "square.fill",
                    title: "总面积",
                    value: formatTotalArea()
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }

    /// 统计项
    private func statisticItem(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(ApocalypseTheme.primary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(ApocalypseTheme.primary.opacity(0.2))
                )

            // 文字
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Spacer()
        }
    }

    /// 领地卡片
    private func territoryCard(territory: Territory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                // 领地名称
                Text(territory.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 面积信息
            HStack(spacing: 8) {
                Image(systemName: "square.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(territory.formattedArea)
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 创建时间
                Text(territory.formattedCreatedAt)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 点数信息
            if let pointCount = territory.pointCount {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.info)

                    Text("\(pointCount) 个点位")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - 辅助方法

    /// 加载我的领地
    private func loadTerritories() {
        isLoading = true

        Task {
            do {
                myTerritories = try await territoryManager.loadMyTerritories()
            } catch {
                errorMessage = "加载失败: \(error.localizedDescription)"
                showErrorAlert = true
            }

            isLoading = false
        }
    }

    /// 刷新领地列表
    private func refreshTerritories() async {
        isRefreshing = true

        do {
            myTerritories = try await territoryManager.loadMyTerritories()
        } catch {
            errorMessage = "刷新失败: \(error.localizedDescription)"
            showErrorAlert = true
        }

        isRefreshing = false
    }

    /// 格式化总面积
    private func formatTotalArea() -> String {
        let totalArea = myTerritories.reduce(0.0) { $0 + $1.area }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let areaString = formatter.string(from: NSNumber(value: totalArea)) ?? "\(Int(totalArea))"
        return "\(areaString) m²"
    }
}

// MARK: - 预览

#Preview {
    TerritoryTabView()
}
