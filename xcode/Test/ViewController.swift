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
        configureTimerDropdown()
        renderSettingsControls()
        appDelegate.configureShortcutHandlers(
            onSave: { [weak self] in self?.saveSessionGlobal() },
            onRestore: { [weak self] in self?.restoreSessionGlobal() }
        )

        configureStaticAppearance()
        renderSessionState()
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
        let actions = UITestActionPlan.makeActions(from: hooks)

        for action in actions {
            handleUITestAction(action)
        }

        writeUITestStateSnapshot()
    }

    private func handleUITestAction(_ action: UITestAction) {
        switch action {
        case .enableWait:
            applyWaitBeforeRestore(true)
        case .disableShortcuts:
            applyShortcutsDisabled(true)
        case .enableShortcuts:
            applyShortcutsDisabled(false)
        case .toggleLaunchAtLogin:
            applyLaunchAtLogin(!appViewModel.launchAtLogin)
        case .triggerSave:
            saveSessionGlobal()
        case .triggerShortcutSave:
            appDelegate.triggerSaveShortcutForTesting()
        case .triggerShortcutRestore:
            appDelegate.triggerRestoreShortcutForTesting()
        case .triggerRestore:
            restoreSessionGlobal()
        case .triggerCancelTimer:
            cancelTimeClick(self)
        }
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

    private func configureTimerDropdown() {
        timeDropdown.target = self
        timeDropdown.action = #selector(timerDurationChanged(_:))
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
        let selectedOption = appViewModel.selectedTimerDuration
        appViewModel.scheduleRestoreTimer(
            durationOption: selectedOption,
            onTick: { [weak self] label in
                self?.timeLabel.stringValue = label
            },
            onComplete: { [weak self] in
                self?.restoreSessionGlobal()
            }
        )
        renderTimerVisibility()
        updateUITestTimerScheduled(true, writeSnapshot: true)
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
        appViewModel.refreshSaveAvailability(trackableAppCount: totalSessions)
        renderSaveAvailability()
    }
    
    @objc func openURL() {
        let url = URL(string: "https://twitter.com/alyssaxuu")
        NSWorkspace.shared.open(url!)
    }
    
    @objc func checkForUpdates() {
        // Use Sparkle to check for updates, not relevant in this version
    }
    
    @objc func switchKey() {
        applyShortcutsDisabled(!appDelegate.shortcutsDisabled)
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
    
    private func renderPreviewImage() {
        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] as NSURL
        let fileUrl = documentsUrl.appendingPathComponent("screenshot.jpg")
        preview.image = NSImage(byReferencing: fileUrl!)
        preview.wantsLayer = true
        preview.layer?.cornerRadius = 10
    }
    
    // One-time styling setup for static controls.
    private func configureStaticAppearance() {
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
        applyLaunchAtLogin(enabled)
    }
    
    @IBAction func closeAppsCheck(_ sender: Any) {
        applyCloseAppsOnRestore(closeApps.state == .on)
    }
    
    
    @IBAction func ignoreSystemWindows(_ sender: Any) {
        applyIgnoreSystemApps(ignoreFinder.state == .on)
    }
    
    @IBAction func keepWindowsOpen(_ sender: Any) {
        // Persisted value keeps legacy meaning: true => keep windows open (hide apps).
        applyKeepWindowsOpen(keepWindowsOpen.state == .off)
    }
    
    @IBAction func waitCheckboxChange(_ sender: Any) {
        applyWaitBeforeRestore(waitCheckbox.state == .on)
    }

    @objc private func timerDurationChanged(_ sender: NSPopUpButton) {
        applySelectedTimerDuration(sender.titleOfSelectedItem ?? "15 minutes")
    }

    private func renderSettingsControls() {
        applyControlState(appViewModel.launchAtLogin, to: checkbox)
        applyControlState(appViewModel.closeAppsOnRestore, to: closeApps)
        applyControlState(appViewModel.ignoreSystemApps, to: ignoreFinder)
        applyControlState(appViewModel.waitBeforeRestore, to: waitCheckbox)
        renderKeepWindowsOpenControl()
        renderTimerDurationControl()
        renderShortcutsMenuItem()
    }

    private func applyControlState(_ enabled: Bool, to control: NSButton) {
        control.state = enabled ? .on : .off
    }

    private func renderKeepWindowsOpenControl() {
        // Persisted value means "keep windows open" (hide apps). The checkbox label is inverse.
        keepWindowsOpen.state = appViewModel.keepWindowsOpen ? .off : .on
    }

    private func renderTimerDurationControl() {
        timeDropdown.selectItem(withTitle: appViewModel.selectedTimerDuration)
    }

    private func renderShortcutsMenuItem() {
        checkKey.state = appDelegate.shortcutsDisabled ? .on : .off
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        appDelegate.setLaunchAtLoginEnabled(enabled, isUITestMode: isUITestMode)
        appViewModel.setLaunchAtLogin(enabled)
        renderSettingsControls()
        writeUITestStateSnapshot()
    }

    private func applyCloseAppsOnRestore(_ enabled: Bool) {
        appViewModel.setCloseAppsOnRestore(enabled)
        renderSettingsControls()
        writeUITestStateSnapshot()
    }

    private func applyIgnoreSystemApps(_ enabled: Bool) {
        appViewModel.setIgnoreSystemApps(enabled)
        renderSettingsControls()
        writeUITestStateSnapshot()
    }

    private func applyKeepWindowsOpen(_ enabled: Bool) {
        appViewModel.setKeepWindowsOpen(enabled)
        renderSettingsControls()
        writeUITestStateSnapshot()
    }

    private func applyWaitBeforeRestore(_ enabled: Bool) {
        appViewModel.setWaitBeforeRestore(enabled)
        renderSettingsControls()
        renderTimerVisibility()
        if !enabled {
            updateUITestTimerScheduled(false, writeSnapshot: false)
        }
        writeUITestStateSnapshot()
    }

    private func applySelectedTimerDuration(_ value: String) {
        appViewModel.refreshSelectedTimerDuration(value)
        renderSettingsControls()
        writeUITestStateSnapshot()
    }

    private func applyShortcutsDisabled(_ disabled: Bool) {
        appDelegate.setShortcutsDisabled(disabled)
        renderSettingsControls()
        writeUITestStateSnapshot()
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
        appViewModel.refreshSaveAvailability(trackableAppCount: 0)
        renderSaveAvailability()
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
        handleRestoreTimerCancelled(writeSnapshot: true)
    }

    private func renderSessionState() {
        if appViewModel.hasSession {
            renderSavedSession()
        } else {
            renderNoSessionState()
        }
        renderPreviewImage()
        renderSaveAvailability()
        currentView.needsLayout = true
        currentView.updateConstraints()
        checkAnyWindows()
    }

    private func renderSaveAvailability() {
        button.isEnabled = appViewModel.isSaveEnabled
    }

    private func renderSavedSession() {
        dateLabel.stringValue = appViewModel.sessionDate
        dateLabel.lineBreakMode = .byTruncatingTail
        sessionLabel.stringValue = appViewModel.sessionLabel
        sessionLabel.lineBreakMode = .byTruncatingTail
        sessionLabel.toolTip = appViewModel.sessionFullName
        numberOfSessions.title = String(appViewModel.sessionCount)
        renderSavedSessionLayout()
        renderTimerVisibility()
    }

    private func renderNoSessionState() {
        renderEmptySessionLayout()
    }

    private func renderTimerVisibility() {
        timeLabel.stringValue = appViewModel.timerLabel ?? ""
        applyTimerLayout(isVisible: appViewModel.isTimerVisible)
    }

    private func renderSavedSessionLayout() {
        topBoxSpacing.constant = 16
        containerHeight.constant = 520
    }

    private func renderEmptySessionLayout() {
        boxHeight.constant = 0
        topBoxSpacing.constant = 0
        containerHeight.constant = 290
        timeWrapperHeight.constant = 0
        timeWrapper.isHidden = true
    }

    private func applyTimerLayout(isVisible: Bool) {
        if isVisible {
            timeWrapperHeight.constant = 40
            boxHeight.constant = 226
            timeWrapper.isHidden = false
        } else {
            timeWrapperHeight.constant = 0
            boxHeight.constant = 206
            timeWrapper.isHidden = true
        }
        currentView.needsLayout = true
        currentView.updateConstraints()
    }

    private func handleRestoreTimerCancelled(writeSnapshot: Bool) {
        appViewModel.cancelRestoreTimer()
        renderTimerVisibility()
        updateUITestTimerScheduled(false, writeSnapshot: writeSnapshot)
    }

    private func updateUITestTimerScheduled(_ scheduled: Bool, writeSnapshot: Bool) {
        guard isUITestMode else {
            return
        }
        UITestStateStore.setTimerScheduled(scheduled)
        if writeSnapshot {
            writeUITestStateSnapshot()
        }
    }

    private func finishControllerAction() {
        closePopoverIfNeeded()
        writeUITestStateSnapshot()
    }

    private func closePopoverIfNeeded() {
        if !isUITestMode {
            appDelegate.closePopover(self)
        }
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
        renderSessionState()
        if appViewModel.waitBeforeRestore {
            waitForSession()
        }
        finishControllerAction()
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
        handleRestoreTimerCancelled(writeSnapshot: false)

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
        finishControllerAction()
    }
    
    // No sessions popover state
    func noSessions() {
        appViewModel.clearActiveSession()
        renderSessionState()
    }
    
    // New session or override
    func updateSession() {
        renderSessionState()
    }

    private func writeUITestStateSnapshot() {
        guard isUITestMode, let stateFileURL = uiTestStateFileURL else {
            return
        }

        do {
            let snapshot = UITestStateSnapshotComposer.makeSnapshot(
                hasSession: appViewModel.hasSession,
                savedAppCount: appViewModel.savedSessionApps.count,
                timerScheduled: UITestStateStore.isTimerScheduled(),
                globalShortcutsDisabled: appDelegate.shortcutsDisabled,
                launchAtLoginEnabled: appViewModel.launchAtLogin
            )
            try UITestStateWriter.write(snapshot, to: stateFileURL)
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
