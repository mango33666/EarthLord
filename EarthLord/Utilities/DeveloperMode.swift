//
//  DeveloperMode.swift
//  EarthLord
//
//  开发者模式管理器
//  支持临时切换测试用户 ID，用于多用户场景测试
//

import Foundation
import Combine

// MARK: - 开发者模式管理器

class DeveloperMode: ObservableObject {

    // MARK: - 单例

    static let shared = DeveloperMode()

    // MARK: - 发布属性

    /// 是否启用开发者模式
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "dev_mode_enabled")
            if !isEnabled {
                // 禁用开发者模式时，清除测试用户 ID
                testUserId = nil
            }
        }
    }

    /// 测试用户 ID（nil 表示使用真实设备 IDFV）
    @Published var testUserId: String? {
        didSet {
            if let userId = testUserId {
                UserDefaults.standard.set(userId, forKey: "dev_mode_test_user_id")
            } else {
                UserDefaults.standard.removeObject(forKey: "dev_mode_test_user_id")
            }
        }
    }

    // MARK: - 预设测试用户

    /// 预设的测试用户列表
    let presetUsers: [(name: String, id: String)] = [
        ("用户 A", "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
        ("用户 B", "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"),
        ("用户 C", "cccccccc-cccc-cccc-cccc-cccccccccccc"),
        ("用户 D", "dddddddd-dddd-dddd-dddd-dddddddddddd"),
        ("用户 E", "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee"),
    ]

    // MARK: - 私有初始化

    private init() {
        // 从 UserDefaults 恢复状态
        self.isEnabled = UserDefaults.standard.bool(forKey: "dev_mode_enabled")
        self.testUserId = UserDefaults.standard.string(forKey: "dev_mode_test_user_id")
    }

    // MARK: - 公开方法

    /// 获取有效的用户 ID（如果启用开发者模式且设置了测试用户 ID，返回测试 ID；否则返回真实设备 IDFV）
    func getEffectiveUserId() -> String {
        if isEnabled, let testId = testUserId {
            return testId
        }
        return DeviceIdentifier.shared.getUserId()
    }

    /// 切换到指定的预设用户
    func switchToPresetUser(index: Int) {
        guard index < presetUsers.count else { return }
        testUserId = presetUsers[index].id
    }

    /// 切换到真实设备用户
    func switchToRealUser() {
        testUserId = nil
    }

    /// 获取当前用户显示名称
    func getCurrentUserDisplayName() -> String {
        let effectiveId = getEffectiveUserId()
        let realId = DeviceIdentifier.shared.getUserId()

        if effectiveId == realId {
            return "真实设备用户"
        }

        if let preset = presetUsers.first(where: { $0.id == effectiveId }) {
            return preset.name
        }

        return "自定义用户"
    }

    /// 获取当前用户 ID 的缩写显示（前 8 位）
    func getCurrentUserIdShort() -> String {
        let effectiveId = getEffectiveUserId()
        return String(effectiveId.prefix(8))
    }
}
