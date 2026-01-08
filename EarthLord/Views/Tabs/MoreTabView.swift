import SwiftUI

struct MoreTabView: View {
    @StateObject private var authManager = AuthManager.shared
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var devMode = DeveloperMode.shared
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

                    // 开发者模式
                    Section {
                        // 开发者模式开关
                        Toggle(isOn: $devMode.isEnabled) {
                            HStack(spacing: 16) {
                                Image(systemName: "person.2.fill")
                                    .font(.title2)
                                    .foregroundColor(devMode.isEnabled ? .green : ApocalypseTheme.textSecondary)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("多用户测试模式")
                                        .font(.headline)
                                        .foregroundColor(ApocalypseTheme.textPrimary)

                                    Text(devMode.isEnabled ? "已启用" : "已禁用")
                                        .font(.caption)
                                        .foregroundColor(devMode.isEnabled ? .green : ApocalypseTheme.textSecondary)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .tint(.green)
                        .listRowBackground(ApocalypseTheme.cardBackground)

                        // 当前用户显示
                        if devMode.isEnabled {
                            HStack(spacing: 16) {
                                Image(systemName: "person.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(ApocalypseTheme.info)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("当前用户")
                                        .font(.headline)
                                        .foregroundColor(ApocalypseTheme.textPrimary)

                                    Text("\(devMode.getCurrentUserDisplayName())")
                                        .font(.subheadline)
                                        .foregroundColor(ApocalypseTheme.primary)

                                    Text("ID: \(devMode.getCurrentUserIdShort())...")
                                        .font(.caption)
                                        .foregroundColor(ApocalypseTheme.textSecondary)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(ApocalypseTheme.cardBackground)

                            // 预设测试用户列表
                            ForEach(devMode.presetUsers.indices, id: \.self) { index in
                                let user = devMode.presetUsers[index]
                                Button(action: {
                                    devMode.switchToPresetUser(index: index)
                                    // 发送通知，触发刷新
                                    NotificationCenter.default.post(name: .developerModeUserChanged, object: nil)
                                }) {
                                    HStack(spacing: 16) {
                                        Image(systemName: "person.fill")
                                            .font(.title3)
                                            .foregroundColor(devMode.testUserId == user.id ? .green : ApocalypseTheme.textSecondary)
                                            .frame(width: 40)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(user.name)
                                                .font(.headline)
                                                .foregroundColor(ApocalypseTheme.textPrimary)

                                            Text("ID: \(String(user.id.prefix(8)))...")
                                                .font(.caption)
                                                .foregroundColor(ApocalypseTheme.textSecondary)
                                        }

                                        Spacer()

                                        if devMode.testUserId == user.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                }
                                .listRowBackground(ApocalypseTheme.cardBackground)
                            }

                            // 真实设备用户
                            Button(action: {
                                devMode.switchToRealUser()
                                NotificationCenter.default.post(name: .developerModeUserChanged, object: nil)
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: "iphone")
                                        .font(.title3)
                                        .foregroundColor(devMode.testUserId == nil ? .green : ApocalypseTheme.textSecondary)
                                        .frame(width: 40)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("真实设备用户")
                                            .font(.headline)
                                            .foregroundColor(ApocalypseTheme.textPrimary)

                                        Text("ID: \(String(DeviceIdentifier.shared.getUserId().prefix(8)))...")
                                            .font(.caption)
                                            .foregroundColor(ApocalypseTheme.textSecondary)
                                    }

                                    Spacer()

                                    if devMode.testUserId == nil {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .listRowBackground(ApocalypseTheme.cardBackground)
                        }
                    } header: {
                        Text("开发者模式")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    } footer: {
                        if devMode.isEnabled {
                            Text("⚠️ 开发者模式：允许临时切换用户 ID 进行多用户场景测试。切换用户后会自动刷新地图和领地数据。")
                                .foregroundColor(ApocalypseTheme.warning.opacity(0.8))
                                .font(.caption)
                        } else {
                            Text("启用后可以临时切换测试用户，用于测试多用户碰撞检测等场景")
                                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.8))
                                .font(.caption)
                        }
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
