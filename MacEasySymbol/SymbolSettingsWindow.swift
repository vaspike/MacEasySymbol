//
//  SymbolSettingsWindow.swift
//  MacEasySymbol
//
//  符号转换设置窗口
//

import Cocoa

protocol SymbolSettingsDelegate: AnyObject {
    func symbolSettingsDidSave()
    func symbolSettingsDidCancel()
}

class SymbolSettingsWindow: NSWindowController {

    weak var delegate: SymbolSettingsDelegate?

    // UI 元素
    private var contentView: NSView!
    private var searchField: NSSearchField!
    private var presetPopup: NSPopUpButton!
    private var symbolScrollView: NSScrollView!
    private var symbolTableView: NSTableView!
    private var selectAllButton: NSButton!
    private var deselectAllButton: NSButton!
    private var saveButton: NSButton!
    private var cancelButton: NSButton!
    private var categoryPopup: NSPopUpButton!

    // 数据源
    private var allSymbols: [SymbolConfig] = []
    private var filteredSymbols: [SymbolConfig] = []
    private var searchText: String = ""
    private var selectedCategory: SymbolCategory?

    // 临时状态存储（用于撤销）
    private var originalStates: [String: Bool] = [:]

    override init(window: NSWindow?) {
        super.init(window: window)
        setupWindow()
        setupUI()
        loadData()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    convenience init() {
        self.init(window: nil)
    }

    // MARK: - 窗口设置

    private func setupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "符号转换设置"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 500, height: 600)

