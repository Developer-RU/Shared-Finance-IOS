import Foundation

final class MigrationManager {
    private let databaseManager: DatabaseManager
    private let errorLogger: ErrorLogger
    private let schemaVersion = 2

    init(databaseManager: DatabaseManager, errorLogger: ErrorLogger) {
        self.databaseManager = databaseManager
        self.errorLogger = errorLogger
    }

    func runMigrationsIfNeeded() {
        do {
            let rows = try databaseManager.query(sql: "SELECT value FROM metadata WHERE key = 'schema_version' LIMIT 1;")
            let current = Int(rows.first?["value"] ?? "0") ?? 0
            guard current < schemaVersion else { return }

            try databaseManager.performTransaction {
                if current < 2 {
                    try databaseManager.execute(sql: "DROP TABLE IF EXISTS conflict_resolution_logs;")
                }

                try databaseManager.execute(sql: "INSERT OR REPLACE INTO metadata (key, value) VALUES ('schema_version', ?);", bindings: ["\(schemaVersion)"])
            }
        } catch {
            errorLogger.log(error, context: "Migration")
        }
    }
}
