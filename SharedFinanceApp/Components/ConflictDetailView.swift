import SwiftUI

struct ConflictDetailView: View {
    let conflict: SyncConflict
    let decisionText: String

    var body: some View {
        NavigationStack {
            Form {
                Section("Conflict") {
                    Text(conflict.entityName)
                    Text(conflict.entityID.uuidString)
                        .font(.caption)
                }
                Section("Local Version") {
                    Text(conflict.localValue)
                }
                Section("Remote Version") {
                    Text(conflict.remoteValue)
                }
                Section("Decision") {
                    Text(decisionText)
                }
            }
            .navigationTitle("Details")
        }
    }
}
