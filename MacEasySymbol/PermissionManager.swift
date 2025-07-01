//
//  PermissionManager.swift
//  SymbolFlow
//
//  Created by river on 2025-06-30.
//

import Cocoa
import ApplicationServices

protocol PermissionManagerDelegate: AnyObject {
    func permissionManagerDidDetectPermissionGranted()
}

class PermissionManager {
    
    weak var delegate: PermissionManagerDelegate?
    private var permissionTimer: Timer?
    private var lastPermissionState: Bool = false
    
    init() {
        lastPermissionState = hasAccessibilityPermission()
    }
    
    deinit {
        stopMonitoringPermissions()
    }
    
    // MARK: - Public Methods
    
    func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    // MARK: - Permission Monitoring
    
    func startMonitoringPermissions() {
        // 如果权限已经获得，不需要监控
        if hasAccessibilityPermission() {
            return
        }
        
        // 停止现有的监控
        stopMonitoringPermissions()
        
        // 启动定时器，每2秒检查一次权限状态
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkPermissionChange()
        }
        
        DebugLogger.log("🔍 开始监控辅助功能权限状态变化")
    }
    
    func stopMonitoringPermissions() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        DebugLogger.log("🛑 停止监控辅助功能权限状态")
    }
    
    private func checkPermissionChange() {
        let currentState = hasAccessibilityPermission()
        
        // 如果权限状态从无到有，说明用户刚刚授予了权限
        if !lastPermissionState && currentState {
            DebugLogger.log("✅ 检测到辅助功能权限已被授予")
            
            // 停止监控
            stopMonitoringPermissions()
            
            // 通知委托
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.permissionManagerDidDetectPermissionGranted()
            }
        }
        
        lastPermissionState = currentState
    }
    
    // MARK: - Static Methods (兼容其他类调用)
    
    static func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    static func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
} 