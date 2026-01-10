//
//  MockExplorationData.swift
//  EarthLord
//
//  探索模块测试假数据
//  用于开发和测试探索、背包、POI等功能
//

import Foundation
import CoreLocation

// MARK: - POI 兴趣点数据模型

/// 兴趣点状态
enum POIStatus: String, Codable {
    case undiscovered = "未发现"  // 未被探索过
    case discovered = "已发现"    // 已被探索过
}

/// 兴趣点类型
enum POIType: String, Codable {
    case supermarket = "超市"
    case hospital = "医院"
    case gasStation = "加油站"
    case pharmacy = "药店"
    case factory = "工厂"
    case warehouse = "仓库"
    case school = "学校"
}

/// 兴趣点（Point of Interest）
struct POI: Identifiable, Codable {
    let id: String
    let name: String                    // 名称
    let type: POIType                   // 类型
    let location: LocationCoordinate    // 位置坐标
    let status: POIStatus               // 状态
    let hasResources: Bool              // 是否有物资
    let description: String             // 描述
    let searchedAt: Date?               // 搜索时间
    let dangerLevel: Int                // 危险等级 (1-5)
}

/// 位置坐标（可编码版本）
struct LocationCoordinate: Codable {
    let latitude: Double
    let longitude: Double

    func toCLLocationCoordinate2D() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - 物品数据模型

/// 物品分类
enum ItemCategory: String, Codable {
    case water = "水类"
    case food = "食物"
    case medical = "医疗"
    case material = "材料"
    case tool = "工具"
    case weapon = "武器"
    case equipment = "装备"
}

/// 物品稀有度
enum ItemRarity: String, Codable {
    case common = "普通"      // 白色
    case uncommon = "优秀"    // 绿色
    case rare = "稀有"        // 蓝色
    case epic = "史诗"        // 紫色
    case legendary = "传说"   // 橙色
}

/// 物品品质（耐久度）
enum ItemQuality: String, Codable {
    case broken = "破损"      // 0-25%
    case worn = "磨损"        // 26-50%
    case good = "良好"        // 51-75%
    case excellent = "完好"   // 76-100%
}

/// 物品定义（物品的基础属性）
struct ItemDefinition: Identifiable, Codable {
    let id: String
    let name: String            // 中文名
    let category: ItemCategory  // 分类
    let weight: Double          // 重量（kg）
    let volume: Double          // 体积（L）
    let rarity: ItemRarity      // 稀有度
    let hasQuality: Bool        // 是否有品质/耐久度
    let description: String     // 描述
    let iconName: String        // 图标名称
}

/// 背包物品实例
struct InventoryItem: Identifiable, Codable {
    let id: String
    let itemId: String          // 物品定义ID
    var quantity: Int           // 数量
    var quality: ItemQuality?   // 品质（可选）
    let obtainedAt: Date        // 获得时间
}

// MARK: - 探索结果数据模型

/// 探索统计
struct ExplorationStats: Codable {
    // 距离统计
    let currentDistance: Double     // 本次行走距离（米）
    let totalDistance: Double       // 累计行走距离（米）
    let distanceRank: Int           // 距离排名

    // 面积统计
    let currentArea: Double         // 本次探索面积（平方米）
    let totalArea: Double           // 累计探索面积（平方米）
    let areaRank: Int               // 面积排名

    // 时长统计
    let duration: TimeInterval      // 探索时长（秒）

    // 获得物品
    let obtainedItems: [ObtainedItem]
}

/// 获得的物品
struct ObtainedItem: Codable {
    let itemId: String
    let itemName: String
    let quantity: Int
}

// MARK: - 测试假数据

class MockExplorationData {

    // MARK: - 单例

    static let shared = MockExplorationData()
    private init() {}

    // MARK: - POI 测试数据

