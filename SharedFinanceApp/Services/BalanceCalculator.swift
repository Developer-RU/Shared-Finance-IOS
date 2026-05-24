import Foundation

struct ParticipantBalance: Identifiable, Hashable {
    let id: UUID
    let name: String
    let contribution: Decimal
    let expense: Decimal
    let balance: Decimal
}

enum BalanceCalculator {
    static func calculate(participants: [Participant], expenses: [Expense]) -> [ParticipantBalance] {
        guard !participants.isEmpty else { return [] }

        let expensesByParticipant = Dictionary(grouping: expenses, by: { $0.participantID })
        return participants.map { participant in
            let expenseSum = expensesByParticipant[participant.id, default: []].reduce(Decimal.zero) { $0 + $1.amount }
            let contribution = participant.contributionAmount
            return ParticipantBalance(
                id: participant.id,
                name: participant.name,
                contribution: contribution,
                expense: expenseSum,
                balance: contribution - expenseSum
            )
        }
    }
}
