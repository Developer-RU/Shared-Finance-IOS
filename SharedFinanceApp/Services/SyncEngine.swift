import Foundation

final class SyncEngine {
    private let errorLogger: ErrorLogger

    init(errorLogger: ErrorLogger) {
        self.errorLogger = errorLogger
    }

    func detectConflicts(local: SyncPayload, remote: SyncPayload) -> SyncDelta {
        let localProjects = Dictionary(uniqueKeysWithValues: local.projects.map { ($0.id, $0) })
        var conflicts: [SyncConflict] = []

        for remoteProject in remote.projects {
            guard let localProject = localProjects[remoteProject.id] else { continue }
            if localProject.recordVersion != remoteProject.recordVersion,
               localProject.updatedAt != remoteProject.updatedAt {
                conflicts.append(
                    SyncConflict(
                        entityName: "Project",
                        entityID: remoteProject.id,
                        localValue: localProject.title,
                        remoteValue: remoteProject.title,
                        localRecordVersion: localProject.recordVersion,
                        remoteRecordVersion: remoteProject.recordVersion,
                        localUpdatedAt: localProject.updatedAt,
                        remoteUpdatedAt: remoteProject.updatedAt
                    )
                )
            }
        }

        errorLogger.log("Sync conflicts detected: \(conflicts.count)")
        return SyncDelta(conflicts: conflicts)
    }
}
