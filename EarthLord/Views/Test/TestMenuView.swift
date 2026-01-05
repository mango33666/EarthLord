//
//  TestMenuView.swift
//  EarthLord
//
//  开发测试菜单
//  提供各种测试功能的入口
//

import SwiftUI

// MARK: - 测试菜单视图

struct TestMenuView: View {

    // MARK: - 主视图

    var body: some View {
        List {
            // Supabase 测试
            NavigationLink(destination: SupabaseTestView()) {
                HStack(spacing: 16) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 24))
                        .foregroundColor(ApocalypseTheme.primary)
                        .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Supabase 连接测试")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("测试数据库连接和 API 调用")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding(.vertical, 8)
            }

            // 圈地功能测试
            NavigationLink(destination: TerritoryTestView()) {
                HStack(spacing: 16) {
                    Image(systemName: "flag.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(ApocalypseTheme.primary)
                        .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("圈地功能测试")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("查看圈地模块实时日志")
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("开发测试")
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ApocalypseTheme.background)
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        TestMenuView()
    }
}
