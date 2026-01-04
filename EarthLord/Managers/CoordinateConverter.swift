//
//  CoordinateConverter.swift
//  EarthLord
//
//  坐标转换工具
//  解决中国 GPS 偏移问题：WGS-84 → GCJ-02
//

import Foundation
import CoreLocation

// MARK: - 坐标转换器

/// 坐标系转换工具，解决中国地图坐标偏移问题
struct CoordinateConverter {

    // MARK: - 常量定义

    /// 长半轴
    private static let a: Double = 6378245.0

    /// 扁率
    private static let ee: Double = 0.00669342162296594323

    /// 圆周率
    private static let pi: Double = 3.1415926535897932384626

    // MARK: - 公开方法

    /// WGS-84 坐标转换为 GCJ-02 坐标（火星坐标系）
    /// - Parameter wgs84: WGS-84 坐标（GPS 原始坐标）
    /// - Returns: GCJ-02 坐标（适用于中国地图）
    static func wgs84ToGcj02(_ wgs84: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 如果在中国境外，不进行转换
        if isOutOfChina(latitude: wgs84.latitude, longitude: wgs84.longitude) {
            return wgs84
        }

        // 计算偏移量
        var dLat = transformLatitude(x: wgs84.longitude - 105.0, y: wgs84.latitude - 35.0)
        var dLon = transformLongitude(x: wgs84.longitude - 105.0, y: wgs84.latitude - 35.0)

        let radLat = wgs84.latitude / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi)

        // 返回偏移后的坐标
        let gcj02Latitude = wgs84.latitude + dLat
        let gcj02Longitude = wgs84.longitude + dLon

        return CLLocationCoordinate2D(latitude: gcj02Latitude, longitude: gcj02Longitude)
    }

    /// 批量转换坐标数组
    /// - Parameter wgs84Coordinates: WGS-84 坐标数组
    /// - Returns: GCJ-02 坐标数组
    static func batchWgs84ToGcj02(_ wgs84Coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        return wgs84Coordinates.map { wgs84ToGcj02($0) }
    }

    // MARK: - 私有辅助方法

    /// 判断是否在中国境外
    private static func isOutOfChina(latitude: Double, longitude: Double) -> Bool {
        if longitude < 72.004 || longitude > 137.8347 {
            return true
        }
        if latitude < 0.8293 || latitude > 55.8271 {
            return true
        }
        return false
    }

    /// 纬度转换
    private static func transformLatitude(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 经度转换
    private static func transformLongitude(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0
        return ret
    }
}
