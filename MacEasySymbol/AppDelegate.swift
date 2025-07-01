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
        // 停止键盘监听
        keyboardMonitor?.stopMonitoring()
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
        NSApplication.shared.terminate(self)
    }
}

