//
//  AuthManager.swift
//  EarthLord
//
//  Created by 芒果888 on 2025/12/29.
//

import Foundation
import Combine
import GoogleSignIn
import UIKit

// MARK: - Response Models

struct AuthResponse: Codable, Sendable {
    let access_token: String?
    let refresh_token: String?
    let user: UserResponse?
}

struct UserResponse: Codable, Sendable {
    let id: String
    let email: String?
}

struct ErrorResponse: Codable, Sendable {
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
struct User: Identifiable, Codable, Sendable {
    let id: UUID
    let email: String?
    let username: String?
    let avatarUrl: String?

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

    // MARK: - Google Configuration

    private let googleClientID = "673837093726-u0gq3h8fr7dnea6b8bm917og4o6jut64.apps.googleusercontent.com"

    /// 当前访问令牌
    private var accessToken: String?
    private var refreshToken: String?

    // MARK: - Initialization

    private init() {
        // 从 UserDefaults 恢复令牌
        accessToken = UserDefaults.standard.string(forKey: "access_token")
        refreshToken = UserDefaults.standard.string(forKey: "refresh_token")

        // 注意：checkSession() 将在 SplashView 中调用
        // 这样可以显示"正在检查登录状态..."的加载提示
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
            errorMessage = String(localized: "创建请求失败")
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
                    errorMessage = String(localized: "发送验证码失败（状态码：\(httpResponse.statusCode)）")
                }
            }
        } catch {
            errorMessage = String(localized: "发送验证码失败：\(error.localizedDescription)")
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
            errorMessage = String(localized: "创建请求失败")
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
                    errorMessage = String(localized: "验证码错误或已过期")
                }
            }
        } catch {
            errorMessage = String(localized: "验证失败：\(error.localizedDescription)")
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
            errorMessage = String(localized: "创建请求失败")
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
                    errorMessage = String(localized: "设置密码失败（状态码：\(httpResponse.statusCode)）")
                }
            }
        } catch {
            errorMessage = String(localized: "设置密码失败：\(error.localizedDescription)")
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
            errorMessage = String(localized: "创建请求失败")
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
                    errorMessage = String(localized: "邮箱或密码错误")
                }
            }
        } catch {
            errorMessage = String(localized: "登录失败：\(error.localizedDescription)")
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
            errorMessage = String(localized: "创建请求失败")
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
                    errorMessage = String(localized: "发送重置邮件失败")
                }
            }
        } catch {
            errorMessage = String(localized: "发送失败：\(error.localizedDescription)")
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
            errorMessage = String(localized: "创建请求失败")
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
                    errorMessage = String(localized: "验证码错误或已过期")
                }
            }
        } catch {
            errorMessage = String(localized: "验证失败：\(error.localizedDescription)")
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
            errorMessage = String(localized: "创建请求失败")
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
                    errorMessage = String(localized: "重置密码失败（状态码：\(httpResponse.statusCode)）")
                }
            }
        } catch {
            errorMessage = String(localized: "重置密码失败：\(error.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - 第三方登录

    /// Apple 登录（待实现）
    func signInWithApple() async {
        // TODO: 实现 Apple 登录
        errorMessage = String(localized: "Apple 登录功能开发中...")
    }

    /// Google 登录
    func signInWithGoogle() async {
        print("🔐 开始 Google 登录流程...")
        isLoading = true
        errorMessage = nil

        // 获取根视图控制器
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ 无法获取根视图控制器")
            errorMessage = String(localized: "无法初始化 Google 登录")
            isLoading = false
            return
        }

        print("✅ 获取根视图控制器成功")

        // 配置 Google Sign-In
        let config = GIDConfiguration(clientID: googleClientID)
        GIDSignIn.sharedInstance.configuration = config

        print("🔧 Google Sign-In 配置完成，开始授权...")

        do {
            // 执行 Google 登录
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            print("✅ Google 授权成功，用户: \(result.user.profile?.email ?? "未知")")

            // 获取 ID Token
            guard let idToken = result.user.idToken?.tokenString else {
                print("❌ 无法获取 Google ID Token")
                errorMessage = String(localized: "Google 登录失败：无法获取令牌")
                isLoading = false
                return
            }

            print("🎫 成功获取 Google ID Token")
            print("📤 准备发送到 Supabase 进行验证...")

            // 使用 Google ID Token 登录 Supabase
            await signInWithGoogleToken(idToken: idToken)

        } catch {
            print("❌ Google 登录失败: \(error.localizedDescription)")
            errorMessage = String(localized: "Google 登录失败: \(error.localizedDescription)")
            isLoading = false
        }
    }

    /// 使用 Google ID Token 登录 Supabase
    private func signInWithGoogleToken(idToken: String) async {
        print("🔄 开始使用 Google Token 登录 Supabase...")

        guard let request = createAuthRequest(
            endpoint: "token?grant_type=id_token",
            body: [
                "provider": "google",
                "id_token": idToken
            ]
        ) else {
            print("❌ 创建 Supabase 请求失败")
            errorMessage = String(localized: "创建请求失败")
            isLoading = false
            return
        }

        print("📡 发送请求到 Supabase...")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("📥 收到 Supabase 响应，状态码: \(httpResponse.statusCode)")

                if httpResponse.statusCode == 200 {
                    if let authResponse = try? JSONDecoder().decode(AuthResponse.self, from: data) {
                        print("✅ Supabase 认证成功")

                        // 保存令牌
                        saveTokens(
                            accessToken: authResponse.access_token,
                            refreshToken: authResponse.refresh_token
                        )
                        print("💾 令牌已保存")

                        // 设置用户信息
                        if let userResponse = authResponse.user {
                            currentUser = User(
                                id: UUID(uuidString: userResponse.id) ?? UUID(),
                                email: userResponse.email,
                                username: nil,
                                avatarUrl: nil
                            )
                            print("👤 用户信息已设置: \(userResponse.email ?? "未知")")
                        }

                        // 登录成功
                        isAuthenticated = true
                        needsPasswordSetup = false
                        errorMessage = nil
                        print("🎉 Google 登录流程完成！")
                    } else {
                        print("❌ 解析 Supabase 响应失败")
                        errorMessage = String(localized: "登录失败：响应格式错误")
                    }
                } else {
                    print("❌ Supabase 返回错误状态码: \(httpResponse.statusCode)")
                    if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                        errorMessage = String(localized: "登录失败: \(errorResponse.message)")
                        print("❌ 错误信息: \(errorResponse.message)")
                    } else {
                        errorMessage = String(localized: "Google 登录失败（状态码：\(httpResponse.statusCode)）")
                    }
                }
            }
        } catch {
            print("❌ 网络请求失败: \(error.localizedDescription)")
            errorMessage = String(localized: "登录失败：\(error.localizedDescription)")
        }

        isLoading = false
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
            errorMessage = String(localized: "创建请求失败")
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
        guard accessToken != nil else {
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
                // 检查会话是否过期
                guard handleResponse(httpResponse) else {
                    isLoading = false
                    return
                }

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
                        print("✅ 会话有效，用户已登录")
                    }
                } else {
                    // 其他错误，清除令牌
                    clearTokens()
                    isAuthenticated = false
                    currentUser = nil
                }
            }
        } catch {
            print("❌ 检查会话失败: \(error.localizedDescription)")
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

    // MARK: - 会话过期处理

    /// 处理会话过期（当 API 返回 401 时调用）
    private func handleSessionExpired() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 清空所有认证状态
            self.clearTokens()
            self.isAuthenticated = false
            self.needsPasswordSetup = false
            self.currentUser = nil
            self.otpSent = false
            self.otpVerified = false

            // 显示会话过期提示
            self.errorMessage = String(localized: "登录已过期，请重新登录")

            print("⚠️ 会话已过期，用户已登出")
        }
    }

    /// 验证响应状态码，处理会话过期
    private func handleResponse(_ httpResponse: HTTPURLResponse) -> Bool {
        if httpResponse.statusCode == 401 {
            // 会话过期或令牌无效
            handleSessionExpired()
            return false
        }
        return true
    }

    // MARK: - 删除账户

    /// 删除当前用户账户
    func deleteAccount() async {
        print("🗑️ 开始删除账户...")
        isLoading = true
        errorMessage = nil

        guard let accessToken = accessToken else {
            print("❌ 未找到访问令牌")
            errorMessage = String(localized: "未登录，无法删除账户")
            isLoading = false
            return
        }

        print("📡 准备调用删除账户边缘函数...")

        // 调用边缘函数
        let endpoint = "\(supabaseURL)/functions/v1/delete-account"
        guard let url = URL(string: endpoint) else {
            print("❌ URL 格式错误")
            errorMessage = String(localized: "删除账户失败：URL 错误")
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        print("🔑 使用 JWT token 调用边缘函数...")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 无效的响应")
                errorMessage = String(localized: "删除账户失败：无效的响应")
                isLoading = false
                return
            }

            print("📥 收到响应，状态码: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 200 {
                print("✅ 账户删除成功")

                // 解析响应
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📋 响应内容: \(responseString)")
                }

                // 清空本地状态
                print("🧹 清理本地数据...")
                clearTokens()
                isAuthenticated = false
                currentUser = nil
                otpSent = false
                otpVerified = false
                needsPasswordSetup = false

                print("🎉 账户删除完成，用户已登出")
                errorMessage = nil
            } else {
                // 解析错误信息
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    print("❌ 删除失败: \(errorResponse.message)")
                    errorMessage = String(localized: "删除账户失败: \(errorResponse.message)")
                } else {
                    let errorText = String(data: data, encoding: .utf8) ?? "未知错误"
                    print("❌ 删除失败: \(errorText)")
                    errorMessage = String(localized: "删除账户失败（状态码：\(httpResponse.statusCode)）")
                }
            }
        } catch {
            print("❌ 网络请求失败: \(error.localizedDescription)")
            errorMessage = String(localized: "删除账户失败：\(error.localizedDescription)")
        }

        isLoading = false
    }
}
