import Foundation

struct Project: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var details: String
    var createdAt: Date
    var participantIDs: [UUID]
    var expenseIDs: [UUID]
    var status: ProjectStatus
    var recordVersion: Int
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        details: String,
        createdAt: Date = .now,
        participantIDs: [UUID] = [],
        expenseIDs: [UUID] = [],
        status: ProjectStatus = .active,
        recordVersion: Int = 1,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.createdAt = createdAt
        self.participantIDs = participantIDs
        self.expenseIDs = expenseIDs
        self.status = status
        self.recordVersion = recordVersion
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case details
        case createdAt
        case participantIDs = "participantIds"
        case expenseIDs = "expenseIds"
        case status
        case recordVersion
        case updatedAt
    }
}

enum ProjectStatus: String, Codable, CaseIterable {
    case active
    case archived

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).lowercased()
        switch rawValue {
        case "active":
            self = .active
        case "archived":
            self = .archived
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported project status: \(rawValue)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .active:
            try container.encode("ACTIVE")
        case .archived:
            try container.encode("ARCHIVED")
        }
    }

    var localizedKey: String {
        switch self {
        case .active: return "project_status_active"
        case .archived: return "project_status_archived"
        }
    }
}
