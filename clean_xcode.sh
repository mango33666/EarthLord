#!/bin/bash

echo "🧹 开始清理 Xcode 缓存..."

# 关闭 Xcode
echo "1. 尝试关闭 Xcode..."
killall Xcode 2>/dev/null || echo "Xcode 未运行"

# 等待
sleep 2

# 清理 DerivedData
echo "2. 清理 DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/EarthLord-*

# 清理包缓存
echo "3. 清理 Swift Package 缓存..."
rm -rf ~/Library/Caches/org.swift.swiftpm/
rm -rf ~/Library/Caches/com.apple.dt.Xcode/

# 清理模块缓存
echo "4. 清理模块缓存..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/

echo "✅ 清理完成！"
echo "📱 现在请打开 Xcode，然后："
echo "   1. File → Packages → Reset Package Caches"
echo "   2. Product → Clean Build Folder"
echo "   3. Product → Build"
