import Foundation
import Combine

enum ParticipantSortOption: String, CaseIterable, Identifiable {
    case nameAscending
    case nameDescending
    case contributionDescending
    case contributionAscending
    case balanceDescending
    case balanceAscending

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .nameAscending: return "Name A-Z"
        case .nameDescending: return "Name Z-A"
        case .contributionDescending: return "Contribution high to low"
        case .contributionAscending: return "Contribution low to high"
        case .balanceDescending: return "Balance high to low"
        case .balanceAscending: return "Balance low to high"
        }
    }
}

enum ParticipantBalanceFilter: String, CaseIterable, Identifiable {
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
final class ParticipantsViewModel: ObservableObject {
    private static let pageSize = 30

    @Published var participants: [Participant] = []
    @Published var searchText = ""
    @Published var selectedSort: ParticipantSortOption = .balanceDescending
    @Published var selectedBalanceFilter: ParticipantBalanceFilter = .all
    @Published private(set) var visibleParticipantsLimit = pageSize

    private let repository: SharedFinanceRepository
    private let errorLogger: ErrorLogger
    private var balancesByParticipantID: [UUID: Decimal] = [:]
    private var expensesByParticipantID: [UUID: Decimal] = [:]
    private var expenseCountsByParticipantID: [UUID: Int] = [:]
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
        participants = repository.fetchParticipants(projectID: projectID)
        let expenses = repository.fetchExpenses(projectID: projectID)
        let groupedExpenses = Dictionary(grouping: expenses, by: { $0.participantID })
        expenseCountsByParticipantID = groupedExpenses.mapValues(\.count)
        expensesByParticipantID = groupedExpenses.mapValues { participantExpenses in
            participantExpenses.reduce(Decimal.zero) { $0 + $1.amount }
        }
        balancesByParticipantID = Dictionary(uniqueKeysWithValues: participants.map { participant in
            let expenseSum = expensesByParticipantID[participant.id] ?? .zero
            return (participant.id, participant.contributionAmount - expenseSum)
        })
        visibleParticipantsLimit = Self.pageSize
    }

    var filteredParticipants: [Participant] {
        var result = participants

        if !searchText.isEmpty {
            result = result.filter { participant in
                participant.name.localizedCaseInsensitiveContains(searchText)
                || participant.contributionAmount.currencyString.localizedCaseInsensitiveContains(searchText)
                || balance(for: participant).currencyString.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch selectedBalanceFilter {
        case .all:
            break
        case .positive:
            result = result.filter { balance(for: $0) > 0 }
        case .zero:
            result = result.filter { balance(for: $0) == 0 }
        case .negative:
            result = result.filter { balance(for: $0) < 0 }
        }

        switch selectedSort {
        case .nameAscending:
            result.sort {
                if $0.name == $1.name { return balance(for: $0) > balance(for: $1) }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .nameDescending:
            result.sort {
                if $0.name == $1.name { return balance(for: $0) > balance(for: $1) }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending
            }
        case .contributionDescending:
            result.sort { $0.contributionAmount > $1.contributionAmount }
        case .contributionAscending:
            result.sort { $0.contributionAmount < $1.contributionAmount }
        case .balanceDescending:
            result.sort { balance(for: $0) > balance(for: $1) }
        case .balanceAscending:
            result.sort { balance(for: $0) < balance(for: $1) }
        }

        return result
    }

    var visibleFilteredParticipants: [Participant] {
        Array(filteredParticipants.prefix(visibleParticipantsLimit))
    }

    func loadMoreParticipantsIfNeeded(currentItem: Participant) {
        guard let lastVisible = visibleFilteredParticipants.last, lastVisible.id == currentItem.id else {
            return
        }
        visibleParticipantsLimit = min(visibleParticipantsLimit + Self.pageSize, filteredParticipants.count)
    }

    func balance(for participant: Participant) -> Decimal {
        balancesByParticipantID[participant.id] ?? participant.balanceAmount
    }

    func participantBalance(for participant: Participant) -> ParticipantBalance {
        let expense = expensesByParticipantID[participant.id] ?? .zero
        return ParticipantBalance(
            id: participant.id,
            name: participant.name,
            contribution: participant.contributionAmount,
            expense: expense,
            balance: balance(for: participant)
        )
    }

    func participantHasExpenses(_ participant: Participant) -> Bool {
        (expenseCountsByParticipantID[participant.id] ?? 0) > 0
    }

    func add(name: String, contribution: Decimal, projectID: UUID) {
        let participant = Participant(name: name, contributionAmount: contribution)
        repository.upsertParticipant(participant, projectID: projectID)
        repository.appendHistory(ChangeHistoryEntry(operationType: .create, actorName: "Local User", description: "Added participant: \(name)", recordVersion: participant.recordVersion))
        load(projectID: projectID)
    }

    func update(participant: Participant, projectID: UUID) {
        var updated = participant
        updated.recordVersion += 1
        updated.updatedAt = .now
        repository.upsertParticipant(updated, projectID: projectID)
        repository.appendHistory(ChangeHistoryEntry(operationType: .update, actorName: "Local User", description: "Updated participant: \(updated.name)", recordVersion: updated.recordVersion))
        load(projectID: projectID)
    }

    func delete(participant: Participant, projectID: UUID) {
        let deleted = repository.deleteParticipant(participant, projectID: projectID)
        guard deleted else {
            errorLogger.log("Unable to delete participant: \(participant.name)")
            return
        }

        repository.appendHistory(ChangeHistoryEntry(operationType: .delete, actorName: "Local User", description: "Deleted participant: \(participant.name)", recordVersion: participant.recordVersion + 1))
        load(projectID: projectID)
    }

    private func setupPaginationResetSubscriptions() {
        Publishers.CombineLatest3(
            $searchText.removeDuplicates(),
            $selectedSort.removeDuplicates(),
            $selectedBalanceFilter.removeDuplicates()
        )
        .dropFirst()
        .sink { [weak self] _, _, _ in
            self?.visibleParticipantsLimit = Self.pageSize
        }
        .store(in: &cancellables)
    }
}