    /// 测试POI列表（5个不同状态的兴趣点）
    lazy var mockPOIs: [POI] = [
        // 1. 废弃超市：已发现，有物资
        POI(
            id: "poi_001",
            name: "华联超市（废弃）",
            type: .supermarket,
            location: LocationCoordinate(
                latitude: 31.186565,
                longitude: 120.612623
            ),
            status: .discovered,
            hasResources: true,
            description: "二层建筑，大部分货架已空，但仍可能有物资残留。注意货架倒塌风险。",
            searchedAt: Date().addingTimeInterval(-86400 * 3), // 3天前
            dangerLevel: 2 // 低危
        ),

        // 2. 医院废墟：已发现，已被搜空
        POI(
            id: "poi_002",
            name: "东方医院（废墟）",
            type: .hospital,
            location: LocationCoordinate(
                latitude: 31.187000,
                longitude: 120.613000
            ),
            status: .discovered,
            hasResources: false,
            description: "建筑严重损毁，所有物资已被搜空。危险区域，不建议再次进入。",
            searchedAt: Date().addingTimeInterval(-86400 * 7), // 7天前
            dangerLevel: 3 // 中危
        ),

        // 3. 加油站：未发现
        POI(
            id: "poi_003",
            name: "中石化加油站",
            type: .gasStation,
            location: LocationCoordinate(
                latitude: 31.186000,
                longitude: 120.614000
            ),
            status: .undiscovered,
            hasResources: true,
            description: "小型加油站，可能有燃料和工具物资。",
            searchedAt: nil,
            dangerLevel: 4 // 高危
        ),

        // 4. 药店废墟：已发现，有物资
        POI(
            id: "poi_004",
            name: "百姓药房（废弃）",
            type: .pharmacy,
            location: LocationCoordinate(
                latitude: 31.185500,
                longitude: 120.612000
            ),
            status: .discovered,
            hasResources: true,
            description: "单层建筑，部分药品还可使用。需要专业知识识别药品。",
            searchedAt: Date().addingTimeInterval(-86400), // 1天前
            dangerLevel: 2 // 低危
        ),

        // 5. 工厂废墟：未发现
        POI(
            id: "poi_005",
            name: "机械制造厂（废弃）",
            type: .factory,
            location: LocationCoordinate(
                latitude: 31.185000,
                longitude: 120.615000
            ),
            status: .undiscovered,
            hasResources: true,
            description: "大型工厂，可能有工具、材料等物资。结构复杂，探索需谨慎。",
            searchedAt: nil,
            dangerLevel: 5 // 极危
        )
    ]

    // MARK: - 物品定义表

    /// 物品定义表（所有可用物品的基础数据）
    lazy var itemDefinitions: [ItemDefinition] = [
        // 水类
        ItemDefinition(
            id: "item_water_001",
            name: "矿泉水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .common,
            hasQuality: false,
            description: "550ml瓶装矿泉水，生存必需品。",
            iconName: "drop.fill"
        ),

        // 食物
        ItemDefinition(
            id: "item_food_001",
            name: "罐头食品",
            category: .food,
            weight: 0.4,
            volume: 0.3,
            rarity: .common,
            hasQuality: false,
            description: "密封罐头，保质期长，可以长期储存。",
            iconName: "takeoutbag.and.cup.and.straw.fill"
        ),

        ItemDefinition(
            id: "item_food_002",
            name: "压缩饼干",
            category: .food,
            weight: 0.3,
            volume: 0.2,
            rarity: .uncommon,
            hasQuality: false,
            description: "军用压缩饼干，能量密度高。",
            iconName: "square.stack.3d.up.fill"
        ),

        // 医疗
        ItemDefinition(
            id: "item_medical_001",
            name: "绷带",
            category: .medical,
            weight: 0.1,
            volume: 0.1,
            rarity: .common,
            hasQuality: true,
            description: "医用绷带，用于包扎伤口。",
            iconName: "cross.case.fill"
        ),

        ItemDefinition(
            id: "item_medical_002",
            name: "消炎药",
            category: .medical,
            weight: 0.05,
            volume: 0.05,
            rarity: .uncommon,
            hasQuality: false,
            description: "常用消炎药物，预防感染。",
            iconName: "pills.fill"
        ),

        ItemDefinition(
            id: "item_medical_003",
            name: "急救包",
            category: .medical,
            weight: 0.8,
            volume: 0.6,
            rarity: .rare,
            hasQuality: true,
            description: "完整的急救工具包，包含多种医疗用品。",
            iconName: "cross.case.fill"
        ),

        // 材料
        ItemDefinition(
            id: "item_material_001",
            name: "木材",
            category: .material,
            weight: 2.0,
            volume: 3.0,
            rarity: .common,
            hasQuality: true,
            description: "建筑用木材，可用于制作和修复。",
            iconName: "square.stack.3d.down.right.fill"
        ),

        ItemDefinition(
            id: "item_material_002",
            name: "废金属",
            category: .material,
            weight: 3.0,
            volume: 1.5,
            rarity: .common,
            hasQuality: false,
            description: "废弃金属零件，可以重新加工利用。",
            iconName: "cube.box.fill"
        ),

        ItemDefinition(
            id: "item_material_003",
            name: "布料",
            category: .material,
            weight: 0.5,
            volume: 1.0,
            rarity: .common,
            hasQuality: true,
            description: "各类织物，可用于制作衣物和遮蔽物。",
            iconName: "tshirt.fill"
        ),

        // 工具
        ItemDefinition(
            id: "item_tool_001",
            name: "手电筒",
            category: .tool,
            weight: 0.3,
            volume: 0.2,
            rarity: .uncommon,
            hasQuality: true,
            description: "LED手电筒，夜间探索必备。需要电池。",
            iconName: "flashlight.on.fill"
        ),

        ItemDefinition(
            id: "item_tool_002",
            name: "绳子",
            category: .tool,
            weight: 1.0,
            volume: 0.5,
            rarity: .common,
            hasQuality: true,
            description: "10米长的尼龙绳，用途广泛。",
            iconName: "link"
        ),

        ItemDefinition(
            id: "item_tool_003",
            name: "多功能刀",
            category: .tool,
            weight: 0.2,
            volume: 0.1,
            rarity: .uncommon,
            hasQuality: true,
            description: "瑞士军刀，集成多种工具功能。",
            iconName: "scissors"
        )
    ]

