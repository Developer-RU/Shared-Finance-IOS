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
    case failed

    var id: String { rawValue }
}

@MainActor
final class HistoryViewModel: ObservableObject {
    private static let maxHistoryRecords = 500
    private static let pageSize = 50

    @Published var history: [ChangeHistoryEntry] = []
    @Published var syncLogs: [SyncLogEntry] = []
    @Published var searchText = ""
    @Published var selectedOperationFilter: HistoryOperationFilter = .all
    @Published var selectedSyncResultFilter: HistorySyncResultFilter = .all
    @Published private(set) var visibleHistoryLimit = pageSize
    @Published private(set) var visibleSyncLogsLimit = pageSize

    private let repository: SharedFinanceRepository
    private var cancellables = Set<AnyCancellable>()

    struct HistoryDayGroup: Identifiable {
        let date: Date
        let items: [ChangeHistoryEntry]

        var id: Date { date }
    }

    init(repository: SharedFinanceRepository, errorLogger: ErrorLogger) {
        self.repository = repository
        _ = errorLogger

        NotificationCenter.default.publisher(for: .sharedFinanceDataDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.load()
            }
            .store(in: &cancellables)

        setupPaginationResetSubscriptions()
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
        let grouped = Dictionary(grouping: visibleFilteredHistory) { calendar.startOfDay(for: $0.date) }

        return grouped.keys
            .sorted(by: >)
            .map { day in
                HistoryDayGroup(
                    date: day,
                    items: (grouped[day] ?? []).sorted { $0.date > $1.date }
                )
            }
    }

    var visibleFilteredHistory: [ChangeHistoryEntry] {
        Array(filteredHistory.prefix(visibleHistoryLimit))
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
            case .failed:
                matchesResult = item.result == .failed
            }

            return matchesSearch && matchesResult
        }
    }

    var visibleFilteredSyncLogs: [SyncLogEntry] {
        Array(filteredSyncLogs.prefix(visibleSyncLogsLimit))
    }

    func load() {
        history = Array(repository.fetchHistory().prefix(Self.maxHistoryRecords))
        syncLogs = Array(repository.fetchSyncLogs().prefix(Self.maxHistoryRecords))
        resetPagination()
    }

    func loadMoreHistoryIfNeeded(currentItem: ChangeHistoryEntry) {
        guard let lastVisible = visibleFilteredHistory.last, lastVisible.id == currentItem.id else {
            return
        }
        visibleHistoryLimit = min(visibleHistoryLimit + Self.pageSize, filteredHistory.count)
    }

    func loadMoreSyncLogsIfNeeded(currentItem: SyncLogEntry) {
        guard let lastVisible = visibleFilteredSyncLogs.last, lastVisible.id == currentItem.id else {
            return
        }
        visibleSyncLogsLimit = min(visibleSyncLogsLimit + Self.pageSize, filteredSyncLogs.count)
    }

    private func resetPagination() {
        visibleHistoryLimit = Self.pageSize
        visibleSyncLogsLimit = Self.pageSize
    }

    private func setupPaginationResetSubscriptions() {
        Publishers.CombineLatest(
            $searchText.removeDuplicates(),
            $selectedOperationFilter.removeDuplicates()
        )
        .dropFirst()
        .sink { [weak self] _, _ in
            self?.visibleHistoryLimit = Self.pageSize
        }
        .store(in: &cancellables)

        Publishers.CombineLatest(
            $searchText.removeDuplicates(),
            $selectedSyncResultFilter.removeDuplicates()
        )
        .dropFirst()
        .sink { [weak self] _, _ in
            self?.visibleSyncLogsLimit = Self.pageSize
        }
        .store(in: &cancellables)
    }
}
