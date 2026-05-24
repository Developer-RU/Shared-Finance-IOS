import SwiftUI

struct BalanceView: View {
    @StateObject var viewModel: BalanceViewModel
    @AppStorage("balance_filters_visible") private var filtersVisible = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("balance_search_prompt", text: $viewModel.searchText)
                }

                if filtersVisible {
                    Section {
                        Picker("Sort by", selection: $viewModel.selectedSort) {
                            ForEach(BalanceSortOption.allCases) { option in
                                Text(verbatim: option.displayTitle).tag(option)
                            }
                        }
                        Picker("Balance filter", selection: $viewModel.selectedFilter) {
                            ForEach(BalanceFilterOption.allCases) { option in
                                Text(verbatim: option.displayTitle).tag(option)
                            }
                        }
                    } header: {
                        Text(verbatim: "Sort and filter")
                    }
                }

                Section("balance_title") {
                    ForEach(viewModel.filteredBalances) { balance in
                        ParticipantBalanceRowView(balance: balance)
                    }
                }
            }
            .navigationTitle("balance_title")
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
            .onAppear { viewModel.load(projectID: nil) }
        }
    }
}
