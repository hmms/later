//
//  ViewController.swift
//  Test
//
//  Created by Alyssa X on 1/22/22.
//

import Cocoa
import SwiftUI
import LaunchAtLogin
import LaterLogic

class ViewController: NSViewController {
    
    @IBOutlet var currentView: NSView!
    @IBOutlet weak var preview: NSImageView!
    @IBOutlet weak var button: NSButton!
    @IBOutlet weak var restore: NSButton!
    @IBOutlet weak var box: NSBox!
    @IBOutlet weak var dateLabel: NSTextField!
    @IBOutlet weak var sessionLabel: NSTextField!
    @IBOutlet weak var numberOfSessions: NSButton!
    @IBOutlet weak var checkbox: NSButton!
    @IBOutlet weak var ignoreFinder: NSButton!
    @IBOutlet weak var keepWindowsOpen: NSButton!
    @IBOutlet weak var waitCheckbox: NSButton!
    @IBOutlet weak var timeDropdown: NSPopUpButton!
    @IBOutlet weak var timeLabel: NSTextField!
    @IBOutlet weak var cancelTime: NSButton!
    @IBOutlet weak var timeWrapper: NSView!
    @IBOutlet weak var timeWrapperHeight: NSLayoutConstraint!
    @IBOutlet weak var closeApps: NSButton!
    var checkKey = NSMenuItem(title: "Disable all shortcuts", action: #selector(switchKey), keyEquivalent: "")
    
    
    let settingsMenu = NSMenu()
    
    
    @IBOutlet weak var boxHeight: NSLayoutConstraint!
    @IBOutlet weak var topBoxSpacing: NSLayoutConstraint!
    @IBOutlet weak var containerHeight: NSLayoutConstraint!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let popoverView = NSPopover()
    
    private var settings = SettingsStore()
    private lazy var appViewModel = AppViewModel(settingsStore: settings)
    private let appFilter = AppFilterService()
    private var isUITestMode: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_MODE")
    }
    private var uiTestStateFileURL: URL? {
        guard let path = ProcessInfo.processInfo.environment["UITEST_STATE_FILE"], !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }
    private var isUITestStubMode: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_STUB_SESSION")
    }
    private var launchAtLoginEnabled: Bool {
        if isUITestMode {
            return settings.launchAtLoginEnabled
        }
        return LaunchAtLogin.isEnabled
    }
    private struct StubSessionApp {
        let localizedName: String
        let bundleIdentifier: String
        let bundleURLString: String
    }
    private let uiTestStubApps: [StubSessionApp] = [
        StubSessionApp(
            localizedName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            bundleURLString: "file:///Applications/Safari.app"
        ),
        StubSessionApp(
            localizedName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            bundleURLString: "file:///Applications/Xcode.app"
        ),
        StubSessionApp(
            localizedName: "Finder",
            bundleIdentifier: "com.apple.finder",
            bundleURLString: "file:///System/Library/CoreServices/Finder.app"
        ),
    ]
    
    var observers = [NSKeyValueObservation]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appViewModel.refreshFromSettings(launchAtLoginEnabled: launchAtLoginEnabled)
        
        if (launchAtLoginEnabled) {
            checkbox.state = .on
        } else {
            checkbox.state = .off
        }
        
        if (appViewModel.closeAppsOnRestore) {
            closeApps.state = .on
        } else {
            closeApps.state = .off
        }
        
        if (appViewModel.ignoreSystemApps) {
            ignoreFinder.state = .on
        } else {
            ignoreFinder.state = .off
        }
        
        // Persisted value means "keep windows open" (hide apps). The checkbox label is inverse.
        if appViewModel.keepWindowsOpen {
            keepWindowsOpen.state = .off
        } else {
            keepWindowsOpen.state = .on
        }
        
        if (appViewModel.waitBeforeRestore) {
            waitCheckbox.state = .on
        } else {
            waitCheckbox.state = .off
        }
        
        if appDelegate.shortcutsDisabled {
            checkKey.state = .on
        } else {
            checkKey.state = .off
        }
        appDelegate.configureShortcutHandlers(
            onSave: { [weak self] in self?.saveSessionGlobal() },
            onRestore: { [weak self] in self?.restoreSessionGlobal() }
        )
        
        
        if (!appViewModel.hasSession) {
            noSessions()
        } else {
            updateSession()
        }
        
        setScreenshot()
        fixStyles()
        setUpMenu()
        setAccessibilityIdentifiers()
        
        observeModel()

        if isUITestMode {
            runUITestHooks()
            writeUITestStateSnapshot()
        }
    }

    private func runUITestHooks() {
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("UITEST_ENABLE_WAIT") {
            waitCheckbox.state = .on
            appViewModel.setWaitBeforeRestore(true)
        }

        if arguments.contains("UITEST_DISABLE_SHORTCUTS") {
            appDelegate.setShortcutsDisabled(true)
            checkKey.state = .on
        } else if arguments.contains("UITEST_ENABLE_SHORTCUTS") {
            appDelegate.setShortcutsDisabled(false)
            checkKey.state = .off
        }

        if arguments.contains("UITEST_TOGGLE_LAUNCH_AT_LOGIN") {
            checkbox.state = checkbox.state == .on ? .off : .on
            startAtLogin(self)
        }

        if arguments.contains("UITEST_TRIGGER_SAVE") {
            saveSessionGlobal()
        }

        if arguments.contains("UITEST_TRIGGER_SHORTCUT_SAVE") {
            appDelegate.triggerSaveShortcutForTesting()
        }

        if arguments.contains("UITEST_TRIGGER_SHORTCUT_RESTORE") {
            appDelegate.triggerRestoreShortcutForTesting()
        }

        if arguments.contains("UITEST_TRIGGER_RESTORE") {
            restoreSessionGlobal()
        }

        if arguments.contains("UITEST_TRIGGER_CANCEL_TIMER") {
            cancelTimeClick(self)
        }

        writeUITestStateSnapshot()
    }

    private func setAccessibilityIdentifiers() {
        applyTestIdentifier("saveSessionButton", to: button)
        applyTestIdentifier("restoreSessionButton", to: restore)
        applyTestIdentifier("ignoreSystemWindowsCheckbox", to: ignoreFinder)
        applyTestIdentifier("quitAppsCheckbox", to: closeApps)
        applyTestIdentifier("keepWindowsOpenCheckbox", to: keepWindowsOpen)
        applyTestIdentifier("waitBeforeRestoreCheckbox", to: waitCheckbox)
        applyTestIdentifier("launchAtLoginCheckbox", to: checkbox)
        applyTestIdentifier("reopenTimerLabel", to: timeLabel)
        applyTestIdentifier("cancelRestoreTimerButton", to: cancelTime)
        applyTestIdentifier("sessionNameLabel", to: sessionLabel)
        applyTestIdentifier("sessionDateLabel", to: dateLabel)
        applyTestIdentifier("sessionCountBadge", to: numberOfSessions)
    }

    private func applyTestIdentifier(_ identifier: String, to view: NSView) {
        view.identifier = NSUserInterfaceItemIdentifier(identifier)
        view.setAccessibilityIdentifier(identifier)
    }
    
    func observeModel() {
        self.observers = [
            NSWorkspace.shared.observe(\.runningApplications, options: [.initial]) {(model, change) in
                self.checkAnyWindows()
            }
        ]
    }
    
    // Set a timer to restore session
    func waitForSession() {
        let selectedOption = timeDropdown.titleOfSelectedItem ?? "15 minutes"
        appViewModel.scheduleRestoreTimer(
            durationOption: selectedOption,
            onTick: { [weak self] label in
                self?.timeLabel.stringValue = label
            },
            onComplete: { [weak self] in
                self?.restoreSessionGlobal()
            }
        )

        if isUITestMode {
            settingsStoreForUITestTimerState(true)
            writeUITestStateSnapshot()
        }
    }
    
    func checkAnyWindows() {
        let totalSessions: Int
        if isUITestStubMode {
            totalSessions = stubSessionAppsForSave().count
        } else {
            var runningTotal = 0
            for runningApplication in NSWorkspace.shared.runningApplications {
                if shouldTrackApplication(runningApplication, includeTerminal: true, includeLater: false) {
                    runningTotal += 1
                }
            }
            totalSessions = runningTotal
        }

        if (totalSessions == 0) {
            button.isEnabled = false
        } else {
            button.isEnabled = true
        }
    }
    
    @objc func openURL() {
        let url = URL(string: "https://twitter.com/alyssaxuu")
        NSWorkspace.shared.open(url!)
    }
    
    @objc func checkForUpdates() {
        // Use Sparkle to check for updates, not relevant in this version
    }
    
    @objc func switchKey() {
        if (checkKey.state == .on) {
            checkKey.state = .off
            appDelegate.setShortcutsDisabled(false)
        } else {
            checkKey.state = .on
            appDelegate.setShortcutsDisabled(true)
        }
        writeUITestStateSnapshot()
    }
    
    // Options menu
    func setUpMenu() {
        self.settingsMenu.addItem(NSMenuItem(title: "Visit website", action: #selector(openURL), keyEquivalent: ""))
        self.settingsMenu.addItem(checkKey)
        // Checking for updates, not relevant
        //self.settingsMenu.addItem(NSMenuItem(title: "Check for updates", action: #selector(checkForUpdates), keyEquivalent: ""))
        self.settingsMenu.addItem(NSMenuItem.separator())
        self.settingsMenu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "Q"))
        settingsMenu.appearance = NSAppearance.current
    }
    
    func setScreenshot() {
        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] as NSURL
        let fileUrl = documentsUrl.appendingPathComponent("screenshot.jpg")
        preview.image = NSImage(byReferencing: fileUrl!)
        preview.wantsLayer = true
        preview.layer?.cornerRadius = 10
    }
    
    // Styling fixes / overrides
    func fixStyles() {
        button.wantsLayer = true
        button.image = NSImage(named:"blue-button")
        button.imageScaling = .scaleAxesIndependently
        button.layer?.cornerRadius = 10

        restore.wantsLayer = true
        restore.image = NSImage(named:"green-button")
        restore.imageScaling = .scaleAxesIndependently
        restore.layer?.cornerRadius = 10
        
        numberOfSessions.wantsLayer = true
        numberOfSessions.layer?.backgroundColor = #colorLiteral(red: 0.9236671925, green: 0.1403781176, blue: 0.3365081847, alpha: 1)
        numberOfSessions.layer?.cornerRadius = numberOfSessions.frame.width / 2
        numberOfSessions.layer?.masksToBounds = true
        
        if let mutableAttributedTitle = numberOfSessions.attributedTitle.mutableCopy() as? NSMutableAttributedString {
            mutableAttributedTitle.addAttribute(.foregroundColor, value: NSColor.white, range: NSRange(location: 0, length: mutableAttributedTitle.length))
            numberOfSessions.attributedTitle = mutableAttributedTitle
        }
        
        checkbox.image?.size.height = 16
        checkbox.image?.size.width = 16
        checkbox.alternateImage?.size.height = 16
        checkbox.alternateImage?.size.width = 16
        
        if let mutableAttributedTitle = checkbox.attributedTitle.mutableCopy() as? NSMutableAttributedString {
            mutableAttributedTitle.addAttribute(.foregroundColor, value: #colorLiteral(red: 0.9136554599, green: 0.9137651324, blue: 0.9136180282, alpha: 1), range: NSRange(location: 0, length: mutableAttributedTitle.length))
            checkbox.attributedTitle = mutableAttributedTitle
        }
        
        closeApps.image?.size.height = 16
        closeApps.image?.size.width = 16
        closeApps.alternateImage?.size.height = 16
        closeApps.alternateImage?.size.width = 16
        
        if let mutableAttributedTitle = closeApps.attributedTitle.mutableCopy() as? NSMutableAttributedString {
            mutableAttributedTitle.addAttribute(.foregroundColor, value: #colorLiteral(red: 0.9136554599, green: 0.9137651324, blue: 0.9136180282, alpha: 1), range: NSRange(location: 0, length: mutableAttributedTitle.length))
            closeApps.attributedTitle = mutableAttributedTitle
        }
        
        ignoreFinder.image?.size.height = 16
        ignoreFinder.image?.size.width = 16
        ignoreFinder.alternateImage?.size.height = 16
        ignoreFinder.alternateImage?.size.width = 16
        
        if let mutableAttributedTitle = ignoreFinder.attributedTitle.mutableCopy() as? NSMutableAttributedString {
            mutableAttributedTitle.addAttribute(.foregroundColor, value: #colorLiteral(red: 0.9136554599, green: 0.9137651324, blue: 0.9136180282, alpha: 1), range: NSRange(location: 0, length: mutableAttributedTitle.length))
            ignoreFinder.attributedTitle = mutableAttributedTitle
        }
        
        keepWindowsOpen.image?.size.height = 16
        keepWindowsOpen.image?.size.width = 16
        keepWindowsOpen.alternateImage?.size.height = 16
        keepWindowsOpen.alternateImage?.size.width = 16
        
        if let mutableAttributedTitle = keepWindowsOpen.attributedTitle.mutableCopy() as? NSMutableAttributedString {
            mutableAttributedTitle.addAttribute(.foregroundColor, value: #colorLiteral(red: 0.9136554599, green: 0.9137651324, blue: 0.9136180282, alpha: 1), range: NSRange(location: 0, length: mutableAttributedTitle.length))
            keepWindowsOpen.attributedTitle = mutableAttributedTitle
        }
        
        waitCheckbox.image?.size.height = 16
        waitCheckbox.image?.size.width = 16
        waitCheckbox.alternateImage?.size.height = 16
        waitCheckbox.alternateImage?.size.width = 16
        
        if let mutableAttributedTitle = waitCheckbox.attributedTitle.mutableCopy() as? NSMutableAttributedString {
            mutableAttributedTitle.addAttribute(.foregroundColor, value: #colorLiteral(red: 0.9136554599, green: 0.9137651324, blue: 0.9136180282, alpha: 1), range: NSRange(location: 0, length: mutableAttributedTitle.length))
            waitCheckbox.attributedTitle = mutableAttributedTitle
        }
        
        timeDropdown.appearance = NSAppearance.current
        
        if let mutableAttributedTitle = cancelTime.attributedTitle.mutableCopy() as? NSMutableAttributedString {
            mutableAttributedTitle.addAttribute(.foregroundColor, value: #colorLiteral(red: 0.155318439, green: 0.5206356049, blue: 1, alpha: 1), range: NSRange(location: 0, length: mutableAttributedTitle.length))
            cancelTime.attributedTitle = mutableAttributedTitle
        }

        // Keep countdown glyph widths stable so the timer text does not jitter every second.
        let countdownSize = timeLabel.font?.pointSize ?? NSFont.systemFontSize
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: countdownSize, weight: .regular)
    }
    
    
    @IBAction func startAtLogin(_ sender: Any) {
        let enabled = checkbox.state == .on
        if !isUITestMode {
            LaunchAtLogin.isEnabled = enabled
        }
        appViewModel.setLaunchAtLogin(enabled)
        writeUITestStateSnapshot()
    }
    
    @IBAction func closeAppsCheck(_ sender: Any) {
        appViewModel.setCloseAppsOnRestore(closeApps.state == .on)
    }
    
    
    @IBAction func ignoreSystemWindows(_ sender: Any) {
        appViewModel.setIgnoreSystemApps(ignoreFinder.state == .on)
    }
    
    @IBAction func keepWindowsOpen(_ sender: Any) {
        // Persisted value keeps legacy meaning: true => keep windows open (hide apps).
        appViewModel.setKeepWindowsOpen(keepWindowsOpen.state == .off)
    }
    
    @IBAction func waitCheckboxChange(_ sender: Any) {
        let enabled = waitCheckbox.state == .on
        appViewModel.setWaitBeforeRestore(enabled)
        if !enabled {
            hideTimer()
            if isUITestMode {
                settingsStoreForUITestTimerState(false)
                writeUITestStateSnapshot()
            }
        }
    }
    
    // Take a screenshot of the workspace to remember how it was like
    func takeScreenshot() {
        guard let screenshot = CGDisplayCreateImage(CGMainDisplayID()) else {
            return
        }

        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] as NSURL
        let fileUrl = documentsUrl.appendingPathComponent("screenshot.jpg")
        let bitmapRep = NSBitmapImageRep(cgImage: screenshot)
        guard let jpegData = bitmapRep.representation(using: NSBitmapImageRep.FileType.jpeg, properties: [:]) else {
            return
        }

        do {
            try jpegData.write(to: fileUrl!, options: .atomic)
        } catch {
            print("error: \(error)")
        }
    }
    
    func currentDateString() -> String {
        let currentDateTime = Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .medium
        return formatter.string(from: currentDateTime)
    }
    
    
    @IBAction func click(_ sender: Any) {
        saveSessionGlobal()
        button.isEnabled = false
    }
    
    @IBAction func restoreSession(_ sender: Any) {
        restoreSessionGlobal()
    }
    
    @IBAction func hideBox(_ sender: Any) {
        noSessions()
    }
    
    @IBAction func settings(_ sender: NSButton) {
        let p = NSPoint(x: sender.frame.origin.x, y: sender.frame.origin.y - (sender.frame.height / 2))
        settingsMenu.popUp(positioning: nil, at: p, in: sender.superview)
    }
    
    @IBAction func cancelTimeClick(_ sender: Any) {
        appViewModel.cancelRestoreTimer()
        hideTimer()
        if isUITestMode {
            settingsStoreForUITestTimerState(false)
            writeUITestStateSnapshot()
        }
    }
    
    func hideTimer() {
        timeWrapperHeight.constant = 0
        boxHeight.constant = 206
        timeWrapper.isHidden = true
        currentView.needsLayout = true
        currentView.updateConstraints()
    }
    
    func showTimer() {
        timeWrapperHeight.constant = 40
        boxHeight.constant = 226
        timeWrapper.isHidden = false
        currentView.needsLayout = true
        currentView.updateConstraints()
    }

    func saveSessionGlobal() {
        var appURLs = [String]()
        var appNames = [String]()
        let action = SessionRules.actionForSavedApp(quitAppsInsteadOfHiding: keepWindowsOpen.state == .on)
        var lastStateWasTerminate = false

        if !isUITestStubMode {
            takeScreenshot()
            NSApp.setActivationPolicy(.regular)
        }

        if isUITestStubMode {
            for runningApplication in stubSessionAppsForSave() {
                appURLs.append(runningApplication.bundleURLString)
                appNames.append(runningApplication.localizedName)
                if action == .terminate {
                    lastStateWasTerminate = lastStateWasTerminate || SessionPresentation.shouldSetLastState(
                        keepWindowsOpen: false,
                        bundleIdentifier: runningApplication.bundleIdentifier
                    )
                }
            }
        } else {
            var trackedApplications = [NSRunningApplication]()
            for runningApplication in NSWorkspace.shared.runningApplications {
                if shouldTrackApplication(runningApplication, includeTerminal: true, includeLater: false) {
                    trackedApplications.append(runningApplication)
                    if let bundleURL = runningApplication.bundleURL {
                        appURLs.append(bundleURL.absoluteString)
                    }
                    if let localizedName = runningApplication.localizedName {
                        appNames.append(localizedName)
                    } else {
                        appNames.append("")
                    }
                }
            }
            // Apply hide/quit after collection so we don't mutate running apps while iterating.
            lastStateWasTerminate = applySavedAppAction(action, to: trackedApplications)
        }

        let summary = SessionPresentation.summarizeSession(appNames: appNames)
        
        if !isUITestStubMode {
            NSApp.setActivationPolicy(.accessory)
        }
        
        // Save session data
        let snapshot = SessionSnapshot(
            appURLs: appURLs,
            appNames: appNames,
            sessionName: summary.sessionName,
            sessionFullName: summary.sessionFullName,
            totalSessions: summary.totalSessions,
            sessionDate: currentDateString(),
            lastStateWasTerminate: lastStateWasTerminate
        )
        appViewModel.saveSessionSnapshot(snapshot)
        updateSession()
        if (waitCheckbox.state == .on) {
            waitForSession()
        }
        
        if !isUITestMode {
            appDelegate.closePopover(self)
        }
        writeUITestStateSnapshot()
    }
    
    private func appURL(from savedURLString: String) -> URL? {
        guard let parsedURL = URL(string: savedURLString) else {
            return nil
        }
        if parsedURL.pathExtension == "app" {
            return parsedURL
        }

        var candidate = parsedURL
        while candidate.path != "/" {
            if candidate.pathExtension == "app" {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }
        return nil
    }

    private func isFinderApp(_ runningApplication: NSRunningApplication) -> Bool {
        runningApplication.bundleIdentifier == "com.apple.finder"
    }

    private func applySavedAppAction(_ action: SavedAppAction, to applications: [NSRunningApplication]) -> Bool {
        switch action {
        case .hide:
            for runningApplication in applications {
                runningApplication.hide()
            }
            return false
        case .terminate:
            var terminatedAny = false
            for runningApplication in applications where !isFinderApp(runningApplication) {
                runningApplication.terminate()
                terminatedAny = true
            }
            return terminatedAny
        }
    }

    private func shouldTrackApplication(_ runningApplication: NSRunningApplication, includeTerminal: Bool, includeLater: Bool) -> Bool {
        let excludedBundleIDs: Set<String> = {
            guard let currentBundleID = Bundle.main.bundleIdentifier else {
                return []
            }
            return [currentBundleID]
        }()

        return appFilter.shouldTrack(
            activationPolicyIsRegular: runningApplication.activationPolicy == .regular,
            localizedName: runningApplication.localizedName,
            bundleIdentifier: runningApplication.bundleIdentifier,
            includeTerminal: includeTerminal,
            includeLater: includeLater,
            ignoreSystemApps: ignoreFinder.state == .on,
            excludedBundleIDs: excludedBundleIDs
        )
    }

    private func stubSessionAppsForSave() -> [StubSessionApp] {
        uiTestStubApps.filter { app in
            if appFilter.shouldIgnore(
                bundleID: app.bundleIdentifier,
                ignoreSystemApps: ignoreFinder.state == .on
            ) {
                return false
            }
            return true
        }
    }

    func activate(name: String, url: String) {
        guard let app = NSWorkspace.shared.runningApplications.filter ({
            return $0.localizedName == name
        }).first else {
            if let appURL = appURL(from: url) {
                NSWorkspace.shared.openApplication(
                    at: appURL,
                    configuration: NSWorkspace.OpenConfiguration()
                ) { _, error in
                    if let error = error {
                        print("Error opening \(appURL): \(error)")
                    }
                }
            }
            return
        }

        app.unhide()
    }
    
    @objc func restoreSessionGlobal() {
        appViewModel.cancelRestoreTimer()
        
        // Check if apps are to be terminated as opposed to hiding them
        if !isUITestStubMode {
            let action = SessionRules.actionForSavedApp(quitAppsInsteadOfHiding: closeApps.state == .on)
            if action == .terminate {
                for runningApplication in NSWorkspace.shared.runningApplications {
                    if shouldTrackApplication(runningApplication, includeTerminal: false, includeLater: true) {
                        runningApplication.terminate()
                    }
                }
            }
        }
        
        // Restore apps
        let apps = appViewModel.savedSessionApps
        let executables = appViewModel.savedSessionURLs
        if !apps.isEmpty && apps.count == executables.count {
            if !isUITestStubMode {
                for (index, app) in apps.enumerated() {
                    activate(name: app, url: executables[index])
                }
            }
            noSessions()
        }
        if isUITestMode {
            settingsStoreForUITestTimerState(false)
        }
        
        if !isUITestMode {
            appDelegate.closePopover(self)
        }
        writeUITestStateSnapshot()
    }
    
    // No sessions popover state
    func noSessions() {
        appViewModel.clearActiveSession()
        boxHeight.constant = 0
        topBoxSpacing.constant = 0
        containerHeight.constant = 290
        currentView.needsLayout = true
        currentView.updateConstraints()
        fixStyles()
        checkAnyWindows()
    }
    
    // New session or override
    func updateSession() {
        dateLabel.stringValue = appViewModel.sessionDate
        dateLabel.lineBreakMode = .byTruncatingTail
        sessionLabel.stringValue = appViewModel.sessionLabel
        sessionLabel.lineBreakMode = .byTruncatingTail
        sessionLabel.toolTip = appViewModel.sessionFullName
        numberOfSessions.title = String(appViewModel.sessionCount)
        if (waitCheckbox.state == .on) {
            showTimer()
        } else {
            hideTimer()
        }
        fixStyles()
        setScreenshot()
        topBoxSpacing.constant = 16
        containerHeight.constant = 520
        currentView.needsLayout = true
        currentView.updateConstraints()
        checkAnyWindows()
    }

    private func settingsStoreForUITestTimerState(_ isScheduled: Bool) {
        UserDefaults.standard.set(isScheduled, forKey: "uiTestTimerScheduled")
    }

    private func writeUITestStateSnapshot() {
        guard isUITestMode, let stateFileURL = uiTestStateFileURL else {
            return
        }

        let payload: [String: Any] = [
            "hasSession": appViewModel.hasSession,
            "savedAppCount": appViewModel.savedSessionApps.count,
            "timerScheduled": UserDefaults.standard.bool(forKey: "uiTestTimerScheduled"),
            "globalShortcutsDisabled": appDelegate.shortcutsDisabled,
            "launchAtLoginEnabled": appViewModel.launchAtLogin,
        ]

        guard JSONSerialization.isValidJSONObject(payload) else {
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            try data.write(to: stateFileURL, options: .atomic)
        } catch {
            print("Failed to write UI test snapshot: \(error)")
        }
    }
    
    private var appDelegate: AppDelegate {
        guard let appDelegate = NSApp.delegate as? AppDelegate else {
            fatalError("Expected AppDelegate")
        }
        return appDelegate
    }

}
