import Cocoa

// 创建应用程序实例
let app = NSApplication.shared

// 创建并设置委托
let delegate = AppDelegate()
app.delegate = delegate

// 运行应用程序
app.run() 