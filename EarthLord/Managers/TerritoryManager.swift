//
//  TerritoryManager.swift
//  EarthLord
//
//  领地管理器
//  负责上传和拉取领地数据
//

import Foundation
import CoreLocation

// MARK: - 领地管理器

class TerritoryManager {

    // MARK: - 单例

    static let shared = TerritoryManager()

    // MARK: - Supabase 配置

    private let supabaseURL = "https://npmazbowtfowbxvpjhst.supabase.co"
    private let supabaseKey = "sb_publishable_59Pm_KFRXgXJUVYUK0nwKg_RqnVRCKQ"

    // MARK: - 私有初始化

    private init() {}

    // MARK: - 用户管理方法

    /// 确保当前设备用户在 profiles 表中存在
    /// - Throws: 创建用户失败错误
    func ensureUserProfileExists() async throws {
        // 1. 获取设备用户 ID
        let userId = DeviceIdentifier.shared.getUserId()

        // 2. 检查用户是否已存在
        let checkEndpoint = "\(supabaseURL)/rest/v1/profiles?id=eq.\(userId)&select=id"
        guard let checkUrl = URL(string: checkEndpoint) else {
            throw NSError(domain: "TerritoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 URL"])
        }

        var checkRequest = URLRequest(url: checkUrl)
        checkRequest.httpMethod = "GET"
        checkRequest.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        checkRequest.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

        let (checkData, _) = try await URLSession.shared.data(for: checkRequest)

        // 3. 解析查询结果
        if let jsonArray = try? JSONSerialization.jsonObject(with: checkData) as? [[String: Any]],
           !jsonArray.isEmpty {
            // 用户已存在，无需创建
            TerritoryLogger.shared.log("用户档案已存在: \(userId)", type: .info)
            return
        }

        // 4. 用户不存在，创建新用户
        TerritoryLogger.shared.log("首次使用，创建用户档案...", type: .info)

