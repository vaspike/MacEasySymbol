//
//  SymbolConfig.swift
//  MacEasySymbol
//
//  符号转换配置数据模型
//

import Foundation

// 符号分类枚举
enum SymbolCategory: String, CaseIterable {
    case punctuation = "标点符号"    // ，。；：？！
    case brackets = "括号符号"       // （）【】「」{}[]
    case quotes = "引号符号"         // ' " 『』「」
    case operators = "运算符"        // +-*/=<>|
    case special = "特殊符号"        // `~@#$%^&_

    var icon: String {
        switch self {
        case .punctuation: return "，"
        case .brackets: return "（）"
        case .quotes: return "\""
        case .operators: return "+"
        case .special: return "@"
        }
    }
}

// 符号配置结构体
struct SymbolConfig {
    let symbol: String              // 符号字符（如 ","）
    let keyCode: Int64             // 按键码（如 43）
    let needsShift: Bool           // 是否需要Shift
    let description: String        // 描述（如"逗号"）
    let category: SymbolCategory   // 分类
    let chineseEquivalent: String? // 对应的中文符号（如果有）

    // 生成UserDefaults的key
    var defaultsKey: String {
        return needsShift ? "SymbolEnabled_\(keyCode)_Shift" : "SymbolEnabled_\(keyCode)"
    }

    // 检查该符号是否启用了转换
    var isEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: defaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultsKey)
        }
    }

    // 获取显示名称
    var displayName: String {
        if let chinese = chineseEquivalent {
            return "\(description) (\(symbol) → \(chinese))"
        } else {
            return "\(description) (\(symbol))"
        }
    }

    // 获取按键显示
    var keyDisplay: String {
        if needsShift {
            return "Shift+\(getKeyName(for: keyCode))"
        } else {
            return getKeyName(for: keyCode)
        }
    }

    // 获取按键名称
    private func getKeyName(for keyCode: Int64) -> String {
        switch keyCode {
        case 43: return ","
        case 47: return "."
        case 41: return ";"
        case 44: return "/"
        case 39: return "'"
        case 33: return "["
        case 30: return "]"
        case 50: return "`"
        case 42: return "\\"
        case 25: return "9"
        case 29: return "0"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 27: return "-"
        case 24: return "="
        default: return "Key\(keyCode)"
        }
    }
}

// 符号配置管理器
class SymbolConfigManager {
    static let shared = SymbolConfigManager()

    // 所有符号配置
    private(set) var allSymbols: [SymbolConfig] = []

    private init() {
        setupDefaultSymbols()
        ensureDefaultsAreSet()
    }

