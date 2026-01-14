//
//  MapViewRepresentable.swift
//  EarthLord
//
//  MKMapView 的 SwiftUI 包装器
//  负责显示地图、应用末世滤镜、处理用户位置更新、轨迹渲染
//

import SwiftUI
import MapKit

// MARK: - POI 标注类

/// 自定义 POI 标注
class POIAnnotation: MKPointAnnotation {
    let poi: POI

    init(poi: POI) {
        self.poi = poi
        super.init()
    }
}

// MARK: - 地图视图包装器

/// 将 UIKit 的 MKMapView 包装成 SwiftUI 视图
struct MapViewRepresentable: UIViewRepresentable {

    // MARK: - 绑定属性

    /// 用户位置（双向绑定）
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @Binding var hasLocatedUser: Bool

    /// 追踪路径坐标数组
    @Binding var trackingPath: [CLLocationCoordinate2D]

    /// 路径更新版本号
    let pathUpdateVersion: Int

    /// 是否正在追踪
    let isTracking: Bool

    /// 路径是否闭合
    let isPathClosed: Bool

    /// 已加载的领地列表
    let territories: [Territory]

    /// 领地数据版本号（强制触发更新）
    let territoriesVersion: Int

    /// 当前用户 ID
    let currentUserId: String?

    /// POI 列表
    var pois: [POI] = []

    /// POI 点击回调
    var onPOITapped: ((POI) -> Void)?

    // MARK: - UIViewRepresentable 协议方法

    /// 创建地图视图
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 基础配置
        mapView.mapType = .hybrid  // 卫星图+道路标签（符合末世风格）
        mapView.pointOfInterestFilter = .excludingAll  // 隐藏所有POI标签（星巴克、餐厅等）
        mapView.showsBuildings = false  // 隐藏3D建筑
        mapView.showsCompass = true  // 显示指南针
        mapView.showsScale = true  // 显示比例尺

        // 用户位置配置
        mapView.showsUserLocation = true  // ⚠️ 关键：显示用户位置蓝点，触发位置更新

        // 交互配置
        mapView.isZoomEnabled = true  // 允许双指缩放
        mapView.isScrollEnabled = true  // 允许单指拖动
        mapView.isRotateEnabled = true  // 允许旋转
        mapView.isPitchEnabled = false  // 禁用倾斜（保持平面视图）

        // 设置代理（⚠️ 关键：必须设置，否则 Coordinator 方法不会被调用）
        mapView.delegate = context.coordinator

        // 应用末世滤镜效果
        applyApocalypseFilter(to: mapView)

