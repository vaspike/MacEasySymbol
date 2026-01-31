import Cocoa
import ServiceManagement

class LoginItemManager {
    
    static let shared = LoginItemManager()
    
    private let launchAgentFileName = "com.rivermao.maceasysymbol.MacEasySymbol.plist"
    private let userDefaultsKey = "LoginItemEnabled"
    
    private init() {}
    
    var isEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: userDefaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userDefaultsKey)
        }
    }
    
    func setLoginItemEnabled(_ enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            return setLoginItemEnabledModern(enabled)
        } else {
            return setLoginItemEnabledLegacy(enabled)
        }
    }

    func getCurrentStatus() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return FileManager.default.fileExists(atPath: getLaunchAgentPath())
        }
    }
    
    @available(macOS 13.0, *)
    private func setLoginItemEnabledModern(_ enabled: Bool) -> Bool {
        do {
            let status = SMAppService.mainApp.status
            isEnabled = enabled
            if enabled {
                if status == .enabled {
                    DebugLogger.log("✅ 登录项已启用")
                } else {
                    try SMAppService.mainApp.register()
                    DebugLogger.log("✅ 登录项已注册并启用")
                }
            } else {
                if status == .notFound {
                    DebugLogger.log("✅ 登录项已禁用")
                } else {
                    try SMAppService.mainApp.unregister()
                    DebugLogger.log("✅ 登录项已注销")
                }
            }
            return true
        } catch {
            DebugLogger.logError("❌ 登录项操作失败: \(error.localizedDescription)")
            return false
        }
    }
    
    private func setLoginItemEnabledLegacy(_ enabled: Bool) -> Bool {
        let launchAgentPath = getLaunchAgentPath()
        let fileManager = FileManager.default
        
        do {
            if enabled {
                let appPath = Bundle.main.bundlePath
                guard !appPath.isEmpty else {
                    DebugLogger.logError("❌ 无法获取应用路径")
                    return false
                }
                
                let plistContent: [String: Any] = [
                    "Label": launchAgentFileName.replacingOccurrences(of: ".plist", with: ""),
                    "ProgramArguments": [appPath],
                    "RunAtLoad": true
                ]
                
                let plistData = try PropertyListSerialization.data(fromPropertyList: plistContent, format: .xml, options: 0)
                try plistData.write(to: URL(fileURLWithPath: launchAgentPath), options: .atomic)
                
                isEnabled = true
                DebugLogger.log("✅ LaunchAgent 已创建并启用")
                return true
            } else {
                if fileManager.fileExists(atPath: launchAgentPath) {
                    try fileManager.removeItem(atPath: launchAgentPath)
                    DebugLogger.log("✅ LaunchAgent 已删除")
                }
                
                isEnabled = false
                DebugLogger.log("✅ 登录项已禁用")
                return true
            }
        } catch {
            DebugLogger.logError("❌ LaunchAgent 操作失败: \(error.localizedDescription)")
            return false
        }
    }
    
    private func getLaunchAgentPath() -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let launchAgentsDir = (homeDir as NSString).appendingPathComponent("Library/LaunchAgents")
        
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: launchAgentsDir) {
            try? fileManager.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        return (launchAgentsDir as NSString).appendingPathComponent(launchAgentFileName)
    }
}
