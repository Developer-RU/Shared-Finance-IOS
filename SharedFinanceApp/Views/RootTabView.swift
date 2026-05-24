import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ProjectsView(viewModel: ProjectsViewModel(repository: container.repository, errorLogger: container.errorLogger))
                .tabItem { Label("projects_tab", systemImage: "folder") }
                .tag(RootTab.projects)

            BalanceView(viewModel: BalanceViewModel(repository: container.repository, errorLogger: container.errorLogger))
                .tabItem { Label("balance_tab", systemImage: "equal.circle") }
                .tag(RootTab.balance)

            HistoryView(viewModel: HistoryViewModel(repository: container.repository, errorLogger: container.errorLogger))
                .tabItem { Label("history_tab", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90") }
                .tag(RootTab.history)

            SyncView(viewModel: SyncViewModel(syncService: container.syncService))
                .tabItem { Label("sync_tab", systemImage: "dot.radiowaves.left.and.right") }
                .tag(RootTab.sync)

            SettingsView(viewModel: SettingsViewModel(appState: appState, backupService: container.backupService))
                .tabItem { Label("settings_tab", systemImage: "gearshape") }
                .tag(RootTab.settings)
        }
        .preferredColorScheme(appState.preferredTheme.colorScheme)
    }
}
