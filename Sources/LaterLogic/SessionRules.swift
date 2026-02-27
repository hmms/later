import Foundation

public enum SavedAppAction: Equatable {
    case hide
    case terminate
}

public enum SessionRules {
    public static let ignoredSystemBundleIDs: Set<String> = [
        "com.apple.finder",
        "com.apple.ActivityMonitor",
        "com.apple.systempreferences",
        "com.apple.SystemSettings",
        "com.apple.AppStore"
    ]

    public static func actionForSavedApp(quitAppsInsteadOfHiding: Bool) -> SavedAppAction {
        return quitAppsInsteadOfHiding ? .terminate : .hide
    }

    public static func shouldIgnoreApp(
        bundleID: String?,
        ignoreSystemApps: Bool,
        customIgnoredBundleIDs: Set<String>
    ) -> Bool {
        guard let bundleID else {
            return false
        }

        if ignoreSystemApps && ignoredSystemBundleIDs.contains(bundleID) {
            return true
        }

        return customIgnoredBundleIDs.contains(bundleID)
    }

    public static func reopenDelaySeconds(for option: String?) -> Double {
        switch option {
        case "15 minutes":
            return 15 * 60
        case "30 minutes":
            return 30 * 60
        case "1 hour":
            return 60 * 60
        case "5 hours":
            return 5 * 60 * 60
        default:
            return 10
        }
    }
}
