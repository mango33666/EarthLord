//
//  LocationManager.swift
//  EarthLord
//
//  GPS 定位管理器
//  负责请求定位权限、获取用户位置、处理定位错误、路径追踪
//

import Foundation
import CoreLocation
import Combine  // ⚠️ 必需：@Published 需要这个框架

// MARK: - 定位管理器

/// GPS 定位管理器，管理用户位置和定位权限
class LocationManager: NSObject, ObservableObject {

    // MARK: - 单例

    static let shared = LocationManager()

    // MARK: - 发布属性

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位权限状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 定位错误信息
    @Published var locationError: String?

    // MARK: - 路径追踪属性

    /// 是否正在追踪路径
    @Published var isTracking: Bool = false

    /// 路径坐标数组（存储原始 WGS-84 坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（用于触发 SwiftUI 更新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否闭合（Day16 会用）
    @Published var isPathClosed: Bool = false

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    // MARK: - 验证状态属性

    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false

    /// 领地验证错误信息
    @Published var territoryValidationError: String?

    /// 计算的领地面积（平方米）
    @Published var calculatedArea: Double = 0

    // MARK: - 私有属性

    /// CoreLocation 定位管理器
    private let locationManager = CLLocationManager()

    /// 当前位置（用于 Timer 采点）
    private var currentLocation: CLLocation?

    /// 路径更新定时器（每 2 秒采点）
    private var pathUpdateTimer: Timer?

    /// 上次位置的时间戳（用于速度检测）
    private var lastLocationTimestamp: Date?

    // MARK: - 常量

    /// 闭环距离阈值（米）
    private let closureDistanceThreshold: Double = 30.0

    /// 闭环检测最少点数（较低，便于检测闭环）
    private let closureMinimumPoints: Int = 8

    /// 验证要求最少点数（较高，确保领地质量）
    private let minimumPathPoints: Int = 15

    // MARK: - 验证常量

    /// 最小行走距离（米）
    private let minimumTotalDistance: Double = 100.0

    /// 最小领地面积（平方米）
    private let minimumEnclosedArea: Double = 300.0

    // MARK: - 计算属性

    /// 是否已授权定位权限
    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    /// 是否被拒绝定位权限
    var isDenied: Bool {
        authorizationStatus == .denied
    }

    // MARK: - 初始化

    override init() {
        // 获取当前授权状态
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 10  // 移动10米才更新位置
    }

    // MARK: - 公开方法

    /// 请求定位权限（使用App期间）
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始更新位置
    func startUpdatingLocation() {
        guard isAuthorized else {
            locationError = "定位权限未授权"
            return
        }

        locationManager.startUpdatingLocation()
    }

    /// 停止更新位置
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - 路径追踪方法

    /// 开始路径追踪
    func startPathTracking() {
        guard isAuthorized else {
            locationError = "定位权限未授权，无法开始追踪"
            return
        }

        // 清除旧路径
        clearPath()

        // 标记为追踪中
        isTracking = true

        // 记录日志
        TerritoryLogger.shared.log("开始圈地追踪", type: .info)

        // 启动定时器，每 2 秒采点一次
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }

        // 立即记录第一个点
        recordPathPoint()
    }

    /// 停止路径追踪
    func stopPathTracking() {
        isTracking = false

        // 记录日志
        TerritoryLogger.shared.log("停止追踪，共 \(pathCoordinates.count) 个点", type: .info)

        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // ⚠️ 关键：重置所有验证状态，防止重复上传
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
        isPathClosed = false
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil

        // 清除路径数据
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
    }

    /// 清除路径
    func clearPath() {
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
    }

    /// 记录路径点（定时器回调）
    private func recordPathPoint() {
        // 获取当前位置
        guard let location = currentLocation else {
            print("⚠️ 当前位置为空，跳过记录")
            return
        }

        // GPS 精度检测：精度太差（>100米）则跳过该点（放宽限制）
        if location.horizontalAccuracy > 100 {
            print("⚠️ GPS 精度较差：\(Int(location.horizontalAccuracy))m，跳过该点")
            return
        } else if location.horizontalAccuracy < 0 {
            print("⚠️ GPS 精度无效：\(location.horizontalAccuracy)m，跳过该点")
            return
        }

        print("📍 GPS 精度：\(Int(location.horizontalAccuracy))m ✓")

        // 速度检测：如果超速，不记录该点
        if !validateMovementSpeed(newLocation: location) {
            print("⚠️ 速度检测未通过，跳过该点")
            return
        }

        let newCoordinate = location.coordinate

        // 判断是否需要记录新点
        var distanceFromLast: Double = 0
        var shouldRecord = false

        if let lastCoordinate = pathCoordinates.last {
            // 计算距离
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let newLocation = CLLocation(latitude: newCoordinate.latitude, longitude: newCoordinate.longitude)
            distanceFromLast = lastLocation.distance(from: newLocation)

            // 距离大于等于 3 米才记录（降低到3米）
            if distanceFromLast >= 3 {
                shouldRecord = true
            } else {
                print("📍 距上点仅 \(String(format: "%.1f", distanceFromLast))m，跳过")
            }
        } else {
            // 第一个点，必须记录
            shouldRecord = true
        }

        // 如果不满足距离条件，但已经很久没记录点了，也强制记录
        if !shouldRecord && pathCoordinates.count > 0 {
            // 获取最后一个点的时间（如果可用）
            if let lastTimestamp = lastLocationTimestamp {
                let timeSinceLastPoint = location.timestamp.timeIntervalSince(lastTimestamp)
                // 如果距离上次记录超过10秒，强制记录该点
                if timeSinceLastPoint > 10 {
                    shouldRecord = true
                    print("⏰ 距上次记录已超过10秒，强制记录该点")
                }
            }
        }

        if !shouldRecord {
            return
        }

        // 记录新点
        pathCoordinates.append(newCoordinate)

        // 更新最后记录时间
        lastLocationTimestamp = location.timestamp

        print("✅ 已记录第 \(pathCoordinates.count) 个点，坐标: (\(String(format: "%.6f", newCoordinate.latitude)), \(String(format: "%.6f", newCoordinate.longitude)))")
        if distanceFromLast > 0 {
            print("   📏 距上点: \(String(format: "%.1f", distanceFromLast))m")
        }

        // 记录日志
        if pathCoordinates.count == 1 {
            TerritoryLogger.shared.log("记录第 1 个点（起点）", type: .info)
        } else {
            TerritoryLogger.shared.log("记录第 \(pathCoordinates.count) 个点，距上点 \(String(format: "%.1f", distanceFromLast))m", type: .info)
        }

        // 更新版本号，触发 SwiftUI 更新
        pathUpdateVersion += 1

        // 检查是否形成闭环
        checkPathClosure()
    }

    // MARK: - 闭环检测

    /// 检查路径是否形成闭环
    private func checkPathClosure() {
        // 如果已经闭合，不再检测（⚠️ 关键：避免重复检测）
        guard !isPathClosed else { return }

        // 检查点数是否足够（使用较低的闭环检测阈值）
        guard pathCoordinates.count >= closureMinimumPoints else {
            return
        }

        // 获取起点和当前点
        guard let startPoint = pathCoordinates.first,
              let currentPoint = pathCoordinates.last else {
            return
        }

        // 计算当前点到起点的距离
        let startLocation = CLLocation(latitude: startPoint.latitude, longitude: startPoint.longitude)
        let currentLocation = CLLocation(latitude: currentPoint.latitude, longitude: currentPoint.longitude)
        let distance = startLocation.distance(from: currentLocation)

        // 记录距离日志（≥10个点后才记录）
        TerritoryLogger.shared.log("距起点 \(String(format: "%.1f", distance))m (需≤30m)", type: .info)

        // 判断是否闭合
        if distance <= closureDistanceThreshold {
            isPathClosed = true
            pathUpdateVersion += 1  // 触发 UI 更新

            // 记录成功日志
            TerritoryLogger.shared.log("闭环成功！距起点 \(String(format: "%.1f", distance))m", type: .success)

            // ⚠️ 关键：闭环成功后自动触发验证
            let validationResult = validateTerritory()
            calculatedArea = calculatePolygonArea()
            territoryValidationPassed = validationResult.isValid
            territoryValidationError = validationResult.errorMessage
        }
    }

    // MARK: - 距离与面积计算

    /// 计算路径总距离
    /// - Returns: 总距离（米）
    func calculateTotalPathDistance() -> Double {
        guard pathCoordinates.count >= 2 else { return 0 }

        var totalDistance: Double = 0

        for i in 0..<(pathCoordinates.count - 1) {
            let current = pathCoordinates[i]
            let next = pathCoordinates[i + 1]

            let currentLocation = CLLocation(latitude: current.latitude, longitude: current.longitude)
            let nextLocation = CLLocation(latitude: next.latitude, longitude: next.longitude)

            totalDistance += currentLocation.distance(from: nextLocation)
        }

        return totalDistance
    }

    /// 计算多边形面积（使用鞋带公式，考虑地球曲率）
    /// - Returns: 面积（平方米）
    private func calculatePolygonArea() -> Double {
        guard pathCoordinates.count >= 3 else { return 0 }

        let earthRadius: Double = 6371000  // 地球半径（米）
        var area: Double = 0

        for i in 0..<pathCoordinates.count {
            let current = pathCoordinates[i]
            let next = pathCoordinates[(i + 1) % pathCoordinates.count]  // 循环取点

            // 经纬度转弧度
            let lat1 = current.latitude * .pi / 180
            let lon1 = current.longitude * .pi / 180
            let lat2 = next.latitude * .pi / 180
            let lon2 = next.longitude * .pi / 180

            // 鞋带公式（球面修正）
            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        area = abs(area * earthRadius * earthRadius / 2.0)
        return area
    }

    // MARK: - 自相交检测

    /// 判断两条线段是否相交（使用 CCW 算法）
    /// - Parameters:
    ///   - p1: 线段1的起点
    ///   - p2: 线段1的终点
    ///   - p3: 线段2的起点
    ///   - p4: 线段2的终点
    /// - Returns: true 表示相交
    private func segmentsIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
                                   p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> Bool {
        /// CCW 辅助函数：判断三点是否逆时针
        /// - Parameters:
        ///   - A: 点A
        ///   - B: 点B
        ///   - C: 点C
        /// - Returns: 叉积 > 0 则为 true（逆时针）
        func ccw(A: CLLocationCoordinate2D, B: CLLocationCoordinate2D, C: CLLocationCoordinate2D) -> Bool {
            // ⚠️ 坐标映射：longitude = X轴，latitude = Y轴
            let crossProduct = (C.latitude - A.latitude) * (B.longitude - A.longitude) -
                              (B.latitude - A.latitude) * (C.longitude - A.longitude)
            return crossProduct > 0
        }

        // 判断逻辑：两条线段相交的充要条件
        return ccw(A: p1, B: p3, C: p4) != ccw(A: p2, B: p3, C: p4) &&
               ccw(A: p1, B: p2, C: p3) != ccw(A: p1, B: p2, C: p4)
    }

    /// 检测路径是否自相交
    /// - Returns: true 表示有自交
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量
        let skipHeadCount = 2
        let skipTailCount = 2

        for i in 0..<segmentCount {
            guard i < pathSnapshot.count - 1 else { break }

            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            for j in startJ..<segmentCount {
                guard j < pathSnapshot.count - 1 else { break }

                // ✅ 跳过首尾附近线段的比较
                let isHeadSegment = i < skipHeadCount
                let isTailSegment = j >= segmentCount - skipTailCount

                if isHeadSegment && isTailSegment {
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交", type: .error)
                    return true
                }
            }
        }

        TerritoryLogger.shared.log("自交检测: 无交叉 ✓", type: .info)
        return false
    }

    // MARK: - 综合验证

    /// 综合验证领地是否有效
    /// - Returns: (是否有效, 错误信息)
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.log("开始领地验证", type: .info)

        // 1. 点数检查
        if pathCoordinates.count < minimumPathPoints {
            let error = "点数不足: \(pathCoordinates.count)个点 (需≥\(minimumPathPoints)个点)"
            TerritoryLogger.shared.log(error, type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("点数检查: \(pathCoordinates.count)个点 ✓", type: .info)

        // 2. 距离检查
        let totalDistance = calculateTotalPathDistance()
        if totalDistance < minimumTotalDistance {
            let error = "距离不足: \(String(format: "%.0f", totalDistance))m (需≥\(String(format: "%.0f", minimumTotalDistance))m)"
            TerritoryLogger.shared.log(error, type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("距离检查: \(String(format: "%.0f", totalDistance))m ✓", type: .info)

        // 3. 自交检测
        if hasPathSelfIntersection() {
            let error = "轨迹自相交，请勿画8字形"
            TerritoryLogger.shared.log(error, type: .error)
            return (false, error)
        }

        // 4. 面积检查
        let area = calculatePolygonArea()
        if area < minimumEnclosedArea {
            let error = "面积不足: \(String(format: "%.0f", area))m² (需≥\(String(format: "%.0f", minimumEnclosedArea))m²)"
            TerritoryLogger.shared.log(error, type: .error)
            return (false, error)
        }
        TerritoryLogger.shared.log("面积检查: \(String(format: "%.0f", area))m² ✓", type: .info)

        // 所有检查通过
        TerritoryLogger.shared.log("领地验证通过！面积: \(String(format: "%.0f", area))m²", type: .success)
        return (true, nil)
    }

    // MARK: - 速度检测

    /// 验证移动速度是否正常（防止作弊）
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示速度正常，false 表示超速
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // 第一个点，无需检测
        guard let lastTimestamp = lastLocationTimestamp,
              let lastCoordinate = pathCoordinates.last else {
            // 第一个点，直接通过（时间戳会在 recordPathPoint 中更新）
            print("🚗 第一个点，跳过速度检测")
            return true
        }

        // 计算时间差（秒）
        let timeInterval = newLocation.timestamp.timeIntervalSince(lastTimestamp)

        // 时间差太小，不检测
        guard timeInterval > 0.5 else {
            print("🚗 时间差太小(\(String(format: "%.1f", timeInterval))秒)，跳过速度检测")
            return true
        }

        // 计算距离（米）
        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = lastLocation.distance(from: newLocation)

        // 计算速度（km/h）
        let speedKmh = (distance / timeInterval) * 3.6

        print("🚗 速度检测：\(String(format: "%.1f", speedKmh)) km/h (距离:\(String(format: "%.1f", distance))m, 时间:\(String(format: "%.1f", timeInterval))秒)")

        // 速度判断（调整为更宽容的检测，避免 GPS 噪声误判）
        if speedKmh > 100 {
            // 极度异常（可能是 GPS 跳点），跳过该点但不停止追踪
            speedWarning = "速度异常（\(String(format: "%.1f", speedKmh)) km/h），跳过该点"
            isOverSpeed = true
            print("⚠️ 速度异常：\(String(format: "%.1f", speedKmh)) km/h，跳过该点")

            // 记录警告日志
            TerritoryLogger.shared.log("速度异常 \(String(format: "%.1f", speedKmh)) km/h，跳过该点", type: .warning)

            // ⚠️ 关键改动：不调用 stopPathTracking()，只是跳过该点
            return false
        } else if speedKmh > 50 {
            // 较快速度，警告但仍记录该点（可能是骑车或跑步）
            speedWarning = "移动速度较快（\(String(format: "%.1f", speedKmh)) km/h）"
            isOverSpeed = true
            print("⚠️ 速度较快：\(String(format: "%.1f", speedKmh)) km/h，仍记录该点")

            // 记录警告日志
            TerritoryLogger.shared.log("速度较快 \(String(format: "%.1f", speedKmh)) km/h", type: .warning)

            // 3秒后自动清除警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.speedWarning = nil
                self?.isOverSpeed = false
            }

            return true  // 继续记录点
        } else {
            // 速度正常，不记录日志（避免日志过多）
            speedWarning = nil
            isOverSpeed = false
            return true
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态改变时调用
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // 更新授权状态
        authorizationStatus = manager.authorizationStatus

        // 如果已授权，自动开始定位
        if isAuthorized {
            startUpdatingLocation()
        }
    }

    /// 位置更新时调用
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // 获取最新位置
        guard let location = locations.last else { return }

        // ⚠️ 重要：更新当前位置（Timer 需要用这个）
        currentLocation = location

        // 更新用户位置
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
            self.locationError = nil  // 清除错误
        }
    }

    /// 定位失败时调用
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = "定位失败：\(error.localizedDescription)"
        }
    }
}