    // 设置默认符号配置
    private func setupDefaultSymbols() {
        allSymbols = [
            // 标点符号
            SymbolConfig(symbol: ",", keyCode: 43, needsShift: false, description: "逗号", category: .punctuation, chineseEquivalent: "，"),
            SymbolConfig(symbol: ".", keyCode: 47, needsShift: false, description: "句号", category: .punctuation, chineseEquivalent: "。"),
            SymbolConfig(symbol: ";", keyCode: 41, needsShift: false, description: "分号", category: .punctuation, chineseEquivalent: "；"),
            SymbolConfig(symbol: ":", keyCode: 41, needsShift: true, description: "冒号", category: .punctuation, chineseEquivalent: "："),
            SymbolConfig(symbol: "/", keyCode: 44, needsShift: false, description: "斜杠", category: .punctuation, chineseEquivalent: "/"),
            SymbolConfig(symbol: "?", keyCode: 44, needsShift: true, description: "问号", category: .punctuation, chineseEquivalent: "？"),
            SymbolConfig(symbol: "'", keyCode: 39, needsShift: false, description: "单引号", category: .quotes, chineseEquivalent: "'"),
            SymbolConfig(symbol: "\"", keyCode: 39, needsShift: true, description: "双引号", category: .quotes, chineseEquivalent: "\""),

            // 括号符号
            SymbolConfig(symbol: "[", keyCode: 33, needsShift: false, description: "左方括号", category: .brackets, chineseEquivalent: nil),
            SymbolConfig(symbol: "]", keyCode: 30, needsShift: false, description: "右方括号", category: .brackets, chineseEquivalent: nil),
            SymbolConfig(symbol: "{", keyCode: 33, needsShift: true, description: "左大括号", category: .brackets, chineseEquivalent: nil),
            SymbolConfig(symbol: "}", keyCode: 30, needsShift: true, description: "右大括号", category: .brackets, chineseEquivalent: nil),
            SymbolConfig(symbol: "(", keyCode: 25, needsShift: true, description: "左括号", category: .brackets, chineseEquivalent: "（"),
            SymbolConfig(symbol: ")", keyCode: 29, needsShift: true, description: "右括号", category: .brackets, chineseEquivalent: "）"),

            // 运算符
            SymbolConfig(symbol: "!", keyCode: 18, needsShift: true, description: "感叹号", category: .operators, chineseEquivalent: "！"),
            SymbolConfig(symbol: "@", keyCode: 19, needsShift: true, description: "@符号", category: .operators, chineseEquivalent: nil),
            SymbolConfig(symbol: "#", keyCode: 20, needsShift: true, description: "#号", category: .operators, chineseEquivalent: nil),
            SymbolConfig(symbol: "$", keyCode: 21, needsShift: true, description: "美元符号", category: .operators, chineseEquivalent: "¥"),
            SymbolConfig(symbol: "%", keyCode: 23, needsShift: true, description: "百分号", category: .operators, chineseEquivalent: nil),
            SymbolConfig(symbol: "^", keyCode: 22, needsShift: true, description: "脱字符", category: .operators, chineseEquivalent: "……"),
            SymbolConfig(symbol: "&", keyCode: 26, needsShift: true, description: "&符号", category: .operators, chineseEquivalent: nil),
            SymbolConfig(symbol: "*", keyCode: 28, needsShift: true, description: "星号", category: .operators, chineseEquivalent: nil),
            SymbolConfig(symbol: "<", keyCode: 43, needsShift: true, description: "小于号", category: .operators, chineseEquivalent: "《"),
            SymbolConfig(symbol: ">", keyCode: 47, needsShift: true, description: "大于号", category: .operators, chineseEquivalent: "》"),
            SymbolConfig(symbol: "+", keyCode: 24, needsShift: true, description: "加号", category: .operators, chineseEquivalent: nil),
            SymbolConfig(symbol: "-", keyCode: 27, needsShift: false, description: "减号", category: .operators, chineseEquivalent: nil),
            SymbolConfig(symbol: "_", keyCode: 27, needsShift: true, description: "下划线", category: .operators, chineseEquivalent: "——"),
            SymbolConfig(symbol: "=", keyCode: 24, needsShift: false, description: "等号", category: .operators, chineseEquivalent: nil),

            // 特殊符号
            SymbolConfig(symbol: "`", keyCode: 50, needsShift: false, description: "反引号", category: .special, chineseEquivalent: "·"),
            SymbolConfig(symbol: "~", keyCode: 50, needsShift: true, description: "波浪号", category: .special, chineseEquivalent: "~"),
            SymbolConfig(symbol: "\\", keyCode: 42, needsShift: false, description: "反斜杠", category: .special, chineseEquivalent: "、"),
            SymbolConfig(symbol: "|", keyCode: 42, needsShift: true, description: "竖线", category: .special, chineseEquivalent: "｜"),
        ]
    }

    // 确保默认值已设置（默认全部启用）
    private func ensureDefaultsAreSet() {
        for symbol in allSymbols {
            if UserDefaults.standard.object(forKey: symbol.defaultsKey) == nil {
                UserDefaults.standard.set(true, forKey: symbol.defaultsKey)  // 默认启用
            }
        }
    }

    // 获取启用的符号
    func getEnabledSymbols() -> [SymbolConfig] {
        return allSymbols.filter { $0.isEnabled }
    }

    // 获取禁用的符号
    func getDisabledSymbols() -> [SymbolConfig] {
        return allSymbols.filter { !$0.isEnabled }
    }

    // 按分类获取符号
    func getSymbolsByCategory(_ category: SymbolCategory) -> [SymbolConfig] {
        return allSymbols.filter { $0.category == category }
    }

    // 按分类获取启用的符号
    func getEnabledSymbolsByCategory(_ category: SymbolCategory) -> [SymbolConfig] {
        return allSymbols.filter { $0.category == category && $0.isEnabled }
    }

