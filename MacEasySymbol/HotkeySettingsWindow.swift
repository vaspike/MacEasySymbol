import Cocoa
import Carbon

protocol HotkeySettingsDelegate: AnyObject {
    func hotkeySettingsDidSave(keyCode: UInt32, modifiers: UInt32, isEnabled: Bool)
    func hotkeySettingsDidCancel()
}

class HotkeySettingsWindow: NSWindowController {
    
    weak var delegate: HotkeySettingsDelegate?
    
    private var modifierPopup: NSPopUpButton!
    private var keyPopup: NSPopUpButton!
    private var previewLabel: NSTextField!
    private var enableCheckbox: NSButton!
    private var bracketKeysCheckbox: NSButton!
    private var saveButton: NSButton!
    private var cancelButton: NSButton!
    
    private var selectedModifiers: UInt32 = UInt32(cmdKey | optionKey)
    private var selectedKeyCode: UInt32 = 1 // S键
    private var isHotkeyEnabled: Bool = false  // 默认禁用快捷键
    private var skipBracketKeys: Bool = false  // 默认不跳过方括号键
    
    // MARK: - Init
    
    convenience init() {
        // 创建窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        self.init(window: window)
        setupWindow()
        loadSavedSettings()
        setupUI()
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        updatePreview()
    }
    
