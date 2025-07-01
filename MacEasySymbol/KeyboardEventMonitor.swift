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
    
    var isMonitoring: Bool {
        return eventTap != nil
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
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
            return
        }
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, CFRunLoopMode.commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        DebugLogger.log("✅ 键盘事件监听已启动")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, CFRunLoopMode.commonModes)
            self.runLoopSource = nil
        }
        
        DebugLogger.log("🛑 键盘事件监听已停止")
    }
    
    // MARK: - Private Methods
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
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
} 