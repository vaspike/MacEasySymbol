//
//  InstalledAppsScanner.swift
//  MacEasySymbol
//
//  Created by River on 2025-08-17.
//

import Cocoa
import Foundation

class InstalledAppsScanner {
    
    static let shared = InstalledAppsScanner()
    
    private var cachedApps: [AppInfo] = []
    private var lastScanTime: Date?
    private let cacheValidDuration: TimeInterval = 300 // 5分钟缓存有效期
    
    private init() {}
    
    // MARK: - 公开方法
    
    /// 获取所有已安装的应用程序
    func getAllInstalledApps(forceRefresh: Bool = false) -> [AppInfo] {
        // 检查缓存是否有效
        if !forceRefresh, let lastScan = lastScanTime,
           Date().timeIntervalSince(lastScan) < cacheValidDuration,
           !cachedApps.isEmpty {
            DebugLogger.log("📱 使用缓存的应用列表 (\(cachedApps.count) 个应用)")
            return cachedApps
        }
        
        DebugLogger.log("🔍 开始扫描已安装应用...")
        
        var apps: [AppInfo] = []
        
        // 扫描常见的应用目录
        let appDirectories = [
            "/Applications",
            "/System/Applications",
            "/System/Library/CoreServices",
            NSSearchPathForDirectoriesInDomains(.applicationDirectory, .localDomainMask, true).first,
            NSSearchPathForDirectoriesInDomains(.applicationDirectory, .userDomainMask, true).first
        ].compactMap { $0 }
        
        for directory in appDirectories {
            apps.append(contentsOf: scanDirectory(directory))
        }
        
        // 去重并排序
        let uniqueApps = removeDuplicates(from: apps)
        let sortedApps = uniqueApps.sorted { app1, app2 in
            // 优先按应用名排序，如果名称相同则按bundle ID排序
            if app1.name == app2.name {
                return app1.bundleID < app2.bundleID
            }
            return app1.name.localizedCaseInsensitiveCompare(app2.name) == .orderedAscending
        }
        
        // 更新缓存
        cachedApps = sortedApps
        lastScanTime = Date()
        
        DebugLogger.log("✅ 应用扫描完成，共找到 \(sortedApps.count) 个应用")
        return sortedApps
    }
    
    /// 根据bundle ID查找应用
    func findApp(bundleID: String) -> AppInfo? {
        return getAllInstalledApps().first { $0.bundleID == bundleID }
    }
    
    /// 搜索应用（按名称或bundle ID）
    func searchApps(query: String) -> [AppInfo] {
        let allApps = getAllInstalledApps()
        let lowercaseQuery = query.lowercased()
        
        return allApps.filter { app in
            app.name.lowercased().contains(lowercaseQuery) ||
            app.bundleID.lowercased().contains(lowercaseQuery)
        }
    }
    
    // MARK: - 私有方法
    
    /// 扫描指定目录下的应用
    private func scanDirectory(_ path: String) -> [AppInfo] {
        var apps: [AppInfo] = []
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            return apps
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            
            for item in contents {
                let fullPath = (path as NSString).appendingPathComponent(item)
                
                // 只处理.app文件
                guard item.hasSuffix(".app") else { continue }
                
                if let appInfo = extractAppInfo(from: fullPath) {
                    apps.append(appInfo)
                }
            }
        } catch {
            DebugLogger.logError("❌ 扫描目录失败 \(path): \(error.localizedDescription)")
        }
        
        return apps
    }
    
    /// 从应用路径提取应用信息
    private func extractAppInfo(from appPath: String) -> AppInfo? {
        let appURL = URL(fileURLWithPath: appPath)
        
        // 获取应用名称（移除.app扩展名）
        let appName = appURL.deletingPathExtension().lastPathComponent
        
        // 尝试获取bundle信息
        guard let bundle = Bundle(url: appURL),
              let bundleID = bundle.bundleIdentifier else {
            // 即使没有bundle信息，也创建基本的AppInfo
            return AppInfo(name: appName, bundleID: "unknown.\(appName.lowercased())")
        }
        
        // 获取应用图标
        let icon = NSWorkspace.shared.icon(forFile: appPath)
        icon.size = NSSize(width: 32, height: 32)
        
        // 获取显示名称（优先使用CFBundleDisplayName）
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                         bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ??
                         appName
        
        return AppInfo(name: displayName, bundleID: bundleID, iconImage: icon)
    }
    
    /// 去除重复的应用（基于bundle ID）
    private func removeDuplicates(from apps: [AppInfo]) -> [AppInfo] {
        var seen = Set<String>()
        var uniqueApps: [AppInfo] = []
        
        for app in apps {
            if !seen.contains(app.bundleID) {
                seen.insert(app.bundleID)
                uniqueApps.append(app)
            }
        }
        
        return uniqueApps
    }
    
    // MARK: - 缓存管理
    
    /// 清除缓存
    func clearCache() {
        cachedApps.removeAll()
        lastScanTime = nil
        DebugLogger.log("🗑️ 应用缓存已清除")
    }
    
    /// 获取缓存状态
    func getCacheInfo() -> String {
        let cacheAge = lastScanTime.map { Date().timeIntervalSince($0) } ?? 0
        return """
        InstalledAppsScanner 缓存状态:
        - 缓存应用数量: \(cachedApps.count)
        - 上次扫描时间: \(lastScanTime?.description ?? "从未扫描")
        - 缓存年龄: \(String(format: "%.1f", cacheAge)) 秒
        - 缓存是否有效: \(cacheAge < cacheValidDuration ? "是" : "否")
        """
    }
}