    // MARK: - Setup
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "MacEasySymbol - 偏好设置"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        
        // 设置窗口委托以处理关闭事件
        window.delegate = self
    }
    
    private func loadSavedSettings() {
        // 加载方括号键配置
        skipBracketKeys = UserDefaults.standard.bool(forKey: "SkipBracketKeys")
        DebugLogger.log("📖 已加载方括号键配置: \(skipBracketKeys ? "跳过" : "处理")")
    }
    
    private func setupUI() {
        guard let window = window, let contentView = window.contentView else { return }
        
        // 创建主容器
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加各个部分到堆栈视图
        stackView.addArrangedSubview(createHeaderSection())
        stackView.addArrangedSubview(createSeparator())
        stackView.addArrangedSubview(createHotkeySection())
        stackView.addArrangedSubview(createSeparator())
        stackView.addArrangedSubview(createCompatibilitySection())
        stackView.addArrangedSubview(createSeparator())
        stackView.addArrangedSubview(createButtonSection())
        
        contentView.addSubview(stackView)
        
        // 设置约束
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - UI创建方法
    
    private func createHeaderSection() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // 应用图标（可选）
        let titleLabel = NSTextField(labelWithString: "MacEasySymbol 偏好设置")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.alignment = .center
        titleLabel.textColor = .labelColor
        
        let subtitleLabel = NSTextField(labelWithString: "自定义应用行为和快捷键")
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.systemFont(ofSize: 13)
        subtitleLabel.alignment = .center
        subtitleLabel.textColor = .secondaryLabelColor
        
        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10)
        ])
        
        return container
    }
    
    private func createSeparator() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let separator = NSBox()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator
        
        container.addSubview(separator)
        
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            container.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        return container
    }
    
    private func createHotkeySection() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // 节标题
        let titleLabel = NSTextField(labelWithString: "全局快捷键")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .labelColor
        
        // 说明文字
        let descLabel = NSTextField(labelWithString: "设置一个全局快捷键来快速切换介入模式")
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.font = NSFont.systemFont(ofSize: 12)
        descLabel.textColor = .secondaryLabelColor
        
        // 启用开关
        enableCheckbox = NSButton(checkboxWithTitle: "启用全局快捷键", target: self, action: #selector(enableCheckboxChanged))
        enableCheckbox.translatesAutoresizingMaskIntoConstraints = false
        enableCheckbox.state = isHotkeyEnabled ? .on : .off
        
        // 快捷键配置容器
        let configContainer = createHotkeyConfigContainer()
        
        // 预览
        let previewContainer = createPreviewSection()
        
        container.addSubview(titleLabel)
        container.addSubview(descLabel)
        container.addSubview(enableCheckbox)
        container.addSubview(configContainer)
        container.addSubview(previewContainer)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 15),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            enableCheckbox.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 12),
            enableCheckbox.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            enableCheckbox.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            configContainer.topAnchor.constraint(equalTo: enableCheckbox.bottomAnchor, constant: 12),
            configContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            configContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            previewContainer.topAnchor.constraint(equalTo: configContainer.bottomAnchor, constant: 12),
            previewContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            previewContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            previewContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -15)
        ])
        
        return container
    }
    
    private func createHotkeyConfigContainer() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // 修饰键选择
        let modifierContainer = createModifierSelector()
        
        // 按键选择
        let keyContainer = createKeySelector()
        
        container.addSubview(modifierContainer)
        container.addSubview(keyContainer)
        
        NSLayoutConstraint.activate([
            modifierContainer.topAnchor.constraint(equalTo: container.topAnchor),
            modifierContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            modifierContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            keyContainer.topAnchor.constraint(equalTo: modifierContainer.bottomAnchor, constant: 8),
            keyContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            keyContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            keyContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createCompatibilitySection() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // 节标题
        let titleLabel = NSTextField(labelWithString: "输入法兼容性")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .labelColor
        
        // 说明文字
        let descLabel = NSTextField(labelWithString: "为不同的输入法使用习惯提供兼容性选项")
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.font = NSFont.systemFont(ofSize: 12)
        descLabel.textColor = .secondaryLabelColor
        
        // 方括号键配置
        let bracketContainer = createBracketKeysSection()
        
        container.addSubview(titleLabel)
        container.addSubview(descLabel)
        container.addSubview(bracketContainer)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 15),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            bracketContainer.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 12),
            bracketContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bracketContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bracketContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -15)
        ])
        
        return container
    }
    
    private func createModifierSelector() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let label = NSTextField(labelWithString: "修饰键:")
        label.translatesAutoresizingMaskIntoConstraints = false
        
        modifierPopup = NSPopUpButton()
        modifierPopup.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加修饰键选项
        let modifiers = GlobalHotkeyManager.getAvailableModifiers()
        for modifier in modifiers {
            modifierPopup.addItem(withTitle: modifier.name)
            modifierPopup.lastItem?.representedObject = modifier.value
        }
        
        // 设置默认选择
        modifierPopup.selectItem(at: 5) // 默认选择 Cmd+Option
        modifierPopup.target = self
        modifierPopup.action = #selector(modifierChanged)
        
        container.addSubview(label)
        container.addSubview(modifierPopup)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 80),
            
            modifierPopup.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10),
            modifierPopup.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            modifierPopup.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            container.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        return container
    }
    
    private func createKeySelector() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let label = NSTextField(labelWithString: "按键:")
        label.translatesAutoresizingMaskIntoConstraints = false
        
        keyPopup = NSPopUpButton()
        keyPopup.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加按键选项
        let keys = GlobalHotkeyManager.getCommonKeyCodes()
        for key in keys {
            keyPopup.addItem(withTitle: key.name)
            keyPopup.lastItem?.representedObject = key.code
        }
        
        // 设置默认选择 S
        if let sIndex = keys.firstIndex(where: { $0.code == 1 }) {
            keyPopup.selectItem(at: sIndex)
        }
        
        keyPopup.target = self
        keyPopup.action = #selector(keyChanged)
        
        container.addSubview(label)
        container.addSubview(keyPopup)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 80),
            
            keyPopup.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10),
            keyPopup.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            keyPopup.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            container.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        return container
    }
    

    
    private func createBracketKeysSection() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // 复选框
        bracketKeysCheckbox = NSButton(checkboxWithTitle: "不拦截 [ 和 ] 键，让输入法处理候选框翻页", target: self, action: #selector(bracketKeysCheckboxChanged))
        bracketKeysCheckbox.translatesAutoresizingMaskIntoConstraints = false
        bracketKeysCheckbox.state = skipBracketKeys ? .on : .off
        
        // 说明文字
        let descLabel = NSTextField(labelWithString: "适用于使用方括号键进行输入法翻页的用户")
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.font = NSFont.systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        
        // 提示文字
        let hintLabel = NSTextField(labelWithString: "⚠️ 启用前请在系统设置中开启「使用半角符号标点」，防止输入【】")
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = .systemOrange
        hintLabel.lineBreakMode = .byWordWrapping
        hintLabel.maximumNumberOfLines = 2
        
        container.addSubview(bracketKeysCheckbox)
        container.addSubview(descLabel)
        container.addSubview(hintLabel)
        
        NSLayoutConstraint.activate([
            bracketKeysCheckbox.topAnchor.constraint(equalTo: container.topAnchor),
            bracketKeysCheckbox.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bracketKeysCheckbox.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            descLabel.topAnchor.constraint(equalTo: bracketKeysCheckbox.bottomAnchor, constant: 4),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            hintLabel.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 4),
            hintLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            hintLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hintLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createPreviewSection() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let label = NSTextField(labelWithString: "预览:")
        label.translatesAutoresizingMaskIntoConstraints = false
        
        previewLabel = NSTextField()
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.isEditable = false
        previewLabel.isBordered = true
        previewLabel.backgroundColor = NSColor.controlBackgroundColor
        previewLabel.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        previewLabel.alignment = .center
        
        container.addSubview(label)
        container.addSubview(previewLabel)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 80),
            
            previewLabel.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10),
            previewLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            previewLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            previewLabel.heightAnchor.constraint(equalToConstant: 30),
            
            container.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        return container
    }
    
    private func createButtonSection() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let buttonStackView = NSStackView()
        buttonStackView.orientation = .horizontal
        buttonStackView.spacing = 12
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        
        cancelButton = NSButton(title: "取消", target: self, action: #selector(cancelClicked))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}" // ESC键
        
        saveButton = NSButton(title: "保存", target: self, action: #selector(saveClicked))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r" // Enter键
        
        buttonStackView.addArrangedSubview(cancelButton)
        buttonStackView.addArrangedSubview(saveButton)
        
        container.addSubview(buttonStackView)
        
        NSLayoutConstraint.activate([
            buttonStackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            buttonStackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 15),
            
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            saveButton.widthAnchor.constraint(equalToConstant: 80),
            
            container.heightAnchor.constraint(equalToConstant: 55)
        ])
        
        return container
    }
    
    // MARK: - Actions
    
    @objc private func modifierChanged() {
        guard let selectedItem = modifierPopup.selectedItem,
              let modifierValue = selectedItem.representedObject as? UInt32 else { return }
        
        selectedModifiers = modifierValue
        updatePreview()
    }
    
    @objc private func keyChanged() {
        guard let selectedItem = keyPopup.selectedItem,
              let keyValue = selectedItem.representedObject as? UInt32 else { return }
        
        selectedKeyCode = keyValue
        updatePreview()
    }
    
    @objc private func enableCheckboxChanged() {
        isHotkeyEnabled = enableCheckbox.state == .on
        updateUI()
    }
    
    @objc private func bracketKeysCheckboxChanged() {
        skipBracketKeys = bracketKeysCheckbox.state == .on
        // 保存配置到 UserDefaults
        UserDefaults.standard.set(skipBracketKeys, forKey: "SkipBracketKeys")
        DebugLogger.log("💾 方括号键配置已保存: \(skipBracketKeys ? "跳过" : "处理")")
    }
    
    @objc private func saveClicked() {
        delegate?.hotkeySettingsDidSave(keyCode: selectedKeyCode, modifiers: selectedModifiers, isEnabled: isHotkeyEnabled)
        close()
    }
    
    @objc private func cancelClicked() {
        delegate?.hotkeySettingsDidCancel()
        close()
    }
    
    // MARK: - Helper Methods
    
    private func updateUI() {
        // 根据启用状态控制UI元素的可用性
        modifierPopup.isEnabled = isHotkeyEnabled
        keyPopup.isEnabled = isHotkeyEnabled
        previewLabel.isEnabled = isHotkeyEnabled
        
        // 更新预览
        updatePreview()
    }
    
    private func updatePreview() {
        let keyString = keyCodeToString(selectedKeyCode)
        let modifierString = modifiersToString(selectedModifiers)
        previewLabel.stringValue = "\(modifierString)\(keyString)"
    }
    
    private func keyCodeToString(_ keyCode: UInt32) -> String {
        let keys = GlobalHotkeyManager.getCommonKeyCodes()
        return keys.first { $0.code == keyCode }?.name ?? "Key\(keyCode)"
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
    
    // 设置当前快捷键（用于编辑现有快捷键）
    func setCurrentHotkey(keyCode: UInt32, modifiers: UInt32, isEnabled: Bool = true) {
        selectedKeyCode = keyCode
        selectedModifiers = modifiers
        isHotkeyEnabled = isEnabled
        
        // 更新UI选择
        let modifiersList = GlobalHotkeyManager.getAvailableModifiers()
        if let modifierIndex = modifiersList.firstIndex(where: { $0.value == modifiers }) {
            modifierPopup.selectItem(at: modifierIndex)
        }
        
        let keysList = GlobalHotkeyManager.getCommonKeyCodes()
        if let keyIndex = keysList.firstIndex(where: { $0.code == keyCode }) {
            keyPopup.selectItem(at: keyIndex)
        }
        
        // 更新复选框状态
        enableCheckbox.state = isHotkeyEnabled ? .on : .off
        bracketKeysCheckbox.state = skipBracketKeys ? .on : .off
        
        updateUI()
    }
}

// MARK: - NSWindowDelegate

extension HotkeySettingsWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        delegate?.hotkeySettingsDidCancel()
    }
} 