# MacEasySymbol

![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/vaspike/maceasysymbol/total?style=for-the-badge)

一个为使用中文输入的用户设计的 macOS 应用，能够让你在中文输入时使用英文标点。

受 Windows 平台微软输入法提供的功能「中文输入时使用英文标点」启发

采用原生 Swift 开发，运行无延迟且资源占用极低，支持自定义快捷键快速切换符号转换功能。

**系统要求：macOS 11.5 或更高版本**

---

最新版本：2.5.1

---

## 应用概览

<img width="185" height="288" alt="image" src="https://github.com/user-attachments/assets/34206b5f-38da-4186-917d-1692a93c6e82" />

<img width="662" alt="image" src="https://github.com/user-attachments/assets/cd0ad805-6092-40b1-9a82-46f066d64f7c" />
<img width="400" height="401" alt="image" src="https://github.com/user-attachments/assets/1ad531cb-1e52-48a5-bdd8-6f3a48718528" />

<img width="700" height="632" alt="image" src="https://github.com/user-attachments/assets/a9f37c9b-1cf6-427d-9bbe-21e60677bd82" />
<img width="600" height="732" alt="image" src="https://github.com/user-attachments/assets/f69091ea-7ebc-4ca8-8480-81baece6b50b" />


---

## 功能特性

- **智能符号转换**：自动将中文符号转换为英文符号
- **自定义转换列表**：可选择性地启用/禁用特定符号的转换
- **应用白名单**：可排除特定应用，避免影响正常输入
- **全局快捷键**：支持自定义快捷键快速切换转换功能（默认 ⌘⌥S）
- **状态栏控制**：通过状态栏图标轻松控制开关
- **权限管理**：自动处理辅助功能权限申请

## 支持的符号转换

| 中文符号 | 英文符号 | 说明 |
|---------|---------|------|
| ， | , | 逗号 |
| 。 | . | 句号 |
| ； | ; | 分号 |
| ： | : | 冒号 |
| ？ | ? | 问号 |
| ！ | ! | 感叹号 |
| “” | "" | 双引号 |
| ‘’ | '' | 单引号 |
| （） | () | 括号 |
| 【】 | [] | 方括号 |
| 、 | / | 顿号→斜杠 |
| —— | _ | 长破折号→下划线 |
| · | ` | 间隔号 |
| ¥ | $ | 人民币符号 |
| …… | ^ | 省略号 |
| 《》 | <> | 尖括号 |
| ｜ | \| | 竖线 |
| ～ | ~ | 波浪号 |
| 「」 | {} | 大括号 |

## 安装方法

### 方法一：使用 Homebrew 安装

```bash
# 安装
brew tap vaspike/maceasysymbol && brew install --cask MacEasySymbol

# 更新
brew update && brew upgrade MacEasySymbol

# 卸载
brew uninstall --cask maceasysymbol
```

### 方法二：使用 DMG 安装包

1. 在 [release](https://github.com/vaspike/MacEasySymbol/releases) 下载最新的 dmg 文件
2. 双击打开 DMG 文件
3. 将 `MacEasySymbol.app` 拖拽到 `Applications` 文件夹
4. 在 Applications 文件夹中启动应用
5. 首次运行需要授予辅助功能权限

### 方法三：从源码构建

```bash
# 克隆项目
git clone https://github.com/vaspike/MacEasySymbol.git
cd MacEasySymbol

# 使用 Xcode 打开项目
open MacEasySymbol.xcodeproj

# 或者使用命令行构建
xcodebuild -project MacEasySymbol.xcodeproj -scheme MacEasySymbol -configuration Release
```

## 使用方法

1. **启动应用**：在 Applications 文件夹中启动 MacEasySymbol
2. **授予权限**：首次运行时会提示授予辅助功能权限
3. **状态栏控制**：在状态栏中可以看到应用图标
   - 闪电图标表示符号转换已启用
   - 圆圈图标表示符号转换已禁用
4. **切换模式**：点击状态栏图标或菜单项来切换模式
5. **自定义转换**：点击状态栏图标 → 符号转换设置，可选择要转换的符号
6. **应用白名单**：点击状态栏图标 → 应用白名单，可排除特定应用
7. **全局快捷键**：点击状态栏图标 → 快捷键设置，可设置快速切换的快捷键

## 权限说明

MacEasySymbol 需要以下权限才能正常工作：

- **辅助功能权限**：用于监听键盘事件，实现符号转换功能
- 权限申请会在首次启动时自动弹出
- 也可以在「系统偏好设置」>「安全性与隐私」>「辅助功能」中手动添加

## 版本历史


### v2.4.1 (2025-11-17)
- 新增自定义符号转换功能，可选择性启用/禁用特定符号
- 新增应用白名单功能，可排除特定应用
- 优化快捷键设置窗口，界面更简洁
- 移除原有的方括号不拦截功能，由新功能替代
- 改进符号转换优先级逻辑

### v2.1.2 (2025-07-06)
- 彻底简化介入模式工作原理，解决小概率发生的介入模式不生效
- 优化菜单栏UI选项，优化菜单栏UI内存管理

### v1.1.2 (2025-07-02)
- 1.1版本-第二次build
- 优化「关于」，显示准确的版本信息

### v1.1.0 (2025-07-02)
- 新增全局快捷键功能（默认 ⌘⌥S）
- 权限授予后自动重启提醒功能
- 快捷键功能默认禁用，需手动启用
- 优化内存管理

### v1.0.0 (2025-07-01)
- 初始版本发布
- 支持 20+ 种中文符号转换
- 智能键盘事件监听
- 状态栏控制界面
- 自动权限管理

## 贡献指南

欢迎提交 Issue 和 Pull Request！

## 联系方式

- GitHub: [@vaspike](https://github.com/vaspike)
- 项目地址: https://github.com/vaspike/MacEasySymbol
- 邮箱: [rivermao@foxmail.com](mailto:rivermao@foxmail.com)
