# 解决构建错误指南

## ❌ 错误原因

```
Multiple commands produce '/Users/mangguo888/Library/Developer/Xcode/DerivedData/EarthLord-.../Info.plist'
```

**原因**: 项目同时配置了自动生成 Info.plist 和手动 Info.plist 文件，导致冲突。

## ✅ 已完成的修复步骤

1. ✅ 删除了手动创建的 `EarthLord/Info.plist` 文件

## 🔧 需要在 Xcode 中完成的配置

### 步骤 1: 在 Xcode 中配置 URL Scheme

由于我们删除了手动的 Info.plist，现在需要直接在 Xcode 项目设置中添加 URL Scheme：

1. **打开 Xcode 项目**
   - 打开 `EarthLord.xcodeproj`

2. **选择 Target**
   - 在项目导航器中，点击最顶部的 `EarthLord` 项目
   - 在 TARGETS 列表中选择 `EarthLord`

3. **进入 Info 标签页**
   - 点击顶部的 `Info` 标签

4. **添加 URL Type**
   - 找到 `URL Types` 部分（可能需要展开）
   - 点击左下角的 `+` 按钮添加新的 URL Type

5. **填写配置**
   - **Identifier**: `com.google.oauth2`（或任意标识符）
   - **URL Schemes**: 点击展开，添加：
     ```
     com.googleusercontent.apps.673837093726-u0gq3h8fr7dnea6b8bm917og4o6jut64
     ```
   - **Role**: 选择 `Editor`

### 步骤 2: 清理构建缓存

在 Xcode 中：
1. 菜单栏选择：`Product` → `Clean Build Folder`
2. 或者按快捷键：`Shift + Command + K`

### 步骤 3: 重新构建

1. 菜单栏选择：`Product` → `Build`
2. 或者按快捷键：`Command + B`

## 📸 配置截图参考

### Info 标签页 - URL Types 配置应该如下：

```
URL Types
  ▼ Item 0
      Identifier: com.google.oauth2
      URL Schemes
        ▼ Item 0: com.googleusercontent.apps.673837093726-u0gq3h8fr7dnea6b8bm917og4o6jut64
      Role: Editor
```

## 🧪 验证配置

配置完成后，可以在终端运行以下命令验证：

```bash
# 构建项目
xcodebuild -project /Users/mangguo888/Desktop/EarthLord/EarthLord.xcodeproj \
  -scheme EarthLord \
  -sdk iphonesimulator \
  clean build
```

## ⚠️ 注意事项

1. **不要手动创建 Info.plist 文件**
   - 项目已配置为自动生成 Info.plist（`GENERATE_INFOPLIST_FILE = YES`）
   - 所有配置都应该在 Xcode 的项目设置中完成

2. **URL Scheme 格式**
   - 必须是完整的反向域名格式
   - 格式：`com.googleusercontent.apps.YOUR-CLIENT-ID`
   - 您的：`com.googleusercontent.apps.673837093726-u0gq3h8fr7dnea6b8bm917og4o6jut64`

3. **如果问题仍然存在**
   - 删除 DerivedData 文件夹：
     ```bash
     rm -rf ~/Library/Developer/Xcode/DerivedData/EarthLord-*
     ```
   - 重启 Xcode
   - 重新构建项目

## 🎯 预期结果

配置完成后：
- ✅ 构建成功，无错误
- ✅ Google 登录可以正常工作
- ✅ URL 回调可以正确处理
- ✅ 中文日志正常输出

---

**问题已解决？** 如果还有其他错误，请检查 Xcode 的错误日志并提供具体信息。
