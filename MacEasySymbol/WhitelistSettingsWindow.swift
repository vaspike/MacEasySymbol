//
//  WhitelistSettingsWindow.swift
//  MacEasySymbol
//
//  Created by River on 2025-08-17.
//

import Cocoa

protocol WhitelistSettingsDelegate: AnyObject {
    func whitelistSettingsDidSave()
    func whitelistSettingsDidCancel()
}

class WhitelistSettingsWindow: NSWindowController {
    
    weak var delegate: WhitelistSettingsDelegate?
    
    // UI 元素
    private var contentView: NSView!
    private var searchField: NSSearchField!
    private var searchResultsScrollView: NSScrollView!
    private var searchResultsStackView: NSStackView!
    private var whitelistTableView: NSTableView!
    private var removeButton: NSButton!
    private var saveButton: NSButton!
    private var cancelButton: NSButton!
    private var loadingIndicator: NSProgressIndicator!
    private var noResultsLabel: NSTextField!
    
    // 数据源
    private var allApps: [AppInfo] = []
    private var filteredApps: [AppInfo] = []
    private var whitelistedApps: [AppInfo] = []
    private var isLoading = false
    private var currentSearchText = ""
    private var searchDebounceTimer: Timer?
    private var buttonToAppMapping: [NSButton: AppInfo] = [:]
    
