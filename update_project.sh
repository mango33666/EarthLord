#!/bin/bash

PROJECT_FILE="/Users/mangguo888/Desktop/EarthLord/EarthLord.xcodeproj/project.pbxproj"

echo "📝 更新项目配置以使用自定义 Info.plist..."

# 备份项目文件
cp "$PROJECT_FILE" "$PROJECT_FILE.backup"

# 替换 GENERATE_INFOPLIST_FILE = YES; 为 NO;
# 并添加 INFOPLIST_FILE 配置
sed -i '' 's/GENERATE_INFOPLIST_FILE = YES;/GENERATE_INFOPLIST_FILE = NO;\
				INFOPLIST_FILE = EarthLord\/Info.plist;/g' "$PROJECT_FILE"

echo "✅ 项目配置已更新"
echo "💾 备份文件: $PROJECT_FILE.backup"
