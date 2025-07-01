import Cocoa
import Carbon

protocol GlobalHotkeyDelegate: AnyObject {
    func globalHotkeyDidTrigger()
}

class GlobalHotkeyManager {
    
    weak var delegate: GlobalHotkeyDelegate?
    
    private var hotKeyRef: EventHotKeyRef?
    private var isHotkeyRegistered: Bool = false
    
    // 默认快捷键：Command + Shift + T
    private var currentKeyCode: UInt32 = 17 // T键
    private var currentModifiers: UInt32 = UInt32(cmdKey | shiftKey)
    
    private let hotkeyID: EventHotKeyID = EventHotKeyID(signature: OSType(0x74747474), id: 1) // 'tttt'
    
    init() {
        loadSavedHotkey()
        setupEventHandler()
    }
    
    deinit {
        unregisterCurrentHotkey()
        DebugLogger.log("🧹 GlobalHotkeyManager 析构完成")
    }
    
    // MARK: - Public Methods
    
    func registerDefaultHotkey() {
        registerHotkey(keyCode: currentKeyCode, modifiers: currentModifiers)
    }
    
    func registerHotkey(keyCode: UInt32, modifiers: UInt32) {
        // 先注销当前快捷键
        unregisterCurrentHotkey()
        
        // 注册新快捷键
        var eventHotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetEventDispatcherTarget(),
            0,
            &eventHotKeyRef
        )
        
        if status == noErr, let hotKeyRef = eventHotKeyRef {
            self.hotKeyRef = hotKeyRef
            self.currentKeyCode = keyCode
            self.currentModifiers = modifiers
            self.isHotkeyRegistered = true
            
            // 保存设置
            saveHotkeySettings()
            
            let keyString = keyCodeToString(keyCode)
            let modifierString = modifiersToString(modifiers)
            DebugLogger.log("✅ 全局快捷键已注册: \(modifierString)\(keyString)")
        } else {
            DebugLogger.logError("❌ 注册全局快捷键失败: \(status)")
            isHotkeyRegistered = false
        }
    }
    
    func unregisterCurrentHotkey() {
        guard isHotkeyRegistered, let hotKeyRef = hotKeyRef else { return }
        
        let status = UnregisterEventHotKey(hotKeyRef)
        if status == noErr {
            DebugLogger.log("🛑 全局快捷键已注销")
        } else {
            DebugLogger.logError("❌ 注销全局快捷键失败: \(status)")
        }
        
        self.hotKeyRef = nil
        self.isHotkeyRegistered = false
    }
    
    func getCurrentHotkeyString() -> String {
        let keyString = keyCodeToString(currentKeyCode)
        let modifierString = modifiersToString(currentModifiers)
        return "\(modifierString)\(keyString)"
    }
    
    func isCurrentlyRegistered() -> Bool {
        return isHotkeyRegistered
    }
    
    // MARK: - Private Methods
    
    private func setupEventHandler() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { (nextHandler: EventHandlerCallRef?, theEvent: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus in
                guard let userData = userData else { return noErr }
                
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotkeyEvent(theEvent)
                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )
    }
    
    private func handleHotkeyEvent(_ event: EventRef?) {
        guard let event = event else { return }
        
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        
        if status == noErr && hotKeyID.signature == self.hotkeyID.signature && hotKeyID.id == self.hotkeyID.id {
            DebugLogger.log("🔥 全局快捷键触发: \(getCurrentHotkeyString())")
            
            // 在主线程中执行委托方法
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.globalHotkeyDidTrigger()
            }
        }
    }
    
    // MARK: - Settings Management
    
    private func saveHotkeySettings() {
        UserDefaults.standard.set(currentKeyCode, forKey: "GlobalHotkeyKeyCode")
        UserDefaults.standard.set(currentModifiers, forKey: "GlobalHotkeyModifiers")
        DebugLogger.log("💾 全局快捷键设置已保存")
    }
    
    private func loadSavedHotkey() {
        let savedKeyCode = UserDefaults.standard.object(forKey: "GlobalHotkeyKeyCode") as? UInt32
        let savedModifiers = UserDefaults.standard.object(forKey: "GlobalHotkeyModifiers") as? UInt32
        
        if let keyCode = savedKeyCode, let modifiers = savedModifiers {
            currentKeyCode = keyCode
            currentModifiers = modifiers
            DebugLogger.log("📖 已加载保存的全局快捷键设置: \(getCurrentHotkeyString())")
        } else {
            DebugLogger.log("📖 使用默认全局快捷键: \(getCurrentHotkeyString())")
        }
    }
    
    // MARK: - Helper Methods
    
    private func keyCodeToString(_ keyCode: UInt32) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Escape"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "Key\(keyCode)"
        }
    }
    
    private func modifiersToString(_ modifiers: UInt32) -> String {
        var result = ""
        
        if modifiers & UInt32(controlKey) != 0 {
            result += "⌃"
        }
        if modifiers & UInt32(optionKey) != 0 {
            result += "⌥"
        }
        if modifiers & UInt32(shiftKey) != 0 {
            result += "⇧"
        }
        if modifiers & UInt32(cmdKey) != 0 {
            result += "⌘"
        }
        
        return result
    }
    
    // 获取所有可用的修饰键组合
    static func getAvailableModifiers() -> [(name: String, value: UInt32)] {
        return [
            ("⌘ (Command)", UInt32(cmdKey)),
            ("⌃ (Control)", UInt32(controlKey)),
            ("⌥ (Option)", UInt32(optionKey)),
            ("⇧ (Shift)", UInt32(shiftKey)),
            ("⌘⇧ (Cmd+Shift)", UInt32(cmdKey | shiftKey)),
            ("⌘⌥ (Cmd+Option)", UInt32(cmdKey | optionKey)),
            ("⌘⌃ (Cmd+Control)", UInt32(cmdKey | controlKey)),
            ("⌃⇧ (Ctrl+Shift)", UInt32(controlKey | shiftKey)),
            ("⌥⇧ (Opt+Shift)", UInt32(optionKey | shiftKey)),
            ("⌘⌃⇧ (Cmd+Ctrl+Shift)", UInt32(cmdKey | controlKey | shiftKey))
        ]
    }
    
    // 获取常用按键的键码
    static func getCommonKeyCodes() -> [(name: String, code: UInt32)] {
        return [
            ("A", 0), ("B", 11), ("C", 8), ("D", 2), ("E", 14), ("F", 3),
            ("G", 5), ("H", 4), ("I", 34), ("J", 38), ("K", 40), ("L", 37),
            ("M", 46), ("N", 45), ("O", 31), ("P", 35), ("Q", 12), ("R", 15),
            ("S", 1), ("T", 17), ("U", 32), ("V", 9), ("W", 13), ("X", 7),
            ("Y", 16), ("Z", 6),
            ("1", 18), ("2", 19), ("3", 20), ("4", 21), ("5", 23),
            ("6", 22), ("7", 26), ("8", 28), ("9", 25), ("0", 29),
            ("Space", 49), ("Tab", 48), ("Return", 36), ("Escape", 53),
            ("←", 123), ("→", 124), ("↓", 125), ("↑", 126)
        ]
    }
} 