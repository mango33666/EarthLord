//
//  NotificationExtensions.swift
//  EarthLord
//
//  NotificationCenter 扩展
//  定义应用内通知名称
//

import Foundation

extension Notification.Name {
    /// 开发者模式用户切换通知
    static let developerModeUserChanged = Notification.Name("developerModeUserChanged")
}
