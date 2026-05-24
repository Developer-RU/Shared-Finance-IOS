import Foundation
import SQLite3

final class DatabaseManager {
    private var db: OpaquePointer?
    private let errorLogger: ErrorLogger

    init(errorLogger: ErrorLogger) {
        self.errorLogger = errorLogger
        try? openDatabase()
        try? bootstrapSchema()
    }

    deinit {
        sqlite3_close(db)
    }

    func execute(sql: String, bindings: [String] = []) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepare(lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }

        for (index, value) in bindings.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), (value as NSString).utf8String, -1, nil)
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.execute(lastErrorMessage)
        }
    }

    func query(sql: String, bindings: [String] = []) throws -> [[String: String]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepare(lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }

        for (index, value) in bindings.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), (value as NSString).utf8String, -1, nil)
        }

        var rows: [[String: String]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: String] = [:]
            let count = sqlite3_column_count(statement)
            for i in 0..<count {
                let columnName = String(cString: sqlite3_column_name(statement, i))
                if let text = sqlite3_column_text(statement, i) {
                    row[columnName] = String(cString: text)
                } else {
                    row[columnName] = ""
                }
            }
            rows.append(row)
        }
        return rows
    }

    func performTransaction(_ block: () throws -> Void) throws {
        try execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
        do {
            try block()
            try execute(sql: "COMMIT;")
        } catch {
            try? execute(sql: "ROLLBACK;")
            throw error
        }
    }

    private func openDatabase() throws {
        let url = try databaseURL()
        if sqlite3_open(url.path, &db) != SQLITE_OK {
            throw SQLiteError.openDatabase(lastErrorMessage)
        }
    }

    private func bootstrapSchema() throws {
        do {
            try execute(sql: "CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);")
            try execute(sql: "CREATE TABLE IF NOT EXISTS projects (id TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at TEXT NOT NULL, version TEXT NOT NULL);")
            try execute(sql: "CREATE TABLE IF NOT EXISTS participants (id TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at TEXT NOT NULL, version TEXT NOT NULL);")
            try execute(sql: "CREATE TABLE IF NOT EXISTS expenses (id TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at TEXT NOT NULL, version TEXT NOT NULL);")
            try execute(sql: "CREATE TABLE IF NOT EXISTS history (id TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at TEXT NOT NULL, version TEXT NOT NULL);")
            try execute(sql: "CREATE TABLE IF NOT EXISTS sync_logs (id TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at TEXT NOT NULL, version TEXT NOT NULL);")
        } catch {
            errorLogger.log(error, context: "Database bootstrap")
        }
    }

    private func databaseURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return directory.appendingPathComponent("shared_finance.sqlite")
    }

    private var lastErrorMessage: String {
        if let cString = sqlite3_errmsg(db) {
            return String(cString: cString)
        }
        return "Unknown SQLite error"
    }
}