        self.window = window
    }

    deinit {
        delegate = nil
        DebugLogger.log("🧹 SymbolSettingsWindow 析构完成")
    }

    // MARK: - UI 设置

    private func setupUI() {
        guard let window = window else { return }

        contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView

        setupHeaderSection()
        setupControlSection()
        setupTableView()
        setupButtonSection()
        layoutViews()
    }

    private func setupHeaderSection() {
        // 标题标签
        let titleLabel = NSTextField(labelWithString: "自定义符号转换")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // 描述标签
        let descLabel = NSTextField(labelWithString: "选择需要自动转换为英文的中文符号")
        descLabel.font = NSFont.systemFont(ofSize: 12)
        descLabel.textColor = NSColor.secondaryLabelColor
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(descLabel)

        // 添加约束（稍后在 layoutViews 中统一处理）
    }

    private func setupControlSection() {
        // 搜索框
        searchField = NSSearchField()
        searchField.placeholderString = "搜索符号..."
        searchField.target = self
        searchField.action = #selector(searchFieldDidChange)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(searchField)

        // 预设方案下拉框
        presetPopup = NSPopUpButton()
        presetPopup.addItem(withTitle: "预设方案")
        for preset in SymbolPreset.allPresets {
            presetPopup.addItem(withTitle: preset.name)
        }
        presetPopup.target = self
        presetPopup.action = #selector(presetDidChange)
        presetPopup.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(presetPopup)

        // 分类过滤下拉框
        categoryPopup = NSPopUpButton()
        categoryPopup.addItem(withTitle: "所有分类")
        for category in SymbolCategory.allCases {
            categoryPopup.addItem(withTitle: "\(category.icon) \(category.rawValue)")
        }
        categoryPopup.target = self
        categoryPopup.action = #selector(categoryDidChange)
        categoryPopup.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(categoryPopup)

        // 全选/取消全选按钮
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        selectAllButton = NSButton(title: "全选", target: self, action: #selector(selectAllSymbols))
        deselectAllButton = NSButton(title: "取消全选", target: self, action: #selector(deselectAllSymbols))

        buttonStack.addArrangedSubview(selectAllButton)
        buttonStack.addArrangedSubview(deselectAllButton)
        contentView.addSubview(buttonStack)
    }

    private func setupTableView() {
        // 创建表格视图
        symbolTableView = NSTableView()
        symbolTableView.delegate = self
        symbolTableView.dataSource = self
        symbolTableView.allowsMultipleSelection = false
        symbolTableView.gridStyleMask = []

        // 添加列
        let checkboxColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("checkbox"))
        checkboxColumn.title = ""
        checkboxColumn.width = 30
        symbolTableView.addTableColumn(checkboxColumn)

        let symbolColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("symbol"))
        symbolColumn.title = "符号"
        symbolColumn.width = 80
        symbolTableView.addTableColumn(symbolColumn)

        let descriptionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("description"))
        descriptionColumn.title = "描述"
        descriptionColumn.width = 150
        symbolTableView.addTableColumn(descriptionColumn)

        let keyColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("key"))
        keyColumn.title = "按键"
        keyColumn.width = 80
        symbolTableView.addTableColumn(keyColumn)

        let categoryColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("category"))
        categoryColumn.title = "分类"
        categoryColumn.width = 100
        symbolTableView.addTableColumn(categoryColumn)

        // 创建滚动视图
        symbolScrollView = NSScrollView()
        symbolScrollView.documentView = symbolTableView
        symbolScrollView.hasVerticalScroller = true
        symbolScrollView.borderType = .bezelBorder
        symbolScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(symbolScrollView)
    }

    private func setupButtonSection() {
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        saveButton = NSButton(title: "保存", target: self, action: #selector(saveSettings))
        saveButton.keyEquivalent = "\r"  // 回车键触发
        saveButton.bezelStyle = .rounded

        cancelButton = NSButton(title: "取消", target: self, action: #selector(cancelSettings))
        cancelButton.keyEquivalent = "\u{1b}"  // ESC键触发
        cancelButton.bezelStyle = .rounded

        buttonStack.addArrangedSubview(cancelButton)
        buttonStack.addArrangedSubview(saveButton)

        contentView.addSubview(buttonStack)
    }

    private func layoutViews() {
        guard let contentView = contentView else { return }

        // 获取所有子视图
        let titleLabel = contentView.subviews.first { ($0 as? NSTextField)?.stringValue == "自定义符号转换" }!
        let descLabel = contentView.subviews.first { ($0 as? NSTextField)?.stringValue == "选择需要自动转换为英文的中文符号" }!

        // 标题约束
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor)
        ])

        // 控制区域约束
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 20),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            searchField.widthAnchor.constraint(equalToConstant: 200),

            presetPopup.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            presetPopup.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            presetPopup.widthAnchor.constraint(equalToConstant: 150),

            categoryPopup.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            categoryPopup.trailingAnchor.constraint(equalTo: presetPopup.leadingAnchor, constant: -20),
            categoryPopup.widthAnchor.constraint(equalToConstant: 150),

            selectAllButton.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 15),
            selectAllButton.leadingAnchor.constraint(equalTo: searchField.leadingAnchor)
        ])

        // 表格约束
        NSLayoutConstraint.activate([
            symbolScrollView.topAnchor.constraint(equalTo: selectAllButton.bottomAnchor, constant: 15),
            symbolScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            symbolScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            symbolScrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -80)
        ])

        // 按钮约束
        let buttonStack = contentView.subviews.last!
        NSLayoutConstraint.activate([
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            buttonStack.widthAnchor.constraint(equalToConstant: 200),
            buttonStack.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    // MARK: - 数据加载

    private func loadData() {
        // 获取所有符号配置
        allSymbols = SymbolConfigManager.shared.allSymbols

        // 保存原始状态（用于撤销）
        saveOriginalStates()

        // 应用过滤
        applyFilters()

        DebugLogger.log("已加载 \(allSymbols.count) 个符号配置")
    }

    private func saveOriginalStates() {
        originalStates.removeAll()
        for symbol in allSymbols {
            originalStates[symbol.defaultsKey] = symbol.isEnabled
        }
    }

    private func applyFilters() {
        filteredSymbols = allSymbols

        // 分类过滤
        if let category = selectedCategory {
            filteredSymbols = filteredSymbols.filter { $0.category == category }
        }

        // 搜索过滤
        if !searchText.isEmpty {
            filteredSymbols = filteredSymbols.filter { symbol in
                symbol.symbol.localizedCaseInsensitiveContains(searchText) ||
                symbol.description.localizedCaseInsensitiveContains(searchText) ||
                symbol.keyDisplay.localizedCaseInsensitiveContains(searchText) ||
                symbol.category.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }

        symbolTableView.reloadData()
        updateUIState()
    }

    private func updateUIState() {
        let hasSelection = filteredSymbols.contains { $0.isEnabled }
        let hasUnselection = filteredSymbols.contains { !$0.isEnabled }

        selectAllButton.isEnabled = hasUnselection
        deselectAllButton.isEnabled = hasSelection
    }

    // MARK: - 事件处理

    @objc private func searchFieldDidChange() {
        searchText = searchField.stringValue
        applyFilters()
    }

    @objc private func presetDidChange() {
        let selectedIndex = presetPopup.indexOfSelectedItem
        guard selectedIndex > 0 else { return }  // 第一个选项是"预设方案"

        let preset = SymbolPreset.allPresets[selectedIndex - 1]

        // 显示确认对话框
        let alert = NSAlert()
        alert.messageText = "应用预设方案"
        alert.informativeText = "确定要应用\"\(preset.name)\"方案吗？这将重置当前的符号选择。"
        alert.addButton(withTitle: "应用")
        alert.addButton(withTitle: "取消")

        if alert.runModal() == .alertFirstButtonReturn {
            preset.apply()
            symbolTableView.reloadData()
            updateUIState()
            DebugLogger.log("已应用预设方案: \(preset.name)")
        }

        // 重置下拉框选择
        presetPopup.selectItem(at: 0)
    }

    @objc private func categoryDidChange() {
        let selectedIndex = categoryPopup.indexOfSelectedItem
        if selectedIndex == 0 {
            selectedCategory = nil
        } else {
            selectedCategory = SymbolCategory.allCases[selectedIndex - 1]
        }
        applyFilters()
    }

    @objc private func selectAllSymbols() {
        for symbol in filteredSymbols {
            SymbolConfigManager.shared.setSymbolEnabled(symbol, enabled: true)
        }
        symbolTableView.reloadData()
        updateUIState()
    }

    @objc private func deselectAllSymbols() {
        for symbol in filteredSymbols {
            SymbolConfigManager.shared.setSymbolEnabled(symbol, enabled: false)
        }
        symbolTableView.reloadData()
        updateUIState()
    }

    @objc private func saveSettings() {
        delegate?.symbolSettingsDidSave()
        window?.close()
        DebugLogger.log("符号设置已保存")
    }

    @objc private func cancelSettings() {
        // 恢复到原始状态
        for symbol in allSymbols {
            if let originalState = originalStates[symbol.defaultsKey] {
                SymbolConfigManager.shared.setSymbolEnabled(symbol, enabled: originalState)
            }
        }

        delegate?.symbolSettingsDidCancel()
        window?.close()
        DebugLogger.log("符号设置已取消")
    }
}

// MARK: - NSTableViewDataSource

extension SymbolSettingsWindow: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredSymbols.count
    }
}

