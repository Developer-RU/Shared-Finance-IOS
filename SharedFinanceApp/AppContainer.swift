import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let databaseManager: DatabaseManager
    let migrationManager: MigrationManager
    let repository: SharedFinanceRepository
    let syncService: SyncService
    let backupService: BackupService
    let errorLogger: ErrorLogger
    let appState: AppState

    init(
        databaseManager: DatabaseManager,
        migrationManager: MigrationManager,
        repository: SharedFinanceRepository,
        syncService: SyncService,
        backupService: BackupService,
        errorLogger: ErrorLogger,
        appState: AppState
    ) {
        self.databaseManager = databaseManager
        self.migrationManager = migrationManager
        self.repository = repository
        self.syncService = syncService
        self.backupService = backupService
        self.errorLogger = errorLogger
        self.appState = appState
    }

    static func bootstrap() -> AppContainer {
        let errorLogger = ErrorLogger()
        let databaseManager = DatabaseManager(errorLogger: errorLogger)
        let migrationManager = MigrationManager(databaseManager: databaseManager, errorLogger: errorLogger)
        migrationManager.runMigrationsIfNeeded()
        let repository = LocalSharedFinanceRepository(databaseManager: databaseManager, errorLogger: errorLogger)
        let bleManager = BLEManager(errorLogger: errorLogger)
        let syncEngine = SyncEngine(errorLogger: errorLogger)
        let syncService = SyncService(repository: repository, bleManager: bleManager, syncEngine: syncEngine, errorLogger: errorLogger)
        let backupService = BackupService(repository: repository, errorLogger: errorLogger)
        let appState = AppState()
        DemoDataSeeder(repository: repository).seedIfNeeded()

        return AppContainer(
            databaseManager: databaseManager,
            migrationManager: migrationManager,
            repository: repository,
            syncService: syncService,
            backupService: backupService,
            errorLogger: errorLogger,
            appState: appState
        )
    }
}

private final class DemoDataSeeder {
    private let repository: SharedFinanceRepository

    init(repository: SharedFinanceRepository) {
        self.repository = repository
    }

