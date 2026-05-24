import SwiftUI

struct BalanceView: View {
    @StateObject var viewModel: BalanceViewModel
    @AppStorage("balance_filters_visible") private var filtersVisible = true
    @State private var participantPendingDeletion: ParticipantBalance?

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
                    ForEach(viewModel.visibleFilteredBalances) { balance in
                        ParticipantBalanceRowView(balance: balance)
                            .swipeActions {
                                Button("participant_delete_action", role: .destructive) {
                                    if viewModel.participantHasExpenses(participantID: balance.id) {
                                        participantPendingDeletion = balance
                                    } else {
                                        viewModel.deleteParticipant(participantID: balance.id)
                                    }
                                }
                            }
                            .onAppear {
                                viewModel.loadMoreBalancesIfNeeded(currentItem: balance)
                            }
                    }
                }
            }
            .navigationTitle("balance_title")
            .alert(
                "balance_delete_confirmation_title",
                isPresented: Binding(
                    get: { participantPendingDeletion != nil },
                    set: { isPresented in
                        if !isPresented {
                            participantPendingDeletion = nil
                        }
                    }
                ),
                presenting: participantPendingDeletion
            ) { participant in
                Button("balance_delete_confirmation_action", role: .destructive) {
                    viewModel.deleteParticipant(participantID: participant.id)
                    participantPendingDeletion = nil
                }
                Button("common_cancel", role: .cancel) {
                    participantPendingDeletion = nil
                }
            } message: { _ in
                Text("balance_delete_confirmation_message")
            }
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
