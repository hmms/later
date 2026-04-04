import Foundation

public struct UITestHooks: Equatable {
    public let enableWait: Bool
    public let disableShortcuts: Bool
    public let enableShortcuts: Bool
    public let toggleLaunchAtLogin: Bool
    public let triggerSave: Bool
    public let triggerShortcutSave: Bool
    public let triggerShortcutRestore: Bool
    public let triggerRestore: Bool
    public let triggerCancelTimer: Bool

    public init(arguments: [String]) {
        let argSet = Set(arguments)
        enableWait = argSet.contains("UITEST_ENABLE_WAIT")
        disableShortcuts = argSet.contains("UITEST_DISABLE_SHORTCUTS")
        enableShortcuts = argSet.contains("UITEST_ENABLE_SHORTCUTS")
        toggleLaunchAtLogin = argSet.contains("UITEST_TOGGLE_LAUNCH_AT_LOGIN")
        triggerSave = argSet.contains("UITEST_TRIGGER_SAVE")
        triggerShortcutSave = argSet.contains("UITEST_TRIGGER_SHORTCUT_SAVE")
        triggerShortcutRestore = argSet.contains("UITEST_TRIGGER_SHORTCUT_RESTORE")
        triggerRestore = argSet.contains("UITEST_TRIGGER_RESTORE")
        triggerCancelTimer = argSet.contains("UITEST_TRIGGER_CANCEL_TIMER")
    }
}

public enum UITestAction: Equatable {
    case enableWait
    case disableShortcuts
    case enableShortcuts
    case toggleLaunchAtLogin
    case triggerSave
    case triggerShortcutSave
    case triggerShortcutRestore
    case triggerRestore
    case triggerCancelTimer
}

public enum UITestActionPlan {
    public static func makeActions(from hooks: UITestHooks) -> [UITestAction] {
        var actions: [UITestAction] = []

        if hooks.enableWait {
            actions.append(.enableWait)
        }

        if hooks.disableShortcuts {
            actions.append(.disableShortcuts)
        } else if hooks.enableShortcuts {
            actions.append(.enableShortcuts)
        }

        if hooks.toggleLaunchAtLogin {
            actions.append(.toggleLaunchAtLogin)
        }

        if hooks.triggerSave {
            actions.append(.triggerSave)
        }

        if hooks.triggerShortcutSave {
            actions.append(.triggerShortcutSave)
        }

        if hooks.triggerShortcutRestore {
            actions.append(.triggerShortcutRestore)
        }

        if hooks.triggerRestore {
            actions.append(.triggerRestore)
        }

        if hooks.triggerCancelTimer {
            actions.append(.triggerCancelTimer)
        }

        return actions
    }
}

public struct UITestStateSnapshot: Equatable {
    public let hasSession: Bool
    public let savedAppCount: Int
    public let timerScheduled: Bool
    public let globalShortcutsDisabled: Bool
    public let launchAtLoginEnabled: Bool

    public init(
        hasSession: Bool,
        savedAppCount: Int,
        timerScheduled: Bool,
        globalShortcutsDisabled: Bool,
        launchAtLoginEnabled: Bool
    ) {
        self.hasSession = hasSession
        self.savedAppCount = savedAppCount
        self.timerScheduled = timerScheduled
        self.globalShortcutsDisabled = globalShortcutsDisabled
        self.launchAtLoginEnabled = launchAtLoginEnabled
    }
}

public enum UITestStateSnapshotComposer {
    public static func makeSnapshot(
        hasSession: Bool,
        savedAppCount: Int,
        timerScheduled: Bool,
        globalShortcutsDisabled: Bool,
        launchAtLoginEnabled: Bool
    ) -> UITestStateSnapshot {
        UITestStateSnapshot(
            hasSession: hasSession,
            savedAppCount: savedAppCount,
            timerScheduled: timerScheduled,
            globalShortcutsDisabled: globalShortcutsDisabled,
            launchAtLoginEnabled: launchAtLoginEnabled
        )
    }
}

public enum UITestStateEncoder {
    public static func encode(_ snapshot: UITestStateSnapshot) throws -> Data {
        let payload: [String: Any] = [
            "hasSession": snapshot.hasSession,
            "savedAppCount": snapshot.savedAppCount,
            "timerScheduled": snapshot.timerScheduled,
            "globalShortcutsDisabled": snapshot.globalShortcutsDisabled,
            "launchAtLoginEnabled": snapshot.launchAtLoginEnabled,
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    }
}

public enum UITestStateWriter {
    public static func write(_ snapshot: UITestStateSnapshot, to url: URL) throws {
        let data = try UITestStateEncoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }
}

public enum UITestStateStore {
    private static let timerScheduledKey = "uiTestTimerScheduled"

    public static func setTimerScheduled(_ isScheduled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(isScheduled, forKey: timerScheduledKey)
    }

    public static func isTimerScheduled(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: timerScheduledKey)
    }
}
