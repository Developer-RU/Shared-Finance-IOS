import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    @State private var backupStatus: String = ""
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument = JSONBackupDocument()

    var body: some View {
        NavigationStack {
            Form {
                Section("settings_theme_section") {
                    Picker("settings_theme_section", selection: $viewModel.selectedTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(LocalizedStringKey(theme.localizedKey)).tag(theme)
                        }
                    }
                    .onChange(of: viewModel.selectedTheme) { _, newValue in
                        viewModel.applyTheme(newValue)
                    }
                }

                Section("settings_language_section") {
                    Picker("settings_language_section", selection: $viewModel.languageCode) {
                        Text("language_ru").tag("ru")
                        Text("language_en").tag("en")
                    }
                    .onChange(of: viewModel.languageCode) { _, newValue in
                        viewModel.applyLanguage(newValue)
                    }
                }

                Section("settings_security_section") {
                    Toggle("settings_face_id", isOn: Binding(
                        get: { viewModel.faceIDEnabled },
                        set: { viewModel.toggleFaceID($0) }
                    ))
                }

                Section("settings_backup_section") {
                    Button("settings_export_json") {
                        guard let data = viewModel.exportBackupData() else {
                            backupStatus = "settings_export_error"
                            return
                        }
                        exportDocument = JSONBackupDocument(data: data)
                        showingExporter = true
                    }
                    Button("settings_import_json") {
                        showingImporter = true
                    }
                    if !backupStatus.isEmpty {
                        Text(LocalizedStringKey(backupStatus))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("settings_title")
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [UTType.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else {
                        backupStatus = "settings_file_not_selected"
                        return
                    }
                    backupStatus = viewModel.importBackup(url: url) ? "settings_import_done" : "settings_import_error"
                case .failure:
                    backupStatus = "settings_import_error"
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "shared_finance_backup"
            ) { result in
                switch result {
                case .success:
                    backupStatus = "settings_export_done"
                case .failure:
                    backupStatus = "settings_export_error"
                }
            }
        }
    }
}
