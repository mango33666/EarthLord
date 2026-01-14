//
//  POI.swift
//  EarthLord
//
//  POI（兴趣点）数据模型
//  用于存储附近可搜刮的真实地点信息
//

import Foundation
import CoreLocation
import MapKit

// MARK: - POI 数据模型

/// 兴趣点（可搜刮的真实地点）
struct POI: Identifiable, Equatable {

    // MARK: - 属性

    /// 唯一标识符（用于地理围栏 identifier）
    let id: String

    /// 地点名称
    let name: String

    /// 地点坐标
    let coordinate: CLLocationCoordinate2D

    /// 地点类型
    let category: POICategory

    /// 是否已被搜刮
    var isScavenged: Bool = false

    // MARK: - Equatable

    static func == (lhs: POI, rhs: POI) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude &&
               lhs.category == rhs.category &&
               lhs.isScavenged == rhs.isScavenged
    }

    // MARK: - 便利初始化

    /// 从 MKMapItem 创建 POI
    init(from mapItem: MKMapItem, category: POICategory) {
        self.id = UUID().uuidString
        self.name = mapItem.name ?? "未知地点"
        // 使用 location 获取坐标
        self.coordinate = mapItem.location.coordinate
        self.category = category
        self.isScavenged = false
    }

    /// 完整初始化
    init(id: String, name: String, coordinate: CLLocationCoordinate2D, category: POICategory, isScavenged: Bool = false) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.category = category
        self.isScavenged = isScavenged
    }
}

// MARK: - POI 类型枚举

/// POI 类型
enum POICategory: String, CaseIterable {

    case store = "商店"
    case hospital = "医院"
    case pharmacy = "药店"
    case gasStation = "加油站"
    case restaurant = "餐厅"
    case cafe = "咖啡店"
    case convenience = "便利店"
    case supermarket = "超市"
    case other = "其他"

    // MARK: - 图标

    /// 获取对应的图标（Emoji）
    var icon: String {
        switch self {
        case .store:
            return "🏪"
        case .hospital:
            return "🏥"
        case .pharmacy:
            return "💊"
        case .gasStation:
            return "⛽"
        case .restaurant:
            return "🍽️"
        case .cafe:
            return "☕"
        case .convenience:
            return "🏬"
        case .supermarket:
            return "🛒"
        case .other:
            return "📍"
        }
    }

    /// 获取对应的 SF Symbol 图标名称
    var systemImage: String {
        switch self {
        case .store:
            return "storefront"
        case .hospital:
            return "cross.case.fill"
        case .pharmacy:
            return "pills.fill"
        case .gasStation:
            return "fuelpump.fill"
        case .restaurant:
            return "fork.knife"
        case .cafe:
            return "cup.and.saucer.fill"
        case .convenience:
            return "building.2.fill"
        case .supermarket:
            return "cart.fill"
        case .other:
            return "mappin.circle.fill"
        }
    }

    /// 获取废土风格的名称
    var wastelandName: String {
        switch self {
        case .store:
            return "废弃商店"
        case .hospital:
            return "废弃医院"
        case .pharmacy:
            return "废弃药店"
        case .gasStation:
            return "废弃加油站"
        case .restaurant:
            return "废弃餐厅"
        case .cafe:
            return "废弃咖啡馆"
        case .convenience:
            return "废弃便利店"
        case .supermarket:
            return "废弃超市"
        case .other:
            return "废墟"
        }
    }

    // MARK: - MapKit 类型映射

    /// 从 MKPointOfInterestCategory 映射
    static func from(mkCategory: MKPointOfInterestCategory) -> POICategory {
        switch mkCategory {
        case .store:
            return .store
        case .hospital:
            return .hospital
        case .pharmacy:
            return .pharmacy
        case .gasStation:
            return .gasStation
        case .restaurant:
            return .restaurant
        case .cafe:
            return .cafe
        default:
            return .other
        }
    }

    /// 转换为 MKPointOfInterestCategory
    var mkCategory: MKPointOfInterestCategory? {
        switch self {
        case .store:
            return .store
        case .hospital:
            return .hospital
        case .pharmacy:
            return .pharmacy
        case .gasStation:
            return .gasStation
        case .restaurant:
            return .restaurant
        case .cafe:
            return .cafe
        case .convenience:
            return .store  // 便利店归类为商店
        case .supermarket:
            return .store  // 超市归类为商店
        case .other:
            return nil
        }
    }
}

// MARK: - 通知名称扩展

extension Notification.Name {
    /// 进入 POI 地理围栏区域
    static let didEnterPOIRegion = Notification.Name("didEnterPOIRegion")

    /// 离开 POI 地理围栏区域
    static let didExitPOIRegion = Notification.Name("didExitPOIRegion")
}
