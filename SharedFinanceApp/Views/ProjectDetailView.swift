import SwiftUI
import UIKit

struct ProjectDetailView: View {
    let project: Project
    @ObservedObject var projectsViewModel: ProjectsViewModel
    @StateObject var expensesViewModel: ExpensesViewModel
    @StateObject var balanceViewModel: BalanceViewModel
    @StateObject var participantsViewModel: ParticipantsViewModel
    @State private var editableProject: Project
    @State private var showingEdit = false
    @State private var draftTitle = ""
    @State private var draftDetails = ""
    @State private var draftDetailsHeight: CGFloat = 56
    @State private var draftStatus: ProjectStatus = .active

    init(
        project: Project,
        projectsViewModel: ProjectsViewModel,
        expensesViewModel: ExpensesViewModel,
        balanceViewModel: BalanceViewModel,
        participantsViewModel: ParticipantsViewModel
    ) {
        self.project = project
        self.projectsViewModel = projectsViewModel
        _expensesViewModel = StateObject(wrappedValue: expensesViewModel)
        _balanceViewModel = StateObject(wrappedValue: balanceViewModel)
        _participantsViewModel = StateObject(wrappedValue: participantsViewModel)
        _editableProject = State(initialValue: project)
    }

    var body: some View {
        List {
            Section("project_info_section") {
                Text(editableProject.title).font(.headline)
                Text(editableProject.details)
                HStack(spacing: 4) {
                    Text("project_status_label")
                    Text(LocalizedStringKey(editableProject.status.localizedKey))
                }
            }

            Section("project_expenses_section") {
                NavigationLink("project_open_expenses") {
                    ExpensesView(projectID: project.id, viewModel: expensesViewModel)
                }
            }

            Section("project_participants_section") {
                NavigationLink("project_manage_participants") {
                    ParticipantsView(projectID: project.id, viewModel: participantsViewModel)
                }
            }

            Section("project_balance_section") {
                ForEach(balanceViewModel.balances) { item in
                    ParticipantBalanceRowView(balance: item)
                }
            }
        }
        .navigationTitle("project_title")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    draftTitle = editableProject.title
                    draftDetails = editableProject.details
                    draftStatus = editableProject.status
                    showingEdit = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                Form {
                    TextField("project_title_placeholder", text: $draftTitle)
                    AutoGrowingTextView(
                        text: $draftDetails,
                        height: $draftDetailsHeight,
                        placeholder: NSLocalizedString("project_details_placeholder", comment: "")
                    )
                    .frame(height: draftDetailsHeight)

                    Picker("project_status_label", selection: $draftStatus) {
                        Text("project_status_active").tag(ProjectStatus.active)
                        Text("project_status_archived").tag(ProjectStatus.archived)
                    }
                }
                .navigationTitle("project_edit_title")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("project_cancel_button") {
                            showingEdit = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("project_save_button") {
                            editableProject.title = draftTitle
                            editableProject.details = draftDetails
                            editableProject.status = draftStatus
                            editableProject.updatedAt = .now
                            editableProject.recordVersion += 1
                            projectsViewModel.updateProject(editableProject)
                            balanceViewModel.load(projectID: editableProject.id)
                            participantsViewModel.load(projectID: editableProject.id)
                            showingEdit = false
                        }
                        .disabled(draftTitle.isEmpty)
                    }
                }
            }
            .onChange(of: showingEdit) { isShowing in
                if isShowing == false {
                    draftDetailsHeight = 56
                }
            }
        }
        .onAppear {
            balanceViewModel.load(projectID: editableProject.id)
            participantsViewModel.load(projectID: editableProject.id)
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
        weak var placeholderLabel: UILabel?

        init(text: Binding<String>, height: Binding<CGFloat>, placeholder: String) {
            self.text = text
            self.height = height
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
