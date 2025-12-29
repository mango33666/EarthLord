//
//  AuthView.swift
//  EarthLord
//
//  Created by 芒果888 on 2025/12/29.
//

import SwiftUI

// MARK: - Auth View
/// 认证页面 - 登录/注册
struct AuthView: View {

    // MARK: - Properties

    @StateObject private var authManager = AuthManager.shared

    /// 当前选中的 Tab（登录/注册）
    @State private var selectedTab: AuthTab = .login

    /// 是否显示忘记密码弹窗
    @State private var showForgotPassword = false

    /// 是否显示 Toast 提示
    @State private var showToast = false
    @State private var toastMessage = ""

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient

            ScrollView {
                VStack(spacing: 40) {
                    Spacer().frame(height: 60)

                    // Logo 和标题
                    logoSection

                    // Tab 切换器
                    tabSwitcher

                    // 内容区域
                    contentSection

                    // 第三方登录
                    thirdPartyLoginSection

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }

            // 加载指示器
            if authManager.isLoading {
                loadingOverlay
            }

            // Toast 提示
            if showToast {
                toastView
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
    }

    // MARK: - 背景渐变

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.08, green: 0.08, blue: 0.12),
                Color(red: 0.05, green: 0.10, blue: 0.20),
                Color(red: 0.03, green: 0.03, blue: 0.08)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Logo 区域

    private var logoSection: some View {
        VStack(spacing: 16) {
            // Logo 图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ApocalypseTheme.primary,
                                ApocalypseTheme.primary.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 20)

                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }

            // 标题
            Text("地球新主")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("EARTH LORD")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .tracking(3)
        }
    }

    // MARK: - Tab 切换器

    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            // 登录 Tab
            TabButton(
                title: "登录",
                isSelected: selectedTab == .login,
                action: {
                    withAnimation {
                        selectedTab = .login
                        authManager.resetState()
                    }
                }
            )

            // 注册 Tab
            TabButton(
                title: "注册",
                isSelected: selectedTab == .register,
                action: {
                    withAnimation {
                        selectedTab = .register
                        authManager.resetState()
                    }
                }
            )
        }
        .frame(maxWidth: 300)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 内容区域

    @ViewBuilder
    private var contentSection: some View {
        VStack(spacing: 24) {
            // 错误提示
            if let error = authManager.errorMessage {
                ErrorBanner(message: error) {
                    authManager.clearError()
                }
            }

            // 根据选中的 Tab 显示内容
            if selectedTab == .login {
                LoginTabContent(showForgotPassword: $showForgotPassword)
            } else {
                RegisterTabContent(showToast: $showToast, toastMessage: $toastMessage)
            }
        }
    }

    // MARK: - 第三方登录

    private var thirdPartyLoginSection: some View {
        VStack(spacing: 20) {
            // 分隔线
            HStack {
                Rectangle()
                    .fill(ApocalypseTheme.textMuted)
                    .frame(height: 1)

                Text("或者使用以下方式登录")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .padding(.horizontal, 12)

                Rectangle()
                    .fill(ApocalypseTheme.textMuted)
                    .frame(height: 1)
            }

            // 第三方登录按钮
            VStack(spacing: 12) {
                // Apple 登录按钮
                ThirdPartyButton(
                    icon: "apple.logo",
                    title: "使用 Apple 登录",
                    backgroundColor: .black,
                    action: {
                        showToastMessage("Apple 登录即将开放")
                    }
                )

                // Google 登录按钮
                ThirdPartyButton(
                    icon: "g.circle.fill",
                    title: "使用 Google 登录",
                    backgroundColor: .white,
                    foregroundColor: .black,
                    action: {
                        showToastMessage("Google 登录即将开放")
                    }
                )
            }
        }
    }

    // MARK: - 加载遮罩

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text("加载中...")
                    .foregroundColor(.white)
                    .font(.subheadline)
            }
            .padding(40)
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - Toast 提示

    private var toastView: some View {
        VStack {
            Spacer()

            Text(toastMessage)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(8)
                .shadow(radius: 10)
                .padding(.bottom, 50)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showToast = false
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
    }
}

