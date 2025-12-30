# Google 登录配置指南

## ✅ 已完成的配置

### 1. GoogleSignIn SDK
- ✅ 已手动添加到项目
- ✅ 在 `EarthLordApp.swift` 中已导入并配置 URL 回调处理

### 2. Supabase Google Provider
- ✅ 已启用
- ✅ Authorized Client IDs 已填入
- ✅ Skip nonce check 已开启

### 3. Google 登录功能实现
- ✅ `AuthManager.swift` 中完整实现了 Google 登录流程（第 496-617 行）
- ✅ `AuthView.swift` 中已添加 Google 登录按钮（第 554-573 行）
- ✅ 所有关键步骤都已添加中文调试日志

### 4. 中文调试日志
以下日志已添加到 `AuthManager.swift` 中：
- 🔐 开始 Google 登录流程...
- ✅ 获取根视图控制器成功
- 🔧 Google Sign-In 配置完成，开始授权...
- ✅ Google 授权成功，用户: xxx
- 🎫 成功获取 Google ID Token
- 📤 准备发送到 Supabase 进行验证...
- 📡 发送请求到 Supabase...
- 📥 收到 Supabase 响应，状态码: xxx
- ✅ Supabase 认证成功
- 💾 令牌已保存
- 👤 用户信息已设置: xxx
- 🎉 Google 登录流程完成！

## ⚙️ 需要在 Xcode 中配置的步骤

### 方法一：在 Xcode 中手动配置 URL Scheme（推荐）

1. 在 Xcode 中打开 `EarthLord.xcodeproj`
2. 选择项目导航器中的 `EarthLord` 项目
3. 选择 `EarthLord` Target
4. 选择 `Info` 标签页
5. 展开 `URL Types` 部分
6. 点击 `+` 添加新的 URL Type
7. 填写以下信息：
   - **Identifier**: `com.google.oauth2`
   - **URL Schemes**: `com.googleusercontent.apps.673837093726-u0gq3h8fr7dnea6b8bm917og4o6jut64`
   - **Role**: `Editor`

### 方法二：使用 Info.plist 文件

如果项目使用自定义 Info.plist：

1. 在 Xcode 中打开 `EarthLord/Info.plist`
2. 验证以下配置已存在：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.673837093726-u0gq3h8fr7dnea6b8bm917og4o6jut64</string>
        </array>
    </dict>
</array>
```

如果项目配置为自动生成 Info.plist（`GENERATE_INFOPLIST_FILE = YES`），需要：

1. 在 Xcode 项目设置中，将 `Generate Info.plist File` 设置为 `NO`
2. 在 `Info.plist File` 字段中输入：`EarthLord/Info.plist`
3. 将项目中的 `Info.plist` 文件添加到项目

## 🧪 测试 Google 登录

### 1. 在真机或模拟器上运行应用
```bash
# 在模拟器上运行
xcodebuild -scheme EarthLord -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build

# 或者直接在 Xcode 中运行（Command + R）
```

### 2. 查看调试日志

运行应用后，点击"通过 Google 登录"按钮，在 Xcode 控制台中查看日志输出：

```
🔐 开始 Google 登录流程...
✅ 获取根视图控制器成功
🔧 Google Sign-In 配置完成，开始授权...
📱 收到 URL 回调: com.googleusercontent.apps.673837093726-u0gq3h8fr7dnea6b8bm917og4o6jut64://...
✅ Google 授权成功，用户: user@example.com
🎫 成功获取 Google ID Token
📤 准备发送到 Supabase 进行验证...
📡 发送请求到 Supabase...
📥 收到 Supabase 响应，状态码: 200
✅ Supabase 认证成功
💾 令牌已保存
👤 用户信息已设置: user@example.com
🎉 Google 登录流程完成！
```

### 3. 常见问题排查

#### 问题 1：点击 Google 登录没有反应
- 检查 Xcode 控制台是否有错误日志
- 确认 URL Scheme 已正确配置
- 检查 Google Client ID 是否正确

#### 问题 2：Google 授权后无法返回应用
- 确认 URL Scheme 格式正确：`com.googleusercontent.apps.673837093726-u0gq3h8fr7dnea6b8bm917og4o6jut64`
- 检查 `EarthLordApp.swift` 中的 `onOpenURL` 是否正确配置

#### 问题 3：Supabase 认证失败
- 检查 Supabase Google Provider 是否已启用
- 确认 Authorized Client IDs 中包含：`673837093726-u0gq3h8fr7dnea6b8bm917og4o6jut64.apps.googleusercontent.com`
- 确认 Skip nonce check 已开启

## 📝 关键文件位置

- **Google 登录逻辑**: `EarthLord/Services/AuthManager.swift` (第 496-617 行)
- **Google 登录按钮**: `EarthLord/Views/AuthView.swift` (第 554-573 行)
- **URL 回调处理**: `EarthLord/EarthLordApp.swift` (第 30-33 行)
- **URL Scheme 配置**: `EarthLord/Info.plist`
- **Google Client ID**: `673837093726-u0gq3h8fr7dnea6b8bm917og4o6jut64.apps.googleusercontent.com`

## 🎯 配置完成后的功能

✅ 用户可以点击"通过 Google 登录"按钮
✅ 应用打开 Google 授权页面
✅ 用户授权后返回应用
✅ 应用获取 Google ID Token
✅ 应用使用 Token 登录 Supabase
✅ 登录成功后进入主界面
✅ 所有步骤都有详细的中文日志输出

---

**注意**: 如果使用真机测试，确保设备已登录 Google 账号，或者有网络连接可以登录 Google。
