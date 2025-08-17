//
//  AppWhitelistManager.swift
//  MacEasySymbol
//
//  Created by River on 2025-08-17.
//

import Cocoa
import ApplicationServices

struct AppInfo {
    let name: String
    let bundleID: String
    let iconImage: NSImage?
    
    init(name: String, bundleID: String, iconImage: NSImage? = nil) {
        self.name = name
        self.bundleID = bundleID
        self.iconImage = iconImage
    }
}

class AppWhitelistManager {
    
    static let shared = AppWhitelistManager()
    
    private let userDefaultsKey = "AppWhitelist"
    
    private init() {}
    
    // MARK: - 白名单管理
    
    /// 获取当前白名单中的bundle ID列表
    func getWhitelistedBundleIDs() -> Set<String> {
        let array = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String] ?? []
        return Set(array)
    }
    
    /// 添加应用到白名单
    func addToWhitelist(bundleID: String) {
        var whitelist = getWhitelistedBundleIDs()
        whitelist.insert(bundleID)
        saveWhitelist(whitelist)
        DebugLogger.log("✅ 已添加到白名单: \(bundleID)")
    }
    
    /// 从白名单中移除应用
    func removeFromWhitelist(bundleID: String) {
        var whitelist = getWhitelistedBundleIDs()
        whitelist.remove(bundleID)
        saveWhitelist(whitelist)
        DebugLogger.log("❌ 已从白名单移除: \(bundleID)")
    }
    
    /// 检查应用是否在白名单中
    func isWhitelisted(bundleID: String) -> Bool {
        return getWhitelistedBundleIDs().contains(bundleID)
    }
    
    /// 保存白名单到UserDefaults
    private func saveWhitelist(_ whitelist: Set<String>) {
        UserDefaults.standard.set(Array(whitelist), forKey: userDefaultsKey)
    }
    
    // MARK: - 当前活动应用检测
    
    /// 获取当前获得焦点的应用的bundle ID
    func getCurrentFocusedAppBundleID() -> String? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        return frontmostApp.bundleIdentifier
    }
    
    /// 检查当前获得焦点的应用是否在白名单中
    func isCurrentAppWhitelisted() -> Bool {
        guard let bundleID = getCurrentFocusedAppBundleID() else {
            return false
        }
        return isWhitelisted(bundleID: bundleID)
    }
    
    // MARK: - 获取白名单应用信息
    
    /// 获取白名单中的应用信息列表
    func getWhitelistedApps() -> [AppInfo] {
        let bundleIDs = getWhitelistedBundleIDs()
        var apps: [AppInfo] = []
        
        for bundleID in bundleIDs {
            if let appInfo = getAppInfo(for: bundleID) {
                apps.append(appInfo)
            } else {
                // 如果找不到应用信息，创建一个基本的AppInfo
                apps.append(AppInfo(name: "未知应用", bundleID: bundleID))
            }
        }
        
        return apps.sorted { $0.name < $1.name }
    }
    
    /// 根据bundle ID获取应用信息
    private func getAppInfo(for bundleID: String) -> AppInfo? {
        // 尝试通过NSWorkspace查找应用
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let appName = appURL.deletingPathExtension().lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            return AppInfo(name: appName, bundleID: bundleID, iconImage: icon)
        }
        
        return nil
    }
    
    // MARK: - 调试方法
    
    func debugInfo() -> String {
        let whitelist = getWhitelistedBundleIDs()
        let currentApp = getCurrentFocusedAppBundleID() ?? "未知"
        let isCurrentWhitelisted = isCurrentAppWhitelisted()
        
        var info = "AppWhitelistManager 状态:\n"
        info += "- 白名单应用数量: \(whitelist.count)\n"
        info += "- 当前焦点应用: \(currentApp)\n"
        info += "- 当前应用是否在白名单: \(isCurrentWhitelisted)\n"
        info += "- 白名单内容: \(Array(whitelist).joined(separator: ", "))"
        
        return info
    }
}