import Foundation
import SwiftUI

final class AppState: ObservableObject {
    @Published var selectedTab: RootTab = AppState.initialSelectedTab
    @Published var preferredTheme: AppTheme = .system
    @Published var languageCode: String = {
        "ru"
    }()
    @Published var isFaceIDEnabled: Bool = false

    static let supportedLanguageCodes = ["en", "ru"]

    private static var initialSelectedTab: RootTab {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--screenshot-tab"),
              index + 1 < arguments.count,
              let tab = RootTab(argumentValue: arguments[index + 1]) else {
            return .projects
        }
        return tab
    }
}

enum RootTab: Hashable {
    case projects
    case balance
    case history
    case sync
    case settings

    init?(argumentValue: String) {
        switch argumentValue.lowercased() {
        case "projects": self = .projects
        case "balance": self = .balance
        case "history": self = .history
        case "sync": self = .sync
        case "settings": self = .settings
        default: return nil
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var localizedKey: String {
        switch self {
        case .system: return "theme_system"
        case .light: return "theme_light"
        case .dark: return "theme_dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
