import SwiftUI

struct ParticipantsView: View {
    let projectID: UUID
    @StateObject var viewModel: ParticipantsViewModel
    @AppStorage("participants_filters_visible") private var filtersVisible = true

    @State private var name = ""
    @State private var contribution = ""
    @State private var participantPendingDeletion: Participant?
    @State private var participantPendingRename: Participant?
    @State private var renamedParticipantName = ""

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
                    ForEach(viewModel.visibleFilteredParticipants) { participant in
                        ParticipantBalanceRowView(balance: viewModel.participantBalance(for: participant))
                        .swipeActions {
                            Button("participant_rename_action") {
                                renamedParticipantName = participant.name
                                participantPendingRename = participant
                            }
                            .tint(.blue)

                            Button("participant_delete_action", role: .destructive) {
                                if viewModel.participantHasExpenses(participant) {
                                    participantPendingDeletion = participant
                                } else {
                                    viewModel.delete(participant: participant, projectID: projectID)
                                }
                            }
                        }
                        .onAppear {
                            viewModel.loadMoreParticipantsIfNeeded(currentItem: participant)
                        }
                    }
                }
            }
            .navigationTitle("participant_title")
            .alert(
                "participant_delete_confirmation_title",
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
                Button("participant_delete_confirmation_action", role: .destructive) {
                    viewModel.delete(participant: participant, projectID: projectID)
                    participantPendingDeletion = nil
                }
                Button("common_cancel", role: .cancel) {
                    participantPendingDeletion = nil
                }
            } message: { _ in
                Text("participant_delete_confirmation_message")
            }
            .sheet(item: $participantPendingRename) { participant in
                NavigationStack {
                    Form {
                        TextField("participant_name_placeholder", text: $renamedParticipantName)
                    }
                    .navigationTitle("participant_rename_title")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("project_cancel_button") {
                                participantPendingRename = nil
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("project_save_button") {
                                var updatedParticipant = participant
                                updatedParticipant.name = renamedParticipantName.trimmingCharacters(in: .whitespacesAndNewlines)
                                viewModel.update(participant: updatedParticipant, projectID: projectID)
                                participantPendingRename = nil
                            }
                            .disabled(renamedParticipantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
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
            .onAppear { viewModel.load(projectID: projectID) }
        }
    }
}
