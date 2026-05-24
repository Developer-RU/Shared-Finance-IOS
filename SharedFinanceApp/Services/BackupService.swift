import Foundation

final class BackupService {
    private let repository: SharedFinanceRepository
    private let errorLogger: ErrorLogger

    init(repository: SharedFinanceRepository, errorLogger: ErrorLogger) {
        self.repository = repository
        self.errorLogger = errorLogger
    }

    func exportBackupData() -> Data? {
        do {
            return try JSONEncoder.pretty.encode(repository.exportPayload())
        } catch {
            errorLogger.log(error, context: "Backup export")
            return nil
        }
    }

    func importBackup(data: Data) -> Bool {
        do {
            let payload = try JSONDecoder.shared.decode(SyncPayload.self, from: data)
            repository.importPayload(payload)
            return true
        } catch {
            errorLogger.log(error, context: "Backup import")
            return false
        }
    }
}
