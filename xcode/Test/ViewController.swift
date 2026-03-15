//
//  ViewController.swift
//  Test
//
//  Created by Alyssa X on 1/22/22.
//

import Cocoa
import SwiftUI
import LaunchAtLogin
import HotKey
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
    
    
    var timer = Timer()
    var timerCount = Timer()
    let settingsMenu = NSMenu()
    var count: Double = 0.0
    
    
    @IBOutlet weak var boxHeight: NSLayoutConstraint!
    @IBOutlet weak var topBoxSpacing: NSLayoutConstraint!
    @IBOutlet weak var containerHeight: NSLayoutConstraint!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let popoverView = NSPopover()
    
    private var settings = SettingsStore()
    private let ignoredSystemBundleIDs: Set<String> = [
        "com.apple.finder",
        "com.apple.ActivityMonitor",
        "com.apple.systempreferences",
        "com.apple.AppStore"
    ]
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
    
    private var closeKey: HotKey? {
        didSet {
            guard let closeKey = closeKey else {
                return
            }

            closeKey.keyDownHandler = { [weak self] in
                self!.saveSessionGlobal()
            }
        }
    }
    
    private var restoreKey: HotKey? {
        didSet {
            guard let restoreKey = restoreKey else {
                return
            }

            restoreKey.keyDownHandler = { [weak self] in
                self!.restoreSessionGlobal()
            }
        }
    }
    
    var observers = [NSKeyValueObservation]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (launchAtLoginEnabled) {
            checkbox.state = .on
        } else {
            checkbox.state = .off
        }
        
        if (settings.closeAppsOnRestore) {
            closeApps.state = .on
        } else {
            closeApps.state = .off
        }
        
        if (settings.ignoreSystemApps) {
            ignoreFinder.state = .on
        } else {
            ignoreFinder.state = .off
        }
        
        if (settings.keepWindowsOpen) {
            keepWindowsOpen.state = .on
        } else {
            keepWindowsOpen.state = .off
        }
        
        if (settings.waitBeforeRestore) {
            waitCheckbox.state = .on
        } else {
            waitCheckbox.state = .off
        }
        
        if (settings.globalShortcutsDisabled) {
            checkKey.state = .on
            closeKey = nil
            restoreKey = nil
        } else {
            checkKey.state = .off
            closeKey = HotKey(key: .l, modifiers: [.command, .shift])
            restoreKey = HotKey(key: .r, modifiers: [.command, .shift])
        }
        
        
        if (!settings.hasSession) {
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
            settings.waitBeforeRestore = true
        }

        if arguments.contains("UITEST_DISABLE_SHORTCUTS") {
            settings.globalShortcutsDisabled = true
            checkKey.state = .on
            closeKey = nil
            restoreKey = nil
        } else if arguments.contains("UITEST_ENABLE_SHORTCUTS") {
            settings.globalShortcutsDisabled = false
            checkKey.state = .off
            closeKey = HotKey(key: .l, modifiers: [.command, .shift])
            restoreKey = HotKey(key: .r, modifiers: [.command, .shift])
        }

        if arguments.contains("UITEST_TOGGLE_LAUNCH_AT_LOGIN") {
            checkbox.state = checkbox.state == .on ? .off : .on
            startAtLogin(self)
        }

        if arguments.contains("UITEST_TRIGGER_SAVE") {
            saveSessionGlobal()
        }

        if arguments.contains("UITEST_TRIGGER_SHORTCUT_SAVE") {
            closeKey?.keyDownHandler?()
        }

        if arguments.contains("UITEST_TRIGGER_SHORTCUT_RESTORE") {
            restoreKey?.keyDownHandler?()
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
    
    @objc func counter() {
        if (count >= 0) {
            count -= 1.0
            hmsFrom(seconds: Int(count)) { hours, minutes, seconds in
                let hours = self.getStringFrom(seconds: hours)
                let minutes = self.getStringFrom(seconds: minutes)
                let seconds = self.getStringFrom(seconds: seconds)
                self.timeLabel.stringValue = "Reopening in "+"\(hours):\(minutes):\(seconds)"
            }
        } else {
            timerCount.invalidate()
        }
    }
    
    // Set a timer to restore session
    func waitForSession() {
        var time: Double = 10
        if (timeDropdown.titleOfSelectedItem == "15 minutes") {
            time = 60*15
        } else if (timeDropdown.titleOfSelectedItem == "30 minutes") {
            time = 60*30
        } else if (timeDropdown.titleOfSelectedItem == "1 hour") {
            time = 60*60
        } else if (timeDropdown.titleOfSelectedItem == "5 hours") {
            time = 60*60*5
        }
        count = time
        hmsFrom(seconds: Int(count)) { hours, minutes, seconds in
            let hours = self.getStringFrom(seconds: hours)
            let minutes = self.getStringFrom(seconds: minutes)
            let seconds = self.getStringFrom(seconds: seconds)
            self.timeLabel.stringValue = "Reopening in "+"\(hours):\(minutes):\(seconds)"
        }
        timer = Timer.scheduledTimer(timeInterval: time, target: self, selector: #selector(restoreSessionGlobal), userInfo: nil, repeats: false)
        timerCount = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(counter), userInfo: nil, repeats: true)
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
            settings.globalShortcutsDisabled = false
            closeKey = HotKey(key: .l, modifiers: [.command, .shift])
            restoreKey = HotKey(key: .r, modifiers: [.command, .shift])
        } else {
            checkKey.state = .on
            settings.globalShortcutsDisabled = true
            restoreKey = nil
            closeKey = nil
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
    }
    
    
    @IBAction func startAtLogin(_ sender: Any) {
        let enabled = checkbox.state == .on
        if isUITestMode {
            settings.launchAtLoginEnabled = enabled
            writeUITestStateSnapshot()
            return
        }
        LaunchAtLogin.isEnabled = enabled
    }
    
    @IBAction func closeAppsCheck(_ sender: Any) {
        if (closeApps.state == .on) {
            settings.closeAppsOnRestore = true
        } else {
            settings.closeAppsOnRestore = false
        }
    }
    
    
    @IBAction func ignoreSystemWindows(_ sender: Any) {
        if (ignoreFinder.state == .on) {
            settings.ignoreSystemApps = true
        } else {
            settings.ignoreSystemApps = false
        }
    }
    
    @IBAction func keepWindowsOpen(_ sender: Any) {
        if (keepWindowsOpen.state == .on) {
            settings.keepWindowsOpen = true
        } else {
            settings.keepWindowsOpen = false
        }
    }
    
    @IBAction func waitCheckboxChange(_ sender: Any) {
        if (waitCheckbox.state == .on) {
            settings.waitBeforeRestore = true
        } else {
            settings.waitBeforeRestore = false
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
    
    func getCurrentDate() {
        let currentDateTime = Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .medium
        settings.sessionDate = formatter.string(from: currentDateTime)
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
        timer.invalidate()
        timerCount.invalidate()
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
        var array = [String]()
        var arrayNames = [String]()
        var sessionName = ""
        var sessionFull = ""
        var sessionsAdded = 1
        var sessionsRemaining = 0
        var totalSessions = 0
        var lastState = false;
        
        if !isUITestStubMode {
            takeScreenshot()
            NSApp.setActivationPolicy(.regular)
        }

        if isUITestStubMode {
            for runningApplication in stubSessionAppsForSave() {
                array.append(runningApplication.bundleURLString)
                arrayNames.append(runningApplication.localizedName)

                if keepWindowsOpen.state == .off && runningApplication.bundleIdentifier != "com.apple.finder" {
                    lastState = true
                }

                if sessionName == "" {
                    sessionName = runningApplication.localizedName
                    sessionFull = runningApplication.localizedName
                } else if (sessionsAdded <= 3) {
                    sessionName += ", " + runningApplication.localizedName
                } else {
                    sessionsRemaining += 1
                }
                sessionFull += ", " + runningApplication.localizedName
                sessionsAdded += 1
                totalSessions += 1
            }
        } else {
            for runningApplication in NSWorkspace.shared.runningApplications {
                if shouldTrackApplication(runningApplication, includeTerminal: true, includeLater: false) {
                    if let bundleURL = runningApplication.bundleURL {
                        array.append(bundleURL.absoluteString)
                    }
                    if let localizedName = runningApplication.localizedName {
                        arrayNames.append(localizedName)
                    } else {
                        arrayNames.append("")
                    }

                    // Keep windows open by hiding apps; otherwise terminate.
                    if (keepWindowsOpen.state == .on) {
                        runningApplication.hide()
                    } else {
                        if !isFinderApp(runningApplication) {
                            runningApplication.terminate()
                        }
                        lastState = true
                    }

                    // Get application names for session label
                    if let localizedName = runningApplication.localizedName {
                        if (sessionName == "") {
                            sessionName = localizedName
                            sessionFull = localizedName
                        } else if (sessionsAdded <= 3) {
                            sessionName += ", " + localizedName
                        } else {
                            sessionsRemaining += 1
                        }
                        sessionFull += ", " + localizedName
                    }

                    sessionsAdded += 1
                    totalSessions += 1
                }
            }
        }
        
        if (sessionsRemaining > 0) {
            sessionName += ", +"+String(sessionsRemaining)+" more"
        }
        
        if !isUITestStubMode {
            NSApp.setActivationPolicy(.accessory)
        }
        
        // Save session data
        settings.lastStateWasTerminate = lastState
        settings.savedAppURLs = array
        settings.savedAppNames = arrayNames
        settings.sessionName = sessionName
        settings.sessionFullName = sessionFull
        settings.totalSessions = String(totalSessions)
        getCurrentDate()
        updateSession()
        if (waitCheckbox.state == .on) {
            waitForSession()
        }
        
        if !isUITestMode {
            let appDelegate = NSApp.delegate as! AppDelegate
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

    private func shouldIgnoreSystemApplication(_ runningApplication: NSRunningApplication) -> Bool {
        guard ignoreFinder.state == .on else {
            return false
        }
        return ignoredSystemBundleIDs.contains(runningApplication.bundleIdentifier ?? "")
    }

    private func isFinderApp(_ runningApplication: NSRunningApplication) -> Bool {
        runningApplication.bundleIdentifier == "com.apple.finder"
    }

    private func shouldTrackApplication(_ runningApplication: NSRunningApplication, includeTerminal: Bool, includeLater: Bool) -> Bool {
        if runningApplication.activationPolicy != .regular {
            return false
        }
        if !includeLater && runningApplication.localizedName == "Later" {
            return false
        }
        if !includeTerminal && runningApplication.localizedName == "Terminal" {
            return false
        }
        if shouldIgnoreSystemApplication(runningApplication) {
            return false
        }
        return true
    }

    private func stubSessionAppsForSave() -> [StubSessionApp] {
        uiTestStubApps.filter { app in
            if ignoreFinder.state == .on && ignoredSystemBundleIDs.contains(app.bundleIdentifier) {
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
        
        // Check if apps are to be terminated as opposed to hiding them
        if (closeApps.state == .on && !isUITestStubMode) {
            for runningApplication in NSWorkspace.shared.runningApplications {
                if shouldTrackApplication(runningApplication, includeTerminal: false, includeLater: true) {
                    runningApplication.terminate()
                }
            }
        }
        
        // Restore apps
        let apps = settings.savedAppNames
        let executables = settings.savedAppURLs
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
            let appDelegate = NSApp.delegate as! AppDelegate
            appDelegate.closePopover(self)
        }
        writeUITestStateSnapshot()
    }
    
    // No sessions popover state
    func noSessions() {
        settings.hasSession = false
        boxHeight.constant = 0
        topBoxSpacing.constant = 0
        containerHeight.constant = 290
        currentView.needsLayout = true
        currentView.updateConstraints()
        fixStyles()
        checkAnyWindows()
    }
    
    func hmsFrom(seconds: Int, completion: @escaping (_ hours: Int, _ minutes: Int, _ seconds: Int)->()) {
        completion(seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
    }

    func getStringFrom(seconds: Int) -> String {
        return seconds < 10 ? "0\(seconds)" : "\(seconds)"
    }
    
    // New session or override
    func updateSession() {
        settings.hasSession = true
        dateLabel.stringValue = settings.sessionDate
        dateLabel.lineBreakMode = .byTruncatingTail
        sessionLabel.stringValue = settings.sessionName
        sessionLabel.lineBreakMode = .byTruncatingTail
        sessionLabel.toolTip = settings.sessionFullName
        numberOfSessions.title = settings.totalSessions
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
            "hasSession": settings.hasSession,
            "savedAppCount": settings.savedAppNames.count,
            "timerScheduled": UserDefaults.standard.bool(forKey: "uiTestTimerScheduled"),
            "globalShortcutsDisabled": settings.globalShortcutsDisabled,
            "launchAtLoginEnabled": settings.launchAtLoginEnabled,
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
    
}