    // MARK: - 背包物品测试数据

    /// 测试背包物品（6-8种不同类型）
    lazy var mockInventoryItems: [InventoryItem] = [
        // 水类
        InventoryItem(
            id: "inv_001",
            itemId: "item_water_001",
            quantity: 8,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-86400 * 2)
        ),

        // 食物
        InventoryItem(
            id: "inv_002",
            itemId: "item_food_001",
            quantity: 5,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-86400 * 2)
        ),

        InventoryItem(
            id: "inv_003",
            itemId: "item_food_002",
            quantity: 3,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-86400)
        ),

        // 医疗
        InventoryItem(
            id: "inv_004",
            itemId: "item_medical_001",
            quantity: 12,
            quality: .good,
            obtainedAt: Date().addingTimeInterval(-86400 * 3)
        ),

        InventoryItem(
            id: "inv_005",
            itemId: "item_medical_002",
            quantity: 6,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-86400)
        ),

        // 材料
        InventoryItem(
            id: "inv_006",
            itemId: "item_material_001",
            quantity: 15,
            quality: .worn,
            obtainedAt: Date().addingTimeInterval(-86400 * 4)
        ),

        InventoryItem(
            id: "inv_007",
            itemId: "item_material_002",
            quantity: 20,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-86400 * 5)
        ),

        // 工具
        InventoryItem(
            id: "inv_008",
            itemId: "item_tool_001",
            quantity: 2,
            quality: .excellent,
            obtainedAt: Date().addingTimeInterval(-86400 * 6)
        ),

        InventoryItem(
            id: "inv_009",
            itemId: "item_tool_002",
            quantity: 3,
            quality: .good,
            obtainedAt: Date().addingTimeInterval(-86400 * 7)
        )
    ]

    // MARK: - 探索结果测试数据

    /// 测试探索结果
    lazy var mockExplorationStats: ExplorationStats = {
        return ExplorationStats(
            // 距离统计
            currentDistance: 2500.0,        // 本次2500米
            totalDistance: 15000.0,         // 累计15公里
            distanceRank: 42,               // 排名42

            // 面积统计
            currentArea: 50000.0,           // 本次5万平方米（0.05平方公里）
            totalArea: 250000.0,            // 累计25万平方米（0.25平方公里）
            areaRank: 38,                   // 排名38

            // 时长
            duration: 1800.0,               // 30分钟

            // 获得物品
            obtainedItems: [
                ObtainedItem(itemId: "item_material_001", itemName: "木材", quantity: 5),
                ObtainedItem(itemId: "item_water_001", itemName: "矿泉水", quantity: 3),
                ObtainedItem(itemId: "item_food_001", itemName: "罐头食品", quantity: 2),
                ObtainedItem(itemId: "item_medical_001", itemName: "绷带", quantity: 4),
                ObtainedItem(itemId: "item_material_003", itemName: "布料", quantity: 8)
            ]
        )
    }()

    // MARK: - 辅助方法

    /// 根据ID获取物品定义
    func getItemDefinition(by id: String) -> ItemDefinition? {
        return itemDefinitions.first { $0.id == id }
    }

    /// 获取某个背包物品的完整信息（包含物品定义）
    func getFullInventoryItem(_ inventoryItem: InventoryItem) -> (item: InventoryItem, definition: ItemDefinition)? {
        guard let definition = getItemDefinition(by: inventoryItem.itemId) else {
            return nil
        }
        return (inventoryItem, definition)
    }

    /// 计算背包总重量
    func calculateTotalWeight() -> Double {
        var totalWeight = 0.0
        for item in mockInventoryItems {
            if let definition = getItemDefinition(by: item.itemId) {
                totalWeight += definition.weight * Double(item.quantity)
            }
        }
        return totalWeight
    }

    /// 计算背包总体积
    func calculateTotalVolume() -> Double {
        var totalVolume = 0.0
        for item in mockInventoryItems {
            if let definition = getItemDefinition(by: item.itemId) {
                totalVolume += definition.volume * Double(item.quantity)
            }
        }
        return totalVolume
    }

    /// 获取已发现的POI列表
    func getDiscoveredPOIs() -> [POI] {
        return mockPOIs.filter { $0.status == .discovered }
    }

    /// 获取未发现的POI列表
    func getUndiscoveredPOIs() -> [POI] {
        return mockPOIs.filter { $0.status == .undiscovered }
    }

    /// 获取有物资的POI列表
    func getPOIsWithResources() -> [POI] {
        return mockPOIs.filter { $0.hasResources }
    }
}
