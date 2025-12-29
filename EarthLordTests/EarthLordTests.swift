//
//  EarthLordTests.swift
//  EarthLordTests
//
//  Created by 芒果888 on 2025/12/27.
//

import Testing
import Foundation
@testable import EarthLord

// MARK: - AuthManager Tests

@MainActor
struct AuthManagerTests {

    // MARK: - Initialization Tests

    @Test("AuthManager clears state correctly after sign out")
    func testInitialState() async throws {
        let authManager = AuthManager.shared

        // 先登出以确保状态清空
        await authManager.signOut()

        // 等待异步操作完成
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒

        #expect(authManager.isLoading == false)
        #expect(authManager.errorMessage == nil)
        #expect(authManager.otpSent == false)
        #expect(authManager.otpVerified == false)
        #expect(authManager.needsPasswordSetup == false)
        #expect(authManager.isAuthenticated == false)
    }

    // MARK: - State Management Tests

    @Test("Reset state clears OTP flags and errors")
    func testResetState() async throws {
        let authManager = AuthManager.shared

        // 设置一些状态
        authManager.resetState()

        // 验证状态被清空
        #expect(authManager.otpSent == false)
        #expect(authManager.otpVerified == false)
        #expect(authManager.errorMessage == nil)
    }

    @Test("Clear error removes error message")
    func testClearError() async throws {
        let authManager = AuthManager.shared

        authManager.clearError()

        #expect(authManager.errorMessage == nil)
    }

    // MARK: - Token Management Tests

    @Test("Sign out clears authentication state")
    func testSignOutClearsState() async throws {
        let authManager = AuthManager.shared

        // 执行登出
        await authManager.signOut()

        // 验证状态被清空
        #expect(authManager.isAuthenticated == false)
        #expect(authManager.needsPasswordSetup == false)
        #expect(authManager.currentUser == nil)
        #expect(authManager.otpSent == false)
        #expect(authManager.otpVerified == false)

        // 验证 UserDefaults 中的令牌被清除
        #expect(UserDefaults.standard.string(forKey: "access_token") == nil)
        #expect(UserDefaults.standard.string(forKey: "refresh_token") == nil)
    }
}

// MARK: - User Model Tests

struct UserModelTests {

    @Test("User model encodes and decodes correctly")
    func testUserCodable() throws {
        let user = User(
            id: UUID(),
            email: "test@example.com",
            username: "testuser",
            avatarUrl: "https://example.com/avatar.jpg"
        )

        // 编码
        let encoder = JSONEncoder()
        let data = try encoder.encode(user)

        // 解码
        let decoder = JSONDecoder()
        let decodedUser = try decoder.decode(User.self, from: data)

        // 验证
        #expect(decodedUser.id == user.id)
        #expect(decodedUser.email == user.email)
        #expect(decodedUser.username == user.username)
        #expect(decodedUser.avatarUrl == user.avatarUrl)
    }

    @Test("User model handles optional fields")
    func testUserOptionalFields() throws {
        let user = User(
            id: UUID(),
            email: nil,
            username: nil,
            avatarUrl: nil
        )

        #expect(user.email == nil)
        #expect(user.username == nil)
        #expect(user.avatarUrl == nil)
    }
}

// MARK: - Response Model Tests

struct ResponseModelTests {

    @Test("AuthResponse decodes valid JSON")
    func testAuthResponseDecoding() throws {
        let json = """
        {
            "access_token": "test_access_token",
            "refresh_token": "test_refresh_token",
            "user": {
                "id": "123e4567-e89b-12d3-a456-426614174000",
                "email": "test@example.com"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(AuthResponse.self, from: data)

        #expect(response.access_token == "test_access_token")
        #expect(response.refresh_token == "test_refresh_token")
        #expect(response.user?.id == "123e4567-e89b-12d3-a456-426614174000")
        #expect(response.user?.email == "test@example.com")
    }

    @Test("ErrorResponse decodes valid JSON")
    func testErrorResponseDecoding() throws {
        let json = """
        {
            "message": "Invalid credentials"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(ErrorResponse.self, from: data)

        #expect(response.message == "Invalid credentials")
    }

    @Test("UserResponse decodes valid JSON")
    func testUserResponseDecoding() throws {
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "email": "test@example.com"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(UserResponse.self, from: data)

        #expect(response.id == "123e4567-e89b-12d3-a456-426614174000")
        #expect(response.email == "test@example.com")
    }
}

// MARK: - Auth Error Tests

struct AuthErrorTests {

    @Test("AuthError provides correct error descriptions")
    func testAuthErrorDescriptions() {
        let invalidResponse = AuthError.invalidResponse
        #expect(invalidResponse.errorDescription == "无效的服务器响应")

        let apiError = AuthError.apiError("自定义错误")
        #expect(apiError.errorDescription == "自定义错误")

        let httpError = AuthError.httpError(404)
        #expect(httpError.errorDescription == "HTTP 错误：404")

        let invalidData = AuthError.invalidData
        #expect(invalidData.errorDescription == "数据格式错误")
    }
}

// MARK: - Integration Tests (需要网络连接)

@MainActor
struct AuthIntegrationTests {

    // 注意：这些测试需要真实的网络连接和有效的 Supabase 配置
    // 在 CI/CD 环境中应该使用 mock 或测试服务器

    @Test("Send register OTP handles invalid email", .disabled("Requires network connection"))
    func testSendRegisterOTPInvalidEmail() async throws {
        let authManager = AuthManager.shared
        authManager.resetState()

        await authManager.sendRegisterOTP(email: "invalid-email")

        // 应该有错误信息
        #expect(authManager.errorMessage != nil)
        #expect(authManager.otpSent == false)
    }

    @Test("Sign in handles invalid credentials", .disabled("Requires network connection"))
    func testSignInInvalidCredentials() async throws {
        let authManager = AuthManager.shared
        authManager.resetState()

        await authManager.signIn(email: "invalid@example.com", password: "wrongpassword")

        // 应该有错误信息
        #expect(authManager.errorMessage != nil)
        #expect(authManager.isAuthenticated == false)
    }

    @Test("Verify OTP handles invalid code", .disabled("Requires network connection"))
    func testVerifyOTPInvalidCode() async throws {
        let authManager = AuthManager.shared
        authManager.resetState()

        await authManager.verifyRegisterOTP(email: "test@example.com", code: "000000")

        // 应该有错误信息
        #expect(authManager.errorMessage != nil)
        #expect(authManager.otpVerified == false)
    }
}

// MARK: - Email Validation Tests (从 AuthView 提取的逻辑)

struct EmailValidationTests {

    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }

    @Test("Valid email addresses pass validation")
    func testValidEmails() {
        #expect(isValidEmail("test@example.com") == true)
        #expect(isValidEmail("user.name@example.com") == true)
        #expect(isValidEmail("user+tag@example.co.uk") == true)
        #expect(isValidEmail("test123@test-domain.com") == true)
    }

    @Test("Invalid email addresses fail validation")
    func testInvalidEmails() {
        #expect(isValidEmail("") == false)
        #expect(isValidEmail("invalid") == false)
        #expect(isValidEmail("@example.com") == false)
        #expect(isValidEmail("user@") == false)
        #expect(isValidEmail("user @example.com") == false)
        #expect(isValidEmail("user@.com") == false)
    }
}
