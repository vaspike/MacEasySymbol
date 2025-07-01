//
//  StatusBarManager.swift
//  SymbolFlow
//
//  Created by river on 2025-06-30.
//

import Cocoa

protocol StatusBarManagerDelegate: AnyObject {
    func statusBarManager(_ manager: StatusBarManager, didToggleIntervention enabled: Bool)
    func statusBarManagerDidRequestQuit(_ manager: StatusBarManager)
}

class StatusBarManager: NSObject {
    
    weak var delegate: StatusBarManagerDelegate?
    
    private var statusItem: NSStatusItem?
    private var isInterventionEnabled: Bool {
        didSet {
            updateStatusBarIcon()
            updateMenu()
        }
    }
    
    override init() {
        // 每次启动都强制设置为启用状态
        self.isInterventionEnabled = true
        super.init()
        // 确保UserDefaults也设置为启用状态
        UserDefaults.standard.set(true, forKey: "InterventionEnabled")
    }
    
    // MARK: - Public Methods
    
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(statusBarButtonClicked)
            updateStatusBarIcon()
        }
        
        updateMenu()
    }
    
    // MARK: - Private Methods
    
    private func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }
        
        // 使用自定义图片图标
        let imageName = isInterventionEnabled ? "enabled" : "disabled"
        
        if let image = NSImage(named: imageName) {
            // 让系统自动选择合适的分辨率版本（1x/2x/3x）
            image.isTemplate = true  // 支持明暗模式自动适配
            button.image = image
            button.title = ""  // 清空文本
        } else {
            // 如果图片加载失败，回退到文本符号
            let title = isInterventionEnabled ? "⚡" : "○"
            button.title = title
            button.image = nil
        }
        
        // 设置工具提示
        button.toolTip = isInterventionEnabled ? "MacEasySymbol - 介入模式" : "SymbolFlow - 不介入模式"
    }
    
    private func updateMenu() {
        let menu = NSMenu()
        
        // 状态信息
        let titleItem = NSMenuItem(title: "MacEasySymbol", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 介入/不介入切换
        let toggleTitle = isInterventionEnabled ? "✓ 介入模式" : "不介入模式"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleIntervention), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 帮助信息
        let helpItem = NSMenuItem(title: "符号转换说明", action: #selector(showHelp), keyEquivalent: "")
        helpItem.target = self
        menu.addItem(helpItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 关于
        let aboutItem = NSMenuItem(title: "关于", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 退出
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    // MARK: - Actions
    
    @objc private func statusBarButtonClicked() {
        // 可以在这里添加点击状态栏图标的逻辑
    }
    
    @objc private func toggleIntervention() {
        isInterventionEnabled.toggle()
        delegate?.statusBarManager(self, didToggleIntervention: isInterventionEnabled)
        
        // 保存用户偏好
        UserDefaults.standard.set(isInterventionEnabled, forKey: "InterventionEnabled")
    }
    
    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "符号转换说明"
        alert.informativeText = """
        介入模式下，以下中文符号会自动转换为英文符号：
        
        ，→ ,（逗号）
        。→ .（句号）
        ；→ ;（分号）
        ：→ :（冒号）
        ？→ ?（问号）
        ！→ !（感叹号）
        “”→ ""（双引号）
        ‘’→ ''（单引号）
        （）→ ()（括号）
        【】→ []（方括号）
        、→ /（顿号→斜杠）
        —— → _(长破折号→下划线)
        · → `（间隔号）
        ¥ → $（人民币符号）
        …… → ^（省略号）
        《 → <（左尖括号）
        》 → >（右尖括号）
        ｜ → |（竖线）
        ～ → ~（波浪号）
        「」→ {}（大括号）

        不介入模式下，不会进行任何转换。
        """
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
    
    @objc private func quitApp() {
        delegate?.statusBarManagerDidRequestQuit(self)
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "MacEasySymbol"
        alert.informativeText = """
        开源版本: 1.0.0
        
        作者: River
        
        版权 © 2025 River 毛小川. 保留所有权利。
        
        GitHub: https://github.com/vaspike/MacEasySymbol
        
        一个帮助使用原生中文输入法的用户自动转换符号的 macOS 应用。
        """
        alert.addButton(withTitle: "访问 GitHub")
        alert.addButton(withTitle: "确定")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 打开 GitHub 链接
            if let url = URL(string: "https://github.com/vaspike/MacEasySymbol") {
                NSWorkspace.shared.open(url)
            }
        }
    }
} 
