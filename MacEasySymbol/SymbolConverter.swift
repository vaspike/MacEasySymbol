//
//  SymbolConverter.swift
//  SymbolFlow
//
//  Created by river on 2025-06-30.
//

import Cocoa
import ApplicationServices
import Carbon

class SymbolConverter: KeyboardEventDelegate {
    
    private var isInterventionEnabled = true
    
    // 缓存键盘输入源相关对象，避免频繁创建
    private var cachedInputSource: TISInputSource?
    private var cachedKeyboardLayout: UnsafePointer<UCKeyboardLayout>?
    private var lastLayoutChangeTime: Date = Date()
    private let cacheValidDuration: TimeInterval = 30.0 // 缓存30秒
    
    // 按键码到符号的映射表（基于美式键盘布局）
    private let keyCodeToEnglishSymbol: [Int64: String] = [
        43: ",",    // 逗号键
        47: ".",    // 句号键
        41: ";",    // 分号键
        // 注意：冒号需要Shift+分号
        44: "/",    // 斜杠键
        39: "'",    // 单引号键
        // 注意：双引号需要Shift+单引号
        25: "]",    // ]键
        33: "[",    // [键
        // 注意：{}需要Shift+[]
        30: "]",    // ]键（另一个位置）
        21: "[",    // [键（另一个位置）
    ]
    
    // 更完整的按键映射（包括需要Shift的符号）
    private let symbolMappings: [String: (keyCode: Int64, needsShift: Bool)] = [
        ",": (43, false),   // 逗号
        ".": (47, false),   // 句号
        ";": (41, false),   // 分号
        ":": (41, true),    // 冒号 (Shift + 分号)
        "/": (44, false),   // 斜杠
        "?": (44, true),    // 问号 (Shift + 斜杠)
        "'": (39, false),   // 单引号
        "\"": (39, true),   // 双引号 (Shift + 单引号)
        "[": (33, false),   // 左方括号
        "]": (30, false),   // 右方括号
        "{": (33, true),    // 左大括号 (Shift + [)
        "}": (30, true),    // 右大括号 (Shift + ])
        "(": (25, true),    // 左括号 (Shift + 9)
        ")": (29, true),    // 右括号 (Shift + 0)
        "!": (18, true),    // 感叹号 (Shift + 1)
        "<": (43, true),    // 小于号 (Shift + 逗号)
        ">": (47, true),    // 大于号 (Shift + 句号)
        "~": (50, true),    // 波浪号 (Shift + `)
        "`": (50, false),   // 反引号
        "\\": (42, false),  // 反斜杠
        "|": (42, true),    // 竖线 (Shift + \)
        "$": (21, true),    // 美元符号 (Shift + 4)
        "^": (22, true),    // 脱字符 (Shift + 6)
        "_": (27, true),    // 下划线 (Shift + 减号)
    ]
    
    // 中文符号到英文符号的映射
    private let chineseToEnglishMapping: [String: String] = [
        "，": ",",
        "。": ".",
        "；": ";",
        "：": ":",
        "？": "?",
        "！": "!",
        "『": "'",          // 直角单引号左
        "』": "'",          // 直角单引号右
        "「": "{",         // 直角双引号左 生效
        "」": "}",         // 直角双引号右 生效
        "（": "(",
        "）": ")",
        "【": "[",
        "】": "]",
        "｛": "{",
        "｝": "}",
        "、": "\\",          // 顿号 -> 反斜杠
        "｜": "|",           // 全角竖线 -> 英文竖线
        "¥": "$",            // 人民币符号 -> 美元符号
        "……": "^",           // 省略号 -> 脱字符
        "《": "<",
        "》": ">",
        // 注意：引号的处理已移至专门的keyCode == 39逻辑中
        "～": "~",           // 全角波浪号
        "·": "`",           // 间隔号 -> 反引号
        "——": "_",           // 长破折号 -> 下划线
        "\u{2014}": "_",    // 长破折号（单个字符）-> 下划线

    ]
    
    // MARK: - 析构函数，清理缓存的资源
    deinit {
        clearKeyboardLayoutCache()
    }
    
    // MARK: - Public Methods
    
    func setInterventionEnabled(_ enabled: Bool) {
        isInterventionEnabled = enabled
        DebugLogger.log("🔄 符号转换\(enabled ? "已启用" : "已禁用")")
    }
    
    // MARK: - KeyboardEventDelegate
    
