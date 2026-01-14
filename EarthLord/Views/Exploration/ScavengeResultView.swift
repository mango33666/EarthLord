//
//  ScavengeResultView.swift
//  EarthLord
//
//  搜刮结果视图
//  显示从 POI 搜刮获得的物品
//

import SwiftUI
import CoreLocation

// MARK: - 搜刮结果视图

struct ScavengeResultView: View {

    // MARK: - 属性

    /// POI 信息
    let poi: POI

    /// 获得的物品列表
    let items: [ObtainedItem]

    /// 确认回调
    let onConfirm: () -> Void

    // MARK: - 动画状态

    @State private var showItems = false
    @State private var showConfirmButton = false

    // MARK: - 主视图

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 结果卡片
            VStack(spacing: 20) {
                // 成功图标
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 80, height: 80)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                }
                .scaleEffect(showItems ? 1.0 : 0.5)
                .opacity(showItems ? 1.0 : 0)

                // 标题
                VStack(spacing: 4) {
                    Text("🎉 搜刮成功！")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("📍 \(poi.name)")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                // 分隔线
                Rectangle()
                    .fill(ApocalypseTheme.textSecondary.opacity(0.2))
                    .frame(height: 1)
                    .padding(.horizontal, 20)

                // 物品列表
                VStack(alignment: .leading, spacing: 12) {
                    Text("获得物品：")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    ForEach(Array(items.enumerated()), id: \.element.itemId) { index, item in
                        itemRow(item: item, index: index)
                    }
                }
                .padding(.horizontal, 20)
                .opacity(showItems ? 1.0 : 0)
                .offset(y: showItems ? 0 : 20)

                // 确认按钮
                Button(action: onConfirm) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))

                        Text("确认")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [.green, .green.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .padding(.horizontal, 20)
                .opacity(showConfirmButton ? 1.0 : 0)
                .scaleEffect(showConfirmButton ? 1.0 : 0.8)
            }
            .padding(.vertical, 30)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(ApocalypseTheme.cardBackground)
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: -10)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(
            Color.black.opacity(0.6)
                .ignoresSafeArea()
        )
        .onAppear {
            // 动画序列
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                showItems = true
            }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4)) {
                showConfirmButton = true
            }
        }
        .transition(.opacity)
    }

    // MARK: - 子视图

    /// 物品行
    private func itemRow(item: ObtainedItem, index: Int) -> some View {
        HStack(spacing: 12) {
            // 物品图标占位
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ApocalypseTheme.primary.opacity(0.2))
                    .frame(width: 44, height: 44)

                Text("📦")
                    .font(.system(size: 24))
            }

            // 物品名称
            Text(item.itemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 数量
            Text("x\(item.quantity)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ApocalypseTheme.primary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ApocalypseTheme.primary.opacity(0.2), lineWidth: 1)
                )
        )
        .opacity(showItems ? 1.0 : 0)
        .offset(x: showItems ? 0 : -50)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.7)
            .delay(Double(index) * 0.1 + 0.2),
            value: showItems
        )
    }
}

// MARK: - 预览

#Preview {
    ScavengeResultView(
        poi: POI(
            id: "test-1",
            name: "沃尔玛超市（测试店）",
            coordinate: .init(latitude: 0, longitude: 0),
            category: .supermarket
        ),
        items: [
            ObtainedItem(itemId: "1", itemName: "矿泉水", quantity: 2),
            ObtainedItem(itemId: "2", itemName: "罐头", quantity: 1),
            ObtainedItem(itemId: "3", itemName: "绷带", quantity: 3)
        ],
        onConfirm: { print("确认") }
    )
}
