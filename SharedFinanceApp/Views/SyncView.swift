import SwiftUI

struct SyncView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject var viewModel: SyncViewModel
    @State private var isProjectSelectionPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
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
                    .padding(.top, 4)

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
                            HStack(alignment: .center, spacing: 8) {
                                if !viewModel.statusMessage.isEmpty {
                                    Text(LocalizedStringKey(viewModel.statusMessage))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(Int(viewModel.progress * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.devices) { device in
                            deviceCard(device)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal)
                .padding(.bottom)
            }
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

        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(device.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(device.id.uuidString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Label {
                    Text("\(device.signalStrength)")
                } icon: {
                    Image(systemName: "dot.radiowaves.left.and.right")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.toggleDeviceConnection(device)
            } label: {
                Image(systemName: isConnected ? "checkmark.circle.fill" : "link.circle.fill")
                    .font(.title)
                    .foregroundStyle(isConnected ? .green : Color.accentColor)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(isConnected ? "sync_status_connected_to" : "sync_connect_button"))
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
