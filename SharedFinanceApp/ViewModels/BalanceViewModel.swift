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
    @Published var balances: [ParticipantBalance] = []
    @Published var searchText = ""
    @Published var selectedSort: BalanceSortOption = .balanceDescending
    @Published var selectedFilter: BalanceFilterOption = .all

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
    }

    func load(projectID: UUID?) {
        currentProjectID = projectID
        let participants = repository.fetchParticipants(projectID: projectID)
        let expenses = repository.fetchExpenses(projectID: projectID)
        balances = BalanceCalculator.calculate(participants: participants, expenses: expenses)
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
}
