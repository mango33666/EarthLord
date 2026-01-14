//
//  POIScavengePopup.swift
//  EarthLord
//
//  POI 搜刮弹窗
//  当玩家接近 POI 时显示搜刮提示
//

import SwiftUI
import CoreLocation

// MARK: - POI 搜刮弹窗

struct POIScavengePopup: View {

    // MARK: - 属性

    /// POI 信息
    let poi: POI

    /// 与 POI 的距离（米）
    let distance: Double

    /// 点击搜刮回调
    let onScavenge: () -> Void

    /// 点击关闭回调
    let onDismiss: () -> Void

    // MARK: - 动画状态

    @State private var isAnimating = false

    // MARK: - 计算属性

    /// 危险等级（1-5，基于POI类型）
    private var dangerLevel: Int {
        switch poi.category {
        case .hospital, .pharmacy:
            return 2  // 医疗设施较安全
        case .supermarket, .convenience, .store:
            return 3  // 商店中等风险
        case .gasStation:
            return 4  // 加油站有爆炸风险
        case .restaurant, .cafe:
            return 1  // 餐饮场所较安全
        case .other:
            return 3  // 未知风险
        }
    }

    // MARK: - 主视图

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 弹窗卡片（底部sheet样式）
            VStack(spacing: 0) {
                // 顶部拖动指示条
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 16)

                // 主内容区域
                HStack(alignment: .top, spacing: 12) {
                    // 左侧：POI 图标
                    ZStack {
                        Circle()
                            .fill(ApocalypseTheme.primary.opacity(0.2))
                            .frame(width: 60, height: 60)

                        Text(poi.category.icon)
                            .font(.system(size: 28))
                    }
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                    // 中间：信息区域
                    VStack(alignment: .leading, spacing: 4) {
                        Text("发现废墟")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        Text(poi.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // 右侧：距离显示
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(distance))")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(ApocalypseTheme.primary)
                        Text("米")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding(.horizontal, 20)

                // 分隔线
                Rectangle()
                    .fill(ApocalypseTheme.textSecondary.opacity(0.2))
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                // 危险等级
                HStack {
                    Text("危险等级")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()

                    // 危险等级指示器（5个三角形）
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { level in
                            Image(systemName: level <= dangerLevel ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                                .font(.system(size: 14))
                                .foregroundColor(level <= dangerLevel ? dangerColor(for: level) : ApocalypseTheme.textSecondary.opacity(0.3))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // 按钮组
                HStack(spacing: 12) {
                    // 稍后再说
                    Button(action: onDismiss) {
                        Text("稍后再说")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ApocalypseTheme.textSecondary.opacity(0.3), lineWidth: 1)
                            )
                    }

                    // 立即搜刮
                    Button(action: onScavenge) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .semibold))

                            Text("立即搜刮")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ApocalypseTheme.primary)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(ApocalypseTheme.cardBackground)
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: -10)
            )
        }
        .background(
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // 点击背景关闭
                    onDismiss()
                }
        )
        .onAppear {
            isAnimating = true
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - 辅助方法

    /// 根据危险等级返回颜色
    private func dangerColor(for level: Int) -> Color {
        switch level {
        case 1:
            return .green
        case 2:
            return .yellow
        case 3:
            return .orange
        case 4, 5:
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - 预览

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()

        POIScavengePopup(
            poi: POI(
                id: "test-1",
                name: "沃尔玛超市（测试店）",
                coordinate: .init(latitude: 0, longitude: 0),
                category: .supermarket
            ),
            distance: 27,
            onScavenge: { print("搜刮") },
            onDismiss: { print("关闭") }
        )
    }
}