        let createEndpoint = "\(supabaseURL)/rest/v1/profiles"
        guard let createUrl = URL(string: createEndpoint) else {
            throw NSError(domain: "TerritoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 URL"])
        }

        // 5. 构建用户数据
        let username = "玩家_\(String(userId.prefix(6)))" // 默认用户名
        let profileData: [String: Any] = [
            "id": userId,
            "username": username
        ]

        // 6. 发送创建请求
        var createRequest = URLRequest(url: createUrl)
        createRequest.httpMethod = "POST"
        createRequest.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        createRequest.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        createRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        createRequest.httpBody = try JSONSerialization.data(withJSONObject: profileData)

        let (_, response) = try await URLSession.shared.data(for: createRequest)

        // 7. 检查响应
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "TerritoryManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "无效的响应"])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "TerritoryManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "创建用户失败"])
        }

        TerritoryLogger.shared.log("✅ 用户档案创建成功: \(username)", type: .success)
        print("✅ 用户档案创建成功: \(username) (ID: \(userId))")
    }

    // MARK: - 辅助方法

    /// 将坐标数组转换为 path JSON 格式
    /// - Parameter coordinates: 坐标数组
    /// - Returns: [{"lat": x, "lon": y}, ...] 格式的数组
    private func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> [[String: Double]] {
        return coordinates.map { coordinate in
            return [
                "lat": coordinate.latitude,
                "lon": coordinate.longitude
            ]
        }
    }

    /// 将坐标数组转换为 WKT Polygon 格式
    /// - Parameter coordinates: 坐标数组
    /// - Returns: WKT 格式字符串，例如：SRID=4326;POLYGON((lon lat, lon lat, ...))
    /// ⚠️ 注意：WKT 格式是「经度在前，纬度在后」
    /// ⚠️ 注意：多边形必须闭合（首尾相同）
    private func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        // 确保至少有 3 个点
        guard coordinates.count >= 3 else {
            return "SRID=4326;POLYGON((0 0, 0 0, 0 0, 0 0))"
        }

        // 构建坐标点字符串（经度在前，纬度在后）
        var points = coordinates.map { "\($0.longitude) \($0.latitude)" }

        // 确保多边形闭合（首尾相同）
        let firstPoint = coordinates.first!
        points.append("\(firstPoint.longitude) \(firstPoint.latitude)")

        // 拼接为 WKT 格式
        let wktPoints = points.joined(separator: ", ")
        return "SRID=4326;POLYGON((\(wktPoints)))"
    }

    /// 计算边界框
    /// - Parameter coordinates: 坐标数组
    /// - Returns: (minLat, maxLat, minLon, maxLon)
    private func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !coordinates.isEmpty else {
            return (0, 0, 0, 0)
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        return (minLat, maxLat, minLon, maxLon)
    }

    // MARK: - 公开方法

    /// 上传领地数据到 Supabase
    /// - Parameters:
    ///   - coordinates: 路径坐标数组
    ///   - area: 领地面积（平方米）
    ///   - startTime: 开始圈地时间
    /// - Throws: 上传错误
    func uploadTerritory(coordinates: [CLLocationCoordinate2D], area: Double, startTime: Date) async throws {
        // 记录开始上传
        TerritoryLogger.shared.log("开始上传领地数据...", type: .info)

        // 1. 确保用户档案存在
        try await ensureUserProfileExists()

        // 2. 转换数据格式
        let pathJSON = coordinatesToPathJSON(coordinates)
        let wktPolygon = coordinatesToWKT(coordinates)
        let bbox = calculateBoundingBox(coordinates)

        // 3. 获取用户 ID（使用设备标识符）
        let userId = DeviceIdentifier.shared.getUserId()

        // 3. 构建上传数据
        let territoryData: [String: Any] = [
            "user_id": userId,
            "path": pathJSON,
            "polygon": wktPolygon,
            "bbox_min_lat": bbox.minLat,
            "bbox_max_lat": bbox.maxLat,
            "bbox_min_lon": bbox.minLon,
            "bbox_max_lon": bbox.maxLon,
            "area": area,
            "point_count": coordinates.count,
            "started_at": ISO8601DateFormatter().string(from: startTime),
            "is_active": true
        ]

        // 4. 发送 HTTP 请求
        let endpoint = "\(supabaseURL)/rest/v1/territories"
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "TerritoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        // 序列化 JSON
        request.httpBody = try JSONSerialization.data(withJSONObject: territoryData)

        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)

        // 检查响应
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "TerritoryManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "无效的响应"])
        }

        // 如果状态码不是 2xx，抛出错误
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
            TerritoryLogger.shared.log("领地上传失败: \(errorMessage)", type: .error)
            throw NSError(domain: "TerritoryManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "上传失败：\(errorMessage)"])
        }

        // 上传成功
        TerritoryLogger.shared.log("领地上传成功！面积: \(Int(area))m²", type: .success)
        print("✅ 领地上传成功")
    }

    /// 从 Supabase 拉取所有激活的领地
    /// - Returns: 领地数组
    /// - Throws: 查询错误
    func loadAllTerritories() async throws -> [Territory] {
        // 1. 构建查询 URL（只查询 is_active = true 的领地）
        let endpoint = "\(supabaseURL)/rest/v1/territories?is_active=eq.true&select=*"
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "TerritoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 URL"])
        }

        // 2. 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 3. 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)

        // 4. 检查响应
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "TerritoryManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "无效的响应"])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
            throw NSError(domain: "TerritoryManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "查询失败：\(errorMessage)"])
        }

        // 5. 解析 JSON
        let decoder = JSONDecoder()
        let territories = try decoder.decode([Territory].self, from: data)

        print("✅ 成功拉取 \(territories.count) 个领地")
        return territories
    }

    /// 从 Supabase 拉取当前用户的领地
    /// - Returns: 当前用户的领地数组
    /// - Throws: 查询错误
    func loadMyTerritories() async throws -> [Territory] {
        // 1. 获取当前用户 ID（使用设备标识符）
        let userId = DeviceIdentifier.shared.getUserId()

        // 2. 构建查询 URL（查询当前用户的激活领地）
        // ⚠️ 注意：这里需要对 user_id 进行 URL 编码，因为它可能包含特殊字符
        guard let encodedUserId = userId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw NSError(domain: "TerritoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的用户 ID"])
        }

        let endpoint = "\(supabaseURL)/rest/v1/territories?user_id=eq.\(encodedUserId)&is_active=eq.true&select=*&order=created_at.desc"
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "TerritoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 URL"])
        }

        // 3. 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 4. 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)

        // 5. 检查响应
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "TerritoryManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "无效的响应"])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
            throw NSError(domain: "TerritoryManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "查询失败：\(errorMessage)"])
        }

        // 6. 解析 JSON
        let decoder = JSONDecoder()
        let territories = try decoder.decode([Territory].self, from: data)

        TerritoryLogger.shared.log("成功拉取我的领地: \(territories.count) 个", type: .info)
        return territories
    }

    /// 删除指定领地（软删除，将 is_active 设置为 false）
    /// - Parameter territoryId: 领地 ID
    /// - Throws: 删除错误
    func deleteTerritory(territoryId: String) async throws {
        // 1. 构建更新 URL
        let endpoint = "\(supabaseURL)/rest/v1/territories?id=eq.\(territoryId)"
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "TerritoryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 URL"])
        }

        // 2. 创建请求（使用 PATCH 方法进行部分更新）
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        // 3. 设置 is_active = false（软删除）
        let updateData: [String: Any] = [
            "is_active": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: updateData)

        // 4. 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)

        // 5. 检查响应
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "TerritoryManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "无效的响应"])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
            TerritoryLogger.shared.log("领地删除失败: \(errorMessage)", type: .error)
            throw NSError(domain: "TerritoryManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "删除失败：\(errorMessage)"])
        }

        // 删除成功
        TerritoryLogger.shared.log("领地删除成功: \(territoryId)", type: .success)
        print("✅ 领地删除成功")
    }
}
