//
//  InventoryManager.swift
//  EarthLord
//
//  背包管理器
//  负责管理玩家背包物品的增删改查
//

import Foundation
import Combine

// MARK: - 背包管理器

@MainActor
class InventoryManager: ObservableObject {

    // MARK: - 单例

    static let shared = InventoryManager()

    // MARK: - Published 属性

    /// 背包物品列表
    @Published var inventoryItems: [InventoryItem] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    // MARK: - Supabase 配置

    private let supabaseURL = "https://npmazbowtfowbxvpjhst.supabase.co"
    private let supabaseKey = "sb_publishable_59Pm_KFRXgXJUVYUK0nwKg_RqnVRCKQ"

    // MARK: - 私有初始化

    private init() {}

    // MARK: - 公开方法

    /// 加载背包物品
    func loadInventory() async throws {
        isLoading = true
        defer { isLoading = false }

        let userId = DeviceIdentifier.shared.getUserId()
        let endpoint = "\(supabaseURL)/rest/v1/inventory_items?user_id=eq.\(userId)&select=*"

        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "InventoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "InventoryManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "加载背包失败"])
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let items = try decoder.decode([InventoryItem].self, from: data)
        inventoryItems = items

        print("✅ 背包已加载：\(items.count) 个物品")
    }

    /// 添加物品到背包
    /// - Parameter items: 要添加的物品列表
    func addItems(_ items: [ObtainedItem]) async throws {
        guard !items.isEmpty else { return }

        let userId = DeviceIdentifier.shared.getUserId()
        print("🎒 [InventoryManager] 准备添加 \(items.count) 个物品到背包")
        print("🎒 [InventoryManager] 用户ID: \(userId)")

        // 确保用户档案存在
        try await ensureUserProfileExists(userId: userId)

        for obtainedItem in items {
            print("🎒 [InventoryManager] 处理物品: \(obtainedItem.itemName) x\(obtainedItem.quantity)")

            // 检查背包中是否已有该物品
            let matchingItems = inventoryItems.filter { item in
                let itemIdMatches = item.itemId == obtainedItem.itemId
                let qualityIsNil = item.quality == nil
                return itemIdMatches && qualityIsNil
            }

            if let existingItem = matchingItems.first {
                // 已有该物品，更新数量
                print("🎒 [InventoryManager] 物品已存在，更新数量: \(existingItem.quantity) + \(obtainedItem.quantity)")
                try await updateItemQuantity(
                    itemId: existingItem.id,
                    newQuantity: existingItem.quantity + obtainedItem.quantity
                )
            } else {
                // 没有该物品，创建新记录
                print("🎒 [InventoryManager] 创建新物品记录...")
                try await createNewItem(
                    userId: userId,
                    itemId: obtainedItem.itemId,
                    quantity: obtainedItem.quantity
                )
            }
        }

        // 重新加载背包
        try await loadInventory()

        print("✅ [InventoryManager] 已添加 \(items.count) 个物品到背包")
    }

    /// 确保用户档案存在于 profiles 表中
    private func ensureUserProfileExists(userId: String) async throws {
        // 检查用户是否已存在
        let checkEndpoint = "\(supabaseURL)/rest/v1/profiles?id=eq.\(userId)&select=id"
        guard let checkUrl = URL(string: checkEndpoint) else {
            throw NSError(domain: "InventoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 URL"])
        }

        var checkRequest = URLRequest(url: checkUrl)
        checkRequest.httpMethod = "GET"
        checkRequest.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        checkRequest.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

        let (checkData, _) = try await URLSession.shared.data(for: checkRequest)

        // 解析查询结果
        if let jsonArray = try? JSONSerialization.jsonObject(with: checkData) as? [[String: Any]],
           !jsonArray.isEmpty {
            // 用户已存在
            print("🎒 [InventoryManager] 用户档案已存在")
            return
        }

        // 用户不存在，创建新用户
        print("🎒 [InventoryManager] 首次使用，创建用户档案...")

        let createEndpoint = "\(supabaseURL)/rest/v1/profiles"
        guard let createUrl = URL(string: createEndpoint) else {
            throw NSError(domain: "InventoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 URL"])
        }

        let username = "玩家_\(String(userId.prefix(6)).uppercased())"
        let profileData: [String: Any] = [
            "id": userId,
            "username": username
        ]

        var createRequest = URLRequest(url: createUrl)
        createRequest.httpMethod = "POST"
        createRequest.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        createRequest.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        createRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        createRequest.httpBody = try JSONSerialization.data(withJSONObject: profileData)

        let (_, response) = try await URLSession.shared.data(for: createRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("❌ [InventoryManager] 创建用户档案失败")
            throw NSError(domain: "InventoryManager", code: -7, userInfo: [NSLocalizedDescriptionKey: "创建用户档案失败"])
        }

        print("✅ [InventoryManager] 用户档案创建成功: \(username)")
    }

    /// 移除物品（减少数量）
    /// - Parameters:
    ///   - itemId: 背包物品实例ID（String）
    ///   - quantity: 要移除的数量
    func removeItem(itemId: String, quantity: Int) async throws {
        guard let item = inventoryItems.first(where: { $0.id == itemId }) else {
            throw NSError(domain: "InventoryManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "物品不存在"])
        }

        let newQuantity = item.quantity - quantity

        if newQuantity <= 0 {
            // 删除物品
            try await deleteItem(itemId: itemId)
        } else {
            // 更新数量
            try await updateItemQuantity(itemId: itemId, newQuantity: newQuantity)
        }

        // 重新加载背包
        try await loadInventory()

        print("✅ 已移除物品：\(quantity) 个")
    }

    // MARK: - 私有方法

    /// 更新物品数量
    private func updateItemQuantity(itemId: String, newQuantity: Int) async throws {
        let endpoint = "\(supabaseURL)/rest/v1/inventory_items?id=eq.\(itemId)"
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "InventoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 URL"])
        }

        let updateData: [String: Any] = ["quantity": newQuantity, "updated_at": ISO8601DateFormatter().string(from: Date())]
        let jsonData = try JSONSerialization.data(withJSONObject: updateData)

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "InventoryManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "更新物品数量失败"])
        }
    }

    /// 创建新物品
    private func createNewItem(userId: String, itemId: String, quantity: Int) async throws {
        let endpoint = "\(supabaseURL)/rest/v1/inventory_items"
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "InventoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 URL"])
        }

        let newItem: [String: Any] = [
            "user_id": userId,
            "item_id": itemId,
            "quantity": quantity,
            "obtained_at": ISO8601DateFormatter().string(from: Date())
        ]

        print("🎒 [InventoryManager] 插入数据: user_id=\(userId), item_id=\(itemId), quantity=\(quantity)")

        let jsonData = try JSONSerialization.data(withJSONObject: newItem)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "InventoryManager", code: -5, userInfo: [NSLocalizedDescriptionKey: "无效的响应"])
        }

        if httpResponse.statusCode == 201 {
            print("✅ [InventoryManager] 物品创建成功")
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
            print("❌ [InventoryManager] 创建物品失败: HTTP \(httpResponse.statusCode)")
            print("❌ [InventoryManager] 错误详情: \(errorMessage)")
            throw NSError(domain: "InventoryManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "创建物品失败: \(errorMessage)"])
        }
    }

    /// 删除物品
    private func deleteItem(itemId: String) async throws {
        let endpoint = "\(supabaseURL)/rest/v1/inventory_items?id=eq.\(itemId)"
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "InventoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "InventoryManager", code: -6, userInfo: [NSLocalizedDescriptionKey: "删除物品失败"])
        }
    }
}
