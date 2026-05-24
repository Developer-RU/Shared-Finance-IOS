import Foundation
import Combine

enum ExpenseSortOption: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case amountDescending
    case amountAscending
    case participantName
    case title

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        case .amountDescending: return "Amount high to low"
        case .amountAscending: return "Amount low to high"
        case .participantName: return "Participant"
        case .title: return "Title"
        }
    }
}

@MainActor
final class ExpensesViewModel: ObservableObject {
    private static let pageSize = 30

    @Published var expenses: [Expense] = []
    @Published var availableParticipants: [Participant] = []
    @Published var validationMessage = ""
    @Published var searchText = ""
    @Published var selectedSort: ExpenseSortOption = .newest
    @Published var selectedParticipantFilterID: UUID? = nil
    @Published private(set) var visibleExpensesLimit = pageSize

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
        expenses = repository.fetchExpenses(projectID: projectID).sorted { $0.date > $1.date }
        availableParticipants = repository.fetchParticipants(projectID: projectID)
        if let selectedParticipantFilterID = selectedParticipantFilterID,
           !availableParticipants.contains(where: { $0.id == selectedParticipantFilterID }) {
            self.selectedParticipantFilterID = nil
        }
        visibleExpensesLimit = Self.pageSize
    }

    var filteredExpenses: [Expense] {
        let participantByID = Dictionary(uniqueKeysWithValues: availableParticipants.map { ($0.id, $0) })

        var result = expenses

        if let selectedParticipantFilterID {
            result = result.filter { $0.participantID == selectedParticipantFilterID }
        }

        if !searchText.isEmpty {
            result = result.filter { expense in
                expense.title.localizedCaseInsensitiveContains(searchText)
                || expense.comment.localizedCaseInsensitiveContains(searchText)
                || expense.amount.currencyString.localizedCaseInsensitiveContains(searchText)
                || participantByID[expense.participantID]?.name.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        switch selectedSort {
        case .newest:
            result.sort { $0.date > $1.date }
        case .oldest:
            result.sort { $0.date < $1.date }
        case .amountDescending:
            result.sort { $0.amount > $1.amount }
        case .amountAscending:
            result.sort { $0.amount < $1.amount }
        case .participantName:
            result.sort {
                let lhsName = participantByID[$0.participantID]?.name ?? ""
                let rhsName = participantByID[$1.participantID]?.name ?? ""
                if lhsName == rhsName { return $0.date > $1.date }
                return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
            }
        case .title:
            result.sort {
                if $0.title == $1.title { return $0.date > $1.date }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
        return result
    }

    var visibleFilteredExpenses: [Expense] {
        Array(filteredExpenses.prefix(visibleExpensesLimit))
    }

    func loadMoreExpensesIfNeeded(currentItem: Expense) {
        guard let lastVisible = visibleFilteredExpenses.last, lastVisible.id == currentItem.id else {
            return
        }
        visibleExpensesLimit = min(visibleExpensesLimit + Self.pageSize, filteredExpenses.count)
    }

    func add(projectID: UUID, participantID: UUID, categoryID: UUID, title: String, amount: Decimal, comment: String) {
        guard amount > 0 else {
            validationMessage = "expense_validation_amount_positive"
            return
        }
        guard repository.fetchProject(id: projectID) != nil else {
            validationMessage = "expense_validation_project_not_found"
            return
        }
        guard let participant = repository.fetchParticipant(id: participantID) else {
            validationMessage = "expense_validation_participant_not_found"
            return
        }
        guard availableParticipants.contains(where: { $0.id == participant.id }) else {
            validationMessage = "expense_validation_participant_not_in_project"
            return
        }

        let expense = Expense(projectID: projectID, participantID: participantID, amount: amount, categoryID: categoryID, title: title, comment: comment)
        repository.upsertExpense(expense)
        repository.appendHistory(ChangeHistoryEntry(operationType: .create, actorName: "Local User", description: "Added expense: \(title)", recordVersion: expense.recordVersion))
        validationMessage = ""
        load(projectID: projectID)
    }

    @discardableResult
    func update(expense: Expense) -> Bool {
        guard expense.amount > 0 else {
            validationMessage = "expense_validation_amount_positive"
            return false
        }
        guard repository.fetchProject(id: expense.projectID) != nil else {
            validationMessage = "expense_validation_project_not_found"
            return false
        }
        guard let participant = repository.fetchParticipant(id: expense.participantID) else {
            validationMessage = "expense_validation_participant_not_found"
            return false
        }
        guard availableParticipants.contains(where: { $0.id == participant.id }) else {
            validationMessage = "expense_validation_participant_not_in_project"
            return false
        }

        var updated = expense
        updated.recordVersion += 1
        updated.updatedAt = .now
        repository.upsertExpense(updated)
        repository.appendHistory(ChangeHistoryEntry(operationType: .update, actorName: "Local User", description: "Updated expense: \(updated.title)", recordVersion: updated.recordVersion))
        validationMessage = ""
        load(projectID: updated.projectID)
        return true
    }

    func delete(expense: Expense) {
        repository.deleteExpense(expense)
        repository.appendHistory(ChangeHistoryEntry(operationType: .delete, actorName: "Local User", description: "Deleted expense: \(expense.title)", recordVersion: expense.recordVersion + 1))
        load(projectID: expense.projectID)
    }

    private func setupPaginationResetSubscriptions() {
        Publishers.CombineLatest3(
            $searchText.removeDuplicates(),
            $selectedSort.removeDuplicates(),
            $selectedParticipantFilterID.removeDuplicates()
        )
        .dropFirst()
        .sink { [weak self] _, _, _ in
            self?.visibleExpensesLimit = Self.pageSize
        }
        .store(in: &cancellables)
    }
}
