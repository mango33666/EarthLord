//
//  ELCard.swift
//  EarthLord
//
//  通用卡片组件
//  提供统一的卡片样式
//

import SwiftUI

// MARK: - 通用卡片组件

struct ELCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ApocalypseTheme.cardBackground)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            )
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 16) {
        ELCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("卡片标题")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("这是卡片内容示例")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(16)
        }

        ELCard {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(ApocalypseTheme.primary)

                Text("信息卡片")
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()
            }
            .padding(12)
        }
    }
    .padding()
    .background(ApocalypseTheme.background)
}
