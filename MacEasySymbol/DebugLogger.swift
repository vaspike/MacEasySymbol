import Foundation

class DebugLogger {
    static func log(_ message: String) {
        #if DEBUG
        print(message)
        #endif
    }
    
    static func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        print("[\(fileName):\(line)] \(function): \(message)")
        #endif
    }
} 