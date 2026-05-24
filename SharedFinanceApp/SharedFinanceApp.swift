import SwiftUI
import LocalAuthentication

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
    @Environment(\.scenePhase) private var scenePhase

    @State private var isLocked = false
    @State private var isAuthenticating = false
    @State private var authErrorMessage = ""

    var body: some View {
        ZStack {
            RootTabView()
                .environment(\.locale, Locale(identifier: appState.languageCode))

            if isLocked {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("auth_unlock_title")
                        .font(.headline)

                    if !authErrorMessage.isEmpty {
                        Text(authErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Button("auth_unlock_button") {
                        authenticateIfNeeded(force: true)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAuthenticating)
                }
                .padding(24)
            }
        }
        .onAppear {
            refreshLockState()
        }
        .onChange(of: appState.isFaceIDEnabled) { _, _ in
            refreshLockState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                if appState.isFaceIDEnabled {
                    isLocked = true
                }
            case .active:
                authenticateIfNeeded(force: false)
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }

    private func refreshLockState() {
        if appState.isFaceIDEnabled {
            isLocked = true
            authenticateIfNeeded(force: true)
        } else {
            isLocked = false
            authErrorMessage = ""
        }
    }

    private func authenticateIfNeeded(force: Bool) {
        guard appState.isFaceIDEnabled else {
            isLocked = false
            return
        }
        guard (isLocked || force) && !isAuthenticating else { return }

        let context = LAContext()
        var error: NSError?
        let reason = String(localized: "settings_face_id")

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            authErrorMessage = error?.localizedDescription ?? "Authentication unavailable"
            isLocked = true
            return
        }

        isAuthenticating = true
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evaluationError in
            DispatchQueue.main.async {
                isAuthenticating = false
                if success {
                    isLocked = false
                    authErrorMessage = ""
                } else {
                    isLocked = true
                    authErrorMessage = evaluationError?.localizedDescription ?? "Authentication failed"
                }
            }
        }
    }
}
