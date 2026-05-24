import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedTheme: AppTheme
    @Published var languageCode: String
    @Published var faceIDEnabled: Bool

    private let appState: AppState
    private let backupService: BackupService
    let repository: SharedFinanceRepository
    let errorLogger: ErrorLogger

    init(appState: AppState, backupService: BackupService, repository: SharedFinanceRepository, errorLogger: ErrorLogger) {
        self.appState = appState
        self.backupService = backupService
        self.repository = repository
        self.errorLogger = errorLogger
        self.selectedTheme = appState.preferredTheme
        self.languageCode = appState.languageCode
        self.faceIDEnabled = appState.isFaceIDEnabled
    }

    func applyTheme(_ theme: AppTheme) {
        appState.preferredTheme = theme
    }

    func applyLanguage(_ code: String) {
        appState.languageCode = code
    }

    func toggleFaceID(_ enabled: Bool) {
        appState.isFaceIDEnabled = enabled
        faceIDEnabled = enabled
    }

    func exportBackupData() -> Data? {
        backupService.exportBackupData()
    }

    func importBackup(url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        return backupService.importBackup(data: data)
    }
}
