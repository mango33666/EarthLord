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

    // MARK: - 碰撞检测算法

    /// 射线法判断点是否在多边形内
    /// - Parameters:
    ///   - point: 待检测的点
    ///   - polygon: 多边形顶点数组
    /// - Returns: 如果点在多边形内返回 true
    func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var inside = false
        let x = point.longitude
        let y = point.latitude

        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            let intersect = ((yi > y) != (yj > y)) &&
                           (x < (xj - xi) * (y - yi) / (yj - yi) + xi)

            if intersect {
                inside.toggle()
            }
            j = i
        }

        return inside
    }

    /// 检查起始点是否在他人领地内
    /// - Parameters:
    ///   - location: 起始点位置
    ///   - currentUserId: 当前用户ID
    /// - Returns: 碰撞检测结果
    func checkPointCollision(location: CLLocationCoordinate2D, currentUserId: String) async throws -> CollisionResult {
        // 加载所有领地
        let allTerritories = try await loadAllTerritories()

        // 过滤出他人领地
        let otherTerritories = allTerritories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else {
            return .safe
        }

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()
            guard polygon.count >= 3 else { continue }

            if isPointInPolygon(point: location, polygon: polygon) {
                TerritoryLogger.shared.log("起点碰撞：位于他人领地内", type: .error)
                return CollisionResult(
                    hasCollision: true,
                    collisionType: .pointInTerritory,
                    message: "不能在他人领地内开始圈地！",
                    closestDistance: 0,
                    warningLevel: .violation
                )
            }
        }

        return .safe
    }

    /// 判断两条线段是否相交（CCW 算法）
    /// - Parameters:
    ///   - p1: 第一条线段起点
    ///   - p2: 第一条线段终点
    ///   - p3: 第二条线段起点
    ///   - p4: 第二条线段终点
    /// - Returns: 如果两条线段相交返回 true
    private func segmentsIntersect(
        p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D
    ) -> Bool {
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            return (C.latitude - A.latitude) * (B.longitude - A.longitude) >
                   (B.latitude - A.latitude) * (C.longitude - A.longitude)
        }

        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检查路径是否穿越他人领地边界
    /// - Parameters:
    ///   - path: 当前路径
    ///   - currentUserId: 当前用户ID
    /// - Returns: 碰撞检测结果
    func checkPathCrossTerritory(path: [CLLocationCoordinate2D], currentUserId: String) async throws -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        // 加载所有领地
        let allTerritories = try await loadAllTerritories()

        // 过滤出他人领地
        let otherTerritories = allTerritories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else { return .safe }

        for i in 0..<(path.count - 1) {
            let pathStart = path[i]
            let pathEnd = path[i + 1]

            for territory in otherTerritories {
                let polygon = territory.toCoordinates()
                guard polygon.count >= 3 else { continue }

                // 检查与领地每条边的相交
                for j in 0..<polygon.count {
                    let boundaryStart = polygon[j]
                    let boundaryEnd = polygon[(j + 1) % polygon.count]

                    if segmentsIntersect(p1: pathStart, p2: pathEnd, p3: boundaryStart, p4: boundaryEnd) {
                        TerritoryLogger.shared.log("路径碰撞：轨迹穿越他人领地边界", type: .error)
                        return CollisionResult(
                            hasCollision: true,
                            collisionType: .pathCrossTerritory,
                            message: "轨迹不能穿越他人领地！",
                            closestDistance: 0,
                            warningLevel: .violation
                        )
                    }
                }

                // 检查路径点是否在领地内
                if isPointInPolygon(point: pathEnd, polygon: polygon) {
                    TerritoryLogger.shared.log("路径碰撞：轨迹点进入他人领地", type: .error)
                    return CollisionResult(
                        hasCollision: true,
                        collisionType: .pointInTerritory,
                        message: "轨迹不能进入他人领地！",
                        closestDistance: 0,
                        warningLevel: .violation
                    )
                }
            }
        }

        return .safe
    }

    /// 计算当前位置到他人领地的最近距离
    /// - Parameters:
    ///   - location: 当前位置
    ///   - currentUserId: 当前用户ID
    /// - Returns: 最近距离（米）
    func calculateMinDistanceToTerritories(location: CLLocationCoordinate2D, currentUserId: String) async throws -> Double {
        // 加载所有领地
        let allTerritories = try await loadAllTerritories()

        // 过滤出他人领地
        let otherTerritories = allTerritories.filter { territory in
            territory.userId.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else { return Double.infinity }

        var minDistance = Double.infinity
        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        for territory in otherTerritories {
            let polygon = territory.toCoordinates()

            for vertex in polygon {
                let vertexLocation = CLLocation(latitude: vertex.latitude, longitude: vertex.longitude)
                let distance = currentLocation.distance(from: vertexLocation)
                minDistance = min(minDistance, distance)
            }
        }

        return minDistance
    }

    /// 综合碰撞检测（主方法）
    /// - Parameters:
    ///   - path: 当前路径
    ///   - currentUserId: 当前用户ID
    /// - Returns: 碰撞检测结果
    func checkPathCollisionComprehensive(path: [CLLocationCoordinate2D], currentUserId: String) async throws -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        // 1. 检查路径是否穿越他人领地
        let crossResult = try await checkPathCrossTerritory(path: path, currentUserId: currentUserId)
        if crossResult.hasCollision {
            return crossResult
        }

        // 2. 计算到最近领地的距离
        guard let lastPoint = path.last else { return .safe }
        let minDistance = try await calculateMinDistanceToTerritories(location: lastPoint, currentUserId: currentUserId)

        // 3. 根据距离确定预警级别和消息
        let warningLevel: WarningLevel
        let message: String?

        if minDistance > 100 {
            warningLevel = .safe
            message = nil
        } else if minDistance > 50 {
            warningLevel = .caution
            message = "注意：距离他人领地 \(Int(minDistance))m"
        } else if minDistance > 25 {
            warningLevel = .warning
            message = "警告：正在靠近他人领地（\(Int(minDistance))m）"
        } else {
            warningLevel = .danger
            message = "危险：即将进入他人领地！（\(Int(minDistance))m）"
        }

        if warningLevel != .safe {
            TerritoryLogger.shared.log("距离预警：\(warningLevel.description)，距离 \(Int(minDistance))m", type: .warning)
        }

        return CollisionResult(
            hasCollision: false,
            collisionType: nil,
            message: message,
            closestDistance: minDistance,
            warningLevel: warningLevel
        )
    }
}
