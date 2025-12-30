//
//  SupabaseTestView.swift
//  EarthLord
//
//  Created by 芒果888 on 2025/12/28.
//

import SwiftUI

// MARK: - Supabase 配置
let supabaseURL = "https://npmazbowtfowbxvpjhst.supabase.co"
let supabaseKey = "sb_publishable_59Pm_KFRXgXJUVYUK0nwKg_RqnVRCKQ"

// MARK: - 测试页面视图
struct SupabaseTestView: View {
    // MARK: - 状态管理
    @State private var isConnected: Bool? = nil  // nil=未测试, true=成功, false=失败
    @State private var debugLog: String = "等待测试..."
    @State private var isTesting: Bool = false

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // MARK: - 状态图标
                ZStack {
                    // 背景圆圈
                    Circle()
                        .fill(statusBackgroundColor)
                        .frame(width: 120, height: 120)
                        .shadow(color: statusBackgroundColor.opacity(0.5), radius: 20)

                    // 图标
                    Image(systemName: statusIcon)
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
                .padding(.top, 40)

                // MARK: - 标题
                Text("Supabase 连接测试")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // MARK: - 调试日志框
                VStack(alignment: .leading, spacing: 12) {
                    Text("调试日志")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 20)

                    ScrollView {
                        Text(debugLog)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(ApocalypseTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(height: 200)
                    .background(ApocalypseTheme.cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                // MARK: - 测试按钮
                Button(action: testConnection) {
                    HStack(spacing: 12) {
                        if isTesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.headline)
                        }
                        Text(isTesting ? "测试中..." : "测试连接")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
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
                .disabled(isTesting)

                Spacer()
            }
        }
        .navigationTitle("Supabase 测试")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 计算属性：状态图标
    private var statusIcon: String {
        if isTesting {
            return "arrow.triangle.2.circlepath"
        }

        switch isConnected {
        case nil:
            return "questionmark.circle.fill"
        case true:
            return "checkmark.circle.fill"
        case false:
            return "exclamationmark.triangle.fill"
        }
    }

    // MARK: - 计算属性：状态背景色
    private var statusBackgroundColor: Color {
        if isTesting {
            return ApocalypseTheme.info
        }

        switch isConnected {
        case nil:
            return ApocalypseTheme.textMuted
        case true:
            return ApocalypseTheme.success
        case false:
            return ApocalypseTheme.danger
        }
    }

    // MARK: - 测试连接方法
    private func testConnection() {
        isTesting = true
        debugLog = "🔍 开始测试 Supabase 连接...\n"
        debugLog += "📡 目标: \(supabaseURL)\n"
        debugLog += "⏳ 使用 REST API 查询不存在的表以验证连接...\n\n"

        Task {
            do {
                // 构建 REST API 请求 URL
                let endpoint = "\(supabaseURL)/rest/v1/non_existent_table?select=*"
                guard let url = URL(string: endpoint) else {
                    updateResult(success: false, message: "❌ URL 格式错误")
                    return
                }

                // 创建请求
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                // 发送请求
                let (data, response) = try await URLSession.shared.data(for: request)

                // 分析响应
                if let httpResponse = response as? HTTPURLResponse {
                    analyzeHTTPResponse(httpResponse, data: data)
                }

            } catch {
                // 分析错误信息
                analyzeError(error)
            }
        }
    }

    // MARK: - HTTP 响应分析
    @MainActor
    private func analyzeHTTPResponse(_ response: HTTPURLResponse, data: Data) {
        let statusCode = response.statusCode
        debugLog += "📊 HTTP 状态码: \(statusCode)\n"

        // 尝试解析响应内容
        if let responseString = String(data: data, encoding: .utf8) {
            debugLog += "📋 响应内容:\n\(responseString.prefix(200))\n\n"

            // 判断 1：404 错误（表不存在）
            if statusCode == 404 || responseString.contains("relation") ||
               responseString.contains("does not exist") {
                debugLog += "✅ 检测到 404 或表不存在错误\n"
                debugLog += "✅ 说明已成功连接到 Supabase\n"
                debugLog += "✅ 数据库响应正常！\n"
                updateResult(success: true, message: "✅ 连接成功（服务器已响应）")
                return
            }

            // 判断 2：PGRST 错误码
            if responseString.contains("PGRST") {
                debugLog += "✅ 检测到 PGRST 错误码\n"
                debugLog += "✅ 说明 PostgREST 服务器已响应\n"
                debugLog += "✅ Supabase 连接正常！\n"
                updateResult(success: true, message: "✅ 连接成功（服务器已响应）")
                return
            }

            // 判断 3：认证错误（也说明连接成功）
            if statusCode == 401 || statusCode == 403 {
                debugLog += "⚠️ 认证错误（但连接成功）\n"
                debugLog += "✅ 服务器可访问\n"
                updateResult(success: true, message: "✅ 连接成功（需要检查 API Key）")
                return
            }
        }

        // 判断 4：其他成功状态码
        if statusCode >= 200 && statusCode < 300 {
            debugLog += "✅ 请求成功\n"
            updateResult(success: true, message: "✅ 连接成功")
        } else {
            debugLog += "⚠️ 意外的状态码\n"
            updateResult(success: false, message: "❌ 状态码: \(statusCode)")
        }
    }

    // MARK: - 错误分析
    @MainActor
    private func analyzeError(_ error: Error) {
        let errorDescription = error.localizedDescription
        debugLog += "📋 错误详情：\n\(errorDescription)\n\n"

        // 判断：网络或 URL 错误
        if errorDescription.contains("hostname") ||
           errorDescription.contains("URL") ||
           errorDescription.contains("NSURLErrorDomain") ||
           errorDescription.contains("Could not connect") {
            debugLog += "❌ 检测到网络错误\n"
            debugLog += "❌ 可能原因：URL 配置错误或网络不可用\n"
            updateResult(success: false, message: "❌ 连接失败：URL 错误或无网络")
            return
        }

        // 其他错误
        debugLog += "❓ 未知错误类型\n"
        debugLog += "详细信息：\n\(error)\n"
        updateResult(success: false, message: "❌ 连接失败：\(errorDescription)")
    }

    // MARK: - 更新测试结果
    @MainActor
    private func updateResult(success: Bool, message: String) {
        isConnected = success
        debugLog += "\n" + String(repeating: "=", count: 40) + "\n"
        debugLog += message + "\n"
        debugLog += String(repeating: "=", count: 40) + "\n"
        isTesting = false
    }
}

// MARK: - 预览
#Preview {
    NavigationStack {
        SupabaseTestView()
    }
}
