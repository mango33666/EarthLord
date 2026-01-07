//
//  DeviceIdentifier.swift
//  EarthLord
//
//  设备标识符工具类
//  提供稳定的设备 UUID，用于用户识别
//

import Foundation
import UIKit

// MARK: - 设备标识符管理器

class DeviceIdentifier {

    // MARK: - 单例

    static let shared = DeviceIdentifier()

    // MARK: - 常量

    private let userIdKey = "earth_lord_user_id"

    // MARK: - 私有初始化

    private init() {}

    // MARK: - 公开方法

    /// 获取用户 ID（使用 IDFV，如果不可用则生成并保存 UUID）
    /// - Returns: 用户 ID 字符串
    func getUserId() -> String {
        // 1. 先检查是否已经保存过用户 ID
        if let savedUserId = UserDefaults.standard.string(forKey: userIdKey) {
            return savedUserId
        }

        // 2. 尝试获取 IDFV（Identifier For Vendor）
        // IDFV 对于同一开发者的所有应用是相同的
        // 只有在卸载所有该开发者的应用后才会重置
        if let idfv = UIDevice.current.identifierForVendor?.uuidString {
            // 保存到 UserDefaults
            UserDefaults.standard.set(idfv, forKey: userIdKey)
            return idfv
        }

        // 3. 如果 IDFV 不可用（极少见情况），生成随机 UUID
        let generatedUUID = UUID().uuidString
        UserDefaults.standard.set(generatedUUID, forKey: userIdKey)

        print("⚠️ IDFV 不可用，使用生成的 UUID: \(generatedUUID)")
        return generatedUUID
    }

    /// 清除保存的用户 ID（仅用于测试）
    func clearUserId() {
        UserDefaults.standard.removeObject(forKey: userIdKey)
        print("🗑️ 已清除保存的用户 ID")
    }

    /// 检查是否是首次使用
    /// - Returns: 如果是首次使用返回 true
    func isFirstLaunch() -> Bool {
        return UserDefaults.standard.string(forKey: userIdKey) == nil
    }
}
