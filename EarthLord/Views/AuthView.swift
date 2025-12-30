//
//  AuthView.swift
//  EarthLord
//
//  Created by 芒果888 on 2025/12/29.
//

import SwiftUI

// MARK: - 认证视图

struct AuthView: View {

    // MARK: - 状态属性

    @StateObject private var authManager = AuthManager.shared

    /// 当前模式：登录或注册
    @State private var authMode: AuthMode = .login

    /// 登录表单
    @State private var loginEmail = ""
    @State private var loginPassword = ""
    @State private var showPassword = false

    /// 注册表单
    @State private var registerEmail = ""
    @State private var otpCode = ""
    @State private var registerPassword = ""
    @State private var confirmPassword = ""
    @State private var countdown = 0
    @State private var timer: Timer?

    /// UI 状态
    @State private var showForgotPassword = false
    @State private var showToast = false
    @State private var toastMessage = ""

    // MARK: - 主视图

    var body: some View {
        ZStack {
            // 深色背景
            Color(red: 0.11, green: 0.12, blue: 0.15)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 60)

                    // Logo 和标题区域
                    logoSection

                    // 模式切换按钮
                    modeSwitcher

                    // 副标题（在按钮下方，仅登录模式显示）
                    if authMode == .login && !authManager.otpSent {
                        subtitleSection
                            .padding(.top, 8)
                    }

                    // 主内容区域
                    contentSection
                        .padding(.top, 12)

                    // 第三方登录
                    thirdPartySection

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 32)
            }

            // 加载遮罩
            if authManager.isLoading {
                loadingOverlay
            }

            // Toast 提示
            if showToast {
                toastView
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet()
        }
    }

    // MARK: - Logo 和标题

    private var logoSection: some View {
        VStack(spacing: 20) {
            // Logo（橙色圆形，内含地球图标）
            ZStack {
                Circle()
                    .fill(Color(hex: "FF6B35"))
                    .frame(width: 100, height: 100)

                // 地球图标
                Image(systemName: "globe.asia.australia.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }

            // 标题
            Text("地球新主")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
        }
    }

    // MARK: - 副标题

    private var subtitleSection: some View {
        Text("征服世界，从脚下开始")
            .font(.system(size: 14))
            .foregroundColor(Color.white.opacity(0.6))
    }

    // MARK: - 模式切换器

    private var modeSwitcher: some View {
        HStack(spacing: 16) {
            // 登录按钮
            Button(action: {
                withAnimation {
                    authMode = .login
                    authManager.resetState()
                }
            }) {
                Text("登录")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(authMode == .login ? .white : Color.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        authMode == .login ?
                        LinearGradient(
                            colors: [Color(hex: "FF6B35"), Color(hex: "FF8C42")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            colors: [Color.clear, Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(authMode == .login ? 0 : 0.2), lineWidth: 1)
                    )
            }

            // 注册按钮
            Button(action: {
                withAnimation {
                    authMode = .register
                    authManager.resetState()
                }
            }) {
                Text("注册")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(authMode == .register ? .white : Color.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        authMode == .register ?
                        LinearGradient(
                            colors: [Color(hex: "FF6B35"), Color(hex: "FF8C42")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            colors: [Color.clear, Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(authMode == .register ? 0 : 0.2), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - 内容区域

    @ViewBuilder
    private var contentSection: some View {
        VStack(spacing: 20) {
            // 错误提示
            if let error = authManager.errorMessage {
                ErrorBanner(message: error) {
                    authManager.clearError()
                }
            }

            // 根据模式显示内容
            if authMode == .login {
                loginContent
            } else {
                registerContent
            }
        }
    }

    // MARK: - 登录内容

    private var loginContent: some View {
        VStack(spacing: 16) {
            // 邮箱输入框
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .foregroundColor(Color.white.opacity(0.3))
                    .frame(width: 20)

                TextField("", text: $loginEmail)
                    .foregroundColor(.white)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .placeholder(when: loginEmail.isEmpty) {
                        Text("邮箱").foregroundColor(Color.white.opacity(0.3))
                    }
            }
            .padding()
            .background(Color(white: 0.15))
            .cornerRadius(10)

            // 密码输入框
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundColor(Color.white.opacity(0.3))
                    .frame(width: 20)

                if showPassword {
                    TextField("", text: $loginPassword)
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .placeholder(when: loginPassword.isEmpty) {
                            Text("密码").foregroundColor(Color.white.opacity(0.3))
                        }
                } else {
                    SecureField("", text: $loginPassword, prompt: Text("密码").foregroundColor(Color.white.opacity(0.3)))
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                }

                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(Color.white.opacity(0.3))
                }
            }
            .padding()
            .background(Color(white: 0.15))
            .cornerRadius(10)

            // 登录按钮
            Button(action: {
                Task {
                    await authManager.signIn(email: loginEmail, password: loginPassword)
                }
            }) {
                Text("登录")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(white: 0.25))
                    .cornerRadius(10)
            }
            .disabled(loginEmail.isEmpty || loginPassword.isEmpty)

            // 忘记密码
            Button(action: {
                showForgotPassword = true
            }) {
                Text("忘记密码?")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "FF6B35"))
            }
            .padding(.top, 4)
        }
    }

    // MARK: - 注册内容

    @ViewBuilder
    private var registerContent: some View {
        if !authManager.otpSent {
            // 第一步：输入邮箱
            registerStep1
        } else if !authManager.otpVerified {
            // 第二步：输入验证码
            registerStep2
        } else if authManager.needsPasswordSetup {
            // 第三步：设置密码
            registerStep3
        }
    }

    // MARK: - 注册第一步：邮箱

    private var registerStep1: some View {
        VStack(spacing: 20) {
            // 邮箱输入框
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .foregroundColor(Color.white.opacity(0.4))
                    .frame(width: 24)

                TextField("邮箱", text: $registerEmail)
                    .foregroundColor(.white)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .placeholder(when: registerEmail.isEmpty) {
                        Text("邮箱").foregroundColor(Color.white.opacity(0.3))
                    }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)

            // 发送验证码按钮
            Button(action: {
                Task {
                    await authManager.sendRegisterOTP(email: registerEmail)
                    if authManager.otpSent {
                        startCountdown()
                    }
                }
            }) {
                Text("发送验证码")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "FF6B35"), Color(hex: "FF8C42")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .opacity(isValidEmail(registerEmail) ? 1.0 : 0.5)
            }
            .disabled(!isValidEmail(registerEmail))
        }
    }

    // MARK: - 注册第二步：验证码

    private var registerStep2: some View {
        VStack(spacing: 20) {
            // 提示文本
            VStack(spacing: 8) {
                Text("验证码已发送至")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.6))

                Text(registerEmail)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "FF6B35"))
            }

            // 验证码输入框
            HStack(spacing: 12) {
                Image(systemName: "number")
                    .foregroundColor(Color.white.opacity(0.4))
                    .frame(width: 24)

                TextField("6位验证码", text: $otpCode)
                    .foregroundColor(.white)
                    .keyboardType(.numberPad)
                    .placeholder(when: otpCode.isEmpty) {
                        Text("请输入 6 位验证码").foregroundColor(Color.white.opacity(0.3))
                    }
                    .onChange(of: otpCode) { newValue in
                        if newValue.count > 6 {
                            otpCode = String(newValue.prefix(6))
                        }
                    }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)

            // 重发倒计时
            if countdown > 0 {
                Text("\(countdown)秒后可重新发送")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.4))
            } else {
                Button("重新发送验证码") {
                    Task {
                        await authManager.sendRegisterOTP(email: registerEmail)
                        if authManager.otpSent {
                            startCountdown()
                        }
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "FF6B35"))
            }

            // 验证按钮
            Button(action: {
                Task {
                    await authManager.verifyRegisterOTP(email: registerEmail, code: otpCode)
                }
            }) {
                Text("验证")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "FF6B35"), Color(hex: "FF8C42")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .opacity(otpCode.count == 6 ? 1.0 : 0.5)
            }
            .disabled(otpCode.count != 6)
        }
    }

    // MARK: - 注册第三步：设置密码

    private var registerStep3: some View {
        VStack(spacing: 20) {
            // 成功提示
            Text("验证成功！请设置密码")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.green)

            // 密码输入框
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundColor(Color.white.opacity(0.4))
                    .frame(width: 24)

                SecureField("密码（至少 6 位）", text: $registerPassword)
                    .foregroundColor(.white)
                    .autocapitalization(.none)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)

            // 确认密码输入框
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundColor(Color.white.opacity(0.4))
                    .frame(width: 24)

                SecureField("确认密码", text: $confirmPassword)
                    .foregroundColor(.white)
                    .autocapitalization(.none)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)

            // 密码强度提示
            if !registerPassword.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: registerPassword.count >= 6 ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(registerPassword.count >= 6 ? .green : .red)
                        .font(.system(size: 12))

                    Text(registerPassword.count >= 6 ? "密码长度符合要求" : "密码至少需要 6 位")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 完成注册按钮
            Button(action: {
                Task {
                    if registerPassword == confirmPassword {
                        await authManager.completeRegistration(password: registerPassword)
                    } else {
                        authManager.errorMessage = "两次输入的密码不一致"
                    }
                }
            }) {
                Text("完成注册")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "FF6B35"), Color(hex: "FF8C42")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .opacity(registerPassword.count >= 6 && registerPassword == confirmPassword ? 1.0 : 0.5)
            }
            .disabled(registerPassword.count < 6 || registerPassword != confirmPassword)
        }
    }

    // MARK: - 第三方登录

    private var thirdPartySection: some View {
        VStack(spacing: 16) {
            // 分隔线
            HStack {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)

                Text("或者使用以下方式登录")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.4))
                    .padding(.horizontal, 12)

                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)
            }

            // Apple 登录
            Button(action: {
                showToastMessage("Apple 登录即将开放")
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 20))

                    Text("通过 Apple 登录")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.black)
                .cornerRadius(12)
            }

            // Google 登录
            Button(action: {
                Task {
                    await authManager.signInWithGoogle()
                }
            }) {
                HStack(spacing: 12) {
                    Text("G")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)

                    Text("通过 Google 登录")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .cornerRadius(12)
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

                Text("加载中...")
                    .foregroundColor(.white)
                    .font(.system(size: 14))
            }
            .padding(40)
            .background(Color(red: 0.2, green: 0.2, blue: 0.25))
            .cornerRadius(16)
        }
    }

    // MARK: - Toast 提示

    private var toastView: some View {
        VStack {
            Spacer()

            Text(toastMessage)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(red: 0.2, green: 0.2, blue: 0.25))
                .cornerRadius(8)
                .shadow(radius: 10)
                .padding(.bottom, 80)
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

// MARK: - 认证模式枚举

enum AuthMode {
    case login
    case register
}

// MARK: - 找回密码弹窗

struct ForgotPasswordSheet: View {
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
                Color(red: 0.11, green: 0.12, blue: 0.15)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 进度指示器
                        HStack(spacing: 8) {
                            ForEach(1...3, id: \.self) { step in
                                Circle()
                                    .fill(step <= currentStep ? Color(hex: "FF6B35") : Color.white.opacity(0.2))
                                    .frame(width: 10, height: 10)
                            }
                        }
                        .padding(.top, 20)

                        // 错误提示
                        if let error = authManager.errorMessage {
                            ErrorBanner(message: error) {
                                authManager.clearError()
                            }
                        }

                        // 步骤内容
                        if currentStep == 1 {
                            forgotPasswordStep1
                        } else if currentStep == 2 {
                            forgotPasswordStep2
                        } else {
                            forgotPasswordStep3
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
                    .foregroundColor(Color(hex: "FF6B35"))
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // 第一步：输入邮箱
    private var forgotPasswordStep1: some View {
        VStack(spacing: 20) {
            Text("请输入您的注册邮箱")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .foregroundColor(Color.white.opacity(0.4))
                    .frame(width: 24)

                TextField("邮箱地址", text: $email)
                    .foregroundColor(.white)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)

            Button(action: {
                Task {
                    await authManager.sendResetOTP(email: email)
                    if authManager.otpSent {
                        currentStep = 2
                        startCountdown()
                    }
                }
            }) {
                Text("发送验证码")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "FF6B35"), Color(hex: "FF8C42")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .disabled(email.isEmpty)
        }
    }

    // 第二步：输入验证码
    private var forgotPasswordStep2: some View {
        VStack(spacing: 20) {
            Text("验证码已发送至 \(email)")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Image(systemName: "number")
                    .foregroundColor(Color.white.opacity(0.4))
                    .frame(width: 24)

                TextField("6位验证码", text: $otpCode)
                    .foregroundColor(.white)
                    .keyboardType(.numberPad)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)

            if countdown > 0 {
                Text("\(countdown)秒后可重新发送")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.4))
            } else {
                Button("重新发送") {
                    Task {
                        await authManager.sendResetOTP(email: email)
                        if authManager.otpSent {
                            startCountdown()
                        }
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "FF6B35"))
            }

            Button(action: {
                Task {
                    await authManager.verifyResetOTP(email: email, code: otpCode)
                    if authManager.otpVerified {
                        currentStep = 3
                    }
                }
            }) {
                Text("验证")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "FF6B35"), Color(hex: "FF8C42")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .disabled(otpCode.count != 6)
        }
    }

    // 第三步：设置新密码
    private var forgotPasswordStep3: some View {
        VStack(spacing: 20) {
            Text("设置新密码")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundColor(Color.white.opacity(0.4))
                    .frame(width: 24)

                SecureField("新密码（至少 6 位）", text: $newPassword)
                    .foregroundColor(.white)
                    .autocapitalization(.none)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)

            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundColor(Color.white.opacity(0.4))
                    .frame(width: 24)

                SecureField("确认新密码", text: $confirmPassword)
                    .foregroundColor(.white)
                    .autocapitalization(.none)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)

            Button(action: {
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
            }) {
                Text("重置密码")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "FF6B35"), Color(hex: "FF8C42")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .disabled(newPassword.count < 6 || newPassword != confirmPassword)
        }
    }

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

// MARK: - 辅助组件

/// 错误横幅
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)

            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .lineLimit(2)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(Color.white.opacity(0.6))
            }
        }
        .padding()
        .background(Color.red.opacity(0.2))
        .cornerRadius(8)
    }
}

// MARK: - 扩展

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - 预览

#Preview {
    AuthView()
}