        return mapView
    }

    /// 更新地图视图
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 绘制领地
        drawTerritories(on: uiView)

        // 更新追踪路径
        updateTrackingPath(on: uiView, context: context)

        // 更新 POI 标记（传入 context 以使用缓存）
        updatePOIAnnotations(on: uiView, context: context)
    }

    /// 创建协调器
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - 末世滤镜

    /// 应用末世废土滤镜效果
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 色调控制：降低饱和度和亮度，营造荒凉感
        let colorControls = CIFilter(name: "CIColorControls")
        colorControls?.setValue(-0.15, forKey: kCIInputBrightnessKey)  // 稍微变暗
        colorControls?.setValue(0.5, forKey: kCIInputSaturationKey)  // 降低饱和度

        // 棕褐色调：废土的泛黄效果
        let sepiaFilter = CIFilter(name: "CISepiaTone")
        sepiaFilter?.setValue(0.65, forKey: kCIInputIntensityKey)  // 棕褐色强度

        // 应用滤镜到地图图层
        if let colorControls = colorControls, let sepiaFilter = sepiaFilter {
            mapView.layer.filters = [colorControls, sepiaFilter]
        }
    }

    // MARK: - 领地绘制

    /// 绘制领地多边形
    private func drawTerritories(on mapView: MKMapView) {
        // 移除旧的领地多边形（保留路径轨迹）
        let territoryOverlays = mapView.overlays.filter { overlay in
            if let polygon = overlay as? MKPolygon {
                return polygon.title == "mine" || polygon.title == "others"
            }
            return false
        }
        mapView.removeOverlays(territoryOverlays)

        // 绘制每个领地
        for territory in territories {
            var coords = territory.toCoordinates()

            // ⚠️ 中国大陆需要坐标转换 WGS-84 → GCJ-02
            coords = coords.map { coord in
                CoordinateConverter.wgs84ToGcj02(coord)
            }

            guard coords.count >= 3 else { continue }

            let polygon = MKPolygon(coordinates: coords, count: coords.count)

            // ⚠️ 关键：比较 userId 时必须统一大小写！
            // 数据库存的是小写 UUID，但 iOS 的 uuidString 返回大写
            // 如果不转换，会导致自己的领地显示为橙色
            let isMine = territory.userId.lowercased() == currentUserId?.lowercased()
            polygon.title = isMine ? "mine" : "others"

            mapView.addOverlay(polygon, level: .aboveRoads)
        }
    }

    // MARK: - 轨迹渲染

    /// 更新追踪路径
    private func updateTrackingPath(on mapView: MKMapView, context: Context) {
        // 移除旧的轨迹线和当前追踪的多边形（保留领地多边形）
        let overlaysToRemove = mapView.overlays.filter { overlay in
            // 移除轨迹线
            if overlay is MKPolyline {
                return true
            }
            // 移除当前追踪的多边形（title 为 nil 或 "tracking"）
            if let polygon = overlay as? MKPolygon {
                return polygon.title == nil || polygon.title == "tracking"
            }
            return false
        }
        mapView.removeOverlays(overlaysToRemove)

        // 如果路径点少于 2 个，不绘制轨迹
        guard trackingPath.count >= 2 else { return }

        // ⚠️ 关键：坐标转换 WGS-84 → GCJ-02
        let gcj02Coordinates = CoordinateConverter.batchWgs84ToGcj02(trackingPath)

        // 创建轨迹线
        let polyline = MKPolyline(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
        mapView.addOverlay(polyline)

        // 如果闭环且点数 ≥ 3，添加多边形填充
        if isPathClosed && gcj02Coordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
            polygon.title = "tracking"  // 标记为当前追踪的多边形
            mapView.addOverlay(polygon)
        }
    }

    // MARK: - POI 标记

    /// 更新 POI 标记
    private func updatePOIAnnotations(on mapView: MKMapView, context: Context) {
        // ⚠️ 关键：检查 POI 列表是否真的改变了，避免频繁刷新导致闪烁
        let currentPOIIds = Set(pois.map { $0.id })
        let existingPOIIds = context.coordinator.displayedPOIIds

        // 如果 POI 列表没变，检查是否有搜刮状态更新
        let needsScavengeUpdate = pois.contains { poi in
            if let existingPOI = context.coordinator.displayedPOIs[poi.id] {
                return existingPOI.isScavenged != poi.isScavenged
            }
            return false
        }

        // 如果 POI 列表相同且无状态更新，跳过
        guard currentPOIIds != existingPOIIds || needsScavengeUpdate else {
            return
        }

        print("🗺️ [MapView] 更新 POI 标记，数量: \(pois.count)")

        // 移除旧的 POI 标记
        let existingPOIAnnotations = mapView.annotations.filter { annotation in
            annotation is POIAnnotation
        }
        mapView.removeAnnotations(existingPOIAnnotations)

        // 更新缓存
        context.coordinator.displayedPOIIds = currentPOIIds
        context.coordinator.displayedPOIs.removeAll()

        // 如果没有 POI，直接返回
        guard !pois.isEmpty else { return }

        // 添加新的 POI 标记
        for poi in pois {
            // ⚠️ 关键修复：MKLocalSearch 返回的坐标在中国已经是 GCJ-02
            // 不需要再次转换，直接使用原坐标
            let annotation = POIAnnotation(poi: poi)
            annotation.coordinate = poi.coordinate
            annotation.title = poi.name
            annotation.subtitle = poi.category.wastelandName

            mapView.addAnnotation(annotation)

            // 缓存 POI 状态
            context.coordinator.displayedPOIs[poi.id] = poi
        }
    }

    // MARK: - 协调器

    /// 协调器：处理地图事件和用户位置更新
    class Coordinator: NSObject, MKMapViewDelegate {

        // MARK: - 属性

        var parent: MapViewRepresentable

        /// 是否已完成首次居中（防止重复居中）
        private var hasInitialCentered = false

        /// 当前显示的 POI ID 集合（用于检测变化，避免闪烁）
        var displayedPOIIds: Set<String> = []

        /// 当前显示的 POI 缓存（用于检测状态变化）
        var displayedPOIs: [String: POI] = [:]

        // MARK: - 初始化

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // MARK: - MKMapViewDelegate 方法

        /// ⭐ 关键方法：用户位置更新时调用
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取位置
            guard let location = userLocation.location else { return }

            // 更新绑定的位置
            DispatchQueue.main.async {
                self.parent.userLocation = location.coordinate
            }

            // 如果已经居中过，不再自动居中（允许用户手动拖动地图）
            guard !hasInitialCentered else { return }

            // 创建居中区域（约1公里范围，适合查看周边环境）
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000,  // 南北1公里
                longitudinalMeters: 1000  // 东西1公里
            )

            // 平滑居中地图（animated: true 实现平滑过渡）
            mapView.setRegion(region, animated: true)

            // 标记已完成首次居中
            hasInitialCentered = true

            // 更新外部状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }
        }

        /// ⭐ 关键方法：渲染轨迹（必须实现，否则轨迹不显示！）
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 如果是轨迹线
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // 轨迹样式：根据是否闭环改变颜色
                if parent.isPathClosed {
                    renderer.strokeColor = UIColor.systemGreen  // 闭环后：绿色
                } else {
                    renderer.strokeColor = UIColor.systemCyan  // 未闭环：青色
                }

                renderer.lineWidth = 5  // 线宽
                renderer.lineCap = .round  // 圆头

                return renderer
            }

            // 如果是多边形
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 根据多边形类型设置样式
                if polygon.title == "mine" {
                    // 我的领地：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                    renderer.lineWidth = 2.0
                } else if polygon.title == "others" {
                    // 他人领地：橙色
                    renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemOrange
                    renderer.lineWidth = 2.0
                } else {
                    // 当前追踪的轨迹多边形：绿色（默认）
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                    renderer.lineWidth = 2.0
                }

                return renderer
            }

            // 默认渲染器
            return MKOverlayRenderer(overlay: overlay)
        }

        /// 地图区域改变时调用
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 可用于保存用户最后查看的区域（暂不实现）
        }

        /// 地图加载完成时调用
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            // 地图加载完成
        }

        // MARK: - POI 标注视图

        /// 自定义标注视图
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 用户位置使用默认蓝点
            guard !(annotation is MKUserLocation) else { return nil }

            // POI 标注
            if let poiAnnotation = annotation as? POIAnnotation {
                let identifier = "POIAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: poiAnnotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                    // ⚠️ 关键修复：禁用添加动画，避免频繁更新时的闪烁
                    annotationView?.animatesWhenAdded = false
                } else {
                    annotationView?.annotation = poiAnnotation
                }

                // 根据类型设置颜色和图标
                let poi = poiAnnotation.poi
                annotationView?.markerTintColor = poi.isScavenged ? .gray : .orange
                annotationView?.glyphText = poi.category.icon
                annotationView?.titleVisibility = .adaptive
                annotationView?.subtitleVisibility = .hidden

                // ⚠️ 关键：添加搜刮按钮到标注弹窗
                if !poi.isScavenged {
                    let scavengeButton = UIButton(type: .detailDisclosure)
                    annotationView?.rightCalloutAccessoryView = scavengeButton
                } else {
                    annotationView?.rightCalloutAccessoryView = nil
                }

                return annotationView
            }

            return nil
        }

        /// ⭐ 关键方法：点击 POI 标注的附属视图（搜刮按钮）
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard let poiAnnotation = view.annotation as? POIAnnotation else { return }

            let poi = poiAnnotation.poi
            print("🎯 [MapView] 用户点击了 POI 搜刮按钮: \(poi.name)")

            // 调用回调
            parent.onPOITapped?(poi)
        }

        /// 点击 POI 标注时调用
        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            guard let poiAnnotation = annotation as? POIAnnotation else { return }
            print("📍 [MapView] 用户选中了 POI: \(poiAnnotation.poi.name)")
        }
    }
}

// MARK: - 预览

#Preview {
    MapViewRepresentable(
        userLocation: .constant(nil),
        hasLocatedUser: .constant(false),
        trackingPath: .constant([]),
        pathUpdateVersion: 0,
        isTracking: false,
        isPathClosed: false,
        territories: [],
        territoriesVersion: 0,
        currentUserId: nil,
        pois: [],
        onPOITapped: nil
    )
}
