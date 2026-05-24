import SwiftUI

struct ExpensesView: View {
    let projectID: UUID
    @StateObject var viewModel: ExpensesViewModel
    @AppStorage("expenses_filters_visible") private var filtersVisible = true

    @State private var title = ""
    @State private var amount = ""
    @State private var comment = ""
    @State private var selectedParticipantID: UUID?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("expense_search_prompt", text: $viewModel.searchText)
                }

                if filtersVisible {
                    Section {
                        Picker("Sort by", selection: $viewModel.selectedSort) {
                            ForEach(ExpenseSortOption.allCases) { option in
                                Text(verbatim: option.displayTitle).tag(option)
                            }
                        }
                        Picker("Participant filter", selection: Binding(
                            get: { viewModel.selectedParticipantFilterID },
                            set: { viewModel.selectedParticipantFilterID = $0 }
                        )) {
                            Text(verbatim: "All participants").tag(nil as UUID?)
                            ForEach(viewModel.availableParticipants) { participant in
                                Text(participant.name).tag(Optional(participant.id))
                            }
                        }
                    }
                    header: {
                        Text(verbatim: "Sort and filter")
                    }
                }

                if viewModel.searchText.isEmpty {
                    Section("add_expense_section") {
                        TextField("expense_title_placeholder", text: $title)
                        TextField("expense_amount_placeholder", text: $amount)
                            .keyboardType(.decimalPad)
                        TextField("expense_comment_placeholder", text: $comment)

                        Picker("expense_participant_picker", selection: $selectedParticipantID) {
                            Text("expense_choose_participant").tag(nil as UUID?)
                            ForEach(viewModel.availableParticipants) { participant in
                                Text(participant.name).tag(Optional(participant.id))
                            }
                        }

                        if !viewModel.validationMessage.isEmpty {
                            Text(LocalizedStringKey(viewModel.validationMessage))
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        if viewModel.availableParticipants.isEmpty {
                            Text("expense_no_participants_message")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button("expense_add_button") {
                            guard let decimal = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) else { return }
                            guard let participantID = selectedParticipantID else { return }
                            let categoryID = Category.defaults.first?.id ?? UUID()
                            viewModel.add(
                                projectID: projectID,
                                participantID: participantID,
                                categoryID: categoryID,
                                title: title,
                                amount: decimal,
                                comment: comment
                            )
                            title = ""
                            amount = ""
                            comment = ""
                        }
                        .disabled(title.isEmpty || amount.isEmpty || selectedParticipantID == nil || viewModel.availableParticipants.isEmpty)
                    }
                }

                Section("expense_list_section") {
                    ForEach(viewModel.filteredExpenses) { expense in
                        ExpenseRowView(expense: expense)
                            .swipeActions {
                                Button("expense_delete_action", role: .destructive) {
                                    viewModel.delete(expense: expense)
                                }
                            }
                    }
                }
            }
            .navigationTitle("expense_title")
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
            .onAppear {
                viewModel.load(projectID: projectID)
                if selectedParticipantID == nil {
                    selectedParticipantID = viewModel.availableParticipants.first?.id
                }
            }
        }
    }
}
