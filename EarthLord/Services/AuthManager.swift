//
//  AuthManager.swift
//  EarthLord
//
//  Created by 芒果888 on 2025/12/29.
//

import SwiftUI
import Supabase

// MARK: - User Model
/// 用户信息模型
struct User: Identifiable, Codable {
    let id: UUID
    let email: String?
    var username: String?
    var avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case avatarUrl = "avatar_url"
    }
}

// MARK: - Auth Manager
/// 认证管理器 - 管理用户注册、登录、密码重置等认证流程
@MainActor
class AuthManager: ObservableObject {

    // MARK: - Singleton
    static let shared = AuthManager()

    // MARK: - Published Properties

    /// 是否已完成认证（登录且完成所有必要流程）
    @Published var isAuthenticated: Bool = false

    /// 是否需要设置密码（OTP 验证后需要设置密码）
    @Published var needsPasswordSetup: Bool = false

    /// 当前登录用户
    @Published var currentUser: User?

    /// 加载状态
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    /// OTP 是否已发送
    @Published var otpSent: Bool = false

    /// OTP 是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - Supabase Client

    private let supabase: SupabaseClient

    // MARK: - Initialization

    private init() {
        // 初始化 Supabase 客户端
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: "https://npmazbowtfowbxvpjhst.supabase.co")!,
            supabaseKey: "sb_publishable_59Pm_KFRXgXJUVYUK0nwKg_RqnVRCKQ"
        )

        // 启动时检查会话
        Task {
            await checkSession()
        }
    }

    // MARK: - 注册流程

    /// 发送注册验证码
    /// - Parameter email: 用户邮箱
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 调用 Supabase 发送 OTP（自动创建用户）
            try await supabase.auth.signInWithOTP(
                email: email,
                redirectTo: nil,
                shouldCreateUser: true,
                data: nil
            )

            // 成功发送
            otpSent = true
            errorMessage = nil

        } catch {
            // 发送失败
            errorMessage = "发送验证码失败：\(error.localizedDescription)"
            otpSent = false
        }

        isLoading = false
    }

    /// 验证注册验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil
        otpVerified = false

        do {
            // 验证 OTP（类型为 email）
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            // 验证成功，用户已登录但需要设置密码
            otpVerified = true
            needsPasswordSetup = true
            isAuthenticated = false  // 注册流程未完成

            // 获取用户信息
            if let supabaseUser = session.user {
                currentUser = User(
                    id: supabaseUser.id,
                    email: supabaseUser.email,
                    username: nil,
                    avatarUrl: nil
                )
            }

            errorMessage = nil

        } catch {
            // 验证失败
            errorMessage = "验证码错误或已过期：\(error.localizedDescription)"
            otpVerified = false
            needsPasswordSetup = false
        }

        isLoading = false
    }

    /// 完成注册（设置密码）
    /// - Parameter password: 用户密码
    func completeRegistration(password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(
                user: UserAttributes(password: password)
            )

            // 注册完成
            needsPasswordSetup = false
            isAuthenticated = true
            otpVerified = false

            errorMessage = nil

        } catch {
            // 设置密码失败
            errorMessage = "设置密码失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 登录方法

    /// 邮箱密码登录
    /// - Parameters:
    ///   - email: 邮箱
    ///   - password: 密码
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 调用 Supabase 登录
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            // 登录成功
            isAuthenticated = true
            needsPasswordSetup = false

            // 获取用户信息
            if let supabaseUser = session.user {
                currentUser = User(
                    id: supabaseUser.id,
                    email: supabaseUser.email,
                    username: nil,
                    avatarUrl: nil
                )
            }

            errorMessage = nil

        } catch {
            // 登录失败
            errorMessage = "登录失败：\(error.localizedDescription)"
            isAuthenticated = false
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 发送密码重置验证码
    /// - Parameter email: 用户邮箱
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 调用 Supabase 发送密码重置邮件
            try await supabase.auth.resetPasswordForEmail(email)

            // 成功发送
            otpSent = true
            errorMessage = nil

        } catch {
            // 发送失败
            errorMessage = "发送重置邮件失败：\(error.localizedDescription)"
            otpSent = false
        }

        isLoading = false
    }

    /// 验证密码重置验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil
        otpVerified = false

        do {
            // ⚠️ 注意：类型是 .recovery 不是 .email
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )

            // 验证成功，用户已登录但需要设置新密码
            otpVerified = true
            needsPasswordSetup = true
            isAuthenticated = false  // 密码重置流程未完成

            // 获取用户信息
            if let supabaseUser = session.user {
                currentUser = User(
                    id: supabaseUser.id,
                    email: supabaseUser.email,
                    username: nil,
                    avatarUrl: nil
                )
            }

            errorMessage = nil

        } catch {
            // 验证失败
            errorMessage = "验证码错误或已过期：\(error.localizedDescription)"
            otpVerified = false
            needsPasswordSetup = false
        }

        isLoading = false
    }

    /// 重置密码（设置新密码）
    /// - Parameter newPassword: 新密码
    func resetPassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )

            // 密码重置完成
            needsPasswordSetup = false
            isAuthenticated = true
            otpVerified = false

            errorMessage = nil

        } catch {
            // 重置密码失败
            errorMessage = "重置密码失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// Apple 登录（待实现）
    func signInWithApple() async {
        // TODO: 实现 Apple 登录
        // 1. 使用 ASAuthorizationController 获取 Apple ID 凭证
        // 2. 调用 supabase.auth.signInWithIdToken(provider: .apple, idToken: token)
        // 3. 处理登录结果
        errorMessage = "Apple 登录功能开发中..."
    }

    /// Google 登录（待实现）
    func signInWithGoogle() async {
        // TODO: 实现 Google 登录
        // 1. 使用 GoogleSignIn SDK 获取 Google 凭证
        // 2. 调用 supabase.auth.signInWithIdToken(provider: .google, idToken: token)
        // 3. 处理登录结果
        errorMessage = "Google 登录功能开发中..."
    }

    // MARK: - 其他方法

    /// 登出
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            // 调用 Supabase 登出
            try await supabase.auth.signOut()

            // 清空状态
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            otpSent = false
            otpVerified = false
            errorMessage = nil

        } catch {
            // 登出失败
            errorMessage = "登出失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 检查会话状态（启动时调用）
    func checkSession() async {
        isLoading = true

        do {
            // 获取当前会话
            let session = try await supabase.auth.session

            // 如果有会话，表示用户已登录
            if let supabaseUser = session.user {
                currentUser = User(
                    id: supabaseUser.id,
                    email: supabaseUser.email,
                    username: nil,
                    avatarUrl: nil
                )

                // 检查是否需要设置密码
                // 注意：这里需要根据实际业务逻辑判断
                // 如果用户有密码，则认为已完成认证
                isAuthenticated = true
                needsPasswordSetup = false
            } else {
                // 没有会话
                isAuthenticated = false
                currentUser = nil
            }

        } catch {
            // 没有有效会话
            isAuthenticated = false
            currentUser = nil
        }

        isLoading = false
    }

    // MARK: - Helper Methods

    /// 清空错误信息
    func clearError() {
        errorMessage = nil
    }

    /// 重置所有状态
    func resetState() {
        otpSent = false
        otpVerified = false
        errorMessage = nil
    }
}
