# 🗑️ delete-account 边缘函数使用指南

## ✅ 部署状态

**函数已成功部署到 Supabase！**

- **函数名称**: `delete-account`
- **版本**: 1
- **状态**: `ACTIVE` ✅
- **JWT 验证**: 已启用 🔒
- **项目**: 地球领主 (npmazbowtfowbxvpjhst)

## 📍 函数 URL

```
https://npmazbowtfowbxvpjhst.supabase.co/functions/v1/delete-account
```

## 🔒 功能说明

这个边缘函数实现了安全的用户账户删除功能：

1. ✅ **JWT 验证**: 自动验证用户的 Authorization token
2. ✅ **身份确认**: 只允许用户删除自己的账户
3. ✅ **Service Role**: 使用 service_role key 调用 Admin API
4. ✅ **CORS 支持**: 支持跨域请求
5. ✅ **中文日志**: 所有日志都是中文，便于调试
6. ✅ **错误处理**: 完善的错误处理和响应

## 🚀 在 iOS 应用中调用

### 方法 1: 简单调用（推荐）

在您的 `AuthManager.swift` 中添加删除账户方法：

\`\`\`swift
/// 删除当前用户账户
func deleteAccount() async throws {
    print("🗑️ 开始删除账户...")
    isLoading = true
    errorMessage = nil

    guard let accessToken = accessToken else {
        throw AuthError.invalidResponse
    }

    // 调用边缘函数
    let url = URL(string: "\\(supabaseURL)/functions/v1/delete-account")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \\(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // 可选：发送确认参数
    let body = ["confirmation": "DELETE"]
    request.httpBody = try? JSONEncoder().encode(body)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw AuthError.invalidResponse
    }

    if httpResponse.statusCode == 200 {
        print("✅ 账户删除成功")

        // 清空本地状态
        clearTokens()
        isAuthenticated = false
        currentUser = nil

        print("🎉 用户已登出，账户已删除")
    } else {
        let errorText = String(data: data, encoding: .utf8) ?? "未知错误"
        print("❌ 删除失败: \\(errorText)")
        throw AuthError.apiError("删除账户失败")
    }

    isLoading = false
}
\`\`\`

### 方法 2: 带确认的调用

\`\`\`swift
/// 删除账户（带确认）
func deleteAccountWithConfirmation(confirmation: String) async throws {
    guard confirmation == "DELETE" else {
        throw AuthError.apiError("确认字符串不正确")
    }

    try await deleteAccount()
}
\`\`\`

## 🎨 在 UI 中使用

在您的设置页面或个人资料页面添加删除账户按钮：

\`\`\`swift
struct ProfileView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var showDeleteConfirmation = false
    @State private var deleteConfirmationText = ""

    var body: some View {
        VStack {
            // ... 其他设置 ...

            // 危险区域
            Section {
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("删除账户")
                    }
                    .foregroundColor(.red)
                }
            } header: {
                Text("危险操作")
                    .foregroundColor(.red)
            }
        }
        .alert("确认删除账户", isPresented: $showDeleteConfirmation) {
            TextField("输入 DELETE 确认", text: $deleteConfirmationText)

            Button("取消", role: .cancel) {
                deleteConfirmationText = ""
            }

            Button("删除", role: .destructive) {
                Task {
                    do {
                        try await authManager.deleteAccountWithConfirmation(
                            confirmation: deleteConfirmationText
                        )
                    } catch {
                        authManager.errorMessage = "删除账户失败: \\(error.localizedDescription)"
                    }
                }
            }
            .disabled(deleteConfirmationText != "DELETE")
        } message: {
            Text("此操作无法撤销！请输入 'DELETE' 确认删除您的账户。")
        }
    }
}
\`\`\`

## 📡 API 请求示例

### 请求

\`\`\`http
POST https://npmazbowtfowbxvpjhst.supabase.co/functions/v1/delete-account
Authorization: Bearer <用户的 JWT token>
apikey: <您的 anon key>
Content-Type: application/json

{
  "confirmation": "DELETE"  // 可选参数
}
\`\`\`

### 成功响应

\`\`\`json
{
  "success": true,
  "message": "账户已成功删除",
  "userId": "user-uuid-here"
}
\`\`\`

### 错误响应

\`\`\`json
{
  "error": "错误类型",
  "details": "详细错误信息"
}
\`\`\`

## 🔍 常见错误及解决方案

### 1. 401 未授权

**错误**: `{ "error": "未授权", "details": "缺少认证令牌" }`

**解决**: 确保在 Authorization header 中包含有效的 JWT token

### 2. Token 验证失败

**错误**: `{ "error": "Token 验证失败", "details": "无效的认证令牌" }`

**解决**: 检查 token 是否过期，如果过期请先刷新 token

### 3. 服务器配置错误

**错误**: `{ "error": "服务器配置错误" }`

**解决**: 这是 Supabase 服务端的问题，通常不应该发生。如果发生，请联系 Supabase 支持。

## 📊 函数日志

边缘函数包含详细的中文日志，可以在 Supabase Dashboard 中查看：

1. 访问 [Supabase Dashboard](https://supabase.com/dashboard/project/npmazbowtfowbxvpjhst)
2. 进入 **Edge Functions** → **delete-account**
3. 点击 **Logs** 查看日志

日志示例：
\`\`\`
🔐 开始删除账户请求...
✅ 验证成功，用户 ID: xxx-xxx-xxx
🗑️ 正在删除用户 xxx-xxx-xxx...
✅ 用户 xxx-xxx-xxx 已成功删除
\`\`\`

## ⚙️ 函数配置

- **verify_jwt**: `true` - 自动验证 JWT token
- **CORS**: 已启用，允许所有来源
- **方法**: 支持 `POST` 和 `OPTIONS`（预检）
- **Service Role**: 使用环境变量 `SUPABASE_SERVICE_ROLE_KEY`

## 🛡️ 安全特性

1. **JWT 验证**: 函数自动验证用户身份，确保只有登录用户才能调用
2. **用户隔离**: 用户只能删除自己的账户，无法删除其他用户
3. **Service Role**: 使用 service_role key 确保有权限删除用户
4. **HTTPS**: 所有请求都通过 HTTPS 加密传输
5. **确认机制**: 可选的确认参数防止误删除

## 🧪 测试函数

### 使用 curl 测试

\`\`\`bash
curl -X POST \\
  https://npmazbowtfowbxvpjhst.supabase.co/functions/v1/delete-account \\
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \\
  -H "apikey: YOUR_ANON_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{"confirmation": "DELETE"}'
\`\`\`

### 在 Supabase Dashboard 测试

1. 进入 **Edge Functions** → **delete-account**
2. 点击 **Invoke Function**
3. 添加 Authorization header
4. 发送测试请求

## 📝 注意事项

⚠️ **重要警告**:

1. **不可逆操作**: 删除账户后无法恢复
2. **数据清理**: 函数只删除用户认证信息，如果有关联的数据库记录，需要额外处理
3. **级联删除**: 建议在数据库中设置 ON DELETE CASCADE 来自动清理关联数据
4. **备份**: 在删除前建议提醒用户备份重要数据

## 🔄 数据库级联删除（推荐）

如果您的数据库中有关联用户的表，建议添加级联删除：

\`\`\`sql
-- 示例：用户配置表
ALTER TABLE user_profiles
  DROP CONSTRAINT IF EXISTS user_profiles_user_id_fkey,
  ADD CONSTRAINT user_profiles_user_id_fkey
    FOREIGN KEY (user_id)
    REFERENCES auth.users(id)
    ON DELETE CASCADE;

-- 示例：用户数据表
ALTER TABLE user_data
  DROP CONSTRAINT IF EXISTS user_data_user_id_fkey,
  ADD CONSTRAINT user_data_user_id_fkey
    FOREIGN KEY (user_id)
    REFERENCES auth.users(id)
    ON DELETE CASCADE;
\`\`\`

## 🎯 下一步

1. ✅ 函数已部署并可用
2. 📱 在 iOS 应用中添加 `deleteAccount()` 方法
3. 🎨 在 UI 中添加删除账户选项
4. 🗄️ 设置数据库级联删除（如果需要）
5. 🧪 在开发环境中测试功能
6. 🚀 部署到生产环境

---

**函数已就绪，可以开始使用！** 🎉
