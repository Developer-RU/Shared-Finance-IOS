import Foundation

struct Expense: Identifiable, Codable, Hashable {
    var id: UUID
    var projectID: UUID
    var participantID: UUID
    var amount: Decimal
    var categoryID: UUID
    var title: String
    var comment: String
    var date: Date
    var recordVersion: Int
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        projectID: UUID,
        participantID: UUID,
        amount: Decimal,
        categoryID: UUID,
        title: String,
        comment: String = "",
        date: Date = .now,
        recordVersion: Int = 1,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.projectID = projectID
        self.participantID = participantID
        self.amount = amount
        self.categoryID = categoryID
        self.title = title
        self.comment = comment
        self.date = date
        self.recordVersion = recordVersion
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case projectID = "projectId"
        case participantID = "participantId"
        case amount
        case categoryID = "categoryId"
        case title
        case comment
        case date
        case recordVersion
        case updatedAt
    }
}
