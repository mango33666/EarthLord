//
//  POISearchManager.swift
//  EarthLord
//
//  POI 搜索管理器
//  使用 MapKit 的 MKLocalSearch 搜索附近真实地点
//

import Foundation
import MapKit
import CoreLocation

// MARK: - POI 搜索管理器

class POISearchManager {

    // MARK: - 单例

    static let shared = POISearchManager()

    // MARK: - 常量

    /// 默认搜索半径（米）
    private let defaultRadius: Double = 1000  // 1km

    /// 每种类型最大搜索数量
    private let maxResultsPerCategory: Int = 10

    /// 总最大 POI 数量（受地理围栏限制）
    private let maxTotalPOIs: Int = 20

    // MARK: - 要搜索的 POI 类型

    /// 搜索的 POI 类型列表
    private let categoriesToSearch: [(query: String, category: POICategory)] = [
        ("超市", .supermarket),
        ("便利店", .convenience),
        ("医院", .hospital),
        ("药店", .pharmacy),
        ("加油站", .gasStation),
        ("餐厅", .restaurant),
        ("咖啡", .cafe)
    ]

    // MARK: - 私有初始化

    private init() {}

    // MARK: - 公开方法

    /// 搜索附近 POI
    /// - Parameters:
    ///   - center: 搜索中心点
    ///   - radius: 搜索半径（米），默认 1km
    /// - Returns: POI 列表
    func searchNearbyPOIs(center: CLLocationCoordinate2D, radius: Double? = nil) async throws -> [POI] {
        let searchRadius = radius ?? defaultRadius

        print("🔍 [POISearchManager] 开始搜索附近 POI...")
        print("   📍 中心点: (\(String(format: "%.6f", center.latitude)), \(String(format: "%.6f", center.longitude)))")
        print("   📏 半径: \(Int(searchRadius))m")

        var allPOIs: [POI] = []

        // 并发搜索所有类型
        await withTaskGroup(of: [POI].self) { group in
            for (query, category) in categoriesToSearch {
                group.addTask {
                    do {
                        let pois = try await self.searchPOIs(
                            query: query,
                            category: category,
                            center: center,
                            radius: searchRadius
                        )
                        return pois
                    } catch {
                        print("⚠️ [POISearchManager] 搜索 \(query) 失败: \(error.localizedDescription)")
                        return []
                    }
                }
            }

            // 收集所有结果
            for await pois in group {
                allPOIs.append(contentsOf: pois)
            }
        }

        // 去重（基于坐标相近度）
        let uniquePOIs = removeDuplicates(from: allPOIs)

        // 按距离排序
        let sortedPOIs = sortByDistance(pois: uniquePOIs, from: center)

        // 限制数量（iOS 地理围栏最多 20 个）
        let limitedPOIs = Array(sortedPOIs.prefix(maxTotalPOIs))

        print("✅ [POISearchManager] 搜索完成，共找到 \(limitedPOIs.count) 个 POI")
        for poi in limitedPOIs {
            print("   \(poi.category.icon) \(poi.name)")
        }

        return limitedPOIs
    }

    // MARK: - 私有方法

    /// 搜索特定类型的 POI
    private func searchPOIs(
        query: String,
        category: POICategory,
        center: CLLocationCoordinate2D,
        radius: Double
    ) async throws -> [POI] {
        // 创建搜索请求
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        // 设置搜索区域
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )
        request.region = region

        // 执行搜索
        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        // 转换为 POI 对象，并过滤距离
        var pois: [POI] = []
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)

        for item in response.mapItems.prefix(maxResultsPerCategory) {
            let poi = POI(from: item, category: category)
            let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
            let distance = centerLocation.distance(from: poiLocation)

            // 只保留半径内的 POI
            if distance <= radius {
                pois.append(poi)
            }
        }

        return pois
    }

    /// 去除重复的 POI（坐标相近视为重复）
    private func removeDuplicates(from pois: [POI]) -> [POI] {
        var uniquePOIs: [POI] = []
        let minDistanceThreshold: Double = 30  // 30米内视为重复

        for poi in pois {
            let poiLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)

            let isDuplicate = uniquePOIs.contains { existingPOI in
                let existingLocation = CLLocation(latitude: existingPOI.coordinate.latitude, longitude: existingPOI.coordinate.longitude)
                return poiLocation.distance(from: existingLocation) < minDistanceThreshold
            }

            if !isDuplicate {
                uniquePOIs.append(poi)
            }
        }

        return uniquePOIs
    }

    /// 按距离排序
    private func sortByDistance(pois: [POI], from center: CLLocationCoordinate2D) -> [POI] {
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)

        return pois.sorted { poi1, poi2 in
            let location1 = CLLocation(latitude: poi1.coordinate.latitude, longitude: poi1.coordinate.longitude)
            let location2 = CLLocation(latitude: poi2.coordinate.latitude, longitude: poi2.coordinate.longitude)
            return centerLocation.distance(from: location1) < centerLocation.distance(from: location2)
        }
    }

    /// 计算两点之间的距离
    func distance(from coordinate1: CLLocationCoordinate2D, to coordinate2: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: coordinate1.latitude, longitude: coordinate1.longitude)
        let location2 = CLLocation(latitude: coordinate2.latitude, longitude: coordinate2.longitude)
        return location1.distance(from: location2)
    }
}
