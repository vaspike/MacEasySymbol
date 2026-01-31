//
//  AppDelegate.swift
//  SymbolFlow
//
//  Created by river on 2025-06-30.
//

import Cocoa
import ApplicationServices
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate, PermissionManagerDelegate {
    
    private var statusBarManager: StatusBarManager?
    private var keyboardMonitor: KeyboardEventMonitor?
    private var symbolConverter: SymbolConverter?
    private var permissionManager: PermissionManager?
    private var globalHotkeyManager: GlobalHotkeyManager?
    private var hotkeySettingsWindow: HotkeySettingsWindow?
    private var whitelistSettingsWindow: WhitelistSettingsWindow?
    private var symbolSettingsWindow: SymbolSettingsWindow?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 设置为Agent应用，隐藏Dock图标
        NSApp.setActivationPolicy(.accessory)
        
        // 检查是否需要重启提醒
        checkRestartReminder()
        
        // 初始化组件
        setupComponents()
        
        // 设置状态栏
        statusBarManager?.setupStatusBar()
        
        // 检查并请求权限
        checkAndRequestPermissions()
    }
    
    private func checkRestartReminder() {
        if UserDefaults.standard.bool(forKey: "NeedsRestartForPermission") {
            // 清除标记
            UserDefaults.standard.removeObject(forKey: "NeedsRestartForPermission")
            
            // 再次检查权限状态
            if PermissionManager.hasAccessibilityPermission() {
                DebugLogger.log("✅ 权限已生效，清除重启提醒")
            } else {
                // 权限仍未生效，显示重启提醒
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.showDelayedRestartReminder()
                }
            }
        }
    }
    
    private func showDelayedRestartReminder() {
        let alert = NSAlert()
        alert.messageText = "建议重启应用"
        alert.informativeText = "为确保辅助功能权限完全生效，建议现在重启应用。"
        alert.addButton(withTitle: "立即重启")
        alert.addButton(withTitle: "跳过")
        alert.alertStyle = .informational
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            restartApplication()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // 完整的清理流程
        cleanupResources()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Private Methods
    
    private func setupComponents() {
        permissionManager = PermissionManager()
        symbolConverter = SymbolConverter()
        keyboardMonitor = KeyboardEventMonitor()
        statusBarManager = StatusBarManager()
        globalHotkeyManager = GlobalHotkeyManager()
        
        // 设置委托关系
        keyboardMonitor?.delegate = symbolConverter
        statusBarManager?.delegate = self
        globalHotkeyManager?.delegate = self
        permissionManager?.delegate = self
        
        // 强制设置为启用状态，每次启动都启用
        symbolConverter?.setInterventionEnabled(true)
        // 同时更新UserDefaults，确保状态栏也显示为启用状态
        UserDefaults.standard.set(true, forKey: "InterventionEnabled")
        
        // GlobalHotkeyManager会根据保存的启用状态自动决定是否注册快捷键
        // 无需手动调用registerDefaultHotkey()
    }
    
    private func checkAndRequestPermissions() {
        guard let permissionManager = permissionManager else { return }
        
        if permissionManager.hasAccessibilityPermission() {
            // 权限已获得，开始监听
            startKeyboardMonitoring()
        } else {
            // 请求权限
            let granted = permissionManager.requestAccessibilityPermission()
            if granted {
                startKeyboardMonitoring()
            } else {
                showPermissionAlert()
            }
        }
    }
    
    private func startKeyboardMonitoring() {
        keyboardMonitor?.startMonitoring()
    }
    
    // 完整的资源清理方法
    private func cleanupResources() {
        DebugLogger.log("🧹 开始清理应用资源...")
        
        // 1. 停止键盘监听
        keyboardMonitor?.stopMonitoring()
        DebugLogger.log("✅ 键盘监听已停止")
        
        // 2. 清理符号转换器的缓存
        symbolConverter?.cleanup()
        
        // 3. 清理状态栏
        statusBarManager = nil
        
        // 4. 清理全局快捷键
        globalHotkeyManager?.unregisterCurrentHotkey()
        
        // 5. 清理所有委托关系，避免循环引用
        keyboardMonitor?.delegate = nil
        statusBarManager?.delegate = nil
        globalHotkeyManager?.delegate = nil
        permissionManager?.delegate = nil
        
        // 6. 清理窗口委托关系和强制关闭窗口
        if let settingsWindow = hotkeySettingsWindow {
            settingsWindow.delegate = nil
            settingsWindow.close()
        }

        if let whitelistWindow = whitelistSettingsWindow {
            whitelistWindow.delegate = nil
            whitelistWindow.close()
        }

        if let symbolWindow = symbolSettingsWindow {
            symbolWindow.delegate = nil
            symbolWindow.close()
        }

        // 8. 清理已废弃的设置数据
        UserDefaults.standard.removeObject(forKey: "SkipBracketKeys")
        
        // 7. 释放组件
        keyboardMonitor = nil
        symbolConverter = nil
        permissionManager = nil
        globalHotkeyManager = nil
        hotkeySettingsWindow = nil
        whitelistSettingsWindow = nil
        symbolSettingsWindow = nil
        
        // 6. 强制垃圾回收（仅用于调试，生产环境中系统会自动管理）
        #if DEBUG
        autoreleasepool {
            // 在调试模式下执行额外的清理
        }
        #endif
        
        DebugLogger.log("✅ 应用资源清理完成")
    }
    
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "MacEasySymbol 需要访问辅助功能权限来监听键盘事件。请在\"系统偏好设置\" > \"安全性与隐私\" > \"辅助功能\"中勾选本应用。"
        alert.addButton(withTitle: "打开系统偏好设置")
        alert.addButton(withTitle: "稍后设置")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 打开系统偏好设置
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            
            // 开始监控权限变化
            permissionManager?.startMonitoringPermissions()
            DebugLogger.log("🔍 用户点击打开系统偏好设置，开始监控权限变化")
        }
    }
    
    // 添加内存警告处理
    func applicationDidReceiveMemoryWarning(_ application: NSApplication) {
        DebugLogger.log("⚠️ 收到内存警告，执行内存清理...")
        
        // 清理符号转换器的缓存
        symbolConverter?.cleanup()
        
        // 强制执行一次垃圾回收
        autoreleasepool {
            // 清理临时对象
        }
        
        DebugLogger.log("✅ 内存警告处理完成")
    }
}

