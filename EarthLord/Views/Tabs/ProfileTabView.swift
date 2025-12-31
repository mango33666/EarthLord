import SwiftUI

/// 个人中心页面 - 幸存者档案
struct ProfileTabView: View {
    /// 认证管理器
    @StateObject private var authManager = AuthManager.shared

    /// 是否显示登出确认弹窗
    @State private var showLogoutConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color.black
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 用户信息卡片
                        userInfoCard
                            .padding(.top, 20)

                        // 统计数据卡片
                        statisticsCard

                        // 功能菜单列表
                        menuList

                        // 退出登录按钮
                        logoutButton

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("幸存者档案")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .confirmationDialog(
                "确定要退出登录吗？",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("退出登录", role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    // MARK: - 用户信息卡片

    private var userInfoCard: some View {
        VStack(spacing: 16) {
            // 用户头像
            ZStack {
                Circle()
                    .fill(Color(hex: "FF6B35"))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }

            // 用户名（使用邮箱前缀或"幸存者"）
            VStack(spacing: 6) {
                Text(getUserDisplayName())
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                // 邮箱
                if let email = authManager.currentUser?.email {
                    Text(email)
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.6))
                }

                // 用户ID
                if let userId = authManager.currentUser?.id {
                    Text("ID: \(userId.uuidString.prefix(8))...")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.4))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - 统计数据卡片

    private var statisticsCard: some View {
        HStack(spacing: 0) {
            // 领地
            StatisticItem(
                icon: "flag.fill",
                value: "0",
                label: "领地",
                iconColor: Color(hex: "FF6B35")
            )

            Divider()
                .background(Color.white.opacity(0.1))
                .frame(height: 40)

            // 资源点
            StatisticItem(
                icon: "info.circle.fill",
                value: "0",
                label: "资源点",
                iconColor: Color(hex: "FF6B35")
            )

            Divider()
                .background(Color.white.opacity(0.1))
                .frame(height: 40)

            // 探索距离
            StatisticItem(
                icon: "figure.walk",
                value: "0",
                label: "探索距离",
                iconColor: Color(hex: "FF6B35")
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(white: 0.15))
        .cornerRadius(16)
    }

    // MARK: - 功能菜单列表

    private var menuList: some View {
        VStack(spacing: 0) {
            // 设置
            MenuRow(
                icon: "gearshape.fill",
                title: "设置",
                iconColor: Color.gray,
                action: {
                    // TODO: 跳转到设置页面
                }
            )

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.leading, 60)

            // 通知
            MenuRow(
                icon: "bell.fill",
                title: "通知",
                iconColor: Color(hex: "FF6B35"),
                action: {
                    // TODO: 跳转到通知页面
                }
            )

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.leading, 60)

            // 帮助
            MenuRow(
                icon: "questionmark.circle.fill",
                title: "帮助",
                iconColor: Color.blue,
                action: {
                    // TODO: 跳转到帮助页面
                }
            )

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.leading, 60)

            // 关于
            MenuRow(
                icon: "info.circle.fill",
                title: "关于",
                iconColor: Color.green,
                action: {
                    // TODO: 跳转到关于页面
                }
            )
        }
        .background(Color(white: 0.15))
        .cornerRadius(16)
    }

    // MARK: - 退出登录按钮

    private var logoutButton: some View {
        Button(action: {
            showLogoutConfirmation = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 20))

                Text("退出登录")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [Color(hex: "FF6B6B"), Color(hex: "FF5252")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        }
    }

    // MARK: - Helper Methods

    private func getUserDisplayName() -> String {
        if let username = authManager.currentUser?.username, !username.isEmpty {
            return username
        }
        if let email = authManager.currentUser?.email {
            // 使用邮箱 @ 前面的部分作为用户名
            return email.components(separatedBy: "@").first ?? String(localized: "幸存者")
        }
        return String(localized: "幸存者")
    }
}

// MARK: - 统计项组件

struct StatisticItem: View {
    let icon: String
    let value: String
    let label: LocalizedStringKey
    let iconColor: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(iconColor)

            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 菜单行组件

struct MenuRow: View {
    let icon: String
    let title: LocalizedStringKey
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
                    .frame(width: 32)

                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - 预览

#Preview {
    ProfileTabView()
}
