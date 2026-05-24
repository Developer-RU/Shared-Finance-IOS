import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @StateObject var viewModel: HistoryViewModel
    @State private var exportDocument = JSONBackupDocument()
    @State private var showingExporter = false
    @State private var exportStatus = ""
    @AppStorage("history_filters_visible") private var filtersVisible = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("history_search_prompt", text: $viewModel.searchText)
                }

                if filtersVisible {
                    Section {
                        Picker("Operation filter", selection: $viewModel.selectedOperationFilter) {
                            Text("All operations").tag(HistoryOperationFilter.all)
                            Text("Created").tag(HistoryOperationFilter.create)
                            Text("Updated").tag(HistoryOperationFilter.update)
                            Text("Deleted").tag(HistoryOperationFilter.delete)
                            Text("Synced").tag(HistoryOperationFilter.sync)
                        }

                        Picker("Sync result filter", selection: $viewModel.selectedSyncResultFilter) {
                            Text("All results").tag(HistorySyncResultFilter.all)
                            Text("Success").tag(HistorySyncResultFilter.success)
                            Text("Conflict").tag(HistorySyncResultFilter.conflict)
                            Text("Failed").tag(HistorySyncResultFilter.failed)
                        }

                        Picker("history_decision_picker", selection: $viewModel.selectedDecisionFilter) {
                            ForEach(ConflictDecisionFilter.allCases) { filter in
                                Text(LocalizedStringKey(filter.titleKey)).tag(filter)
                            }
                        }

                        Picker("history_date_picker", selection: $viewModel.selectedDateFilter) {
                            ForEach(ConflictDateFilter.allCases) { filter in
                                Text(LocalizedStringKey(filter.titleKey)).tag(filter)
                            }
                        }
                    } header: {
                        Text("Filters")
                    }
                }

                if viewModel.groupedFilteredHistory.isEmpty {
                    Section("history_changes_section") {
                        Text("history_no_records")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(viewModel.groupedFilteredHistory) { group in
                        Section(header: Text(group.date.shortDate)) {
                            ForEach(group.items) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.description)
                                        .font(.headline)
                                    Text("\(item.actorName) • \(item.date.shortDateTime)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("history_sync_logs_section") {
                    ForEach(viewModel.filteredSyncLogs) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.deviceName)
                            Text(LocalizedStringKey(item.result.localizedKey)) + Text(" • \(item.changedRecordsCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("history_conflict_resolutions_section") {
                    if viewModel.conflictResolutionLogs.isEmpty {
                        Text("history_no_records")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("history_export_conflicts_button") {
                        guard let data = viewModel.exportFilteredConflictLogsData() else {
                            exportStatus = "history_export_error"
                            return
                        }
                        exportDocument = JSONBackupDocument(data: data)
                        showingExporter = true
                    }

                    if !exportStatus.isEmpty {
                        Text(LocalizedStringKey(exportStatus))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(viewModel.filteredConflictResolutionLogs) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(item.entityName) • \(item.entityID.uuidString.prefix(8))")
                                .font(.headline)
                            Text("history_local_label \(item.localValue)")
                                .font(.caption)
                            Text("history_remote_label \(item.remoteValue)")
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("history_title")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        filtersVisible.toggle()
                    } label: {
                        Image(systemName: filtersVisible ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel(filtersVisible ? "Hide filters" : "Show filters")
                }
            }
            .onAppear { viewModel.load() }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: UTType.json,
                defaultFilename: "shared_finance_conflicts"
            ) { result in
                switch result {
                case .success:
                    exportStatus = "history_export_done"
                case .failure:
                    exportStatus = "history_export_error"
                }
            }
        }
    }
}
