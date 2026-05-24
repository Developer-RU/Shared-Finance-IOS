import SwiftUI

@main
struct SharedFinanceApp: App {
    @StateObject private var appContainer = AppContainer.bootstrap()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appContainer)
                .environmentObject(appContainer.appState)
        }
    }
}

private struct AppRootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        RootTabView()
            .environment(\.locale, Locale(identifier: appState.languageCode))
    }
}
