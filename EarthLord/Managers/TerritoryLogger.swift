//
//  TerritoryLogger.swift
//  EarthLord
//
//  圈地功能日志管理器
//  用于在 App 内显示调试日志，方便真机测试时查看运行状态
//

import Foundation
import SwiftUI
import Combine

// MARK: - 日志类型

/// 日志类型枚举
enum LogType: String {
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"

    /// 日志类型对应的颜色
    var color: Color {
        switch self {
        case .info:
            return .cyan
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

// MARK: - 日志条目

/// 日志条目结构
struct LogEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let message: String
    let type: LogType

    init(message: String, type: LogType = .info) {
        self.id = UUID()
        self.timestamp = Date()
        self.message = message
        self.type = type
    }

    /// 格式化显示（用于界面显示）
    func formatted() -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let timeString = timeFormatter.string(from: timestamp)
        return "[\(timeString)] [\(type.rawValue)] \(message)"
    }

    /// 格式化导出（用于导出文件）
    func formattedForExport() -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timeString = timeFormatter.string(from: timestamp)
        return "[\(timeString)] [\(type.rawValue)] \(message)"
    }
}

// MARK: - 日志管理器

/// 圈地功能日志管理器（单例）
class TerritoryLogger: ObservableObject {

    // MARK: - 单例

    /// 全局单例实例
    static let shared = TerritoryLogger()

    // MARK: - 发布属性

    /// 日志条目数组
    @Published var logs: [LogEntry] = []

    /// 格式化的日志文本（用于界面显示）
    @Published var logText: String = ""

    // MARK: - 常量

    /// 最大日志条数（防止内存溢出）
    private let maxLogCount = 200

    // MARK: - 初始化

    /// 私有初始化（确保单例）
    private init() {
        log("日志系统初始化完成", type: .info)
    }

    // MARK: - 公开方法

    /// 添加日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - type: 日志类型
    func log(_ message: String, type: LogType = .info) {
        // 确保在主线程更新 UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 创建新日志条目
            let entry = LogEntry(message: message, type: type)

            // 添加到数组
            self.logs.append(entry)

            // 限制日志条数
            if self.logs.count > self.maxLogCount {
                self.logs.removeFirst()
            }

            // 更新格式化文本
            self.updateLogText()

            // 同时输出到控制台（方便 Xcode 调试）
            print("🏴 \(entry.formatted())")
        }
    }

    /// 清空所有日志
    func clear() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.logs.removeAll()
            self.logText = ""
            print("🏴 日志已清空")
        }
    }

    /// 导出日志为文本
    /// - Returns: 格式化的日志文本字符串
    func export() -> String {
        // 生成导出头信息
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let exportTime = dateFormatter.string(from: Date())

        var output = """
        === 圈地功能测试日志 ===
        导出时间: \(exportTime)
        日志条数: \(logs.count)

        """

        // 添加所有日志
        for log in logs {
            output += log.formattedForExport() + "\n"
        }

        return output
    }

    // MARK: - 私有方法

    /// 更新格式化日志文本
    private func updateLogText() {
        logText = logs.map { $0.formatted() }.joined(separator: "\n")
    }
}
