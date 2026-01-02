//
//  MapViewRepresentable.swift
//  EarthLord
//
//  MKMapView 的 SwiftUI 包装器
//  负责显示地图、应用末世滤镜、处理用户位置更新
//

import SwiftUI
import MapKit

// MARK: - 地图视图包装器

/// 将 UIKit 的 MKMapView 包装成 SwiftUI 视图
struct MapViewRepresentable: UIViewRepresentable {

    // MARK: - 绑定属性

    /// 用户位置（双向绑定）
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @Binding var hasLocatedUser: Bool

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

    /// 更新地图视图（空实现即可）
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // 不需要在这里处理更新
        // 位置更新由 Coordinator 的 didUpdate userLocation 处理
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

    // MARK: - 协调器

    /// 协调器：处理地图事件和用户位置更新
    class Coordinator: NSObject, MKMapViewDelegate {

        // MARK: - 属性

        var parent: MapViewRepresentable

        /// 是否已完成首次居中（防止重复居中）
        private var hasInitialCentered = false

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

        /// 地图区域改变时调用
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 可用于保存用户最后查看的区域（暂不实现）
        }

        /// 地图加载完成时调用
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            // 地图加载完成
        }
    }
}
