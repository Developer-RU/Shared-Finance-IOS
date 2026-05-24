import SwiftUI

struct ParticipantsView: View {
    let projectID: UUID
    @StateObject var viewModel: ParticipantsViewModel
    @AppStorage("participants_filters_visible") private var filtersVisible = true

    @State private var name = ""
    @State private var contribution = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("participant_search_prompt", text: $viewModel.searchText)
                }

                if filtersVisible {
                    Section {
                        Picker("Sort by", selection: $viewModel.selectedSort) {
                            ForEach(ParticipantSortOption.allCases) { option in
                                Text(verbatim: option.displayTitle).tag(option)
                            }
                        }
                        Picker("Balance filter", selection: $viewModel.selectedBalanceFilter) {
                            ForEach(ParticipantBalanceFilter.allCases) { option in
                                Text(verbatim: option.displayTitle).tag(option)
                            }
                        }
                    }
                    header: {
                        Text(verbatim: "Sort and filter")
                    }
                }

                if viewModel.searchText.isEmpty {
                    Section("add_participant_section") {
                        TextField("participant_name_placeholder", text: $name)
                        TextField("participant_contribution_placeholder", text: $contribution)
                            .keyboardType(.decimalPad)
                        Button("participant_add_button") {
                            guard let contributionValue = Decimal(string: contribution.replacingOccurrences(of: ",", with: ".")) else { return }
                            viewModel.add(name: name, contribution: contributionValue, projectID: projectID)
                            name = ""
                            contribution = ""
                        }
                        .disabled(name.isEmpty || contribution.isEmpty)
                    }
                }

                Section("participant_list_section") {
                    ForEach(viewModel.filteredParticipants) { participant in
                        VStack(alignment: .leading) {
                            Text(participant.name)
                            Text("participant_contribution_label \(participant.contributionAmount.currencyString)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(verbatim: "Balance: \(viewModel.balance(for: participant).currencyString)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("participant_delete_action", role: .destructive) {
                                viewModel.delete(participant: participant, projectID: projectID)
                            }
                        }
                    }
                }
            }
            .navigationTitle("participant_title")
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
            .onAppear { viewModel.load(projectID: projectID) }
        }
    }
}
