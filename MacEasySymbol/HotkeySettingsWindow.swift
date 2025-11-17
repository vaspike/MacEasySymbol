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
    private var saveButton: NSButton!
    private var cancelButton: NSButton!
    
    private var selectedModifiers: UInt32 = UInt32(cmdKey | optionKey)
    private var selectedKeyCode: UInt32 = 1 // S键
    private var isHotkeyEnabled: Bool = false  // 默认禁用快捷键
    
    // MARK: - Init
    
    convenience init() {
        // 创建窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        self.init(window: window)
        setupWindow()
        loadSavedSettings()
        setupUI()
    }
    
    deinit {
        cleanupAllReferences()
        DebugLogger.log("🧹 HotkeySettingsWindow 析构完成")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        updatePreview()
    }
    
    // MARK: - Setup
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "快捷键设置"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        
        // 设置窗口委托以处理关闭事件
        window.delegate = self
    }
    
    private func loadSavedSettings() {
        DebugLogger.log("📖 快捷键设置窗口已加载")
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

        // 节标题
        let titleLabel = NSTextField(labelWithString: "全局快捷键配置")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.alignment = .center
        titleLabel.textColor = .labelColor

        let subtitleLabel = NSTextField(labelWithString: "设置全局快捷键来切换符号转换功能")
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.alignment = .center
        subtitleLabel.textColor = .secondaryLabelColor

        container.addSubview(titleLabel)
        container.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
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

        // 启用开关
        enableCheckbox = NSButton(checkboxWithTitle: "启用全局快捷键", target: self, action: #selector(enableCheckboxChanged))
        enableCheckbox.translatesAutoresizingMaskIntoConstraints = false
        enableCheckbox.state = isHotkeyEnabled ? .on : .off

        // 快捷键配置容器
        let configContainer = createHotkeyConfigContainer()

        // 预览
        let previewContainer = createPreviewSection()

        container.addSubview(enableCheckbox)
        container.addSubview(configContainer)
        container.addSubview(previewContainer)

        NSLayoutConstraint.activate([
            enableCheckbox.topAnchor.constraint(equalTo: container.topAnchor, constant: 15),
            enableCheckbox.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            enableCheckbox.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            configContainer.topAnchor.constraint(equalTo: enableCheckbox.bottomAnchor, constant: 15),
            configContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            configContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            previewContainer.topAnchor.constraint(equalTo: configContainer.bottomAnchor, constant: 15),
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
    

    
    
    private func createPreviewSection() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let label = NSTextField(labelWithString: "预览:")
        label.translatesAutoresizingMaskIntoConstraints = false
        
        previewLabel = NSTextField()
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.isEditable = false
        previewLabel.isBordered = true
        previewLabel.backgroundColor = NSColor.textBackgroundColor
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
    
    
    @objc private func saveClicked() {
        delegate?.hotkeySettingsDidSave(keyCode: selectedKeyCode, modifiers: selectedModifiers, isEnabled: isHotkeyEnabled)
        close()
    }
    
    @objc private func cancelClicked() {
        delegate?.hotkeySettingsDidCancel()
        close()
    }
    
    // MARK: - Memory Management
    
    private func cleanupAllReferences() {
        // 清理所有UI组件的target-action引用，避免循环引用
        // 这个方法只在deinit时调用，确保对象被销毁时彻底清理
        modifierPopup?.target = nil
        modifierPopup?.action = nil
        keyPopup?.target = nil
        keyPopup?.action = nil
        saveButton?.target = nil
        saveButton?.action = nil
        cancelButton?.target = nil
        cancelButton?.action = nil
        enableCheckbox?.target = nil
        enableCheckbox?.action = nil
        
        // 清理委托引用
        delegate = nil
        
        // 清理窗口委托
        window?.delegate = nil
        
        DebugLogger.log("🧹 已清理所有UI组件的target-action引用")
    }
    
    override func close() {
        // 注意：不在这里清理UI组件引用，因为窗口可能会被重复使用
        // 只清理委托关系，避免回调到已释放的对象
        delegate = nil
        super.close()
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
        
        updateUI()
    }
}

// MARK: - NSWindowDelegate

extension HotkeySettingsWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // 窗口关闭时只清理委托关系，不清理UI组件引用
        // 因为窗口设置了isReleasedWhenClosed = false，可能会被重复使用
        delegate?.hotkeySettingsDidCancel()
        delegate = nil
    }
} 