import Foundation

enum SQLiteError: Error, LocalizedError {
    case openDatabase(String)
    case execute(String)
    case prepare(String)

    var errorDescription: String? {
        switch self {
        case .openDatabase(let message):
            return "Failed to open database: \(message)"
        case .execute(let message):
            return "Failed to execute SQL: \(message)"
        case .prepare(let message):
            return "Failed to prepare SQL: \(message)"
        }
    }
}
