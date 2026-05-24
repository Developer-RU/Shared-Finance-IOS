import SwiftUI

struct SyncView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject var viewModel: SyncViewModel
    @State private var selectedConflict: SyncConflict?
    @State private var isProjectSelectionPresented = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                    Button {
                        viewModel.refreshProjectSelection()
                        isProjectSelectionPresented = true
                    } label: {
                        Text("sync_run_button")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(viewModel.connectedDevice == nil)

                    if !viewModel.statusMessage.isEmpty {
                        HStack {
                            Text(LocalizedStringKey(viewModel.statusMessage))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    if case .syncing = viewModel.state {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: viewModel.progress)
                                .progressViewStyle(.linear)
                            Text("\(Int(viewModel.progress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.devices) { device in
                                deviceCard(device)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if !viewModel.conflicts.isEmpty {
                        ScrollView {
                            VStack(spacing: 8) {
                                HStack {
                                    Button("sync_accept_all_remote") {
                                        viewModel.acceptAllConflicts()
                                    }
                                    .buttonStyle(.bordered)

                                    Button("sync_keep_all_local") {
                                        viewModel.keepAllLocalConflicts()
                                    }
                                    .buttonStyle(.bordered)

                                    Button("sync_auto_select") {
                                        viewModel.autoSelectByVersionRule()
                                    }
                                    .buttonStyle(.bordered)
                                }

                                Text(viewModel.conflictDecisionProgressText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                ForEach(viewModel.conflicts) { conflict in
                                    SyncConflictCardView(conflict: conflict, isUndecided: viewModel.isUndecided(conflict)) {
                                        viewModel.acceptConflict(conflict)
                                    } onReject: {
                                        viewModel.rejectConflict(conflict)
                                    }
                                    .onTapGesture {
                                        selectedConflict = conflict
                                    }
                                    Text(LocalizedStringKey(viewModel.decisionText(for: conflict)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Button("sync_apply_decisions") {
                                    Task { await viewModel.applyConflictDecisions() }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(!viewModel.allConflictsDecided)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding()
                .background(Color(.systemGroupedBackground))
            .navigationTitle("sync_title")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if isScanning {
                            viewModel.stopScan()
                        } else {
                            viewModel.startScan()
                        }
                    }
                    label: {
                        Image(systemName: isScanning ? "stop.circle.fill" : "magnifyingglass")
                    }
                    .accessibilityLabel(Text(isScanning ? "sync_stop_button" : "sync_search_button"))
                }
            }
            .sheet(item: $selectedConflict) { conflict in
                ConflictDetailView(
                    conflict: conflict,
                    decisionText: viewModel.decisionText(for: conflict)
                )
            }
            .sheet(isPresented: $isProjectSelectionPresented) {
                NavigationStack {
                    VStack(spacing: 12) {
                        Text("sync_choose_projects_message")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if viewModel.availableProjects.isEmpty {
                            Text("sync_choose_projects_empty")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        } else {
                            List(viewModel.availableProjects, id: \.id) { project in
                                let isSelected = viewModel.selectedProjectIDs.contains(project.id)
                                Button {
                                    viewModel.toggleProjectSelection(project.id)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(project.title)
                                                .font(.body)
                                                .foregroundStyle(.primary)
                                            if !project.details.isEmpty {
                                                Text(project.details)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .listStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .navigationTitle("sync_choose_projects_title")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("sync_clear_projects") {
                                viewModel.clearSelectedProjects()
                            }
                            .disabled(viewModel.availableProjects.isEmpty)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("sync_select_all_projects") {
                                viewModel.selectAllProjects()
                            }
                            .disabled(viewModel.availableProjects.isEmpty)
                        }
                        ToolbarItem(placement: .bottomBar) {
                            Button("sync_choose_projects_confirm") {
                                isProjectSelectionPresented = false
                                Task { await viewModel.syncNow() }
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .disabled(viewModel.availableProjects.isEmpty || viewModel.selectedProjectIDs.isEmpty)
                        }
                    }
                }
            }
        }
    }

    private var isScanning: Bool {
        if case .scanning = viewModel.state {
            return true
        }
        return false
    }

    @ViewBuilder
    private func deviceCard(_ device: BLEDevice) -> some View {
        let isConnected = viewModel.connectedDevice?.id == device.id

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(device.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Label {
                    Text("\(device.signalStrength)")
                } icon: {
                    Image(systemName: "dot.radiowaves.left.and.right")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Text(device.id.uuidString)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack {
                Spacer()
                Button {
                    viewModel.toggleDeviceConnection(device)
                } label: {
                    Image(systemName: isConnected ? "checkmark.circle.fill" : "link.circle.fill")
                        .font(isConnected ? .title3 : .title2)
                        .foregroundStyle(isConnected ? .green : Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(isConnected ? "sync_status_connected_to" : "sync_connect_button"))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            colorScheme == .dark
            ? Color(.secondarySystemBackground)
            : Color(.systemBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            viewModel.toggleDeviceConnection(device)
        }
    }

}