    func handleKeyboardEvent(keyCode: Int64, flags: CGEventFlags, originalEvent: CGEvent) -> CGEvent? {
        // 如果不启用介入，直接返回原事件
        guard isInterventionEnabled else {
            return originalEvent
        }
        
        // 获取当前按键对应的字符（使用缓存优化）
        guard let inputString = getInputString(for: keyCode, flags: flags) else {
            return originalEvent
        }
        
        // 特殊处理引号 - 当检测到任何引号时，统一输出英文引号
        if keyCode == 39 { // 引号键的keyCode是39
            if inputString == "'" || inputString == "\u{2018}" || inputString == "\u{2019}" || inputString == "\u{FF07}" {
                // 单引号相关 -> 输出英文单引号
                return createEventForSymbol("'", originalEvent: originalEvent)
            } else if inputString == "\"" || inputString == "\u{201C}" || inputString == "\u{201D}" || inputString == "\u{FF02}" {
                // 双引号相关 -> 输出英文双引号  
                return createEventForSymbol("\"", originalEvent: originalEvent)
            }
        }
        
        // 检查是否为其他中文符号
        guard let englishSymbol = chineseToEnglishMapping[inputString] else {
            return originalEvent
        }
        
        // 创建新的键盘事件来输出英文符号
        return createEventForSymbol(englishSymbol, originalEvent: originalEvent)
    }
    
    // MARK: - Private Methods
    
    private func isSymbolKey(keyCode: Int64) -> Bool {
        // 常见符号按键的键盘码
        let symbolKeyCodes: Set<Int64> = [
            43, 47, 41, 44, 39, 33, 30, 25, 29, 18, // 基础符号
            19, 20, 21, 23, 22, 26, 28, 24, 27,    // 数字行的符号
            50, // 反引号键（波浪号）
        ]
        return symbolKeyCodes.contains(keyCode)
    }
    
    // 优化的获取输入字符串方法，使用缓存减少API调用
    private func getInputString(for keyCode: Int64, flags: CGEventFlags) -> String? {
        // 检查缓存是否需要更新
        let now = Date()
        if cachedKeyboardLayout == nil || now.timeIntervalSince(lastLayoutChangeTime) > cacheValidDuration {
            updateKeyboardLayoutCache()
        }
        
        guard let keyboardLayout = cachedKeyboardLayout else {
            return nil
        }
        
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var actualLength = 0
        
        let modifierKeyState = UInt32((flags.rawValue >> 16) & 0xFF)
        
        let status = UCKeyTranslate(
            keyboardLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDown),
            modifierKeyState,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            4,
            &actualLength,
            &chars
        )
        
        guard status == noErr, actualLength > 0 else {
            return nil
        }
        
        return String(utf16CodeUnits: chars, count: actualLength)
    }
    
    // 更新键盘布局缓存
    private func updateKeyboardLayoutCache() {
        // 清理旧的缓存
        clearKeyboardLayoutCache()
        
        // 获取新的输入源
        cachedInputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
        
        guard let inputSource = cachedInputSource else {
            return
        }
        
        // 获取键盘布局数据
        let layoutData = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData)
        
        guard let keyLayoutPtr = layoutData else {
            return
        }
        
        let keyLayout = Unmanaged<CFData>.fromOpaque(keyLayoutPtr).takeUnretainedValue()
        let keyLayoutDataPtr = CFDataGetBytePtr(keyLayout)
        
        cachedKeyboardLayout = keyLayoutDataPtr?.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { $0 }
        lastLayoutChangeTime = Date()
        
        DebugLogger.log("🔄 键盘布局缓存已更新")
    }
    
    // 清理键盘布局缓存
    private func clearKeyboardLayoutCache() {
        cachedKeyboardLayout = nil
        // 注意：cachedInputSource 是通过 takeRetainedValue() 获取的，ARC会自动管理
        cachedInputSource = nil
    }
    
    private func createEventForSymbol(_ symbol: String, originalEvent: CGEvent) -> CGEvent? {
        guard let mapping = symbolMappings[symbol] else {
            return originalEvent
        }
        
        // 创建新的键盘事件
        let newEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(mapping.keyCode),
            keyDown: true
        )
        
        guard let event = newEvent else {
            return originalEvent
        }
        
        // 如果需要Shift键，添加Shift修饰符
        if mapping.needsShift {
            event.flags = [.maskShift]
        }
        
        // 设置事件的字符串
        let utf16Chars = Array(symbol.utf16)
        event.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
        
        DebugLogger.log("🔄 符号转换: 输出英文符号 '\(symbol)'")
        
        return event
    }
    
    // 添加手动清理方法，供外部调用
    func cleanup() {
        clearKeyboardLayoutCache()
        DebugLogger.log("🧹 SymbolConverter 内存清理完成")
    }
} 
