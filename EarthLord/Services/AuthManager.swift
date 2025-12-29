//
//  AuthManager.swift
//  EarthLord
//
//  Created by 芒果888 on 2025/12/29.
//

import SwiftUI

// MARK: - Response Models

struct AuthResponse: Codable {
    let access_token: String?
    let refresh_token: String?
    let user: UserResponse?
}

struct UserResponse: Codable {
    let id: String
    let email: String?
}

struct ErrorResponse: Codable {
    let message: String
}

// MARK: - Auth Error

enum AuthError: Error, LocalizedError {
    case invalidResponse
    case apiError(String)
    case httpError(Int)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "无效的服务器响应"
        case .apiError(let message):
            return message
        case .httpError(let code):
            return "HTTP 错误：\(code)"
        case .invalidData:
            return "数据格式错误"
        }
    }
}

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

    // MARK: - Supabase Configuration

    private let supabaseURL = "https://npmazbowtfowbxvpjhst.supabase.co"
    private let supabaseKey = "sb_publishable_59Pm_KFRXgXJUVYUK0nwKg_RqnVRCKQ"

    /// 当前访问令牌
    private var accessToken: String?
    private var refreshToken: String?

    // MARK: - Initialization

    private init() {
        // 从 UserDefaults 恢复令牌
        accessToken = UserDefaults.standard.string(forKey: "access_token")
        refreshToken = UserDefaults.standard.string(forKey: "refresh_token")

        // 启动时检查会话
        Task {
            await checkSession()
        }
    }

    // MARK: - Helper Methods

    /// 创建认证请求
    private func createAuthRequest(endpoint: String, method: String = "POST", body: [String: Any]? = nil) -> URLRequest? {
        guard let url = URL(string: "\(supabaseURL)/auth/v1/\(endpoint)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let accessToken = accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        return request
    }

    /// 保存令牌
    private func saveTokens(accessToken: String?, refreshToken: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken

        if let accessToken = accessToken {
            UserDefaults.standard.set(accessToken, forKey: "access_token")
        }
        if let refreshToken = refreshToken {
            UserDefaults.standard.set(refreshToken, forKey: "refresh_token")
        }
    }

    /// 清除令牌
    private func clearTokens() {
        accessToken = nil
        refreshToken = nil
        UserDefaults.standard.removeObject(forKey: "access_token")
        UserDefaults.standard.removeObject(forKey: "refresh_token")
    }

    // MARK: - 注册流程

    /// 发送注册验证码
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        guard let request = createAuthRequest(
            endpoint: "otp",
            body: [
                "email": email,
                "create_user": true
            ]
        ) else {
            errorMessage = "创建请求失败"
            isLoading = false
            return
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    otpSent = true
                    errorMessage = nil
                } else {
                    errorMessage = "发送验证码失败（状态码：\(httpResponse.statusCode)）"
                }
            }
        } catch {
            errorMessage = "发送验证码失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 验证注册验证码
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil
        otpVerified = false

        guard let request = createAuthRequest(
            endpoint: "verify",
            body: [
                "email": email,
                "token": code,
                "type": "email"
            ]
        ) else {
            errorMessage = "创建请求失败"
            isLoading = false
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    if let authResponse = try? JSONDecoder().decode(AuthResponse.self, from: data) {
                        // 保存令牌
                        saveTokens(
                            accessToken: authResponse.access_token,
                            refreshToken: authResponse.refresh_token
                        )

                        // 设置用户信息
                        if let userResponse = authResponse.user {
                            currentUser = User(
                                id: UUID(uuidString: userResponse.id) ?? UUID(),
                                email: userResponse.email,
                                username: nil,
                                avatarUrl: nil
                            )
                        }

                        // 验证成功，需要设置密码
                        otpVerified = true
                        needsPasswordSetup = true
                        isAuthenticated = false
                        errorMessage = nil
                    }
                } else {
                    errorMessage = "验证码错误或已过期"
                }
            }
        } catch {
            errorMessage = "验证失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 完成注册（设置密码）
    func completeRegistration(password: String) async {
        isLoading = true
        errorMessage = nil

        guard let request = createAuthRequest(
            endpoint: "user",
            method: "PUT",
            body: ["password": password]
        ) else {
            errorMessage = "创建请求失败"
            isLoading = false
            return
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // 密码设置成功
                    needsPasswordSetup = false
                    isAuthenticated = true
                    otpVerified = false
                    errorMessage = nil
                } else {
                    errorMessage = "设置密码失败（状态码：\(httpResponse.statusCode)）"
                }
            }
        } catch {
            errorMessage = "设置密码失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 登录方法

    /// 邮箱密码登录
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        guard let request = createAuthRequest(
            endpoint: "token?grant_type=password",
            body: [
                "email": email,
                "password": password
            ]
        ) else {
            errorMessage = "创建请求失败"
            isLoading = false
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    if let authResponse = try? JSONDecoder().decode(AuthResponse.self, from: data) {
                        // 保存令牌
                        saveTokens(
                            accessToken: authResponse.access_token,
                            refreshToken: authResponse.refresh_token
                        )

                        // 设置用户信息
                        if let userResponse = authResponse.user {
                            currentUser = User(
                                id: UUID(uuidString: userResponse.id) ?? UUID(),
                                email: userResponse.email,
                                username: nil,
                                avatarUrl: nil
                            )
                        }

                        // 登录成功
                        isAuthenticated = true
                        needsPasswordSetup = false
                        errorMessage = nil
                    }
                } else {
                    errorMessage = "邮箱或密码错误"
                }
            }
        } catch {
            errorMessage = "登录失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 发送密码重置验证码
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        guard let request = createAuthRequest(
            endpoint: "recover",
            body: ["email": email]
        ) else {
            errorMessage = "创建请求失败"
            isLoading = false
            return
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    otpSent = true
                    errorMessage = nil
                } else {
                    errorMessage = "发送重置邮件失败"
                }
            }
        } catch {
            errorMessage = "发送失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 验证密码重置验证码
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil
        otpVerified = false

        guard let request = createAuthRequest(
            endpoint: "verify",
            body: [
                "email": email,
                "token": code,
                "type": "recovery"  // 注意：类型是 recovery
            ]
        ) else {
            errorMessage = "创建请求失败"
            isLoading = false
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    if let authResponse = try? JSONDecoder().decode(AuthResponse.self, from: data) {
                        // 保存令牌
                        saveTokens(
                            accessToken: authResponse.access_token,
                            refreshToken: authResponse.refresh_token
                        )

                        // 设置用户信息
                        if let userResponse = authResponse.user {
                            currentUser = User(
                                id: UUID(uuidString: userResponse.id) ?? UUID(),
                                email: userResponse.email,
                                username: nil,
                                avatarUrl: nil
                            )
                        }

                        // 验证成功，需要设置新密码
                        otpVerified = true
                        needsPasswordSetup = true
                        isAuthenticated = false
                        errorMessage = nil
                    }
                } else {
                    errorMessage = "验证码错误或已过期"
                }
            }
        } catch {
            errorMessage = "验证失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 重置密码（设置新密码）
    func resetPassword(newPassword: String) async {
        isLoading = true
        errorMessage = nil

        guard let request = createAuthRequest(
            endpoint: "user",
            method: "PUT",
            body: ["password": newPassword]
        ) else {
            errorMessage = "创建请求失败"
            isLoading = false
            return
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // 密码重置成功
                    needsPasswordSetup = false
                    isAuthenticated = true
                    otpVerified = false
                    errorMessage = nil
                } else {
                    errorMessage = "重置密码失败（状态码：\(httpResponse.statusCode)）"
                }
            }
        } catch {
            errorMessage = "重置密码失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// Apple 登录（待实现）
    func signInWithApple() async {
        // TODO: 实现 Apple 登录
        errorMessage = "Apple 登录功能开发中..."
    }

    /// Google 登录（待实现）
    func signInWithGoogle() async {
        // TODO: 实现 Google 登录
        errorMessage = "Google 登录功能开发中..."
    }

    // MARK: - 其他方法

    /// 登出
    func signOut() async {
        isLoading = true
        errorMessage = nil

        guard let request = createAuthRequest(
            endpoint: "logout",
            method: "POST"
        ) else {
            errorMessage = "创建请求失败"
            isLoading = false
            return
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 204 || httpResponse.statusCode == 200 {
                    // 清空状态
                    clearTokens()
                    isAuthenticated = false
                    needsPasswordSetup = false
                    currentUser = nil
                    otpSent = false
                    otpVerified = false
                    errorMessage = nil
                }
            }
        } catch {
            // 即使登出失败，也清空本地状态
            clearTokens()
            isAuthenticated = false
            currentUser = nil
        }

        isLoading = false
    }

    /// 检查会话状态（启动时调用）
    func checkSession() async {
        guard let accessToken = accessToken else {
            isAuthenticated = false
            return
        }

        isLoading = true

        guard let request = createAuthRequest(
            endpoint: "user",
            method: "GET"
        ) else {
            isAuthenticated = false
            isLoading = false
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    if let userResponse = try? JSONDecoder().decode(UserResponse.self, from: data) {
                        currentUser = User(
                            id: UUID(uuidString: userResponse.id) ?? UUID(),
                            email: userResponse.email,
                            username: nil,
                            avatarUrl: nil
                        )
                        isAuthenticated = true
                        needsPasswordSetup = false
                    }
                } else {
                    // 令牌无效，清除
                    clearTokens()
                    isAuthenticated = false
                    currentUser = nil
                }
            }
        } catch {
            clearTokens()
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
