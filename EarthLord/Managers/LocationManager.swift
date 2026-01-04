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

    // MARK: - 私有属性

    /// CoreLocation 定位管理器
    private let locationManager = CLLocationManager()

    /// 当前位置（用于 Timer 采点）
    private var currentLocation: CLLocation?

    /// 路径更新定时器（每 2 秒采点）
    private var pathUpdateTimer: Timer?

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

        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil
    }

    /// 清除路径
    func clearPath() {
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
    }

    /// 记录路径点（定时器回调）
    private func recordPathPoint() {
        // 获取当前位置
        guard let location = currentLocation else { return }

        let newCoordinate = location.coordinate

        // 判断是否需要记录新点
        if let lastCoordinate = pathCoordinates.last {
            // 计算距离
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let newLocation = CLLocation(latitude: newCoordinate.latitude, longitude: newCoordinate.longitude)
            let distance = lastLocation.distance(from: newLocation)

            // 距离小于 10 米，不记录新点
            if distance < 10 {
                return
            }
        }

        // 记录新点
        pathCoordinates.append(newCoordinate)

        // 更新版本号，触发 SwiftUI 更新
        pathUpdateVersion += 1
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
