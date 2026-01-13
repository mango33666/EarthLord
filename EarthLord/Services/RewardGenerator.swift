//
//  RewardGenerator.swift
//  EarthLord
//
//  奖励生成器
//  根据行走距离生成奖励物品
//

import Foundation

// MARK: - 奖励生成结果

struct RewardResult {
    let tier: RewardTier
    let items: [ObtainedItem]
}

// MARK: - 奖励生成器

class RewardGenerator {

    // MARK: - 单例

    static let shared = RewardGenerator()

    // MARK: - Supabase 配置

    private let supabaseURL = "https://npmazbowtfowbxvpjhst.supabase.co"
    private let supabaseKey = "sb_publishable_59Pm_KFRXgXJUVYUK0nwKg_RqnVRCKQ"

    // MARK: - 缓存的物品定义

    private var cachedItemDefinitions: [ItemDefinition] = []
    private var lastCacheTime: Date?
    private let cacheExpiration: TimeInterval = 3600 // 1小时缓存

    // MARK: - 私有初始化

    private init() {}

    // MARK: - 公开方法

    /// 根据距离生成奖励
    /// - Parameter distance: 行走距离（米）
    /// - Returns: 奖励结果（等级 + 物品列表）
    func generateReward(distance: Double) async -> RewardResult {
        // 1. 计算奖励等级
        let tier = calculateTier(distance: distance)

        // 2. 如果无奖励，直接返回
        guard tier != .none else {
            return RewardResult(tier: .none, items: [])
        }

        // 3. 加载物品定义
        await loadItemDefinitionsIfNeeded()

        // 4. 根据等级生成物品
        let items = generateItems(for: tier)

        return RewardResult(tier: tier, items: items)
    }

    /// 计算奖励等级
    /// - Parameter distance: 行走距离（米）
    /// - Returns: 奖励等级
    func calculateTier(distance: Double) -> RewardTier {
        if distance < 200 {
            return .none
        } else if distance < 500 {
            return .bronze
        } else if distance < 1000 {
            return .silver
        } else if distance < 2000 {
            return .gold
        } else {
            return .diamond
        }
    }

    // MARK: - 私有方法

    /// 加载物品定义（带缓存）
    private func loadItemDefinitionsIfNeeded() async {
        // 检查缓存是否有效
        if let lastCacheTime = lastCacheTime,
           Date().timeIntervalSince(lastCacheTime) < cacheExpiration,
           !cachedItemDefinitions.isEmpty {
            return
        }

        // 从数据库加载物品定义
        let endpoint = "\(supabaseURL)/rest/v1/item_definitions?select=*"
        guard let url = URL(string: endpoint) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let definitions = try decoder.decode([ItemDefinition].self, from: data)
            cachedItemDefinitions = definitions
            lastCacheTime = Date()

            print("✅ 物品定义已加载：\(definitions.count) 个物品")
        } catch {
            print("❌ 加载物品定义失败：\(error.localizedDescription)")
            // 如果加载失败，使用本地假数据作为后备
            cachedItemDefinitions = MockExplorationData.shared.itemDefinitions
        }
    }

    /// 根据等级生成物品列表
    private func generateItems(for tier: RewardTier) -> [ObtainedItem] {
        guard !cachedItemDefinitions.isEmpty else {
            print("⚠️ 物品定义为空，无法生成奖励")
            return []
        }

        // 获取该等级的配置
        let config = getTierConfig(tier)

        var items: [ObtainedItem] = []

        // 生成指定数量的物品
        for _ in 0..<config.itemCount {
            // 随机选择稀有度
            let rarity = selectRarity(config: config)

            // 从该稀有度的物品池中随机选择
            if let item = selectRandomItem(rarity: rarity) {
                items.append(ObtainedItem(
                    itemId: item.id,
                    itemName: item.name,
                    quantity: 1
                ))
            }
        }

        return items
    }

    /// 获取等级配置
    private func getTierConfig(_ tier: RewardTier) -> TierConfig {
        switch tier {
        case .none:
            return TierConfig(itemCount: 0, commonWeight: 0, rareWeight: 0, epicWeight: 0)
        case .bronze:
            return TierConfig(itemCount: 1, commonWeight: 90, rareWeight: 10, epicWeight: 0)
        case .silver:
            return TierConfig(itemCount: 2, commonWeight: 70, rareWeight: 25, epicWeight: 5)
        case .gold:
            return TierConfig(itemCount: 3, commonWeight: 50, rareWeight: 35, epicWeight: 15)
        case .diamond:
            return TierConfig(itemCount: 5, commonWeight: 30, rareWeight: 40, epicWeight: 30)
        }
    }

    /// 根据概率权重选择稀有度
    private func selectRarity(config: TierConfig) -> ItemRarity {
        let totalWeight = config.commonWeight + config.rareWeight + config.epicWeight
        let randomValue = Int.random(in: 0..<totalWeight)

        if randomValue < config.commonWeight {
            return .common
        } else if randomValue < config.commonWeight + config.rareWeight {
            return .rare
        } else {
            return .epic
        }
    }

    /// 从指定稀有度的物品池中随机选择
    private func selectRandomItem(rarity: ItemRarity) -> ItemDefinition? {
        // 根据稀有度筛选物品池
        let pool = cachedItemDefinitions.filter { $0.rarity == rarity }

        // 如果该稀有度没有物品，降级到普通物品
        if pool.isEmpty {
            let fallbackPool = cachedItemDefinitions.filter { $0.rarity == .common }
            return fallbackPool.randomElement()
        }

        return pool.randomElement()
    }
}

// MARK: - 等级配置

private struct TierConfig {
    let itemCount: Int
    let commonWeight: Int
    let rareWeight: Int
    let epicWeight: Int
}
