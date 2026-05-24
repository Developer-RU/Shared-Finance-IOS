import Foundation
import Combine

enum HistoryOperationFilter: String, CaseIterable, Identifiable {
    case all
    case create
    case update
    case delete
    case sync

    var id: String { rawValue }
}

enum HistorySyncResultFilter: String, CaseIterable, Identifiable {
    case all
    case success
    case conflict
    case failed

    var id: String { rawValue }
}

enum ConflictDecisionFilter: String, CaseIterable, Identifiable {
    case all
    case acceptRemote
    case keepLocal

    var id: String { rawValue }
    var titleKey: String {
        switch self {
        case .all: return "history_filter_all_decisions"
        case .acceptRemote: return "history_filter_accept_remote"
        case .keepLocal: return "history_filter_keep_local"
        }
    }
}

enum ConflictDateFilter: String, CaseIterable, Identifiable {
    case all
    case today
    case sevenDays
    case thirtyDays

    var id: String { rawValue }
    var titleKey: String {
        switch self {
        case .all: return "history_filter_all_dates"
        case .today: return "history_filter_today"
        case .sevenDays: return "history_filter_7_days"
        case .thirtyDays: return "history_filter_30_days"
        }
    }
}

@MainActor
final class HistoryViewModel: ObservableObject {
    private static let maxHistoryRecords = 500

    @Published var history: [ChangeHistoryEntry] = []
    @Published var syncLogs: [SyncLogEntry] = []
    @Published var conflictResolutionLogs: [ConflictResolutionLogEntry] = []
    @Published var searchText = ""
    @Published var selectedOperationFilter: HistoryOperationFilter = .all
    @Published var selectedSyncResultFilter: HistorySyncResultFilter = .all
    @Published var selectedDecisionFilter: ConflictDecisionFilter = .all
    @Published var selectedDateFilter: ConflictDateFilter = .all

    private let repository: SharedFinanceRepository
    private let errorLogger: ErrorLogger
    private var cancellables = Set<AnyCancellable>()

    struct HistoryDayGroup: Identifiable {
        let date: Date
        let items: [ChangeHistoryEntry]

        var id: Date { date }
    }

    init(repository: SharedFinanceRepository, errorLogger: ErrorLogger) {
        self.repository = repository
        self.errorLogger = errorLogger

        NotificationCenter.default.publisher(for: .sharedFinanceDataDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.load()
            }
            .store(in: &cancellables)
    }

    var filteredHistory: [ChangeHistoryEntry] {
        history.filter { item in
            let matchesSearch = searchText.isEmpty
                || item.description.localizedCaseInsensitiveContains(searchText)
                || item.actorName.localizedCaseInsensitiveContains(searchText)

            let matchesOperation: Bool
            switch selectedOperationFilter {
            case .all:
                matchesOperation = true
            case .create:
                matchesOperation = item.operationType == .create
            case .update:
                matchesOperation = item.operationType == .update
            case .delete:
                matchesOperation = item.operationType == .delete
            case .sync:
                matchesOperation = item.operationType == .sync
            }

            return matchesSearch && matchesOperation
        }
    }

    var groupedFilteredHistory: [HistoryDayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredHistory) { calendar.startOfDay(for: $0.date) }

        return grouped.keys
            .sorted(by: >)
            .map { day in
                HistoryDayGroup(
                    date: day,
                    items: (grouped[day] ?? []).sorted { $0.date > $1.date }
                )
            }
    }

    var filteredSyncLogs: [SyncLogEntry] {
        syncLogs.filter { item in
            let matchesSearch = searchText.isEmpty
                || item.deviceName.localizedCaseInsensitiveContains(searchText)
                || item.result.localizedKey.localizedCaseInsensitiveContains(searchText)

            let matchesResult: Bool
            switch selectedSyncResultFilter {
            case .all:
                matchesResult = true
            case .success:
                matchesResult = item.result == .success
            case .conflict:
                matchesResult = item.result == .conflict
            case .failed:
                matchesResult = item.result == .failed
            }

            return matchesSearch && matchesResult
        }
    }

    var filteredConflictResolutionLogs: [ConflictResolutionLogEntry] {
        let now = Date()
        return conflictResolutionLogs.filter { entry in
            let matchesEntity = searchText.isEmpty || entry.entityName.localizedCaseInsensitiveContains(searchText) || entry.localValue.localizedCaseInsensitiveContains(searchText) || entry.remoteValue.localizedCaseInsensitiveContains(searchText)
            let matchesDecision: Bool
            switch selectedDecisionFilter {
            case .all: matchesDecision = true
            case .acceptRemote: matchesDecision = entry.decision == .acceptRemote
            case .keepLocal: matchesDecision = entry.decision == .keepLocal
            }

            let matchesDate: Bool
            switch selectedDateFilter {
            case .all:
                matchesDate = true
            case .today:
                matchesDate = Calendar.current.isDateInToday(entry.date)
            case .sevenDays:
                matchesDate = entry.date >= Calendar.current.date(byAdding: .day, value: -7, to: now) ?? .distantPast
            case .thirtyDays:
                matchesDate = entry.date >= Calendar.current.date(byAdding: .day, value: -30, to: now) ?? .distantPast
            }

            return matchesEntity && matchesDecision && matchesDate
        }
    }

    func load() {
        history = Array(repository.fetchHistory().prefix(Self.maxHistoryRecords))
        syncLogs = Array(repository.fetchSyncLogs().prefix(Self.maxHistoryRecords))
        conflictResolutionLogs = Array(repository.fetchConflictResolutionLogs().prefix(Self.maxHistoryRecords))
    }

    func exportFilteredConflictLogsData() -> Data? {
        do {
            return try JSONEncoder.pretty.encode(filteredConflictResolutionLogs)
        } catch {
            errorLogger.log(error, context: "History export")
            return nil
        }
    }
}
