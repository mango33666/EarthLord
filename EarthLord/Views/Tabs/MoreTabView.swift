import SwiftUI

struct MoreTabView: View {
    @StateObject private var authManager = AuthManager.shared
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showDeleteConfirmation = false
    @State private var deleteConfirmationText = ""
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                List {
                    // 开发工具
                    Section {
                        NavigationLink(destination: TestMenuView()) {
                            HStack(spacing: 16) {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .font(.title2)
                                    .foregroundColor(ApocalypseTheme.primary)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("开发测试")
                                        .font(.headline)
                                        .foregroundColor(ApocalypseTheme.textPrimary)

                                    Text("各项功能测试工具")
                                        .font(.caption)
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(ApocalypseTheme.cardBackground)
                    } header: {
                        Text("开发工具")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }

                    // 应用设置
                    Section {
                        Picker("语言", selection: $languageManager.currentLanguage) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.displayName)
                                    .tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .listRowBackground(ApocalypseTheme.cardBackground)
                    } header: {
                        Text("应用设置")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    } footer: {
                        Text("选择应用显示语言，跟随系统将使用设备系统语言")
                            .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.8))
                            .font(.caption)
                    }

                    // 账户管理
                    Section {
                        // 登出按钮
                        Button(action: {
                            Task {
                                await authManager.signOut()
                            }
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.title2)
                                    .foregroundColor(ApocalypseTheme.warning)
                                    .frame(width: 40)

                                Text("登出")
                                    .font(.headline)
                                    .foregroundColor(ApocalypseTheme.textPrimary)

                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(ApocalypseTheme.cardBackground)

                        // 删除账户按钮
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: "trash.fill")
                                    .font(.title2)
                                    .foregroundColor(ApocalypseTheme.danger)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("删除账户")
                                        .font(.headline)
                                        .foregroundColor(ApocalypseTheme.danger)

                                    Text("永久删除您的账户和所有数据")
                                        .font(.caption)
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(ApocalypseTheme.cardBackground)
                    } header: {
                        Text("账户管理")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    } footer: {
                        Text("删除账户后，您的所有数据将被永久删除且无法恢复")
                            .foregroundColor(ApocalypseTheme.danger.opacity(0.8))
                            .font(.caption)
                    }
                }
                .scrollContentBackground(.hidden)

                // 加载遮罩
                if authManager.isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("更多")
            .alert("确认删除账户", isPresented: $showDeleteConfirmation) {
                TextField("请输入\"删除\"确认", text: $deleteConfirmationText)
                    .foregroundColor(.primary)

                Button("取消", role: .cancel) {
                    deleteConfirmationText = ""
                }

                Button("删除账户", role: .destructive) {
                    Task {
                        print("👆 用户确认删除账户")
                        await authManager.deleteAccount()
                        deleteConfirmationText = ""

                        // 如果删除成功（isAuthenticated 变为 false），显示成功提示
                        if !authManager.isAuthenticated && authManager.errorMessage == nil {
                            showDeleteAlert = true
                        }
                    }
                }
                .disabled(deleteConfirmationText != "删除")
            } message: {
                Text("⚠️ 此操作无法撤销！\n\n删除账户后，您的所有数据将被永久删除。\n\n请在下方输入\"删除\"以确认此操作。")
            }
            .alert("账户已删除", isPresented: $showDeleteAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("您的账户已被成功删除")
            }
            .alert("错误", isPresented: .constant(authManager.errorMessage != nil && !authManager.isLoading)) {
                Button("确定", role: .cancel) {
                    authManager.clearError()
                }
            } message: {
                if let error = authManager.errorMessage {
                    Text(LocalizedStringKey(error))
                }
            }
        }
    }

    // MARK: - 加载遮罩

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text("正在删除账户...")
                    .foregroundColor(.white)
                    .font(.system(size: 14))
            }
            .padding(40)
            .background(Color(red: 0.2, green: 0.2, blue: 0.25))
            .cornerRadius(16)
        }
    }
}

#Preview {
    MoreTabView()
}
