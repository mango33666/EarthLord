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

    /// 最少路径点数（用于闭环检测）
    private let minimumPathPoints: Int = 10

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
    }

    /// 清除路径
    func clearPath() {
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
        speedWarning = nil
        isOverSpeed = false
        lastLocationTimestamp = nil
    }

    /// 记录路径点（定时器回调）
    private func recordPathPoint() {
        // 获取当前位置
        guard let location = currentLocation else { return }

        // 速度检测：如果超速，不记录该点
        if !validateMovementSpeed(newLocation: location) {
            return
        }

        let newCoordinate = location.coordinate

        // 判断是否需要记录新点
        var distanceFromLast: Double = 0
        if let lastCoordinate = pathCoordinates.last {
            // 计算距离
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let newLocation = CLLocation(latitude: newCoordinate.latitude, longitude: newCoordinate.longitude)
            distanceFromLast = lastLocation.distance(from: newLocation)

            // 距离小于 10 米，不记录新点
            if distanceFromLast < 10 {
                return
            }
        }

        // 记录新点
        pathCoordinates.append(newCoordinate)

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

        // 检查点数是否足够
        guard pathCoordinates.count >= minimumPathPoints else {
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
        }
    }

    // MARK: - 速度检测

    /// 验证移动速度是否正常（防止作弊）
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示速度正常，false 表示超速
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // 第一个点，无需检测
        guard let lastTimestamp = lastLocationTimestamp,
              let lastCoordinate = pathCoordinates.last else {
            lastLocationTimestamp = newLocation.timestamp
            return true
        }

        // 计算时间差（秒）
        let timeInterval = newLocation.timestamp.timeIntervalSince(lastTimestamp)

        // 时间差太小，不检测
        guard timeInterval > 0.5 else {
            return true
        }

        // 计算距离（米）
        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = lastLocation.distance(from: newLocation)

        // 计算速度（km/h）
        let speedKmh = (distance / timeInterval) * 3.6

        print("🚗 速度检测：\(String(format: "%.1f", speedKmh)) km/h")

        // 更新时间戳
        lastLocationTimestamp = newLocation.timestamp

        // 速度判断
        if speedKmh > 30 {
            // 严重超速，暂停追踪
            speedWarning = "速度过快（\(String(format: "%.1f", speedKmh)) km/h），已暂停追踪"
            isOverSpeed = true

            // 记录错误日志
            TerritoryLogger.shared.log("超速 \(String(format: "%.1f", speedKmh)) km/h，已停止追踪", type: .error)

            stopPathTracking()
            return false
        } else if speedKmh > 15 {
            // 轻度超速，警告但继续追踪
            speedWarning = "移动速度过快（\(String(format: "%.1f", speedKmh)) km/h），请放慢速度"
            isOverSpeed = true

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
