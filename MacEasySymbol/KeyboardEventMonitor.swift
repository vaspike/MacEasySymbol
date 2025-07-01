//
//  KeyboardEventMonitor.swift
//  SymbolFlow
//
//  Created by river on 2025-06-30.
//

import Cocoa
import ApplicationServices

protocol KeyboardEventDelegate: AnyObject {
    func handleKeyboardEvent(keyCode: Int64, flags: CGEventFlags, originalEvent: CGEvent) -> CGEvent?
}

class KeyboardEventMonitor {
    
    weak var delegate: KeyboardEventDelegate?
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // 添加监听状态跟踪，便于调试和内存管理
    private var isCurrentlyMonitoring: Bool = false
    
    var isMonitoring: Bool {
        return eventTap != nil && isCurrentlyMonitoring
    }
    
    // MARK: - 析构函数，确保资源清理
    deinit {
        stopMonitoring()
        DebugLogger.log("🧹 KeyboardEventMonitor 析构完成")
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        guard !isMonitoring else { 
            DebugLogger.log("⚠️ 键盘监听已在运行中")
            return 
        }
        
        // 检查权限
        guard PermissionManager.hasAccessibilityPermission() else {
            DebugLogger.log("⚠️ 无辅助功能权限，无法开始监听键盘事件")
            return
        }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard let userInfo = userInfo else {
                    return Unmanaged.passRetained(event)
                }
                
                let monitor = Unmanaged<KeyboardEventMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )
        
        guard let eventTap = eventTap else {
            DebugLogger.log("❌ 创建事件tap失败")
            return
        }
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        
        guard let runLoopSource = runLoopSource else {
            DebugLogger.log("❌ 创建runloop source失败")
            // 清理已创建的eventTap
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
            return
        }
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, CFRunLoopMode.commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        isCurrentlyMonitoring = true
        DebugLogger.log("✅ 键盘事件监听已启动")
    }
    
    func stopMonitoring() {
        guard isCurrentlyMonitoring else { 
            DebugLogger.log("ℹ️ 键盘监听未在运行，无需停止")
            return 
        }
        
        isCurrentlyMonitoring = false
        
        // 禁用事件tap
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        
        // 从运行循环中移除源
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, CFRunLoopMode.commonModes)
            // 注意：CFRunLoopSource 会被自动释放，因为我们使用的是非保留引用
            self.runLoopSource = nil
        }
        
        DebugLogger.log("🛑 键盘事件监听已停止")
    }
    
    // 添加重启监听功能，用于权限变更后的恢复
    func restartMonitoring() {
        DebugLogger.log("🔄 重启键盘监听...")
        stopMonitoring()
        
        // 短暂延迟后重新开始，确保系统状态稳定
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.startMonitoring()
        }
    }
    
    // MARK: - Private Methods
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 检查是否仍在监听状态（防止在停止过程中处理事件）
        guard isCurrentlyMonitoring else {
            return Unmanaged.passRetained(event)
        }
        
        // 只处理按键按下事件
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }
        
        // 获取按键码和修饰键
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        // 委托给符号处理器
        if let convertedEvent = delegate?.handleKeyboardEvent(
            keyCode: keyCode,
            flags: flags,
            originalEvent: event
        ) {
            return Unmanaged.passRetained(convertedEvent)
        }
        
        return Unmanaged.passRetained(event)
    }
    
    // 检查事件tap是否仍然有效
    func isEventTapValid() -> Bool {
        guard let eventTap = eventTap else { return false }
        return CFMachPortIsValid(eventTap)
    }
    
    // 添加监听状态诊断方法
    func diagnosesStatus() -> String {
        var status = "KeyboardEventMonitor 状态:\n"
        status += "- isMonitoring: \(isMonitoring)\n"
        status += "- isCurrentlyMonitoring: \(isCurrentlyMonitoring)\n"
        status += "- eventTap: \(eventTap != nil ? "存在" : "不存在")\n"
        status += "- runLoopSource: \(runLoopSource != nil ? "存在" : "不存在")\n"
        status += "- eventTap有效: \(isEventTapValid())\n"
        status += "- 权限状态: \(PermissionManager.hasAccessibilityPermission() ? "有权限" : "无权限")"
        return status
    }
} 