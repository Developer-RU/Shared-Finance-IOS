import Foundation
import Combine

enum BalanceSortOption: String, CaseIterable, Identifiable {
    case nameAscending
    case nameDescending
    case contributionDescending
    case contributionAscending
    case expenseDescending
    case expenseAscending
    case balanceDescending
    case balanceAscending

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .nameAscending: return "Name A-Z"
        case .nameDescending: return "Name Z-A"
        case .contributionDescending: return "Contribution high to low"
        case .contributionAscending: return "Contribution low to high"
        case .expenseDescending: return "Expense high to low"
        case .expenseAscending: return "Expense low to high"
        case .balanceDescending: return "Balance high to low"
        case .balanceAscending: return "Balance low to high"
        }
    }
}

enum BalanceFilterOption: String, CaseIterable, Identifiable {
    case all
    case positive
    case zero
    case negative

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .all: return "All balances"
        case .positive: return "Positive"
        case .zero: return "Zero"
        case .negative: return "Negative"
        }
    }
}

@MainActor
final class BalanceViewModel: ObservableObject {
    private static let pageSize = 30

    @Published var balances: [ParticipantBalance] = []
    @Published var searchText = ""
    @Published var selectedSort: BalanceSortOption = .balanceDescending
    @Published var selectedFilter: BalanceFilterOption = .all
    @Published private(set) var visibleBalancesLimit = pageSize

    private let repository: SharedFinanceRepository
    private let errorLogger: ErrorLogger
    private var currentProjectID: UUID?
    private var cancellables = Set<AnyCancellable>()

    init(repository: SharedFinanceRepository, errorLogger: ErrorLogger) {
        self.repository = repository
        self.errorLogger = errorLogger

        NotificationCenter.default.publisher(for: .sharedFinanceDataDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.load(projectID: self.currentProjectID)
            }
            .store(in: &cancellables)

        setupPaginationResetSubscriptions()
    }

    func load(projectID: UUID?) {
        currentProjectID = projectID
        let participants = repository.fetchParticipants(projectID: projectID)
        let expenses = repository.fetchExpenses(projectID: projectID)
        balances = BalanceCalculator.calculate(participants: participants, expenses: expenses)
        visibleBalancesLimit = Self.pageSize
    }

    var filteredBalances: [ParticipantBalance] {
        var result = balances

        if !searchText.isEmpty {
            result = result.filter { balance in
                balance.name.localizedCaseInsensitiveContains(searchText)
                    || balance.contribution.currencyString.localizedCaseInsensitiveContains(searchText)
                    || balance.expense.currencyString.localizedCaseInsensitiveContains(searchText)
                    || balance.balance.currencyString.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch selectedFilter {
        case .all:
            break
        case .positive:
            result = result.filter { $0.balance > 0 }
        case .zero:
            result = result.filter { $0.balance == 0 }
        case .negative:
            result = result.filter { $0.balance < 0 }
        }

        switch selectedSort {
        case .nameAscending:
            result.sort {
                if $0.name == $1.name { return $0.balance > $1.balance }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .nameDescending:
            result.sort {
                if $0.name == $1.name { return $0.balance > $1.balance }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending
            }
        case .contributionDescending:
            result.sort { $0.contribution > $1.contribution }
        case .contributionAscending:
            result.sort { $0.contribution < $1.contribution }
        case .expenseDescending:
            result.sort { $0.expense > $1.expense }
        case .expenseAscending:
            result.sort { $0.expense < $1.expense }
        case .balanceDescending:
            result.sort { $0.balance > $1.balance }
        case .balanceAscending:
            result.sort { $0.balance < $1.balance }
        }

        return result
    }

    var visibleFilteredBalances: [ParticipantBalance] {
        Array(filteredBalances.prefix(visibleBalancesLimit))
    }

    func loadMoreBalancesIfNeeded(currentItem: ParticipantBalance) {
        guard let lastVisible = visibleFilteredBalances.last, lastVisible.id == currentItem.id else {
            return
        }
        visibleBalancesLimit = min(visibleBalancesLimit + Self.pageSize, filteredBalances.count)
    }

    func participantHasExpenses(participantID: UUID) -> Bool {
        repository.fetchExpenses(projectID: nil).contains { $0.participantID == participantID }
    }

    func deleteParticipant(participantID: UUID) {
        guard let participant = repository.fetchParticipant(id: participantID) else {
            return
        }

        let allProjects = repository.fetchProjects()
        let linkedProjectIDs = Set(
            allProjects
                .filter { $0.participantIDs.contains(participantID) }
                .map(\.id)
        )
        let expenseProjectIDs = Set(
            repository
                .fetchExpenses(projectID: nil)
                .filter { $0.participantID == participantID }
                .map(\.projectID)
        )
        let candidateProjectIDs = linkedProjectIDs.union(expenseProjectIDs)
        let projectsToProcess = allProjects.filter { candidateProjectIDs.contains($0.id) }

        var deletedFromAtLeastOneProject = false
        if projectsToProcess.isEmpty {
            let fallbackProjectID = allProjects.first?.id ?? UUID()
            deletedFromAtLeastOneProject = repository.deleteParticipant(participant, projectID: fallbackProjectID)
        } else {
            for project in projectsToProcess {
                let deleted = repository.deleteParticipant(participant, projectID: project.id)
                deletedFromAtLeastOneProject = deletedFromAtLeastOneProject || deleted
            }
        }

        guard deletedFromAtLeastOneProject else {
            errorLogger.log("Unable to delete participant from balance: \(participant.name)")
            return
        }

        repository.appendHistory(
            ChangeHistoryEntry(
                operationType: .delete,
                actorName: "Local User",
                description: "Deleted participant from balance: \(participant.name)",
                recordVersion: participant.recordVersion + 1
            )
        )

        load(projectID: currentProjectID)
    }

    private func setupPaginationResetSubscriptions() {
        Publishers.CombineLatest3(
            $searchText.removeDuplicates(),
            $selectedSort.removeDuplicates(),
            $selectedFilter.removeDuplicates()
        )
        .dropFirst()
        .sink { [weak self] _, _, _ in
            self?.visibleBalancesLimit = Self.pageSize
        }
        .store(in: &cancellables)
    }
}
