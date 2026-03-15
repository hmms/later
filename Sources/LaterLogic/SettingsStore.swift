import Foundation

public struct SettingsStore {
    private enum Key {
        static let closeApps = "closeApps"
        static let ignoreSystem = "ignoreSystem"
        static let keepWindowsOpen = "keepWindowsOpen"
        static let waitCheckbox = "waitCheckbox"
        static let switchKey = "switchKey"
        static let session = "session"
        static let lastState = "lastState"
        static let apps = "apps"
        static let appNames = "appNames"
        static let sessionName = "sessionName"
        static let sessionFullName = "sessionFullName"
        static let totalSessions = "totalSessions"
        static let date = "date"
        static let launchAtLogin = "launchAtLogin"
    }

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public var closeAppsOnRestore: Bool {
        get { userDefaults.bool(forKey: Key.closeApps) }
        set { userDefaults.set(newValue, forKey: Key.closeApps) }
    }

    public var ignoreSystemApps: Bool {
        get { userDefaults.bool(forKey: Key.ignoreSystem) }
        set { userDefaults.set(newValue, forKey: Key.ignoreSystem) }
    }

    public var keepWindowsOpen: Bool {
        get { userDefaults.bool(forKey: Key.keepWindowsOpen) }
        set { userDefaults.set(newValue, forKey: Key.keepWindowsOpen) }
    }

    public var waitBeforeRestore: Bool {
        get { userDefaults.bool(forKey: Key.waitCheckbox) }
        set { userDefaults.set(newValue, forKey: Key.waitCheckbox) }
    }

    public var globalShortcutsDisabled: Bool {
        get { userDefaults.bool(forKey: Key.switchKey) }
        set { userDefaults.set(newValue, forKey: Key.switchKey) }
    }

    public var hasSession: Bool {
        get { userDefaults.bool(forKey: Key.session) }
        set { userDefaults.set(newValue, forKey: Key.session) }
    }

    public var lastStateWasTerminate: Bool {
        get { userDefaults.bool(forKey: Key.lastState) }
        set { userDefaults.set(newValue, forKey: Key.lastState) }
    }

    public var savedAppURLs: [String] {
        get { userDefaults.stringArray(forKey: Key.apps) ?? [] }
        set { userDefaults.set(newValue, forKey: Key.apps) }
    }

    public var savedAppNames: [String] {
        get { userDefaults.stringArray(forKey: Key.appNames) ?? [] }
        set { userDefaults.set(newValue, forKey: Key.appNames) }
    }

    public var sessionName: String {
        get { userDefaults.string(forKey: Key.sessionName) ?? "" }
        set { userDefaults.set(newValue, forKey: Key.sessionName) }
    }

    public var sessionFullName: String {
        get { userDefaults.string(forKey: Key.sessionFullName) ?? "" }
        set { userDefaults.set(newValue, forKey: Key.sessionFullName) }
    }

    public var totalSessions: String {
        get { userDefaults.string(forKey: Key.totalSessions) ?? "" }
        set { userDefaults.set(newValue, forKey: Key.totalSessions) }
    }

    public var sessionDate: String {
        get { userDefaults.string(forKey: Key.date) ?? "" }
        set { userDefaults.set(newValue, forKey: Key.date) }
    }

    public var launchAtLoginEnabled: Bool {
        get { userDefaults.bool(forKey: Key.launchAtLogin) }
        set { userDefaults.set(newValue, forKey: Key.launchAtLogin) }
    }
}
