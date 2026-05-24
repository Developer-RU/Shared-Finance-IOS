import SwiftUI

struct SyncConflictCardView: View {
    let conflict: SyncConflict
    let isUndecided: Bool
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(conflict.entityName) • \(conflict.entityID.uuidString.prefix(8))")
                .font(.headline)
            (Text("sync_conflict_local_label") + Text(" \(conflict.localValue)"))
                .font(.caption)
            (Text("sync_conflict_remote_label") + Text(" \(conflict.remoteValue)"))
                .font(.caption)

            HStack {
                Button("sync_conflict_keep_local", action: onReject)
                    .buttonStyle(.bordered)
                Button("sync_conflict_accept_remote", action: onAccept)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isUndecided ? Color.orange : Color.clear, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
