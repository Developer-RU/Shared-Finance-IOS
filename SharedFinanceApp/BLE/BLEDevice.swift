import Foundation

struct BLEDevice: Identifiable, Hashable {
    let id: UUID
    let name: String
    let signalStrength: Int

    init(id: UUID = UUID(), name: String, signalStrength: Int) {
        self.id = id
        self.name = name
        self.signalStrength = signalStrength
    }
}
