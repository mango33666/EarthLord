//
//  PlayerLocationManager.swift
//  EarthLord
//
//  玩家位置上报管理器
//  负责上报玩家位置、查询附近玩家密度
//

import Foundation
import CoreLocation
import Combine

// MARK: - 密度等级

/// 玩家密度等级
enum DensityLevel: String, CaseIterable {
    case solo = "独行者"      // 0人
    case low = "低密度"       // 1-5人
    case medium = "中密度"    // 6-20人
    case high = "高密度"      // 20+人

    /// 根据附近玩家数量获取密度等级
    static func fromCount(_ count: Int) -> DensityLevel {
        switch count {
        case 0:
            return .solo
        case 1...5:
            return .low
        case 6...20:
            return .medium
        default:
            return .high
        }
    }

    /// 该密度等级对应的最大 POI 数量
    var maxPOICount: Int {
        switch self {
        case .solo:
            return 1
        case .low:
            return 3
        case .medium:
            return 6
        case .high:
            return 20
        }
    }

    /// 显示图标
    var icon: String {
        switch self {
        case .solo:
            return "🚶"
        case .low:
            return "👥"
        case .medium:
            return "👨‍👩‍👦"
        case .high:
            return "🏟️"
        }
    }
}

// MARK: - 玩家位置管理器

@MainActor
class PlayerLocationManager: ObservableObject {

    // MARK: - 单例

    static let shared = PlayerLocationManager()

    // MARK: - Published 属性

    /// 附近玩家数量
    @Published var nearbyPlayerCount: Int = 0

    /// 当前密度等级
    @Published var densityLevel: DensityLevel = .solo

    // MARK: - 私有属性

    /// 位置上报定时器
    private var reportTimer: Timer?

    /// 上次上报的位置
    private var lastReportedLocation: CLLocationCoordinate2D?

    /// 位置管理器引用
    private let locationManager = LocationManager.shared

    /// Supabase 配置
    private let supabaseURL = "https://npmazbowtfowbxvpjhst.supabase.co"
    private let supabaseKey = "sb_publishable_59Pm_KFRXgXJUVYUK0nwKg_RqnVRCKQ"

    /// 上报间隔（秒）
    private let reportInterval: TimeInterval = 30

    /// 触发立即上报的最小移动距离（米）
    private let minDistanceForImmediateReport: Double = 50

    // MARK: - 私有初始化

    private init() {}

    // MARK: - 公开方法

    /// 上报位置并获取附近玩家密度
    /// - Parameter location: 当前位置
    /// - Returns: 附近玩家数量
    func reportLocationAndGetDensity(location: CLLocationCoordinate2D) async -> Int {
        let userId = DeviceIdentifier.shared.getUserId()

        do {
            let count = try await callReportAndGetNearbyCount(
                userId: userId,
                lat: location.latitude,
                lng: location.longitude
            )

            nearbyPlayerCount = count
            densityLevel = DensityLevel.fromCount(count)
            lastReportedLocation = location

            print("📍 [PlayerLocation] 上报位置并查询密度")
            print("   位置: (\(String(format: "%.6f", location.latitude)), \(String(format: "%.6f", location.longitude)))")
            print("   附近玩家: \(count) 人")
            print("   密度等级: \(densityLevel.icon) \(densityLevel.rawValue)")
            print("   POI 上限: \(densityLevel.maxPOICount) 个")

            return count
        } catch {
            print("❌ [PlayerLocation] 上报失败: \(error.localizedDescription)")
            return 0
        }
    }

    /// 启动周期性位置上报（30秒间隔）
    func startPeriodicReporting() {
        stopPeriodicReporting()

        print("⏱️ [PlayerLocation] 启动周期性上报（每 \(Int(reportInterval)) 秒）")

        reportTimer = Timer.scheduledTimer(withTimeInterval: reportInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.periodicReport()
            }
        }
    }

    /// 停止周期性上报并标记离线
    func stopPeriodicReporting() {
        reportTimer?.invalidate()
        reportTimer = nil

        // 标记离线
        Task {
            await markOffline()
        }

        print("⏹️ [PlayerLocation] 已停止周期性上报")
    }

    // MARK: - 私有方法

    /// 周期性上报（仅上报位置，不查询密度）
    private func periodicReport() async {
        guard let location = locationManager.userLocation else {
            print("⚠️ [PlayerLocation] 无法获取位置，跳过上报")
            return
        }

        // 检查是否需要上报（移动超过阈值或首次上报）
        if let lastLocation = lastReportedLocation {
            let distance = calculateDistance(from: lastLocation, to: location)
            if distance < minDistanceForImmediateReport {
                // 未移动足够距离，但仍然上报以保持在线状态
            }
        }

        let userId = DeviceIdentifier.shared.getUserId()

        do {
            try await callReportLocation(
                userId: userId,
                lat: location.latitude,
                lng: location.longitude
            )
            lastReportedLocation = location
            print("📍 [PlayerLocation] 周期性上报成功")
        } catch {
            print("❌ [PlayerLocation] 周期性上报失败: \(error.localizedDescription)")
        }
    }

    /// 标记离线
    private func markOffline() async {
        let userId = DeviceIdentifier.shared.getUserId()

        do {
            try await callMarkOffline(userId: userId)
            print("👋 [PlayerLocation] 已标记为离线")
        } catch {
            print("❌ [PlayerLocation] 标记离线失败: \(error.localizedDescription)")
        }
    }

    /// 计算两点之间的距离
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }

    // MARK: - Supabase RPC 调用

    /// 调用 report_location_and_get_nearby_count 函数
    private func callReportAndGetNearbyCount(userId: String, lat: Double, lng: Double) async throws -> Int {
        let url = URL(string: "\(supabaseURL)/rest/v1/rpc/report_location_and_get_nearby_count")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "p_user_id": userId,
            "p_lat": lat,
            "p_lng": lng,
            "p_radius_meters": 1000
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "PlayerLocationManager", code: statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "RPC 调用失败: \(responseBody)"])
        }

        // 解析返回的整数
        if let count = try? JSONDecoder().decode(Int.self, from: data) {
            return count
        }

        return 0
    }

    /// 调用 report_location 函数（仅上报，不返回数据）
    private func callReportLocation(userId: String, lat: Double, lng: Double) async throws {
        let url = URL(string: "\(supabaseURL)/rest/v1/rpc/report_location")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "p_user_id": userId,
            "p_lat": lat,
            "p_lng": lng
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "PlayerLocationManager", code: statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "RPC 调用失败: \(responseBody)"])
        }
    }

    /// 调用 mark_player_offline 函数
    private func callMarkOffline(userId: String) async throws {
        let url = URL(string: "\(supabaseURL)/rest/v1/rpc/mark_player_offline")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "p_user_id": userId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "PlayerLocationManager", code: statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "RPC 调用失败: \(responseBody)"])
        }
    }
}