    // 懒加载相关
    private var visibleCardViews: [NSView] = []
    private var loadedItemsCount = 0
    private let initialLoadCount = 5  // 初始加载数量
    private let loadMoreCount = 3     // 每次懒加载数量
    
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
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "应用白名单设置"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 600, height: 500)
        
        self.window = window
    }
    
    // MARK: - UI 设置
    
    private func setupUI() {
        guard let window = window else { return }
        
        contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView
        
        setupLoadingIndicator()
        setupSearchField()
        setupSearchResults()
        setupTableView()
        setupButtons()
        layoutViews()
    }
    
    private func setupLoadingIndicator() {
        loadingIndicator = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
        loadingIndicator.style = .spinning
        loadingIndicator.isHidden = true
        contentView.addSubview(loadingIndicator)
    }
    
    private func setupSearchField() {
        // 搜索标签
        let searchLabel = NSTextField(labelWithString: "搜索应用:")
        searchLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        contentView.addSubview(searchLabel)
        searchLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 搜索框
        searchField = NSSearchField(frame: NSRect(x: 0, y: 0, width: 300, height: 32))
        searchField.placeholderString = "输入应用名称或Bundle ID搜索..."
        searchField.target = self
        searchField.action = #selector(searchFieldChanged)
        searchField.font = NSFont.systemFont(ofSize: 14)
        contentView.addSubview(searchField)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        
        // 设置约束
        NSLayoutConstraint.activate([
            searchLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            searchLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            searchField.topAnchor.constraint(equalTo: searchLabel.bottomAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            searchField.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupSearchResults() {
        // 搜索结果容器
        searchResultsStackView = NSStackView()
        searchResultsStackView.orientation = .vertical
        searchResultsStackView.alignment = .centerX
        searchResultsStackView.distribution = .fill
        searchResultsStackView.spacing = 8
        searchResultsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // 创建滚动视图来容纳搜索结果
        searchResultsScrollView = NSScrollView()
        searchResultsScrollView.documentView = searchResultsStackView
        searchResultsScrollView.hasVerticalScroller = true
        searchResultsScrollView.hasHorizontalScroller = false
        searchResultsScrollView.autohidesScrollers = true
        searchResultsScrollView.borderType = .bezelBorder
        searchResultsScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(searchResultsScrollView)
        
        // 无结果提示标签
        noResultsLabel = NSTextField(labelWithString: "输入关键词搜索应用")
        noResultsLabel.font = NSFont.systemFont(ofSize: 14)
        noResultsLabel.textColor = NSColor.secondaryLabelColor
        noResultsLabel.alignment = .center
        noResultsLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(noResultsLabel)
        
        // 设置约束
        NSLayoutConstraint.activate([
            searchResultsScrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            searchResultsScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            searchResultsScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            searchResultsScrollView.heightAnchor.constraint(equalToConstant: 200),
            
            noResultsLabel.centerXAnchor.constraint(equalTo: searchResultsScrollView.centerXAnchor),
            noResultsLabel.centerYAnchor.constraint(equalTo: searchResultsScrollView.centerYAnchor)
        ])
        
        // 初始状态显示提示
        updateSearchResultsDisplay()
    }
    
    private func updateSearchResultsDisplay() {
        // 清空之前的搜索结果和按钮映射
        clearSearchResults()
        
        if currentSearchText.isEmpty {
            noResultsLabel.stringValue = "输入关键词搜索应用"
            noResultsLabel.isHidden = false
            return
        }
        
        if filteredApps.isEmpty {
            noResultsLabel.stringValue = "😢 未找到匹配的应用"
            noResultsLabel.isHidden = false
            return
        }
        
        noResultsLabel.isHidden = true
        loadedItemsCount = 0
        
        // 初始懒加载
        loadMoreSearchResults()
    }
    
    private func clearSearchResults() {
        // 清理按钮映射
        for subview in searchResultsStackView.arrangedSubviews {
            for button in buttonToAppMapping.keys {
                if button.superview?.isDescendant(of: subview) == true {
                    buttonToAppMapping.removeValue(forKey: button)
                }
            }
            subview.removeFromSuperview()
        }
        visibleCardViews.removeAll()
        loadedItemsCount = 0
    }
    
    private func loadMoreSearchResults() {
        let loadCount = loadedItemsCount == 0 ? initialLoadCount : loadMoreCount
        let endIndex = min(loadedItemsCount + loadCount, filteredApps.count)
        
        for i in loadedItemsCount..<endIndex {
            let app = filteredApps[i]
            let cardView = createAppCardView(for: app)
            searchResultsStackView.addArrangedSubview(cardView)
            visibleCardViews.append(cardView)
        }
        
        loadedItemsCount = endIndex
        
        // 如果还有更多结果，显示"加载更多"按钮
        if loadedItemsCount < filteredApps.count {
            addLoadMoreButton()
        }
    }
    
    private func addLoadMoreButton() {
        let loadMoreButton = NSButton()
        loadMoreButton.title = "加载更多 (\(filteredApps.count - loadedItemsCount) 个应用)"
        loadMoreButton.font = NSFont.systemFont(ofSize: 12)
        loadMoreButton.bezelStyle = .rounded
        loadMoreButton.controlSize = .small
        loadMoreButton.target = self
        loadMoreButton.action = #selector(loadMoreButtonClicked)
        loadMoreButton.translatesAutoresizingMaskIntoConstraints = false
        
        let containerView = NSView()
        containerView.addSubview(loadMoreButton)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // 居中显示按钮
        NSLayoutConstraint.activate([
            loadMoreButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            loadMoreButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 40),
            containerView.widthAnchor.constraint(equalToConstant: 640)
        ])
        
        searchResultsStackView.addArrangedSubview(containerView)
    }
    
    @objc private func loadMoreButtonClicked() {
        // 移除"加载更多"按钮
        if let lastView = searchResultsStackView.arrangedSubviews.last {
            lastView.removeFromSuperview()
        }
        
        // 加载更多结果
        loadMoreSearchResults()
    }
    
    private func createAppCardView(for app: AppInfo) -> NSView {
        let cardView = NSView()
        cardView.wantsLayer = true
        cardView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        cardView.layer?.cornerRadius = 8
        cardView.layer?.borderWidth = 0.5
        cardView.layer?.borderColor = NSColor.separatorColor.cgColor
        
        // 添加悬停效果
        let trackingArea = NSTrackingArea(
            rect: cardView.bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: cardView,
            userInfo: nil
        )
        cardView.addTrackingArea(trackingArea)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        // 应用图标
        let iconView = NSImageView()
        iconView.image = app.iconImage ?? NSImage(named: NSImage.applicationIconName)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(iconView)
        
        // 应用名称
        let nameLabel = NSTextField(labelWithString: app.name)
        nameLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        nameLabel.isEditable = false
        nameLabel.isSelectable = false
        nameLabel.isBordered = false
        nameLabel.backgroundColor = NSColor.clear
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(nameLabel)
        
        // Bundle ID
        let bundleLabel = NSTextField(labelWithString: app.bundleID)
        bundleLabel.font = NSFont.systemFont(ofSize: 11)
        bundleLabel.textColor = NSColor.secondaryLabelColor
        bundleLabel.isEditable = false
        bundleLabel.isSelectable = false
        bundleLabel.isBordered = false
        bundleLabel.backgroundColor = NSColor.clear
        bundleLabel.lineBreakMode = .byTruncatingTail
        bundleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(bundleLabel)
        
        // 添加按钮
        let isWhitelisted = whitelistedApps.contains { $0.bundleID == app.bundleID }
        let addButton = NSButton()
        addButton.title = isWhitelisted ? "已在白名单" : "+ 添加"
        addButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        addButton.bezelStyle = .rounded
        addButton.controlSize = .small
        addButton.isEnabled = !isWhitelisted
        addButton.target = self
        addButton.action = #selector(addAppToWhitelist(_:))
        buttonToAppMapping[addButton] = app
        addButton.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(addButton)
        
        // 设置约束
        NSLayoutConstraint.activate([
            cardView.heightAnchor.constraint(equalToConstant: 60),
            cardView.widthAnchor.constraint(equalToConstant: 640), // 固定宽度，稍小于滚动视图
            
            iconView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),
            
            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -12),
            
            bundleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            bundleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            bundleLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            
            addButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            addButton.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 80)
        ])
        
        return cardView
    }
    
    private func setupTableView() {
        // 白名单标签
        let whitelistLabel = NSTextField(labelWithString: "当前白名单(白名单应用内介入模式失效):")
        whitelistLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        contentView.addSubview(whitelistLabel)
        whitelistLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 创建表格视图
        whitelistTableView = NSTableView(frame: NSRect(x: 0, y: 0, width: 400, height: 250))
        whitelistTableView.delegate = self
        whitelistTableView.dataSource = self
        whitelistTableView.headerView = nil
        whitelistTableView.allowsEmptySelection = true
        whitelistTableView.allowsMultipleSelection = false
        
        // 创建列
        let appColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        appColumn.title = "应用"
        appColumn.width = 400
        whitelistTableView.addTableColumn(appColumn)
        
        // 创建滚动视图
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 250))
        scrollView.documentView = whitelistTableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        contentView.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // 移除按钮
        removeButton = NSButton(title: "移除", target: self, action: #selector(removeSelectedApp))
        removeButton.isEnabled = false
        contentView.addSubview(removeButton)
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 设置约束
        NSLayoutConstraint.activate([
            whitelistLabel.topAnchor.constraint(equalTo: searchResultsScrollView.bottomAnchor, constant: 20),
            whitelistLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            scrollView.topAnchor.constraint(equalTo: whitelistLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.heightAnchor.constraint(equalToConstant: 200),
            
            removeButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 10),
            removeButton.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    private func setupButtons() {
        // 取消按钮
        cancelButton = NSButton(title: "取消", target: self, action: #selector(cancelSettings))
        contentView.addSubview(cancelButton)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 保存按钮
        saveButton = NSButton(title: "保存&重启应用", target: self, action: #selector(saveSettings))
        saveButton.keyEquivalent = "\r" // Enter键
        contentView.addSubview(saveButton)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 设置约束
        NSLayoutConstraint.activate([
            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -10),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            saveButton.widthAnchor.constraint(equalToConstant: 120)
        ])
    }
    
    private func layoutViews() {
        // 加载指示器居中
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    // MARK: - 数据加载
    
    private func loadData() {
        showLoading(true)
        
        // 在后台线程加载应用列表
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = InstalledAppsScanner.shared.getAllInstalledApps()
            
            DispatchQueue.main.async {
                self?.allApps = apps
                self?.loadWhitelistedApps()
                self?.showLoading(false)
            }
        }
    }
    
    private func loadWhitelistedApps() {
        whitelistedApps = AppWhitelistManager.shared.getWhitelistedApps()
        whitelistTableView.reloadData()
        updateRemoveButtonState()
        
        // 更新搜索结果显示（如果有搜索结果的话）
        if !currentSearchText.isEmpty {
            updateSearchResultsDisplay()
        }
    }
    
    private func showLoading(_ show: Bool) {
        isLoading = show
        loadingIndicator.isHidden = !show
        
        if show {
            loadingIndicator.startAnimation(nil)
        } else {
            loadingIndicator.stopAnimation(nil)
        }
        
        // 禁用/启用UI元素
        searchField.isEnabled = !show
        searchResultsScrollView.isHidden = show
        if !show {
            updateRemoveButtonState()
        } else {
            removeButton.isEnabled = false
        }
    }
    
    // MARK: - 操作方法
    
    @objc private func searchFieldChanged() {
        // 取消之前的防抖定时器
        searchDebounceTimer?.invalidate()
        
        let searchText = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 设置新的防抖定时器（300ms延迟）
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.performSearch(searchText: searchText)
            }
        }
    }
    
    private func performSearch(searchText: String) {
        currentSearchText = searchText
        
        if searchText.isEmpty {
            filteredApps = []
        } else {
            filteredApps = allApps.filter { app in
                app.name.lowercased().contains(searchText.lowercased()) ||
                app.bundleID.lowercased().contains(searchText.lowercased())
            }
        }
        
        updateSearchResultsDisplay()
    }
    
    private func updateRemoveButtonState() {
        guard !isLoading else { return }
        removeButton.isEnabled = whitelistTableView.selectedRow >= 0
    }
    
    @objc private func addAppToWhitelist(_ sender: NSButton) {
        guard let appInfo = buttonToAppMapping[sender] else { return }
        
        // 检查是否已经在白名单中
        if whitelistedApps.contains(where: { $0.bundleID == appInfo.bundleID }) {
            showAlert(title: "提示", message: "该应用已在白名单中")
            return
        }
        
        // 添加到白名单
        AppWhitelistManager.shared.addToWhitelist(bundleID: appInfo.bundleID)
        loadWhitelistedApps()
        
        // 更新搜索结果显示（更新按钮状态）
        updateSearchResultsDisplay()
        
        // 显示成功反馈
        sender.title = "✓ 已添加"
        sender.isEnabled = false
        
        // 1秒后恢复按钮文字
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            sender.title = "已在白名单"
        }
    }
    
    @objc private func removeSelectedApp() {
        let selectedRow = whitelistTableView.selectedRow
        guard selectedRow >= 0 && selectedRow < whitelistedApps.count else { return }
        
        let appToRemove = whitelistedApps[selectedRow]
        
        let alert = NSAlert()
        alert.messageText = "确认移除"
        alert.informativeText = "确定要从白名单中移除 \"\(appToRemove.name)\" 吗？"
        alert.addButton(withTitle: "移除")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            AppWhitelistManager.shared.removeFromWhitelist(bundleID: appToRemove.bundleID)
            loadWhitelistedApps()
            // 更新搜索结果显示（更新按钮状态）
            updateSearchResultsDisplay()
        }
    }
    
    @objc private func saveSettings() {
        searchDebounceTimer?.invalidate()
        delegate?.whitelistSettingsDidSave()
        window?.close()
        
        // 重启应用,重启的原因一个是防止不生效(小概率), 主要原因是白名单设置界面的内存管理
        restartApplication()
    }
    
    private func restartApplication() {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [Bundle.main.bundlePath]
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            task.launch()
            NSApplication.shared.terminate(nil)
        }
    }
    
    @objc private func cancelSettings() {
        searchDebounceTimer?.invalidate()
        delegate?.whitelistSettingsDidCancel()
        window?.close()
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}

// MARK: - NSTableViewDataSource

extension WhitelistSettingsWindow: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return whitelistedApps.count
    }
}

// MARK: - NSTableViewDelegate

extension WhitelistSettingsWindow: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < whitelistedApps.count else { return nil }
        
        let app = whitelistedApps[row]
        let cellView = NSTableCellView()
        
        // 创建图标
        let iconView = NSImageView()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        if let icon = app.iconImage {
            iconView.image = icon
        } else {
            iconView.image = NSImage(named: NSImage.applicationIconName)
        }
        cellView.addSubview(iconView)
        
        // 创建文本
        let textField = NSTextField()
        textField.isEditable = false
        textField.isBordered = false
        textField.backgroundColor = NSColor.clear
        textField.stringValue = "\(app.name) (\(app.bundleID))"
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.translatesAutoresizingMaskIntoConstraints = false
        cellView.addSubview(textField)
        
        // 使用Auto Layout实现垂直居中
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8)
        ])
        
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        updateRemoveButtonState()
    }
}

