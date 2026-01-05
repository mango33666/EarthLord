//
//  TerritoryTestView.swift
//  EarthLord
//
//  圈地功能测试界面
//  显示圈地模块的实时日志，支持清空和导出
//

import SwiftUI

// MARK: - 圈地测试视图

struct TerritoryTestView: View {

    // MARK: - 环境对象

    /// 定位管理器（监听追踪状态）
    @EnvironmentObject var locationManager: LocationManager

    // MARK: - 观察对象

    /// 日志管理器（监听日志更新）
    @ObservedObject var logger = TerritoryLogger.shared

    // MARK: - 主视图

    var body: some View {
        VStack(spacing: 0) {
            // 状态指示器
            statusIndicator
                .padding()
                .background(ApocalypseTheme.cardBackground)

            Divider()

            // 日志滚动区域
            logScrollView

            Divider()

            // 底部按钮栏
            bottomButtons
                .padding()
                .background(ApocalypseTheme.cardBackground)
        }
        .navigationTitle("圈地测试")
        .background(ApocalypseTheme.background)
    }

    // MARK: - 子视图

    /// 状态指示器
    private var statusIndicator: some View {
        HStack(spacing: 12) {
            // 状态圆点
            Circle()
                .fill(locationManager.isTracking ? Color.green : Color.gray)
                .frame(width: 12, height: 12)

            // 状态文字
            Text(locationManager.isTracking ? "追踪中" : "未追踪")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 日志数量
            Text("共 \(logger.logs.count) 条日志")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    /// 日志滚动区域
    private var logScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if logger.logs.isEmpty {
                        // 空状态提示
                        emptyStateView
                    } else {
                        // 日志列表
                        ForEach(logger.logs) { log in
                            logEntryView(log)
                                .id(log.id)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: logger.logText) { _, _ in
                // 日志更新时自动滚动到底部
                if let lastLog = logger.logs.last {
                    withAnimation {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    /// 空状态提示
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("暂无日志")
                .font(.system(size: 16))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text("前往地图页面开始圈地追踪")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    /// 单条日志视图
    private func logEntryView(_ log: LogEntry) -> some View {
        Text(log.formatted())
            .font(.system(size: 12, weight: .regular).monospaced())
            .foregroundColor(log.type.color)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 底部按钮栏
    private var bottomButtons: some View {
        HStack(spacing: 16) {
            // 清空按钮
            Button(action: {
                logger.clear()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                    Text("清空日志")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.red.opacity(0.8))
                .cornerRadius(8)
            }
            .disabled(logger.logs.isEmpty)
            .opacity(logger.logs.isEmpty ? 0.5 : 1.0)

            // 导出按钮
            ShareLink(
                item: logger.export(),
                subject: Text("圈地功能测试日志"),
                message: Text("导出时间：\(Date().formatted())")
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出日志")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(ApocalypseTheme.primary)
                .cornerRadius(8)
            }
            .disabled(logger.logs.isEmpty)
            .opacity(logger.logs.isEmpty ? 0.5 : 1.0)
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        TerritoryTestView()
            .environmentObject(LocationManager())
    }
}
