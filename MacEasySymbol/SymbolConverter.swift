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
    
    // 用户配置：是否跳过方括号键的处理
    private var skipBracketKeys: Bool {
        return UserDefaults.standard.bool(forKey: "SkipBracketKeys")
    }
    
    // 基础符号键映射（无需Shift）
    private let basicSymbolKeyCodes: [Int64: String] = [
        43: ",",    // 逗号
        47: ".",    // 句号
        41: ";",    // 分号
        44: "/",    // 斜杠
        39: "'",    // 单引号
        33: "[",    // 左方括号
        30: "]",    // 右方括号
        50: "`",    // 反引号
        42: "\\",   // 反斜杠
        // 注意：移除了 24: "=" 和 27: "-"，让它们在中文输入法候选框中正常工作
    ]
    
    // 需要Shift的符号键映射
    private let shiftSymbolKeyCodes: [Int64: String] = [
        41: ":",    // 冒号 (Shift + 分号)
        44: "?",    // 问号 (Shift + 斜杠)
        39: "\"",   // 双引号 (Shift + 单引号)
        33: "{",    // 左大括号 (Shift + [)
        30: "}",    // 右大括号 (Shift + ])
        25: "(",    // 左括号 (Shift + 9)
        29: ")",    // 右括号 (Shift + 0)
        18: "!",    // 感叹号 (Shift + 1)
        19: "@",    // @ (Shift + 2)
        20: "#",    // # (Shift + 3)
        21: "$",    // 美元符号 (Shift + 4)
        23: "%",    // % (Shift + 5)
        22: "^",    // 脱字符 (Shift + 6)
        26: "&",    // & (Shift + 7)
        28: "*",    // * (Shift + 8)
        43: "<",    // 小于号 (Shift + 逗号)
        47: ">",    // 大于号 (Shift + 句号)
        50: "~",    // 波浪号 (Shift + `)
        42: "|",    // 竖线 (Shift + \)
        27: "_",    // 下划线 (Shift + 减号)
        24: "+",    // 加号 (Shift + 等号)
    ]
    
    // 符号键集合（用于快速判断）
    private lazy var allSymbolKeyCodes: Set<Int64> = {
        Set(basicSymbolKeyCodes.keys).union(Set(shiftSymbolKeyCodes.keys))
    }()
    
    // 符号映射表（用于创建事件）
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
        "@": (19, true),    // @ (Shift + 2)
        "#": (20, true),    // # (Shift + 3)
        "$": (21, true),    // 美元符号 (Shift + 4)
        "%": (23, true),    // % (Shift + 5)
        "^": (22, true),    // 脱字符 (Shift + 6)
        "&": (26, true),    // & (Shift + 7)
        "*": (28, true),    // * (Shift + 8)
        "<": (43, true),    // 小于号 (Shift + 逗号)
        ">": (47, true),    // 大于号 (Shift + 句号)
        "~": (50, true),    // 波浪号 (Shift + `)
        "`": (50, false),   // 反引号
        "\\": (42, false),  // 反斜杠
        "|": (42, true),    // 竖线 (Shift + \)
        "_": (27, true),    // 下划线 (Shift + 减号)
        "+": (24, true),    // 加号 (Shift + 等号)
        // 注意：移除了 "-" 和 "=" 的基础映射，保留 Shift 版本
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
        "「": "{",         // 直角双引号左
        "」": "}",         // 直角双引号右
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
        "～": "~",           // 全角波浪号
        "·": "`",           // 间隔号 -> 反引号
        "——": "_",           // 长破折号 -> 下划线
        "\u{2014}": "_",    // 长破折号（单个字符）-> 下划线
    ]
    
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
        
        // 只处理符号键
        guard allSymbolKeyCodes.contains(keyCode) else {
            return originalEvent
        }
        
        // 检查修饰键：只允许无修饰键或仅有Shift键的情况
        let hasCommand = flags.contains(.maskCommand)
        let hasOption = flags.contains(.maskAlternate)
        let hasControl = flags.contains(.maskControl)
        let hasShift = flags.contains(.maskShift)
        let hasFn = flags.contains(.maskSecondaryFn)
        
        // 如果有Command、Option、Control或Fn键，直接返回原事件，不进行符号转换
        guard !hasCommand && !hasOption && !hasControl && !hasFn else {
            DebugLogger.log("⏭️ 检测到修饰键组合 (cmd:\(hasCommand), opt:\(hasOption), ctrl:\(hasControl), fn:\(hasFn))，跳过符号转换")
            return originalEvent
        }
        
        // 检查是否需要跳过方括号键（只对无修饰键的情况生效）
        if skipBracketKeys && !hasShift && (keyCode == 33 || keyCode == 30) {
            DebugLogger.log("⏭️ 根据用户配置跳过方括号键处理 (keyCode: \(keyCode))")
            return originalEvent
        }
        
        // 现在只可能是：无修饰键 或 仅有Shift键
        // 获取要输出的英文符号
        let englishSymbol: String
        if hasShift, let shiftSymbol = shiftSymbolKeyCodes[keyCode] {
            englishSymbol = shiftSymbol
        } else if !hasShift, let basicSymbol = basicSymbolKeyCodes[keyCode] {
            englishSymbol = basicSymbol
        } else {
            // 这种情况不应该发生，但为了安全起见
            return originalEvent
        }
        
        // 创建新的键盘事件来输出英文符号
        let result = createEventForSymbol(englishSymbol, originalEvent: originalEvent)
        
        DebugLogger.log("🔄 符号转换: keyCode=\(keyCode), shift=\(hasShift), 输出='\(englishSymbol)'")
        
        return result
    }
    
    // MARK: - Private Methods
    
    private func createEventForSymbol(_ symbol: String, originalEvent: CGEvent) -> CGEvent? {
        guard let mapping = symbolMappings[symbol] else {
            DebugLogger.logError("❌ 无法找到符号 '\(symbol)' 的映射")
            return originalEvent
        }
        
        // 创建新的键盘事件
        let newEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(mapping.keyCode),
            keyDown: true
        )
        
        guard let event = newEvent else {
            DebugLogger.logError("❌ 创建键盘事件失败")
            return originalEvent
        }
        
        // 如果需要Shift键，添加Shift修饰符
        if mapping.needsShift {
            event.flags = [.maskShift]
        }
        
        // 设置事件的字符串
        let utf16Chars = Array(symbol.utf16)
        event.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
        
        return event
    }
    
    // 添加手动清理方法，供外部调用（保持接口兼容性）
    func cleanup() {
        // 新版本无需清理缓存，但保留方法以维持接口兼容性
        DebugLogger.log("🧹 SymbolConverter 清理完成（简化版本无需清理）")
    }
    
    // MARK: - Debug Methods
    
    func getSupportedSymbols() -> [String] {
        return Array(symbolMappings.keys).sorted()
    }
    
    func getKeyCodeMapping() -> String {
        var result = "支持的按键映射:\n"
        
        result += "\n基础符号键 (无需Shift):\n"
        for (keyCode, symbol) in basicSymbolKeyCodes.sorted(by: { $0.key < $1.key }) {
            result += "  keyCode \(keyCode) -> '\(symbol)'\n"
        }
        
        result += "\nShift符号键 (需要Shift):\n"
        for (keyCode, symbol) in shiftSymbolKeyCodes.sorted(by: { $0.key < $1.key }) {
            result += "  keyCode \(keyCode) + Shift -> '\(symbol)'\n"
        }
        
        result += "\n中文符号映射:\n"
        for (chinese, english) in chineseToEnglishMapping.sorted(by: { $0.key < $1.key }) {
            result += "  '\(chinese)' -> '\(english)'\n"
        }
        
        return result
    }
} 