// MARK: - NSTableViewDelegate

extension SymbolSettingsWindow: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredSymbols.count else { return nil }

        let symbol = filteredSymbols[row]
        let columnIdentifier = tableColumn?.identifier.rawValue ?? ""

        switch columnIdentifier {
        case "checkbox":
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(symbolCheckboxChanged(_:)))
            checkbox.state = symbol.isEnabled ? .on : .off
            checkbox.tag = row
            return checkbox

        case "symbol":
            let textField = NSTextField(labelWithString: symbol.symbol)
            textField.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)
            textField.alignment = .center
            return textField

        case "description":
            let textField = NSTextField(labelWithString: symbol.description)
            textField.font = NSFont.systemFont(ofSize: 13)
            return textField

        case "key":
            let textField = NSTextField(labelWithString: symbol.keyDisplay)
            textField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            textField.textColor = NSColor.secondaryLabelColor
            return textField

        case "category":
            let textField = NSTextField(labelWithString: symbol.category.rawValue)
            textField.font = NSFont.systemFont(ofSize: 12)
            textField.textColor = NSColor.tertiaryLabelColor
            return textField

        default:
            return nil
        }
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 28
    }

    @objc private func symbolCheckboxChanged(_ sender: NSButton) {
        let row = sender.tag
        guard row < filteredSymbols.count else { return }

        let symbol = filteredSymbols[row]
        let newState = (sender.state == .on)
        SymbolConfigManager.shared.setSymbolEnabled(symbol, enabled: newState)

        updateUIState()
        let status = newState ? "启用" : "禁用"
        DebugLogger.log("符号 \(symbol.description) \(status)")
    }
}