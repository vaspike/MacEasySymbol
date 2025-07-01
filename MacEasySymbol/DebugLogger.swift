import Foundation
import os.log

class DebugLogger {
    
    private static let logger = OSLog(subsystem: "com.rivermao.maceasysymbol", category: "Debug")
    private static var startTime = Date()
    private static var lastMemoryCheck = Date()
    private static let memoryCheckInterval: TimeInterval = 60.0 // 每分钟检查一次内存
    
    static func log(_ message: String, category: String = "General") {
        let timestamp = String(format: "%.2f", Date().timeIntervalSince(startTime))
        let formattedMessage = "[\(timestamp)s] \(message)"
        
        // 输出到控制台
        print(formattedMessage)
        
        // 输出到系统日志
        os_log("%{public}@", log: logger, type: .info, formattedMessage)
        
        // 定期检查内存使用
        checkMemoryUsageIfNeeded()
    }
    
    static func logError(_ message: String) {
        let timestamp = String(format: "%.2f", Date().timeIntervalSince(startTime))
        let formattedMessage = "[\(timestamp)s] ❌ ERROR: \(message)"
        
        print(formattedMessage)
        os_log("%{public}@", log: logger, type: .error, formattedMessage)
    }
    
    static func logMemoryWarning(_ message: String) {
        let timestamp = String(format: "%.2f", Date().timeIntervalSince(startTime))
        let formattedMessage = "[\(timestamp)s] ⚠️ MEMORY: \(message)"
        
        print(formattedMessage)
        os_log("%{public}@", log: logger, type: .fault, formattedMessage)
    }
    
    // 获取当前内存使用情况
    static func getCurrentMemoryUsage() -> (physical: Double, virtual: Double) {
        let task = mach_task_self_
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(task, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let physicalMemory = Double(taskInfo.resident_size) / 1024.0 / 1024.0  // MB
            let virtualMemory = Double(taskInfo.virtual_size) / 1024.0 / 1024.0   // MB
            return (physicalMemory, virtualMemory)
        }
        
        return (0, 0)
    }
    
    // 检查内存使用情况
    private static func checkMemoryUsageIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastMemoryCheck) >= memoryCheckInterval else {
            return
        }
        
        lastMemoryCheck = now
        
        let (physical, virtual) = getCurrentMemoryUsage()
        let runtime = String(format: "%.1f", now.timeIntervalSince(startTime) / 60.0)
        
        log("📊 内存使用情况 - 运行时间: \(runtime)分钟, 物理内存: \(String(format: "%.1f", physical))MB, 虚拟内存: \(String(format: "%.1f", virtual))MB")
        
        // 如果物理内存超过30MB，发出警告
        if physical > 30.0 {
            logMemoryWarning("物理内存使用过高: \(String(format: "%.1f", physical))MB，可能存在内存泄漏")
        }
    }
    
    // 手动记录内存使用情况
    static func logMemoryUsage(context: String = "") {
        let (physical, virtual) = getCurrentMemoryUsage()
        let runtime = String(format: "%.1f", Date().timeIntervalSince(startTime) / 60.0)
        let contextStr = context.isEmpty ? "" : " (\(context))"
        
        log("📊 内存检查点\(contextStr) - 运行时间: \(runtime)分钟, 物理内存: \(String(format: "%.1f", physical))MB, 虚拟内存: \(String(format: "%.1f", virtual))MB")
    }
    
    // 重置起始时间（用于测试）
    static func resetStartTime() {
        startTime = Date()
        lastMemoryCheck = Date()
        log("🔄 DebugLogger 时间重置")
    }
    
    // 生成内存使用报告
    static func generateMemoryReport() -> String {
        let (physical, virtual) = getCurrentMemoryUsage()
        let runtime = String(format: "%.1f", Date().timeIntervalSince(startTime) / 60.0)
        
        return """
        📊 MacEasySymbol 内存使用报告
        ================================
        运行时间: \(runtime) 分钟
        物理内存: \(String(format: "%.1f", physical)) MB
        虚拟内存: \(String(format: "%.1f", virtual)) MB
        
        内存状态: \(physical > 30 ? "⚠️ 需要关注" : "✅ 正常")
        
        建议操作:
        \(physical > 30 ? "• 检查是否存在内存泄漏\n• 考虑重启应用" : "• 内存使用正常，无需特殊操作")
        """
    }
} 