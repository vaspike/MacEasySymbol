//
//  AppDelegate.swift
//  SymbolFlow
//
//  Created by river on 2025-06-30.
//

import Cocoa
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarManager: StatusBarManager?
    private var keyboardMonitor: KeyboardEventMonitor?
    private var symbolConverter: SymbolConverter?
    private var permissionManager: PermissionManager?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 设置为Agent应用，隐藏Dock图标
        NSApp.setActivationPolicy(.accessory)
        
        // 初始化组件
        setupComponents()
        
        // 设置状态栏
        statusBarManager?.setupStatusBar()
        
        // 检查并请求权限
        checkAndRequestPermissions()
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
        
        // 设置委托关系
        keyboardMonitor?.delegate = symbolConverter
        statusBarManager?.delegate = self
        
        // 强制设置为启用状态，每次启动都启用
        symbolConverter?.setInterventionEnabled(true)
        // 同时更新UserDefaults，确保状态栏也显示为启用状态
        UserDefaults.standard.set(true, forKey: "InterventionEnabled")
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
        
        // 4. 清理所有委托关系，避免循环引用
        keyboardMonitor?.delegate = nil
        statusBarManager?.delegate = nil
        
        // 5. 释放组件
        keyboardMonitor = nil
        symbolConverter = nil
        permissionManager = nil
        
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
        alert.informativeText = "SymbolFlow 需要访问辅助功能权限来监听键盘事件。请在\"系统偏好设置\" > \"安全性与隐私\" > \"辅助功能\"中勾选本应用。"
        alert.addButton(withTitle: "打开系统偏好设置")
        alert.addButton(withTitle: "稍后设置")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
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
    
    func statusBarManagerDidRequestQuit(_ manager: StatusBarManager) {
        // 确保在退出前完整清理资源
        cleanupResources()
        NSApplication.shared.terminate(self)
    }
}

