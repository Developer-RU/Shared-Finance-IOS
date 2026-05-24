import Foundation

struct Participant: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date
    var contributionAmount: Decimal
    var expenseAmount: Decimal
    var balanceAmount: Decimal
    var comment: String
    var recordVersion: Int
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        contributionAmount: Decimal = .zero,
        expenseAmount: Decimal = .zero,
        balanceAmount: Decimal = .zero,
        comment: String = "",
        recordVersion: Int = 1,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.contributionAmount = contributionAmount
        self.expenseAmount = expenseAmount
        self.balanceAmount = balanceAmount
        self.comment = comment
        self.recordVersion = recordVersion
        self.updatedAt = updatedAt
    }
}
