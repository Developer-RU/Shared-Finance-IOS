import SwiftUI

struct HistoryView: View {
    @StateObject var viewModel: HistoryViewModel
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
                                .onAppear {
                                    viewModel.loadMoreHistoryIfNeeded(currentItem: item)
                                }
                            }
                        }
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
        }
    }
}
