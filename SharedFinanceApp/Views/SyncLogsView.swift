import SwiftUI

struct SyncLogsView: View {
    @StateObject var viewModel: HistoryViewModel

    var body: some View {
        List {
            Section {
                TextField("history_search_prompt", text: $viewModel.searchText)
            }

            Section {
                Picker("Sync result filter", selection: $viewModel.selectedSyncResultFilter) {
                    Text("All results").tag(HistorySyncResultFilter.all)
                    Text("Success").tag(HistorySyncResultFilter.success)
                    Text("Failed").tag(HistorySyncResultFilter.failed)
                }
            } header: {
                Text("Filters")
            }

            if viewModel.visibleFilteredSyncLogs.isEmpty {
                Section("history_sync_logs_section") {
                    Text("history_no_records")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("history_sync_logs_section") {
                    ForEach(viewModel.visibleFilteredSyncLogs) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.deviceName)
                                .font(.headline)
                            Text("\(item.date.shortDateTime)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(LocalizedStringKey(item.result.localizedKey)) + Text(" • \(item.changedRecordsCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .onAppear {
                            viewModel.loadMoreSyncLogsIfNeeded(currentItem: item)
                        }
                    }
                }
            }
        }
        .navigationTitle("history_sync_logs_section")
        .onAppear { viewModel.load() }
    }
}