// MARK: - StatusBarManagerDelegate

extension AppDelegate: StatusBarManagerDelegate {
    func statusBarManager(_ manager: StatusBarManager, didToggleIntervention enabled: Bool) {
        symbolConverter?.setInterventionEnabled(enabled)
        
        if enabled && keyboardMonitor?.isMonitoring == false {
            checkAndRequestPermissions()
        }
    }
    
    func statusBarManagerDidRequestHotkeySettings(_ manager: StatusBarManager) {
        showHotkeySettingsWindow()
    }

    func statusBarManagerDidRequestSymbolSettings(_ manager: StatusBarManager) {
        showSymbolSettingsWindow()
    }

    func statusBarManagerDidRequestWhitelistSettings(_ manager: StatusBarManager) {
        showWhitelistSettingsWindow()
    }
    
    func statusBarManagerDidRequestToggleLoginItem(_ manager: StatusBarManager) {
        let currentStatus = LoginItemManager.shared.getCurrentStatus()
        let newStatus = !currentStatus
        
        let success = LoginItemManager.shared.setLoginItemEnabled(newStatus)
        
        if success {
            statusBarManager?.updateLoginItemStatus(newStatus)
            DebugLogger.log("🔄 开机自启已\(newStatus ? "启用" : "禁用")")
        } else {
            DebugLogger.logError("❌ 开机自启设置失败")
        }
    }
    
    func statusBarManagerDidRequestQuit(_ manager: StatusBarManager) {
        // 确保在退出前完整清理资源
        cleanupResources()
        NSApplication.shared.terminate(self)
    }
}

// MARK: - GlobalHotkeyDelegate

extension AppDelegate: GlobalHotkeyDelegate {
    func globalHotkeyDidTrigger() {
        // 切换介入模式
        guard let statusBarManager = statusBarManager else { return }
        statusBarManager.toggleInterventionMode()
        DebugLogger.log("🔥 全局快捷键触发，切换介入模式")
    }
}

// MARK: - HotkeySettingsDelegate

extension AppDelegate: HotkeySettingsDelegate {
    func hotkeySettingsDidSave(keyCode: UInt32, modifiers: UInt32, isEnabled: Bool) {
        globalHotkeyManager?.setEnabled(isEnabled)
        if isEnabled {
            globalHotkeyManager?.registerHotkey(keyCode: keyCode, modifiers: modifiers)
        }
        
        // 保存完成后重新设置委托，因为窗口可能会被重复使用
        hotkeySettingsWindow?.delegate = self
        DebugLogger.log("✅ 全局快捷键设置已保存: 启用=\(isEnabled)")
    }
    
    func hotkeySettingsDidCancel() {
        // 取消操作后重新设置委托，因为窗口可能会被重复使用
        hotkeySettingsWindow?.delegate = self
        DebugLogger.log("❌ 全局快捷键设置已取消")
    }
}

// MARK: - Helper Methods for Hotkey Settings