    // 获取所有分类的统计
    func getCategoryStats() -> [SymbolCategory: (total: Int, enabled: Int)] {
        var stats: [SymbolCategory: (total: Int, enabled: Int)] = [:]

        for category in SymbolCategory.allCases {
            let symbols = getSymbolsByCategory(category)
            let enabled = symbols.filter { $0.isEnabled }.count
            stats[category] = (total: symbols.count, enabled: enabled)
        }

        return stats
    }

    // 设置单个符号状态
    func setSymbolEnabled(_ symbol: SymbolConfig, enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: symbol.defaultsKey)
        let status = enabled ? "启用" : "禁用"
        DebugLogger.log("符号设置已更新: \(symbol.description) = \(status)")
    }

    // 批量设置分类状态
    func setCategoryEnabled(_ category: SymbolCategory, enabled: Bool) {
        let symbols = getSymbolsByCategory(category)
        for symbol in symbols {
            UserDefaults.standard.set(enabled, forKey: symbol.defaultsKey)
        }
        let status = enabled ? "启用" : "禁用"
        DebugLogger.log("分类设置已更新: \(category.rawValue) 全部\(status)")
    }

    // 启用所有符号
    func enableAllSymbols() {
        for symbol in allSymbols {
            UserDefaults.standard.set(true, forKey: symbol.defaultsKey)
        }
        DebugLogger.log("所有符号已启用")
    }

    // 禁用所有符号
    func disableAllSymbols() {
        for symbol in allSymbols {
            UserDefaults.standard.set(false, forKey: symbol.defaultsKey)
        }
        DebugLogger.log("所有符号已禁用")
    }

    // 检查符号是否启用（用于转换逻辑）
    func isSymbolEnabled(keyCode: Int64, needsShift: Bool) -> Bool {
        let key = needsShift ? "SymbolEnabled_\(keyCode)_Shift" : "SymbolEnabled_\(keyCode)"
        return UserDefaults.standard.bool(forKey: key)
    }

    // 获取调试信息
    func getDebugInfo() -> String {
        let enabledCount = getEnabledSymbols().count
        let totalCount = allSymbols.count
        let stats = getCategoryStats()

        var info = "符号配置管理器状态:\n"
        info += "- 总符号数: \(totalCount)\n"
        info += "- 启用符号数: \(enabledCount)\n"
        info += "- 禁用符号数: \(totalCount - enabledCount)\n"
        info += "\n分类统计:\n"

        for (category, stat) in stats {
            info += "- \(category.rawValue): \(stat.enabled)/\(stat.total) 启用\n"
        }

        return info
    }
}

// 预设方案
struct SymbolPreset {
    let name: String
    let description: String
    let enabledCategories: [SymbolCategory]
    let specificSymbols: [String] // 特定的符号字符

    static let allPresets: [SymbolPreset] = [
        SymbolPreset(
            name: "全部启用",
            description: "转换所有支持的符号",
            enabledCategories: SymbolCategory.allCases,
            specificSymbols: []
        ),
        SymbolPreset(
            name: "仅标点",
            description: "只转换常用标点符号",
            enabledCategories: [.punctuation],
            specificSymbols: []
        ),
        SymbolPreset(
            name: "标点+括号",
            description: "转换标点和括号符号",
            enabledCategories: [.punctuation, .brackets],
            specificSymbols: []
        ),
        SymbolPreset(
            name: "编程常用",
            description: "适合编程使用的符号组合",
            enabledCategories: [.brackets, .operators, .quotes],
            specificSymbols: [",", ".", ";", ":", "/", "?"]
        ),
        SymbolPreset(
            name: "最小集合",
            description: "只转换最常用的符号",
            enabledCategories: [],
            specificSymbols: [",", ".", ";", "'", "\""]
        )
    ]

    func apply() {
        // 先禁用所有符号
        SymbolConfigManager.shared.disableAllSymbols()

        // 启用指定分类的符号
        for category in enabledCategories {
            SymbolConfigManager.shared.setCategoryEnabled(category, enabled: true)
        }

        // 启用特定符号
        for symbolChar in specificSymbols {
            if let symbol = SymbolConfigManager.shared.allSymbols.first(where: { $0.symbol == symbolChar }) {
                UserDefaults.standard.set(true, forKey: symbol.defaultsKey)
            }
        }

        DebugLogger.log("已应用预设方案: \(name)")
    }
}