// MARK: - Auth Tab Enum

enum AuthTab {
    case login
    case register
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(isSelected ? ApocalypseTheme.textPrimary : ApocalypseTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    isSelected ? ApocalypseTheme.primary : Color.clear
                )
                .cornerRadius(12)
        }
    }
}

// MARK: - Login Tab Content

struct LoginTabContent: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var password = ""

    @Binding var showForgotPassword: Bool

    var body: some View {
        VStack(spacing: 20) {
            // 邮箱输入
            InputField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $email,
                keyboardType: .emailAddress
            )

            // 密码输入
            InputField(
                icon: "lock.fill",
                placeholder: "密码",
                text: $password,
                isSecure: true
            )

            // 忘记密码
            HStack {
                Spacer()
                Button("忘记密码？") {
                    showForgotPassword = true
                }
                .font(.caption)
                .foregroundColor(ApocalypseTheme.primary)
            }

            // 登录按钮
            PrimaryButton(title: "登录") {
                Task {
                    await authManager.signIn(email: email, password: password)
                }
            }
            .disabled(email.isEmpty || password.isEmpty)
        }
    }
}

// MARK: - Register Tab Content

struct RegisterTabContent: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var email = ""
    @State private var otpCode = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var countdown = 0
    @State private var timer: Timer?

    @Binding var showToast: Bool
    @Binding var toastMessage: String

    var body: some View {
        VStack(spacing: 20) {
            // 根据状态显示不同步骤
            if !authManager.otpSent {
                // 第一步：输入邮箱
                step1EmailInput
            } else if !authManager.otpVerified {
                // 第二步：输入验证码
                step2OTPInput
            } else if authManager.needsPasswordSetup {
                // 第三步：设置密码
                step3SetPassword
            }
        }
    }

    // MARK: - 第一步：邮箱输入

    private var step1EmailInput: some View {
        VStack(spacing: 20) {
            Text("请输入您的邮箱")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            InputField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $email,
                keyboardType: .emailAddress
            )

            PrimaryButton(title: "发送验证码") {
                Task {
                    await authManager.sendRegisterOTP(email: email)
                    if authManager.otpSent {
                        startCountdown()
                    }
                }
            }
            .disabled(email.isEmpty || !isValidEmail(email))
        }
    }

    // MARK: - 第二步：验证码输入

    private var step2OTPInput: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("验证码已发送至")
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(email)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.primary)
            }

            InputField(
                icon: "number",
                placeholder: "请输入 6 位验证码",
                text: $otpCode,
                keyboardType: .numberPad
            )
            .onChange(of: otpCode) { newValue in
                // 限制为 6 位数字
                if newValue.count > 6 {
                    otpCode = String(newValue.prefix(6))
                }
            }

            // 重发倒计时
            if countdown > 0 {
                Text("\(countdown)秒后可重新发送")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            } else {
                Button("重新发送验证码") {
                    Task {
                        await authManager.sendRegisterOTP(email: email)
                        if authManager.otpSent {
                            startCountdown()
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(ApocalypseTheme.primary)
            }

            PrimaryButton(title: "验证") {
                Task {
                    await authManager.verifyRegisterOTP(email: email, code: otpCode)
                }
            }
            .disabled(otpCode.count != 6)
        }
    }

    // MARK: - 第三步：设置密码

    private var step3SetPassword: some View {
        VStack(spacing: 20) {
            Text("设置您的密码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("验证成功！请设置密码以完成注册")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.success)
                .frame(maxWidth: .infinity, alignment: .leading)

            InputField(
                icon: "lock.fill",
                placeholder: "密码（至少 6 位）",
                text: $password,
                isSecure: true
            )

            InputField(
                icon: "lock.fill",
                placeholder: "确认密码",
                text: $confirmPassword,
                isSecure: true
            )

            // 密码强度提示
            if !password.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: password.count >= 6 ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(password.count >= 6 ? ApocalypseTheme.success : ApocalypseTheme.danger)
                    Text(password.count >= 6 ? "密码长度符合要求" : "密码至少需要 6 位")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            PrimaryButton(title: "完成注册") {
                Task {
                    if password == confirmPassword {
                        await authManager.completeRegistration(password: password)
                    } else {
                        authManager.errorMessage = "两次输入的密码不一致"
                    }
                }
            }
            .disabled(password.count < 6 || password != confirmPassword)
        }
    }

    // MARK: - Helper Methods

    private func startCountdown() {
        countdown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer?.invalidate()
            }
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
}

// MARK: - Forgot Password View

struct ForgotPasswordView: View {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var otpCode = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var currentStep = 1
    @State private var countdown = 0
    @State private var timer: Timer?

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 进度指示器
                        ProgressIndicator(currentStep: currentStep, totalSteps: 3)
                            .padding(.top, 20)

                        // 错误提示
                        if let error = authManager.errorMessage {
                            ErrorBanner(message: error) {
                                authManager.clearError()
                            }
                        }

                        // 根据步骤显示内容
                        if currentStep == 1 {
                            step1ResetEmail
                        } else if currentStep == 2 {
                            step2ResetOTP
                        } else {
                            step3NewPassword
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // MARK: - 第一步：邮箱

    private var step1ResetEmail: some View {
        VStack(spacing: 20) {
            Text("请输入您的注册邮箱")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            InputField(
                icon: "envelope.fill",
                placeholder: "邮箱地址",
                text: $email,
                keyboardType: .emailAddress
            )

            PrimaryButton(title: "发送验证码") {
                Task {
                    await authManager.sendResetOTP(email: email)
                    if authManager.otpSent {
                        currentStep = 2
                        startCountdown()
                    }
                }
            }
            .disabled(email.isEmpty)
        }
    }

    // MARK: - 第二步：验证码

    private var step2ResetOTP: some View {
        VStack(spacing: 20) {
            Text("验证码已发送至 \(email)")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            InputField(
                icon: "number",
                placeholder: "请输入 6 位验证码",
                text: $otpCode,
                keyboardType: .numberPad
            )

            if countdown > 0 {
                Text("\(countdown)秒后可重新发送")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            } else {
                Button("重新发送") {
                    Task {
                        await authManager.sendResetOTP(email: email)
                        if authManager.otpSent {
                            startCountdown()
                        }
                    }
                }
                .foregroundColor(ApocalypseTheme.primary)
            }

            PrimaryButton(title: "验证") {
                Task {
                    await authManager.verifyResetOTP(email: email, code: otpCode)
                    if authManager.otpVerified {
                        currentStep = 3
                    }
                }
            }
            .disabled(otpCode.count != 6)
        }
    }

    // MARK: - 第三步：新密码

    private var step3NewPassword: some View {
        VStack(spacing: 20) {
            Text("设置新密码")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            InputField(
                icon: "lock.fill",
                placeholder: "新密码（至少 6 位）",
                text: $newPassword,
                isSecure: true
            )

            InputField(
                icon: "lock.fill",
                placeholder: "确认新密码",
                text: $confirmPassword,
                isSecure: true
            )

            PrimaryButton(title: "重置密码") {
                Task {
                    if newPassword == confirmPassword {
                        await authManager.resetPassword(newPassword: newPassword)
                        if authManager.isAuthenticated {
                            dismiss()
                        }
                    } else {
                        authManager.errorMessage = "两次输入的密码不一致"
                    }
                }
            }
            .disabled(newPassword.count < 6 || newPassword != confirmPassword)
        }
    }

    // MARK: - Helper

    private func startCountdown() {
        countdown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
}

// MARK: - Reusable Components

/// 输入框组件
struct InputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .autocapitalization(.none)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

/// 主按钮组件
struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 10)
        }
    }
}

/// 第三方登录按钮
struct ThirdPartyButton: View {
    let icon: String
    let title: String
    let backgroundColor: Color
    var foregroundColor: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .cornerRadius(12)
        }
    }
}

/// 错误横幅
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(ApocalypseTheme.danger)

            Text(message)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(2)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding()
        .background(ApocalypseTheme.danger.opacity(0.2))
        .cornerRadius(8)
    }
}

/// 进度指示器
struct ProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                    .frame(width: 10, height: 10)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AuthView()
}
