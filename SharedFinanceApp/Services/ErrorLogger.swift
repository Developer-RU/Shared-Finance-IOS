import Foundation

final class ErrorLogger {
    func log(_ error: Error, context: String) {
        print("[Error][\(context)] \(error.localizedDescription)")
    }

    func log(_ message: String) {
        print("[Log] \(message)")
    }
}
