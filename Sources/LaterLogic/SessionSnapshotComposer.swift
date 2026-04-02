import Foundation

public struct SessionSnapshotDraft: Equatable {
    public let appURLs: [String]
    public let appNames: [String]

    public init(appURLs: [String], appNames: [String]) {
        self.appURLs = appURLs
        self.appNames = appNames
    }
}

public enum SessionSnapshotComposer {
    public static func makeSnapshot(
        draft: SessionSnapshotDraft,
        sessionDate: String,
        lastStateWasTerminate: Bool
    ) -> SessionSnapshot {
        let summary = SessionPresentation.summarizeSession(appNames: draft.appNames)

        return SessionSnapshot(
            appURLs: draft.appURLs,
            appNames: draft.appNames,
            sessionName: summary.sessionName,
            sessionFullName: summary.sessionFullName,
            totalSessions: summary.totalSessions,
            sessionDate: sessionDate,
            lastStateWasTerminate: lastStateWasTerminate
        )
    }
}
