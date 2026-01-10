//
//  ExplorationResultView.swift
//  EarthLord
//
//  探索结果页面
//  显示探索完成后的统计数据和获得物品
//

import SwiftUI

// MARK: - 探索结果视图

struct ExplorationResultView: View {

    // MARK: - 属性

    /// 探索统计数据
    let stats: ExplorationStats

    /// 错误信息（可选）
    let errorMessage: String?

    /// 重试回调
    let onRetry: (() -> Void)?

    /// 控制页面关闭
    @Environment(\.dismiss) var dismiss

    /// 测试数据
    private let mockData = MockExplorationData.shared

    /// 动画状态：当前显示的距离
    @State private var animatedCurrentDistance: Double = 0
    @State private var animatedTotalDistance: Double = 0
    @State private var animatedCurrentArea: Double = 0
    @State private var animatedTotalArea: Double = 0
    @State private var animatedDuration: TimeInterval = 0

    /// 物品显示状态
    @State private var visibleItemsCount: Int = 0

    /// 对勾动画状态
    @State private var checkmarkScale: Double = 0

    // MARK: - 初始化

    init(stats: ExplorationStats? = nil, errorMessage: String? = nil, onRetry: (() -> Void)? = nil) {
        // 如果没有传入数据，使用mock数据
        self.stats = stats ?? MockExplorationData.shared.mockExplorationStats
        self.errorMessage = errorMessage
        self.onRetry = onRetry
    }

