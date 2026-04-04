//
//  ViewController.swift
//  Test
//
//  Created by Alyssa X on 1/22/22.
//

import Cocoa
import SwiftUI
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
    private let lifecycleAdapter = AppLifecycleAdapter()
    private lazy var sessionRuntime = SessionRuntimeCoordinator(
        appFilter: appFilter,
        currentBundleIdentifier: Bundle.main.bundleIdentifier
    )
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
        appDelegate.launchAtLoginEnabled(isUITestMode: isUITestMode)
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
        let hooks = UITestHooks(arguments: ProcessInfo.processInfo.arguments)

        if hooks.enableWait {
            waitCheckbox.state = .on
            appViewModel.setWaitBeforeRestore(true)
        }

        if hooks.disableShortcuts {
            appDelegate.setShortcutsDisabled(true)
            checkKey.state = .on
        } else if hooks.enableShortcuts {
            appDelegate.setShortcutsDisabled(false)
            checkKey.state = .off
        }

        if hooks.toggleLaunchAtLogin {
            checkbox.state = checkbox.state == .on ? .off : .on
            startAtLogin(self)
        }

        if hooks.triggerSave {
            saveSessionGlobal()
        }

        if hooks.triggerShortcutSave {
            appDelegate.triggerSaveShortcutForTesting()
        }

        if hooks.triggerShortcutRestore {
            appDelegate.triggerRestoreShortcutForTesting()
        }

        if hooks.triggerRestore {
            restoreSessionGlobal()
        }

        if hooks.triggerCancelTimer {
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
            UITestStateStore.setTimerScheduled(true)
            writeUITestStateSnapshot()
        }
    }
    
    func checkAnyWindows() {
        let ignoreSystemApps = appViewModel.ignoreSystemApps
        let totalSessions: Int
        if isUITestStubMode {
            totalSessions = stubSessionAppsForSave().count
        } else {
            totalSessions = sessionRuntime.trackableRunningApps(
                includeTerminal: true,
                includeLater: false,
                ignoreSystemApps: ignoreSystemApps
            ).count
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
        appDelegate.setLaunchAtLoginEnabled(enabled, isUITestMode: isUITestMode)
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
                UITestStateStore.setTimerScheduled(false)
                writeUITestStateSnapshot()
            }
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
            UITestStateStore.setTimerScheduled(false)
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
        let ignoreSystemApps = appViewModel.ignoreSystemApps
        var capturedApps = [SessionCapturedApp]()
        var lastStateWasTerminate = false
        // keepWindowsOpen=true means hide apps; quitAppsInsteadOfHiding uses inverse semantics.
        let action = SessionSavePlanner.actionForSave(quitAppsInsteadOfHiding: !appViewModel.keepWindowsOpen)
        let sideEffectsPlan = SessionSaveSideEffectsPlanner.makePlan(isUITestStubMode: isUITestStubMode)
        lifecycleAdapter.applyPreSaveEffects(plan: sideEffectsPlan)

        if isUITestStubMode {
            for runningApplication in stubSessionAppsForSave() {
                capturedApps.append(
                    SessionCapturedApp(
                        localizedName: runningApplication.localizedName,
                        bundleIdentifier: runningApplication.bundleIdentifier,
                        bundleURLString: runningApplication.bundleURLString
                    )
                )
            }
            lastStateWasTerminate = SessionSavePlanner.lastStateWasTerminate(
                capturedApps: capturedApps,
                action: action
            )
        } else {
            let trackedApplications = sessionRuntime.trackableRunningApps(
                includeTerminal: true,
                includeLater: false,
                ignoreSystemApps: ignoreSystemApps
            )
            for runningApplication in trackedApplications {
                capturedApps.append(
                    SessionCapturedApp(
                        localizedName: runningApplication.localizedName ?? "",
                        bundleIdentifier: runningApplication.bundleIdentifier,
                        bundleURLString: runningApplication.bundleURL?.absoluteString
                    )
                )
            }
            // Apply hide/quit after collection so we don't mutate running apps while iterating.
            lastStateWasTerminate = sessionRuntime.applySavedAppAction(action, to: trackedApplications)
        }
        
        lifecycleAdapter.applyPostSaveEffects(plan: sideEffectsPlan)
        
        let snapshotDraft = SessionSavePlanner.makeDraft(from: capturedApps)
        let snapshot = SessionSnapshotComposer.makeSnapshot(
            draft: snapshotDraft,
            sessionDate: currentDateString(),
            lastStateWasTerminate: lastStateWasTerminate
        )

        // Save session data
        appViewModel.saveSessionSnapshot(snapshot)
        updateSession()
        if appViewModel.waitBeforeRestore {
            waitForSession()
        }
        
        if !isUITestMode {
            appDelegate.closePopover(self)
        }
        writeUITestStateSnapshot()
    }
    
    private func stubSessionAppsForSave() -> [StubSessionApp] {
        let ignoreSystemApps = appViewModel.ignoreSystemApps
        return uiTestStubApps.filter { app in
            if appFilter.shouldIgnore(
                bundleID: app.bundleIdentifier,
                ignoreSystemApps: ignoreSystemApps
            ) {
                return false
            }
            return true
        }
    }
    
    @objc func restoreSessionGlobal() {
        let ignoreSystemApps = appViewModel.ignoreSystemApps
        appViewModel.cancelRestoreTimer()

        let apps = appViewModel.savedSessionApps
        let executables = appViewModel.savedSessionURLs

        let restorePlan = SessionRestorePlanner.makePlan(
            isUITestStubMode: isUITestStubMode,
            closeAppsOnRestore: appViewModel.closeAppsOnRestore,
            appNames: apps,
            appURLs: executables
        )

        if let preRestoreAction = restorePlan.preRestoreAction {
            let runningApps = sessionRuntime.trackableRunningApps(
                includeTerminal: false,
                includeLater: true,
                ignoreSystemApps: ignoreSystemApps
            )
            _ = sessionRuntime.applySavedAppAction(preRestoreAction, to: runningApps)
        }

        if restorePlan.shouldRestoreApps {
            if !isUITestStubMode {
                sessionRuntime.restoreSavedApps(names: apps, urls: executables)
            }
            noSessions()
        }
        if isUITestMode {
            UITestStateStore.setTimerScheduled(false)
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
        if appViewModel.waitBeforeRestore {
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

    private func writeUITestStateSnapshot() {
        guard isUITestMode, let stateFileURL = uiTestStateFileURL else {
            return
        }

        do {
            let snapshot = UITestStateSnapshot(
                hasSession: appViewModel.hasSession,
                savedAppCount: appViewModel.savedSessionApps.count,
                timerScheduled: UITestStateStore.isTimerScheduled(),
                globalShortcutsDisabled: appDelegate.shortcutsDisabled,
                launchAtLoginEnabled: appViewModel.launchAtLogin
            )
            let data = try UITestStateEncoder.encode(snapshot)
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
