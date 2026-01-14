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

    /// 点击搜刮回调
    let onScavenge: () -> Void

    /// 点击关闭回调
    let onDismiss: () -> Void

    // MARK: - 动画状态

    @State private var isAnimating = false

    // MARK: - 主视图

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 弹窗卡片
            VStack(spacing: 16) {
                // 顶部图标和标题
                VStack(spacing: 8) {
                    // POI 图标
                    Text(poi.category.icon)
                        .font(.system(size: 60))
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true),
                            value: isAnimating
                        )

                    // 废墟标题
                    Text("发现废墟")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    // POI 名称
                    Text(poi.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    // 类型标签
                    Text(poi.category.wastelandName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(ApocalypseTheme.primary.opacity(0.8))
                        )
                }
                .padding(.top, 20)

                // 分隔线
                Rectangle()
                    .fill(ApocalypseTheme.textSecondary.opacity(0.2))
                    .frame(height: 1)
                    .padding(.horizontal, 20)

                // 提示文字
                Text("这里可能藏有物资，是否搜刮？")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)

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
                            Image(systemName: "hand.raised.fingers.spread.fill")
                                .font(.system(size: 16))

                            Text("立即搜刮")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [ApocalypseTheme.primary, ApocalypseTheme.primary.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(ApocalypseTheme.cardBackground)
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: -10)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
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
            onScavenge: { print("搜刮") },
            onDismiss: { print("关闭") }
        )
    }
}
