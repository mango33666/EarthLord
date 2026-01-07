//
//  Territory.swift
//  EarthLord
//
//  领地数据模型
//  用于解析 Supabase 返回的领地数据
//

import Foundation
import CoreLocation

// MARK: - 领地数据模型

struct Territory: Codable, Identifiable {

    // MARK: - 属性

    /// 领地 ID
    let id: String

    /// 用户 ID
    let userId: String

    /// 领地名称（可选，数据库允许为空）
    let name: String?

    /// 路径坐标数组，格式：[{"lat": x, "lon": y}, ...]
    let path: [[String: Double]]

    /// 领地面积（平方米）
    let area: Double

    /// 路径点数量（可选）
    let pointCount: Int?

    /// 是否激活（可选）
    let isActive: Bool?

    /// 开始圈地时间（可选）
    let startedAt: String?

    /// 完成圈地时间（可选）
    let completedAt: String?

    /// 创建时间（可选）
    let createdAt: String?

    // MARK: - CodingKeys

    /// 编码键（映射数据库字段名）
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case path
        case area
        case pointCount = "point_count"
        case isActive = "is_active"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
    }

    // MARK: - 辅助方法

    /// 将 path 转换为 CLLocationCoordinate2D 数组
    /// - Returns: 坐标数组
    func toCoordinates() -> [CLLocationCoordinate2D] {
        return path.compactMap { point in
            guard let lat = point["lat"], let lon = point["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    /// 格式化面积显示
    /// - Returns: 格式化的面积字符串（如："1,234 m²"）
    var formattedArea: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let areaString = formatter.string(from: NSNumber(value: area)) ?? "\(Int(area))"
        return "\(areaString) m²"
    }

    /// 显示名称（如果有名称则显示名称，否则显示"领地 #ID前6位"）
    /// - Returns: 显示名称
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        let shortId = String(id.prefix(6))
        return "领地 #\(shortId)"
    }

    /// 格式化创建时间
    /// - Returns: 格式化的时间字符串（如："2024-01-08 14:30"）
    var formattedCreatedAt: String {
        guard let createdAt = createdAt else { return "未知" }

        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: createdAt) else { return "未知" }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return displayFormatter.string(from: date)
    }
}
