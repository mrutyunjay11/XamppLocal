import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let cli = XamppCLI()
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var windowController: ControlWindowController?
    private var lastStatus: StackStatus?
    private var busy = false

    private(set) lazy var appLogoImage: NSImage? = {
        if let url = Bundle.main.url(forResource: "logo", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        return nil
    }()

    private let dockPrefKey = "KeepIconInDock"
    var keepInDock: Bool {
        get { UserDefaults.standard.bool(forKey: dockPrefKey) }
        set { UserDefaults.standard.set(newValue, forKey: dockPrefKey) }
    }

    private var mainMasterItem: NSMenuItem?
    private var mainPmaItem: NSMenuItem?
    private var mainStopQuitItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let logo = appLogoImage {
            NSApp.applicationIconImage = logo
        }
        setupMainMenu()
        NSApp.setActivationPolicy(keepInDock ? .regular : .accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = menu
        menu.delegate = self
        updateMenuIcon(running: false)
        rebuildMenu()
        refreshStatus(includeMemory: false)
    }

    private func makeItem(_ title: String, action: Selector?, key: String, mods: NSEvent.ModifierFlags = [.command], target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = mods
        item.target = target
        return item
    }

    private func setupMainMenu() {
        let bar = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(makeItem("About XamppControl", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), key: "", target: NSApp))
        appMenu.addItem(.separator())
        let stopQuit = makeItem("Stop All Servers & Quit", action: #selector(menuStopAndQuit), key: "q", mods: [.command, .option], target: self)
        mainStopQuitItem = stopQuit
        appMenu.addItem(stopQuit)
        appMenu.addItem(makeItem("Quit XamppControl (Keep Servers Running)", action: #selector(NSApplication.terminate(_:)), key: "q", target: NSApp))
        appMenuItem.submenu = appMenu
        bar.addItem(appMenuItem)

        // Stack menu
        let stackMenuItem = NSMenuItem()
        let stackMenu = NSMenu(title: "Stack")
        let master = makeItem("Start All Services", action: #selector(menuToggleAll), key: "s", target: self)
        mainMasterItem = master
        stackMenu.addItem(master)
        stackMenu.addItem(makeItem("Refresh & Measure RAM", action: #selector(menuMeasureRAM), key: "r", target: self))
        stackMenu.addItem(.separator())
        stackMenu.addItem(makeItem("Switch Website Folder...", action: #selector(browseAndSwitchWebRoot), key: "l", target: self))
        stackMenu.addItem(makeItem("Reset Website Folder to Default", action: #selector(resetWebRoot), key: "l", mods: [.command, .shift], target: self))
        stackMenu.addItem(.separator())
        stackMenu.addItem(makeItem("Open Site in Browser", action: #selector(openLocalhost), key: "o", target: self))
        let pma = makeItem("Open phpMyAdmin", action: #selector(openPhpMyAdmin), key: "p", target: self)
        mainPmaItem = pma
        stackMenu.addItem(pma)
        stackMenu.addItem(makeItem("Run Doctor Checks", action: #selector(runDoctor), key: "d", target: self))
        stackMenuItem.submenu = stackMenu
        bar.addItem(stackMenuItem)

        // Edit menu (enables Cmd+C/V/X/A in dialogs & alerts)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(makeItem("Cut", action: #selector(NSText.cut(_:)), key: "x"))
        editMenu.addItem(makeItem("Copy", action: #selector(NSText.copy(_:)), key: "c"))
        editMenu.addItem(makeItem("Paste", action: #selector(NSText.paste(_:)), key: "v"))
        editMenu.addItem(makeItem("Select All", action: #selector(NSText.selectAll(_:)), key: "a"))
        editMenuItem.submenu = editMenu
        bar.addItem(editMenuItem)

        // Window menu
        let winMenuItem = NSMenuItem()
        let winMenu = NSMenu(title: "Window")
        winMenu.addItem(makeItem("Open Control Window", action: #selector(openControlWindow), key: "k", target: self))
        winMenu.addItem(makeItem("Close Window", action: #selector(NSWindow.performClose(_:)), key: "w"))
        winMenu.addItem(makeItem("Minimize", action: #selector(NSWindow.performMiniaturize(_:)), key: "m"))
        winMenuItem.submenu = winMenu
        bar.addItem(winMenuItem)

        NSApp.mainMenu = bar
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshStatus(includeMemory: windowController != nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openControlWindow() }
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard let first = filenames.first else { return }
        switchWebRoot(first, openInBrowser: true)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        switchWebRoot(filename, openInBrowser: true)
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Never auto-stop running servers on app quit; long-running projects stay alive unless explicitly stopped.
        cli.cancelAllWatchers()
        return .terminateNow
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshStatus(includeMemory: false)
    }

    func refreshStatus(includeMemory: Bool) {
        cli.fetchStatus(includeMemory: includeMemory) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let status):
                self.lastStatus = status
                let anyRunning = status.services.apache.isRunning || status.services.phpFpm.isRunning || status.services.db.isRunning
                self.updateMenuIcon(running: anyRunning)
                let pids = [status.services.apache.pid, status.services.phpFpm.pid, status.services.db.pid].compactMap { $0 }
                self.cli.watchProcesses(pids: pids) { [weak self] in
                    self?.refreshStatus(includeMemory: self?.windowController != nil)
                }
                self.rebuildMenu()
                self.windowController?.update(status: status, busy: self.busy)
                if let r = status.readiness, !r.isReady, self.windowController == nil {
                    self.openControlWindow()
                }
            case .failure(let err):
                self.rebuildMenu(error: err.localizedDescription)
            }
        }
    }

    private func makeMenuBarRackIcon(running: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { _ in
            NSColor.labelColor.setStroke()
            NSColor.labelColor.setFill()
            let ys: [CGFloat] = [2.5, 7.25, 12.0]
            for (idx, y) in ys.enumerated() {
                let blade = NSBezierPath(roundedRect: NSRect(x: 1.5, y: y, width: 15.0, height: 3.5), xRadius: 1.2, yRadius: 1.2)
                blade.lineWidth = 1.2
                if running {
                    blade.fill()
                    NSColor.clear.setFill()
                } else {
                    blade.stroke()
                }
                if !running {
                    let dot = NSBezierPath(ovalIn: NSRect(x: 3.0, y: y + 1.0, width: 1.5, height: 1.5))
                    NSColor.labelColor.setFill()
                    dot.fill()
                } else if idx == 2 {
                    NSColor.labelColor.setFill()
                }
            }
            return true
        }
        img.isTemplate = true
        return img
    }

    private func updateMenuIcon(running: Bool) {
        if busy, let spin = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "XamppLocal") {
            spin.isTemplate = true
            statusItem.button?.image = spin
        } else {
            statusItem.button?.image = makeMenuBarRackIcon(running: running)
        }
        statusItem.button?.toolTip = running ? "XamppLocal: Running" : "XamppLocal: Stopped"
    }

    private func rebuildMenu(error: String? = nil) {
        menu.removeAllItems()
        if let error {
            let errItem = NSMenuItem(title: "Error: \(error)", action: nil, keyEquivalent: "")
            errItem.isEnabled = false
            menu.addItem(errItem)
        }

        let st = lastStatus
        let anyRunning = (st?.services.apache.isRunning ?? false) || (st?.services.phpFpm.isRunning ?? false) || (st?.services.db.isRunning ?? false)

        mainMasterItem?.title = anyRunning ? "Stop All Services" : "Start All Services"
        mainMasterItem?.isEnabled = !busy
        mainPmaItem?.isEnabled = st?.phpmyadminAvailable ?? false
        mainStopQuitItem?.isEnabled = anyRunning && !busy

        let header = NSMenuItem(
            title: anyRunning ? "XamppLocal: Running (127.0.0.1:\(st?.httpPort ?? 8080))" : "XamppLocal: Stopped (0 MB)",
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        if let r = st?.readiness, !r.isReady {
            let setupItem = NSMenuItem(title: "⚠️ Setup Required (Click to Set Up)", action: #selector(openControlWindow), keyEquivalent: "")
            setupItem.target = self
            menu.addItem(setupItem)
            menu.addItem(.separator())
        }

        let master = NSMenuItem(title: anyRunning ? "Stop All Services" : "Start All Services", action: #selector(menuToggleAll), keyEquivalent: "s")
        master.target = self
        master.isEnabled = !busy
        menu.addItem(master)

        if let st {
            menu.addItem(makeServiceMenuItem(title: "Apache (\(st.services.apache.status))", action: #selector(menuToggleApache)))
            menu.addItem(makeServiceMenuItem(title: "PHP-FPM (\(st.services.phpFpm.status))", action: #selector(menuTogglePHP)))
            menu.addItem(makeServiceMenuItem(title: "DB: \(st.dbEngine) (\(st.services.db.status))", action: #selector(menuToggleDB), enabled: st.dbEngine != "sqlite"))

            if st.services.apache.footprintMb + st.services.phpFpm.footprintMb + st.services.db.footprintMb > 0 {
                let total = st.services.apache.footprintMb + st.services.phpFpm.footprintMb + st.services.db.footprintMb
                let memItem = NSMenuItem(title: String(format: "Footprint: %.2f MB", total), action: nil, keyEquivalent: "")
                memItem.isEnabled = false
                menu.addItem(memItem)
            }
            let meas = NSMenuItem(title: "Measure RAM (footprint)...", action: #selector(menuMeasureRAM), keyEquivalent: "r")
            meas.target = self
            menu.addItem(meas)

            menu.addItem(.separator())
            // Laragon-style website folder switcher
            let folderName = (st.webRoot as NSString).lastPathComponent
            let rootInfo = NSMenuItem(title: "Website Folder: \(folderName)", action: nil, keyEquivalent: "")
            rootInfo.isEnabled = false
            menu.addItem(rootInfo)

            let browseItem = NSMenuItem(title: "Switch Website Folder...", action: #selector(browseAndSwitchWebRoot), keyEquivalent: "l")
            browseItem.target = self
            browseItem.isEnabled = !busy
            menu.addItem(browseItem)

            let recentsSub = NSMenu()
            for p in (st.recentWebRoots ?? [st.webRoot]) {
                let item = NSMenuItem(title: p, action: #selector(menuSelectRecentRoot(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = p
                item.state = (p == st.webRoot) ? .on : .off
                recentsSub.addItem(item)
            }
            recentsSub.addItem(.separator())
            let resetItem = NSMenuItem(title: "Reset to Default (~/Sites/Xampp)", action: #selector(resetWebRoot), keyEquivalent: "")
            resetItem.target = self
            recentsSub.addItem(resetItem)
            let recentsMenu = NSMenuItem(title: "Recent Website Folders", action: nil, keyEquivalent: "")
            recentsMenu.submenu = recentsSub
            menu.addItem(recentsMenu)

            menu.addItem(.separator())
            let dbSubmenu = NSMenu()
            for eng in st.engines {
                let label = eng.state == "NOT_DOWNLOADED" ? "\(eng.name) — Download & Enable..." : eng.name
                let item = NSMenuItem(title: label, action: #selector(menuSelectDB(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = eng.id
                item.state = eng.active ? .on : .off
                item.isEnabled = !busy
                dbSubmenu.addItem(item)
            }
            let dbRoot = NSMenuItem(title: "Database Engine (\(st.dbEngine))", action: nil, keyEquivalent: "")
            dbRoot.submenu = dbSubmenu
            menu.addItem(dbRoot)

            let profSub = NSMenu()
            for (pid, label) in [("default", "Default (64M)"), ("eco", "Eco (32M)"), ("import", "Heavy Import (256M)")] {
                let item = NSMenuItem(title: label, action: #selector(menuSelectProfile(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = pid
                item.state = (st.dbProfile == pid) ? .on : .off
                profSub.addItem(item)
            }
            let profRoot = NSMenuItem(title: "DB Memory Profile (\(st.dbProfile))", action: nil, keyEquivalent: "")
            profRoot.submenu = profSub
            menu.addItem(profRoot)
        }

        menu.addItem(.separator())
        let winItem = NSMenuItem(title: "Open Control Window", action: #selector(openControlWindow), keyEquivalent: "k")
        winItem.target = self
        menu.addItem(winItem)

        let dockItem = NSMenuItem(title: "Show Icon in Dock", action: #selector(menuToggleDock), keyEquivalent: "")
        dockItem.target = self
        dockItem.state = keepInDock ? .on : .off
        menu.addItem(dockItem)

        menu.addItem(.separator())
        let webItem = NSMenuItem(title: "Open http://127.0.0.1:\(st?.httpPort ?? 8080)", action: #selector(openLocalhost), keyEquivalent: "o")
        webItem.target = self
        menu.addItem(webItem)

        let pmaItem = NSMenuItem(title: "Open phpMyAdmin (:\(st?.pmaPort ?? 8081))", action: #selector(openPhpMyAdmin), keyEquivalent: "p")
        pmaItem.target = self
        pmaItem.isEnabled = st?.phpmyadminAvailable ?? false
        menu.addItem(pmaItem)

        let rootItem = NSMenuItem(title: "Reveal Website Folder in Finder", action: #selector(openWebRoot), keyEquivalent: "")
        rootItem.target = self
        menu.addItem(rootItem)

        let logsItem = NSMenuItem(title: "Reveal Logs Folder", action: #selector(openLogs), keyEquivalent: "")
        logsItem.target = self
        menu.addItem(logsItem)

        let docItem = NSMenuItem(title: "Run Doctor Checks...", action: #selector(runDoctor), keyEquivalent: "d")
        docItem.target = self
        menu.addItem(docItem)

        menu.addItem(.separator())
        let stopQuitItem = NSMenuItem(title: "Stop All Servers & Quit", action: #selector(menuStopAndQuit), keyEquivalent: "q")
        stopQuitItem.keyEquivalentModifierMask = [.command, .option]
        stopQuitItem.target = self
        stopQuitItem.isEnabled = anyRunning && !busy
        menu.addItem(stopQuitItem)

        let quitItem = NSMenuItem(title: "Quit XamppControl (Keep Servers Running)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)
    }

    private func makeServiceMenuItem(title: String, action: Selector, enabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = !busy && enabled
        return item
    }

    private func runCommandAndRefresh(_ args: [String], completion: ((CLIResult) -> Void)? = nil) {
        busy = true
        updateMenuIcon(running: false)
        if let st = lastStatus { windowController?.update(status: st, busy: true) }
        cli.run(args) { [weak self] res in
            guard let self else { return }
            self.busy = false
            if res.exitCode != 0 {
                self.showAlert(title: "Command Failed", text: res.stderr.isEmpty ? res.stdout : res.stderr)
            }
            self.refreshStatus(includeMemory: self.windowController != nil)
            completion?(res)
        }
    }

    func runBootstrap(onProgress: @escaping (BootstrapProgress) -> Void, onComplete: @escaping (Bool, String) -> Void) {
        busy = true
        updateMenuIcon(running: false)
        var lastMsg = "Completed"
        cli.runStreaming(["bootstrap", "--json"], onLine: { line in
            guard let data = line.data(using: .utf8),
                  let prog = try? JSONDecoder().decode(BootstrapProgress.self, from: data) else { return }
            lastMsg = prog.message
            onProgress(prog)
        }, completion: { [weak self] code in
            guard let self else { return }
            self.busy = false
            let success = (code == 0)
            self.refreshStatus(includeMemory: self.windowController != nil)
            onComplete(success, success ? "Stack setup complete!" : "Setup failed: \(lastMsg)")
        })
    }

    func toggleAll() {
        let anyRunning = (lastStatus?.services.apache.isRunning ?? false) || (lastStatus?.services.phpFpm.isRunning ?? false) || (lastStatus?.services.db.isRunning ?? false)
        runCommandAndRefresh([anyRunning ? "stop" : "start", "all"])
    }

    func toggleService(_ svc: String) {
        let running: Bool
        switch svc {
        case "apache": running = lastStatus?.services.apache.isRunning ?? false
        case "php": running = lastStatus?.services.phpFpm.isRunning ?? false
        case "db": running = lastStatus?.services.db.isRunning ?? false
        default: running = false
        }
        runCommandAndRefresh([running ? "stop" : "start", svc])
    }

    @objc func browseAndSwitchWebRoot() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = "Select Any Website / PHP Project Folder"
        panel.prompt = "Serve Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if let cur = lastStatus?.webRoot {
            panel.directoryURL = URL(fileURLWithPath: cur)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }

        var chosen = url.path
        let fm = FileManager.default
        let rootIndex = url.appendingPathComponent("index.php").path
        let rootHtml = url.appendingPathComponent("index.html").path
        let publicIndex = url.appendingPathComponent("public/index.php").path
        if !fm.fileExists(atPath: rootIndex) && !fm.fileExists(atPath: rootHtml) && fm.fileExists(atPath: publicIndex) {
            let ask = NSAlert()
            ask.messageText = "Laravel / Public Folder Detected"
            ask.informativeText = "'\(url.lastPathComponent)' has a 'public/index.php' entrypoint. Serve '\(url.lastPathComponent)/public' so routes and assets work like Laragon?"
            ask.addButton(withTitle: "Use public/ (Recommended)")
            ask.addButton(withTitle: "Use Selected Root")
            if ask.runModal() == .alertFirstButtonReturn {
                chosen = url.appendingPathComponent("public").path
            }
        }
        switchWebRoot(chosen, openInBrowser: true)
    }

    func switchWebRoot(_ path: String, openInBrowser: Bool = false) {
        runCommandAndRefresh(["webroot", path]) { [weak self] res in
            guard let self, res.exitCode == 0 else { return }
            if !res.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.showAlert(title: "macOS Folder Permission Note", text: res.stderr)
            }
            if openInBrowser {
                self.openLocalhost()
            }
        }
    }

    @objc func resetWebRoot() {
        runCommandAndRefresh(["webroot", "--reset"])
    }

    func selectDatabaseEngine(_ engine: String) {
        guard let info = lastStatus?.engines.first(where: { $0.id == engine }) else { return }
        if info.active { return }
        if info.state == "NOT_DOWNLOADED" {
            busy = true
            updateMenuIcon(running: false)
            if let st = lastStatus { windowController?.update(status: st, busy: true) }
            cli.run(["db", "install", engine, "--dry-run"]) { [weak self] dryRes in
                guard let self else { return }
                self.busy = false
                let alert = NSAlert()
                alert.messageText = "Download & Enable \(info.name)?"
                alert.informativeText = "\(info.name) is not downloaded yet. Homebrew dry-run check:\n\n\(dryRes.stdout)\(dryRes.stderr)\n\nProceed with download and switch active DB?"
                alert.addButton(withTitle: "Download & Switch")
                alert.addButton(withTitle: "Cancel")
                if alert.runModal() == .alertFirstButtonReturn {
                    self.runCommandAndRefresh(["db", "install", engine, "--allow-brew-dep-upgrades", "--use"])
                } else {
                    self.refreshStatus(includeMemory: self.windowController != nil)
                }
            }
        } else {
            runCommandAndRefresh(["db", "use", engine])
        }
    }

    func selectDatabaseProfile(_ profile: String) {
        runCommandAndRefresh(["db", "profile", profile])
    }

    @objc func openControlWindow() {
        NSApp.setActivationPolicy(.regular)
        if windowController == nil {
            windowController = ControlWindowController(appDelegate: self)
        }
        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        refreshStatus(includeMemory: true)
    }

    func handleWindowClosed() {
        windowController = nil
        if !keepInDock {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func setKeepInDock(_ keep: Bool) {
        keepInDock = keep
        if keep || windowController != nil {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        rebuildMenu()
    }

    @objc private func menuToggleAll() { toggleAll() }
    @objc private func menuToggleApache() { toggleService("apache") }
    @objc private func menuTogglePHP() { toggleService("php") }
    @objc private func menuToggleDB() { toggleService("db") }
    @objc private func menuMeasureRAM() { refreshStatus(includeMemory: true) }
    @objc private func menuToggleDock() { setKeepInDock(!keepInDock) }

    @objc private func menuStopAndQuit() {
        busy = true
        cli.cancelAllWatchers()
        cli.run(["stop", "all"]) { _ in
            NSApp.terminate(nil)
        }
    }

    @objc private func menuSelectRecentRoot(_ sender: NSMenuItem) {
        if let p = sender.representedObject as? String { switchWebRoot(p) }
    }

    @objc private func menuSelectDB(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { selectDatabaseEngine(id) }
    }

    @objc private func menuSelectProfile(_ sender: NSMenuItem) {
        if let p = sender.representedObject as? String { selectDatabaseProfile(p) }
    }

    @objc func openLocalhost() {
        if let url = URL(string: "http://127.0.0.1:\(lastStatus?.httpPort ?? 8080)/") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openPhpMyAdmin() {
        if let url = URL(string: "http://127.0.0.1:\(lastStatus?.pmaPort ?? 8081)/") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openWebRoot() {
        let p = lastStatus?.webRoot ?? (NSHomeDirectory() + "/Sites/Xampp")
        NSWorkspace.shared.open(URL(fileURLWithPath: p))
    }

    @objc func openLogs() {
        let p = (lastStatus?.appSupport ?? (NSHomeDirectory() + "/Library/Application Support/XamppLocal")) + "/logs"
        NSWorkspace.shared.open(URL(fileURLWithPath: p))
    }

    @objc func runDoctor() {
        cli.run(["doctor"]) { [weak self] res in
            self?.showAlert(
                title: res.exitCode == 0 ? "Doctor: All Checks Passed" : "Doctor: Issues Detected",
                text: res.stdout + res.stderr
            )
        }
    }

    private func showAlert(title: String, text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
