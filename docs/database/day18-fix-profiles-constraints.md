# Day 18 数据库配置修复

## 日期
2026-01-08

## 问题描述

用户上传领地时失败，错误信息：`"上传失败: 创建用户失败"`

## 根本原因

### 1. profiles 表外键约束冲突
- `profiles.id` 字段有外键约束指向 `auth.users` 表
- 应用使用设备 IDFV（iOS identifierForVendor）作为用户 ID
- IDFV 是标准 UUID 格式，但不存在于 Supabase Auth 的 `users` 表中
- 插入 profile 时违反外键约束被拒绝

### 2. RLS 策略限制
- `profiles_insert_own` 策略要求 `auth.uid() = id`
- 但应用未使用 Supabase Auth 认证
- 导致无法创建用户档案

## 解决方案

### 1. 删除 profiles.id 外键约束

```sql
-- 删除外键约束，允许使用设备 IDFV
ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS profiles_id_fkey;
```

**说明：**
- 删除 `profiles.id → auth.users` 的外键约束
- 允许应用使用设备 IDFV 作为独立的用户标识
- profiles 表不再依赖 Supabase Auth

### 2. 修改 profiles INSERT RLS 策略

```sql
-- 删除旧策略
DROP POLICY IF EXISTS profiles_insert_own ON public.profiles;

-- 创建新策略，允许任何人插入
CREATE POLICY profiles_insert_allow_all
ON public.profiles
FOR INSERT
TO public
WITH CHECK (true);
```

**说明：**
- 移除 `auth.uid()` 认证要求
- 允许任何人创建用户档案
- 适用于无需登录的开箱即用体验

### 3. territories INSERT RLS 策略（已在之前修复）

```sql
-- 删除旧策略
DROP POLICY IF EXISTS territories_insert_own ON public.territories;

-- 创建新策略
CREATE POLICY territories_insert_allow_all
ON public.territories
FOR INSERT TO public
WITH CHECK (true);
```

## 验证测试

### 测试用户插入

```sql
-- 成功插入测试用户
INSERT INTO profiles (id, username)
VALUES ('550e8400-e29b-41d4-a716-446655440000', '测试玩家_550e84')
RETURNING id, username, created_at;

-- 结果：
-- id: 550e8400-e29b-41d4-a716-446655440000
-- username: 测试玩家_550e84
-- created_at: 2026-01-08 11:22:30+00
```

### 当前约束状态

**profiles 表：**
- ✅ `profiles_pkey` (PRIMARY KEY)
- ✅ `profiles_username_key` (UNIQUE)
- ❌ `profiles_id_fkey` (已删除)

**territories 表：**
- ✅ `territories_pkey` (PRIMARY KEY)
- ✅ `territories_user_id_fkey` (FOREIGN KEY → profiles.id)

## 架构设计

```
设备 IDFV (UUID)
    ↓
profiles 表 (独立用户档案)
    ↓ (外键约束)
territories 表 (领地数据)
```

**特点：**
- profiles 表独立于 Supabase Auth
- 使用设备 IDFV 作为稳定标识
- 保留 territories → profiles 的数据完整性
- 支持无需登录的即用体验

## 预期结果

应用上传领地时：
1. 自动检查用户档案是否存在
2. 如不存在，使用 IDFV 创建用户档案
3. 上传领地数据（外键约束保证 user_id 有效）
4. 上传成功

## 后续考虑

### 生产环境建议

1. **添加 API 密钥验证**
   - 当前策略允许任何人插入（`WITH CHECK (true)`）
   - 生产环境应添加 API 密钥或其他认证机制

2. **迁移到 Supabase Auth**
   - 未来集成 Supabase Auth 后
   - 可考虑将设备 IDFV 用户迁移到 Auth 系统
   - 恢复 `profiles.id → auth.users` 外键约束

3. **防止重复用户名**
   - 当前 `username` 字段有唯一约束
   - 应用层应处理冲突（如添加随机后缀）

## 相关文件

- `EarthLord/Utilities/DeviceIdentifier.swift` - 设备标识符管理
- `EarthLord/Managers/TerritoryManager.swift` - 用户档案创建逻辑
- `EarthLord/Models/Territory.swift` - 领地数据模型

## 参考链接

- Supabase RLS 文档: https://supabase.com/docs/guides/auth/row-level-security
- iOS IDFV 文档: https://developer.apple.com/documentation/uikit/uidevice/1620059-identifierforvendor
