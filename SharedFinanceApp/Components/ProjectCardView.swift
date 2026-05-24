import SwiftUI

struct ProjectCardView: View {
    let project: Project
    let participantCount: Int
    let projectBalance: Decimal
    var isPinned: Bool = false

    private var statusBadgeTitle: String {
        switch project.status {
        case .active: return "project_status_active"
        case .archived: return "project_status_archived"
        }
    }

    private var statusBadgeIcon: String {
        switch project.status {
        case .active: return "flag.fill"
        case .archived: return "archivebox.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(project.title)
                    .font(.headline)
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(.top, 2)
                }
                Spacer()
                Label {
                    Text(LocalizedStringKey(statusBadgeTitle))
                } icon: {
                    Image(systemName: statusBadgeIcon)
                }
                .font(.caption2)
                .foregroundStyle(project.status == .active ? .green : .secondary)
            }
            Text(project.details)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                    Text("project_participants_count")
                    Text("- \(participantCount)")
                }
                .lineLimit(1)
                .layoutPriority(1)

                Spacer(minLength: 8)

                Text(projectBalance.currencyString)
                    .fontWeight(.medium)
                    .foregroundStyle(projectBalance >= 0 ? .green : .red)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .font(.caption)
        }
        .padding(12)
    }
}