    func seedIfNeeded() {
        guard repository.fetchProjects().isEmpty else { return }

        let now = Date()
        let day: TimeInterval = 24 * 60 * 60

        let projectTrip = Project(
            title: "Weekend Trip",
            details: "Shared costs for travel and stay",
            createdAt: now.addingTimeInterval(-9 * day),
            status: .active,
            updatedAt: now.addingTimeInterval(-1 * day)
        )
        let projectHome = Project(
            title: "Apartment",
            details: "Monthly apartment expenses",
            createdAt: now.addingTimeInterval(-18 * day),
            status: .active,
            updatedAt: now.addingTimeInterval(-2 * day)
        )

        repository.upsertProject(projectTrip)
        repository.upsertProject(projectHome)

        let alex = Participant(name: "Alex", contributionAmount: Decimal(string: "180.00") ?? 180)
        let maria = Participant(name: "Maria", contributionAmount: Decimal(string: "160.00") ?? 160)
        let john = Participant(name: "John", contributionAmount: Decimal(string: "90.00") ?? 90)
        let nina = Participant(name: "Nina", contributionAmount: Decimal(string: "220.00") ?? 220)
        let li = Participant(name: "Li", contributionAmount: Decimal(string: "140.00") ?? 140)

        repository.upsertParticipant(alex, projectID: projectTrip.id)
        repository.upsertParticipant(maria, projectID: projectTrip.id)
        repository.upsertParticipant(john, projectID: projectTrip.id)

        repository.upsertParticipant(nina, projectID: projectHome.id)
        repository.upsertParticipant(li, projectID: projectHome.id)

        let categories = Category.defaults
        let foodCategoryID = categories.indices.contains(0) ? categories[0].id : UUID()
        let transportCategoryID = categories.indices.contains(1) ? categories[1].id : UUID()
        let housingCategoryID = categories.indices.contains(2) ? categories[2].id : UUID()
        let otherCategoryID = categories.indices.contains(3) ? categories[3].id : UUID()

        let demoExpenses: [Expense] = [
            Expense(
                projectID: projectTrip.id,
                participantID: alex.id,
                amount: Decimal(string: "120.00") ?? 120,
                categoryID: transportCategoryID,
                title: "Train tickets",
                comment: "Round trip",
                date: now.addingTimeInterval(-8 * day),
                updatedAt: now.addingTimeInterval(-8 * day)
            ),
            Expense(
                projectID: projectTrip.id,
                participantID: maria.id,
                amount: Decimal(string: "98.50") ?? 98.5,
                categoryID: foodCategoryID,
                title: "Groceries",
                comment: "Snacks and breakfast",
                date: now.addingTimeInterval(-7 * day),
                updatedAt: now.addingTimeInterval(-7 * day)
            ),
            Expense(
                projectID: projectTrip.id,
                participantID: john.id,
                amount: Decimal(string: "67.00") ?? 67,
                categoryID: otherCategoryID,
                title: "Museum tickets",
                comment: "Group booking",
                date: now.addingTimeInterval(-6 * day),
                updatedAt: now.addingTimeInterval(-6 * day)
            ),
            Expense(
                projectID: projectHome.id,
                participantID: nina.id,
                amount: Decimal(string: "320.00") ?? 320,
                categoryID: housingCategoryID,
                title: "Electricity",
                comment: "Monthly bill",
                date: now.addingTimeInterval(-5 * day),
                updatedAt: now.addingTimeInterval(-5 * day)
            ),
            Expense(
                projectID: projectHome.id,
                participantID: li.id,
                amount: Decimal(string: "55.20") ?? 55.2,
                categoryID: foodCategoryID,
                title: "Cleaning supplies",
                comment: "Household",
                date: now.addingTimeInterval(-4 * day),
                updatedAt: now.addingTimeInterval(-4 * day)
            ),
            Expense(
                projectID: projectHome.id,
                participantID: nina.id,
                amount: Decimal(string: "42.00") ?? 42,
                categoryID: otherCategoryID,
                title: "Internet",
                comment: "Monthly payment",
                date: now.addingTimeInterval(-3 * day),
                updatedAt: now.addingTimeInterval(-3 * day)
            )
        ]

        demoExpenses.forEach { repository.upsertExpense($0) }

        let historyEntries: [ChangeHistoryEntry] = [
            ChangeHistoryEntry(
                operationType: .create,
                actorName: "System",
                date: now.addingTimeInterval(-9 * day),
                description: "Created project Weekend Trip",
                recordVersion: 1
            ),
            ChangeHistoryEntry(
                operationType: .create,
                actorName: "System",
                date: now.addingTimeInterval(-8 * day),
                description: "Added first expense",
                recordVersion: 1
            ),
            ChangeHistoryEntry(
                operationType: .update,
                actorName: "System",
                date: now.addingTimeInterval(-2 * day),
                description: "Updated apartment expenses",
                recordVersion: 1
            )
        ]
        historyEntries.forEach { repository.appendHistory($0) }

        let syncLog = SyncLogEntry(
            date: now.addingTimeInterval(-1 * day),
            deviceName: "Demo Device",
            result: .success,
            changedRecordsCount: demoExpenses.count
        )
        repository.appendSyncLog(syncLog)

        let conflictLog = ConflictResolutionLogEntry(
            id: UUID(),
            date: now.addingTimeInterval(-12 * 60 * 60),
            entityName: "Expense",
            entityID: demoExpenses[0].id,
            localValue: "120.00",
            remoteValue: "125.00",
            decision: .keepLocal,
            decisionSource: .manual,
            isApplied: true
        )
        repository.appendConflictResolutionLog(conflictLog)
    }
}
