import Foundation

struct Category: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var iconSystemName: String

    init(id: UUID = UUID(), title: String, iconSystemName: String) {
        self.id = id
        self.title = title
        self.iconSystemName = iconSystemName
    }

    static let defaults: [Category] = [
        Category(title: "Food", iconSystemName: "fork.knife"),
        Category(title: "Transport", iconSystemName: "car"),
        Category(title: "Housing", iconSystemName: "house"),
        Category(title: "Other", iconSystemName: "ellipsis.circle")
    ]
}