extension AppDelegate {
    private func showHotkeySettingsWindow() {
        // 如果窗口已存在，重新设置委托并激活它
        if let existingWindow = hotkeySettingsWindow {
            existingWindow.delegate = self  // 确保委托正确设置
            existingWindow.showWindow(self)
            existingWindow.window?.makeKeyAndOrderFront(self)
            
            // 更新当前设置值
            if let manager = globalHotkeyManager {
                let currentKeyCode = UserDefaults.standard.object(forKey: "GlobalHotkeyKeyCode") as? UInt32 ?? 1
                let currentModifiers = UserDefaults.standard.object(forKey: "GlobalHotkeyModifiers") as? UInt32 ?? UInt32(cmdKey | optionKey)
                let isEnabled = manager.getEnabled()
                existingWindow.setCurrentHotkey(keyCode: currentKeyCode, modifiers: currentModifiers, isEnabled: isEnabled)
            }
            return
        }
        
        // 创建新窗口
        hotkeySettingsWindow = HotkeySettingsWindow()
        hotkeySettingsWindow?.delegate = self
        
        // 设置当前快捷键值
        if let manager = globalHotkeyManager {
            let currentKeyCode = UserDefaults.standard.object(forKey: "GlobalHotkeyKeyCode") as? UInt32 ?? 1
            let currentModifiers = UserDefaults.standard.object(forKey: "GlobalHotkeyModifiers") as? UInt32 ?? UInt32(cmdKey | optionKey)
            let isEnabled = manager.getEnabled()
            hotkeySettingsWindow?.setCurrentHotkey(keyCode: currentKeyCode, modifiers: currentModifiers, isEnabled: isEnabled)
        }
        
        hotkeySettingsWindow?.showWindow(self)
        hotkeySettingsWindow?.window?.makeKeyAndOrderFront(self)
    }
    
    private func showWhitelistSettingsWindow() {
        // 如果窗口已存在，重新设置委托并激活它
        if let existingWindow = whitelistSettingsWindow {
            existingWindow.delegate = self  // 确保委托正确设置
            existingWindow.showWindow(self)
            existingWindow.window?.makeKeyAndOrderFront(self)
            return
        }

        // 创建新窗口
        whitelistSettingsWindow = WhitelistSettingsWindow()
        whitelistSettingsWindow?.delegate = self
        whitelistSettingsWindow?.showWindow(self)
        whitelistSettingsWindow?.window?.makeKeyAndOrderFront(self)
    }

    private func showSymbolSettingsWindow() {
        // 如果窗口已存在，重新设置委托并激活它
        if let existingWindow = symbolSettingsWindow {
            existingWindow.delegate = self  // 确保委托正确设置
            existingWindow.showWindow(self)
            existingWindow.window?.makeKeyAndOrderFront(self)
            return
        }

        // 创建新窗口
        symbolSettingsWindow = SymbolSettingsWindow()
        symbolSettingsWindow?.delegate = self
        symbolSettingsWindow?.showWindow(self)
        symbolSettingsWindow?.window?.makeKeyAndOrderFront(self)
    }
}

// MARK: - PermissionManagerDelegate

extension AppDelegate {
    func permissionManagerDidDetectPermissionGranted() {
        DebugLogger.log("🎉 检测到辅助功能权限已授予，准备重启应用")
        showRestartAlert()
    }
    
    private func showRestartAlert() {
        let alert = NSAlert()
        alert.messageText = "权限授予成功"
        alert.informativeText = "辅助功能权限已成功授予。为确保权限完全生效，应用需要重启。"
        alert.addButton(withTitle: "立即重启")
        alert.addButton(withTitle: "稍后重启")
        alert.alertStyle = .informational
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            restartApplication()
        } else {
            // 用户选择稍后重启，设置标记下次启动时提醒
            UserDefaults.standard.set(true, forKey: "NeedsRestartForPermission")
            DebugLogger.log("📝 用户选择稍后重启，已设置重启提醒标记")
        }
    }
    
    private func restartApplication() {
        DebugLogger.log("🔄 开始重启应用...")
        
        // 清理资源
        cleanupResources()
        
        // 获取应用Bundle路径
        let bundlePath = Bundle.main.bundlePath
        
        // 使用open命令重启应用
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [bundlePath]
        
        // 延迟启动，确保当前应用完全退出
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                try task.run()
                DebugLogger.log("✅ 重启命令已执行")
                
                // 退出当前应用
                NSApplication.shared.terminate(nil)
            } catch {
                DebugLogger.logError("❌ 重启应用失败: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - WhitelistSettingsDelegate
//防止未重启应用继续使用时可能不生效

extension AppDelegate: WhitelistSettingsDelegate {
    func whitelistSettingsDidSave() {
        // 白名单设置保存后重新设置委托，因为窗口可能会被重复使用
        whitelistSettingsWindow?.delegate = self
        DebugLogger.log("✅ 白名单设置已保存")
    }
    
    func whitelistSettingsDidCancel() {
        // 取消操作后重新设置委托，因为窗口可能会被重复使用
        whitelistSettingsWindow?.delegate = self
        DebugLogger.log("❌ 白名单设置已取消")
    }
}

// MARK: - SymbolSettingsDelegate

extension AppDelegate: SymbolSettingsDelegate {
    func symbolSettingsDidSave() {
        // 符号设置保存后重新设置委托
        symbolSettingsWindow?.delegate = self
        DebugLogger.log("✅ 符号转换设置已保存")
    }

    func symbolSettingsDidCancel() {
        // 取消操作后重新设置委托
        symbolSettingsWindow?.delegate = self
        DebugLogger.log("❌ 符号转换设置已取消")
    }
}