    // MARK: - 主视图

    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if let error = errorMessage {
                    // 错误状态
                    errorStateView(message: error)
                } else {
                    // 正常结果
                    ScrollView {
                        VStack(spacing: 24) {
                            // 成就标题
                            achievementHeader

                            // 统计数据卡片
                            statisticsCard

                            // 奖励物品卡片
                            if !stats.obtainedItems.isEmpty {
                                rewardItemsCard
                            }

                            // 确认按钮
                            confirmButton

                            // 底部占位
                            Color.clear.frame(height: 20)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                    }
                }
            }
            .navigationTitle("探索结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .onAppear {
                if errorMessage == nil {
                    startAnimations()
                }
            }
        }
    }

    // MARK: - 子视图

    /// 成就标题
    private var achievementHeader: some View {
        VStack(spacing: 20) {
            // 大图标（带动画效果）
            ZStack {
                // 外圈光环
                Circle()
                    .fill(ApocalypseTheme.success.opacity(0.2))
                    .frame(width: 120, height: 120)

                // 图标背景
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                ApocalypseTheme.success,
                                ApocalypseTheme.success.opacity(0.7)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                // 图标
                Image(systemName: "map.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }

            // 标题文字
            VStack(spacing: 8) {
                Text("探索完成！")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("又是充实的一天")
                    .font(.system(size: 15))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    /// 统计数据卡片
    private var statisticsCard: some View {
        ELCard {
            VStack(spacing: 20) {
                // 标题
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text("本次探索统计")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()
                }

                Divider()

                // 行走距离
                statisticSection(
                    icon: "figure.walk",
                    iconColor: .blue,
                    title: "行走距离",
                    current: formatDistance(animatedCurrentDistance),
                    total: formatDistance(animatedTotalDistance),
                    rank: stats.distanceRank
                )

                Divider()

                // 探索面积
                statisticSection(
                    icon: "map",
                    iconColor: .green,
                    title: "探索面积",
                    current: formatArea(animatedCurrentArea),
                    total: formatArea(animatedTotalArea),
                    rank: stats.areaRank
                )

                Divider()

                // 探索时长
                HStack(spacing: 12) {
                    // 图标
                    Image(systemName: "clock.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                        )

                    // 文字
                    VStack(alignment: .leading, spacing: 4) {
                        Text("探索时长")
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(formatDuration(animatedDuration))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .contentTransition(.numericText())
                    }

                    Spacer()
                }
            }
            .padding(16)
        }
    }

    /// 统计区块
    private func statisticSection(
        icon: String,
        iconColor: Color,
        title: String,
        current: String,
        total: String,
        rank: Int
    ) -> some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.15))
                )

            // 文字信息
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                HStack(spacing: 16) {
                    // 本次
                    VStack(alignment: .leading, spacing: 2) {
                        Text("本次")
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(current)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }

                    // 累计
                    VStack(alignment: .leading, spacing: 2) {
                        Text("累计")
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(total)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }

            Spacer()

            // 排名
            VStack(spacing: 4) {
                Text("排名")
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("#\(rank)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(ApocalypseTheme.success)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ApocalypseTheme.success.opacity(0.1))
            )
        }
    }

    /// 奖励物品卡片
    private var rewardItemsCard: some View {
        ELCard {
            VStack(spacing: 16) {
                // 标题
                HStack {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.purple)

                    Text("获得物品")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()
                }

                Divider()

                // 物品列表
                VStack(spacing: 12) {
                    ForEach(Array(stats.obtainedItems.prefix(visibleItemsCount).enumerated()), id: \.element.itemId) { index, obtainedItem in
                        rewardItemRow(obtainedItem: obtainedItem, index: index)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .leading)),
                                removal: .opacity
                            ))
                    }
                }

                // 底部提示
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.success)

                    Text("已添加到背包")
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()
                }
                .padding(.top, 8)
            }
            .padding(16)
        }
    }

    /// 奖励物品行
    private func rewardItemRow(obtainedItem: ObtainedItem, index: Int) -> some View {
        // 获取物品定义（用于获取图标和分类）
        let definition = mockData.getItemDefinition(by: obtainedItem.itemId)
        let categoryStyle = definition.map { ItemCategoryStyle.style(for: $0.category) }

        return HStack(spacing: 12) {
            // 物品图标
            Image(systemName: definition?.iconName ?? "cube.fill")
                .font(.system(size: 20))
                .foregroundColor(categoryStyle?.color ?? .gray)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill((categoryStyle?.color ?? .gray).opacity(0.15))
                )

            // 物品名称
            Text(obtainedItem.itemName)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 数量
            Text("x\(obtainedItem.quantity)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ApocalypseTheme.textSecondary.opacity(0.1))
                )

            // 对勾（弹跳动画）
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(ApocalypseTheme.success)
                .scaleEffect(checkmarkScale)
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.5)
                        .delay(Double(index) * 0.2 + 0.8),
                    value: checkmarkScale
                )
        }
        .padding(.vertical, 4)
    }

    /// 确认按钮
    private var confirmButton: some View {
        Button(action: {
            dismiss()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))

                Text("确认")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        ApocalypseTheme.primary,
                        ApocalypseTheme.primary.opacity(0.8)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    /// 错误状态视图
    private func errorStateView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 20) {
                // 错误图标
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.danger)

                // 标题
                Text("探索失败")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 错误信息
                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            VStack(spacing: 12) {
                // 重试按钮
                if let retry = onRetry {
                    Button(action: {
                        retry()
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16))

                            Text("重新探索")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    ApocalypseTheme.primary,
                                    ApocalypseTheme.primary.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }

                // 关闭按钮
                Button(action: {
                    dismiss()
                }) {
                    Text("关闭")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ApocalypseTheme.cardBackground)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    // MARK: - 辅助方法

    /// 格式化距离
    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    /// 格式化面积
    private func formatArea(_ squareMeters: Double) -> String {
        if squareMeters >= 1_000_000 {
            return String(format: "%.2f km²", squareMeters / 1_000_000)
        } else {
            return String(format: "%.0f m²", squareMeters)
        }
    }

    /// 格式化时长
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d 小时 %d 分钟", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%d 分钟 %d 秒", minutes, secs)
        } else {
            return String(format: "%d 秒", secs)
        }
    }

    /// 启动动画
    private func startAnimations() {
        // 数字从0跳动到目标值
        withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
            animatedCurrentDistance = stats.currentDistance
            animatedTotalDistance = stats.totalDistance
            animatedCurrentArea = stats.currentArea
            animatedTotalArea = stats.totalArea
            animatedDuration = stats.duration
        }

        // 物品依次出现（每个间隔0.2秒）
        for i in 0..<stats.obtainedItems.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2 + 0.5) {
                withAnimation {
                    visibleItemsCount = i + 1
                }
            }
        }

        // 对勾图标弹跳动画（在所有物品显示完后）
        let totalDelay = Double(stats.obtainedItems.count) * 0.2 + 0.7
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
            checkmarkScale = 1.0
        }
    }
}

// MARK: - 预览

#Preview {
    ExplorationResultView()
}

#Preview("无物品") {
    ExplorationResultView(stats: ExplorationStats(
        currentDistance: 1500.0,
        totalDistance: 10000.0,
        distanceRank: 50,
        currentArea: 30000.0,
        totalArea: 150000.0,
        areaRank: 45,
        duration: 900.0,
        obtainedItems: []
    ))
}

#Preview("探索失败") {
    ExplorationResultView(
        errorMessage: "区域危险等级过高，无法继续探索",
        onRetry: {
            print("重试探索")
        }
    )
}
