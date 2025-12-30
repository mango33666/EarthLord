//
//  ContentView.swift
//  EarthLord
//
//  Created by 芒果888 on 2025/12/27.
//

import SwiftUI

/// 主内容视图 - 已登录用户看到的界面
struct ContentView: View {
    /// 认证管理器（监听登出事件）
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        MainTabView()
            .onChange(of: authManager.isAuthenticated) { isAuth in
                // 当用户登出时，此视图会自动被 RootView 替换为 AuthView
                if !isAuth {
                    print("用户已登出，即将返回登录页面")
                }
            }
    }
}

#Preview {
    ContentView()
}
