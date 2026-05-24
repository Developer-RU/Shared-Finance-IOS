import Foundation
import Combine

enum ProjectStatusFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case archived

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .all: return "All projects"
        case .active: return "Active"
        case .archived: return "Archived"
        }
    }
}

enum ProjectSortOption: String, CaseIterable, Identifiable {
    case updatedNewest
    case updatedOldest
    case titleAZ
    case titleZA

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .updatedNewest: return "Updated: newest"
        case .updatedOldest: return "Updated: oldest"
        case .titleAZ: return "Title: A-Z"
        case .titleZA: return "Title: Z-A"
        }
    }
}

@MainActor
final class ProjectsViewModel: ObservableObject {
    private static let pageSize = 30
    private static let pinnedStorageKey = "projects_pinned_ids"

    @Published var projects: [Project] = []
    @Published var searchText = ""
    @Published var selectedStatusFilter: ProjectStatusFilter = .all
    @Published var selectedSort: ProjectSortOption = .updatedNewest
    @Published private(set) var visibleProjectsLimit = pageSize
    @Published private(set) var pinnedProjectIDs: Set<UUID> = []

    private let repository: SharedFinanceRepository
    private let errorLogger: ErrorLogger
    private var cancellables = Set<AnyCancellable>()

    init(repository: SharedFinanceRepository, errorLogger: ErrorLogger) {
        self.repository = repository
        self.errorLogger = errorLogger
        self.pinnedProjectIDs = Self.loadPinnedProjectIDs()

        NotificationCenter.default.publisher(for: .sharedFinanceDataDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadProjects()
            }
            .store(in: &cancellables)

        setupPaginationResetSubscriptions()
    }

    var filteredProjects: [Project] {
        var filtered = searchText.isEmpty
            ? projects
            : projects.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.details.localizedCaseInsensitiveContains(searchText) }

        switch selectedStatusFilter {
        case .all:
            break
        case .active:
            filtered = filtered.filter { $0.status == .active }
        case .archived:
            filtered = filtered.filter { $0.status == .archived }
        }

        switch selectedSort {
        case .updatedNewest:
            return filtered.sorted {
                if self.pinnedProjectIDs.contains($0.id) != self.pinnedProjectIDs.contains($1.id) {
                    return self.pinnedProjectIDs.contains($0.id)
                }
                if $0.status != $1.status {
                    return $0.status == .active
                }
                return $0.updatedAt > $1.updatedAt
            }
        case .updatedOldest:
            return filtered.sorted {
                if self.pinnedProjectIDs.contains($0.id) != self.pinnedProjectIDs.contains($1.id) {
                    return self.pinnedProjectIDs.contains($0.id)
                }
                if $0.status != $1.status {
                    return $0.status == .active
                }
                return $0.updatedAt < $1.updatedAt
            }
        case .titleAZ:
            return filtered.sorted {
                if self.pinnedProjectIDs.contains($0.id) != self.pinnedProjectIDs.contains($1.id) {
                    return self.pinnedProjectIDs.contains($0.id)
                }
                if $0.status != $1.status {
                    return $0.status == .active
                }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .titleZA:
            return filtered.sorted {
                if self.pinnedProjectIDs.contains($0.id) != self.pinnedProjectIDs.contains($1.id) {
                    return self.pinnedProjectIDs.contains($0.id)
                }
                if $0.status != $1.status {
                    return $0.status == .active
                }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending
            }
        }
    }

    var visibleFilteredProjects: [Project] {
        Array(filteredProjects.prefix(visibleProjectsLimit))
    }

    func loadProjects() {
        projects = repository.fetchProjects().sorted {
            if $0.status != $1.status {
                return $0.status == .active
            }
            return $0.updatedAt > $1.updatedAt
        }
        visibleProjectsLimit = Self.pageSize
    }

    func loadMoreProjectsIfNeeded(currentItem: Project) {
        guard let lastVisible = visibleFilteredProjects.last, lastVisible.id == currentItem.id else {
            return
        }
        visibleProjectsLimit = min(visibleProjectsLimit + Self.pageSize, filteredProjects.count)
    }

    func createProject(title: String, details: String) {
        let project = Project(title: title, details: details)
        repository.upsertProject(project)
        repository.appendHistory(ChangeHistoryEntry(operationType: .create, actorName: "Local User", description: "Created project: \(title)", recordVersion: 1))
        loadProjects()
    }

    func updateProject(_ project: Project) {
        var updated = project
        updated.recordVersion += 1
        updated.updatedAt = .now
        repository.upsertProject(updated)
        repository.appendHistory(ChangeHistoryEntry(operationType: .update, actorName: "Local User", description: "Updated project: \(updated.title)", recordVersion: updated.recordVersion))
        loadProjects()
    }

    func archiveProject(_ project: Project) {
        var updated = project
        updated.status = .archived
        updated.recordVersion += 1
        updated.updatedAt = .now
        repository.upsertProject(updated)
        repository.appendHistory(ChangeHistoryEntry(operationType: .update, actorName: "Local User", description: "Archived project: \(project.title)", recordVersion: updated.recordVersion))
        loadProjects()
    }

    func deleteProject(_ project: Project) {
        repository.deleteProject(project)
        pinnedProjectIDs.remove(project.id)
        savePinnedProjectIDs()
        repository.appendHistory(ChangeHistoryEntry(operationType: .delete, actorName: "Local User", description: "Deleted project: \(project.title)", recordVersion: project.recordVersion + 1))
        loadProjects()
    }

    func togglePinned(_ project: Project) {
        if pinnedProjectIDs.contains(project.id) {
            pinnedProjectIDs.remove(project.id)
        } else {
            pinnedProjectIDs.insert(project.id)
        }
        savePinnedProjectIDs()
    }

    func isPinned(_ project: Project) -> Bool {
        pinnedProjectIDs.contains(project.id)
    }

    func balance(for project: Project) -> Decimal {
        let participants = repository.fetchParticipants(projectID: project.id)
        let expenses = repository.fetchExpenses(projectID: project.id)
        return BalanceCalculator.calculate(participants: participants, expenses: expenses).reduce(.zero) { $0 + $1.balance }
    }

    private func setupPaginationResetSubscriptions() {
        Publishers.CombineLatest3(
            $searchText.removeDuplicates(),
            $selectedStatusFilter.removeDuplicates(),
            $selectedSort.removeDuplicates()
        )
        .dropFirst()
        .sink { [weak self] _, _, _ in
            self?.visibleProjectsLimit = Self.pageSize
        }
        .store(in: &cancellables)
    }

    private static func loadPinnedProjectIDs() -> Set<UUID> {
        let raw = UserDefaults.standard.array(forKey: pinnedStorageKey) as? [String] ?? []
        return Set(raw.compactMap(UUID.init(uuidString:)))
    }

    private func savePinnedProjectIDs() {
        let raw = pinnedProjectIDs.map(\.uuidString)
        UserDefaults.standard.set(raw, forKey: Self.pinnedStorageKey)
    }
}
