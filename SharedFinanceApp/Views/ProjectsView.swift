import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject var viewModel: ProjectsViewModel
    @AppStorage("projects_filters_visible") private var filtersVisible = true
    @State private var showingCreate = false
    @State private var newTitle = ""
    @State private var newDescription = ""
    @State private var newDescriptionHeight: CGFloat = 56

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("search_projects_prompt", text: $viewModel.searchText)
                }

                if filtersVisible {
                    Section {
                        Picker("Status filter", selection: $viewModel.selectedStatusFilter) {
                            ForEach(ProjectStatusFilter.allCases) { filter in
                                Text(verbatim: filter.displayTitle).tag(filter)
                            }
                        }

                        Picker("Sort by", selection: $viewModel.selectedSort) {
                            ForEach(ProjectSortOption.allCases) { option in
                                Text(verbatim: option.displayTitle).tag(option)
                            }
                        }
                    } header: {
                        Text(verbatim: "Sort and filter")
                    }
                }

                Section("projects_title") {
                    ForEach(viewModel.filteredProjects) { project in
                        NavigationLink {
                            ProjectDetailView(
                                project: project,
                                projectsViewModel: viewModel,
                                expensesViewModel: ExpensesViewModel(repository: container.repository, errorLogger: container.errorLogger),
                                balanceViewModel: BalanceViewModel(repository: container.repository, errorLogger: container.errorLogger),
                                participantsViewModel: ParticipantsViewModel(repository: container.repository, errorLogger: container.errorLogger)
                            )
                        } label: {
                            ProjectCardView(
                                project: project,
                                participantCount: project.participantIDs.count,
                                projectBalance: viewModel.balance(for: project)
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .swipeActions {
                            Button("project_archive_action") { viewModel.archiveProject(project) }
                                .tint(.orange)
                            Button("project_delete_action", role: .destructive) { viewModel.deleteProject(project) }
                        }
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                        .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
                            dimensions[.trailing]
                        }
                    }
                }
            }
            .navigationTitle("projects_title")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            filtersVisible.toggle()
                        } label: {
                            Image(systemName: filtersVisible ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        }
                        .accessibilityLabel(filtersVisible ? "Hide filters" : "Show filters")

                        Button {
                            showingCreate = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreate) {
                NavigationStack {
                    Form {
                        TextField("project_title_placeholder", text: $newTitle)
                        AutoGrowingTextView(
                            text: $newDescription,
                            height: $newDescriptionHeight,
                            placeholder: NSLocalizedString("project_details_placeholder", comment: "")
                        )
                        .frame(height: newDescriptionHeight)
                    }
                    .navigationTitle("new_project_title")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("project_cancel_button") { showingCreate = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("project_create_button") {
                                viewModel.createProject(title: newTitle, details: newDescription)
                                newTitle = ""
                                newDescription = ""
                                showingCreate = false
                            }
                            .disabled(newTitle.isEmpty)
                        }
                    }
                }
            }
            .onAppear { viewModel.loadProjects() }
            .onChange(of: showingCreate) { isShowing in
                if isShowing == false {
                    newDescriptionHeight = 56
                }
            }
        }
    }
}

private struct AutoGrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    let placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, height: $height, placeholder: placeholder)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textColor = .label
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .vertical)

        let placeholderLabel = UILabel()
        placeholderLabel.text = placeholder
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.font = .preferredFont(forTextStyle: .body)
        placeholderLabel.numberOfLines = 0
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.tag = 999
        textView.addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 13),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -13),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 10)
        ])

        context.coordinator.placeholderLabel = placeholderLabel
        context.coordinator.updatePlaceholderVisibility(text.isEmpty)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        context.coordinator.updatePlaceholderVisibility(text.isEmpty)
        DispatchQueue.main.async {
            let targetSize = CGSize(width: uiView.bounds.width, height: .greatestFiniteMagnitude)
            let fittingSize = uiView.sizeThatFits(targetSize)
            if height != fittingSize.height {
                height = fittingSize.height
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let text: Binding<String>
        private let height: Binding<CGFloat>
        private let placeholder: String
        weak var placeholderLabel: UILabel?

        init(text: Binding<String>, height: Binding<CGFloat>, placeholder: String) {
            self.text = text
            self.height = height
            self.placeholder = placeholder
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
            updatePlaceholderVisibility(textView.text.isEmpty)

            let targetSize = CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)
            let fittingSize = textView.sizeThatFits(targetSize)
            if height.wrappedValue != fittingSize.height {
                height.wrappedValue = fittingSize.height
            }
        }

        func updatePlaceholderVisibility(_ isHidden: Bool) {
            placeholderLabel?.isHidden = !isHidden
        }
    }
}
