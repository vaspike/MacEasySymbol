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
    func statusBarManagerDidRequestHotkeySettings(_ manager: StatusBarManager)
    func statusBarManagerDidRequestWhitelistSettings(_ manager: StatusBarManager)
    func statusBarManagerDidRequestSymbolSettings(_ manager: StatusBarManager)
    func statusBarManagerDidRequestToggleLoginItem(_ manager: StatusBarManager)
}

class StatusBarManager: NSObject {
    
    weak var delegate: StatusBarManagerDelegate?
    
    private var statusItem: NSStatusItem?
    private let statusItemHiddenKey = "StatusItemHidden"
    private let hideExplanationShownKey = "StatusItemHideExplanationShown"

    private var isStatusItemHidden: Bool {
        return UserDefaults.standard.bool(forKey: statusItemHiddenKey)
    }

    private var isInterventionEnabled: Bool {
        didSet {
            updateStatusBarIcon()
            updateMenu()
        }
    }
    
    private var loginItemEnabled: Bool {
        didSet {
            updateMenu()
        }
    }
    
    override init() {
        // 每次启动都强制设置为启用状态
        self.isInterventionEnabled = true
        // 读取登录项状态
        self.loginItemEnabled = LoginItemManager.shared.getCurrentStatus()
        super.init()
        // 确保UserDefaults也设置为启用状态
        UserDefaults.standard.set(true, forKey: "InterventionEnabled")
    }
    
    // MARK: - 析构函数，清理UI资源
    deinit {
        cleanup()
        DebugLogger.log("🧹 StatusBarManager 析构完成")
    }
    
    // MARK: - Public Methods
    
    func setupStatusBar() {
        guard !isStatusItemHidden else {
            DebugLogger.log("⏭️ 菜单栏图标保持隐藏；再次启动应用可恢复显示")
            return
        }

        // 如果已经存在，先清理
        if statusItem != nil {
            cleanup()
        }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(statusBarButtonClicked)
            updateStatusBarIcon()
        }
        
        updateMenu()
        DebugLogger.log("✅ 状态栏设置完成")
    }

    // 用户再次启动应用时恢复菜单栏图标。
    func showStatusBar() {
        UserDefaults.standard.set(false, forKey: statusItemHiddenKey)
        setupStatusBar()
        DebugLogger.log("✅ 菜单栏图标已恢复显示")
    }

    private func hideStatusBar() {
        UserDefaults.standard.set(true, forKey: statusItemHiddenKey)
        cleanup()
        DebugLogger.log("🙈 菜单栏图标已隐藏，后台功能保持运行")
    }
    
    // 添加清理方法
    func cleanup() {
        // 清理状态栏项目
        if let statusItem = statusItem {
            // 清理菜单
            statusItem.menu = nil
            
            // 清理按钮
            if let button = statusItem.button {
                button.target = nil
                button.action = nil
                button.image = nil
            }
            
            // 从状态栏移除
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        
        DebugLogger.log("🧹 StatusBarManager 清理完成")
    }
    
    // 公开的切换方法，供外部调用（如全局快捷键）
    func toggleInterventionMode() {
        isInterventionEnabled.toggle()
        delegate?.statusBarManager(self, didToggleIntervention: isInterventionEnabled)
        
        // 保存用户偏好
        UserDefaults.standard.set(isInterventionEnabled, forKey: "InterventionEnabled")
        DebugLogger.log("🔄 通过全局快捷键切换介入模式: \(isInterventionEnabled ? "启用" : "禁用")")
    }
    
    // 更新登录项状态
    func updateLoginItemStatus(_ enabled: Bool) {
        loginItemEnabled = enabled
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
        // 创建新菜单前先清理旧菜单
        statusItem?.menu = nil
        
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
        
        // 偏好设置
        let hotkeyItem = NSMenuItem(title: "快捷键设置", action: #selector(showHotkeySettings), keyEquivalent: "")
        hotkeyItem.target = self
        menu.addItem(hotkeyItem)

        // 符号转换设置
        let symbolItem = NSMenuItem(title: "符号转换设置", action: #selector(showSymbolSettings), keyEquivalent: "")
        symbolItem.target = self
        menu.addItem(symbolItem)

        // 白名单设置
        let whitelistItem = NSMenuItem(title: "应用白名单", action: #selector(showWhitelistSettings), keyEquivalent: "")
        whitelistItem.target = self
        menu.addItem(whitelistItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 帮助信息
        let helpItem = NSMenuItem(title: "符号转换说明", action: #selector(showHelp), keyEquivalent: "")
        helpItem.target = self
        menu.addItem(helpItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 开机自启
        let loginItemTitle = loginItemEnabled ? "✓ 开机自启" : "开机自启"
        let loginItemMenuItem = NSMenuItem(title: loginItemTitle, action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItemMenuItem.target = self
        menu.addItem(loginItemMenuItem)

        let hideItem = NSMenuItem(title: "隐藏菜单栏图标", action: #selector(hideMenuBarIcon), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)
        
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
        DebugLogger.log("🔄 介入模式已\(isInterventionEnabled ? "启用" : "禁用")")
    }
    
    @objc private func showHelp() {
        // 在主线程上显示alert，确保UI正确处理
        DispatchQueue.main.async { [weak self] in
            guard self != nil else { return }
            
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
            ""→ ""（双引号）
            ''→ ''（单引号）
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
    }
    
    @objc private func showHotkeySettings() {
        delegate?.statusBarManagerDidRequestHotkeySettings(self)
    }

    @objc private func showSymbolSettings() {
        delegate?.statusBarManagerDidRequestSymbolSettings(self)
    }

    @objc private func showWhitelistSettings() {
        delegate?.statusBarManagerDidRequestWhitelistSettings(self)
    }
    
    @objc private func toggleLoginItem() {
        delegate?.statusBarManagerDidRequestToggleLoginItem(self)
    }

    @objc private func hideMenuBarIcon() {
        let defaults = UserDefaults.standard

        if !defaults.bool(forKey: hideExplanationShownKey) {
            let alert = NSAlert()
            alert.messageText = "隐藏菜单栏图标？"
            alert.informativeText = "隐藏后，符号转换、白名单和全局快捷键仍会正常工作。\n\n如需重新显示图标，请再次启动 MacEasySymbol。"
            alert.addButton(withTitle: "隐藏")
            alert.addButton(withTitle: "取消")
            alert.alertStyle = .informational

            NSApp.activate(ignoringOtherApps: true)
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            defaults.set(true, forKey: hideExplanationShownKey)
        }

        hideStatusBar()
    }
    
    @objc private func quitApp() {
        delegate?.statusBarManagerDidRequestQuit(self)
    }
    
    @objc private func showAbout() {
        // 在主线程上显示alert
        DispatchQueue.main.async { [weak self] in
            guard self != nil else { return }
            
            let alert = NSAlert()
            alert.messageText = "MacEasySymbol"
            alert.informativeText = """
            当前版本: 2.5.1
            
            作者: River
            
            轻松在macOS下实现: 中文输入时使用英文标点。
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
    
    // 添加状态诊断方法
    func diagnosesStatus() -> String {
        var status = "StatusBarManager 状态:\n"
        status += "- isInterventionEnabled: \(isInterventionEnabled)\n"
        status += "- statusItem: \(statusItem != nil ? "存在" : "不存在")\n"
        status += "- 隐藏偏好: \(isStatusItemHidden)\n"
        status += "- menu: \(statusItem?.menu != nil ? "存在" : "不存在")\n"
        status += "- button: \(statusItem?.button != nil ? "存在" : "不存在")"
        return status
    }
} 
