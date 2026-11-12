import AppKit

final class ControlWindowController: NSWindowController, NSWindowDelegate {
    private weak var appDelegate: AppDelegate?
    private let logoView = NSImageView()
    private let summaryLabel = NSTextField(labelWithString: "Loading status...")
    private let apacheLabel = NSTextField(labelWithString: "-")
    private let phpLabel = NSTextField(labelWithString: "-")
    private let dbLabel = NSTextField(labelWithString: "-")
    private let totalMemLabel = NSTextField(labelWithString: "-")

    private let masterBtn = NSButton(title: "Start All", target: nil, action: nil)
    private let apacheBtn = NSButton(title: "Start", target: nil, action: nil)
    private let phpBtn = NSButton(title: "Start", target: nil, action: nil)
    private let dbBtn = NSButton(title: "Start", target: nil, action: nil)

    private let webRootLabel = NSTextField(labelWithString: "~/Sites/Xampp")
    private let recentRootPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let browseRootBtn = NSButton(title: "Browse Folder...", target: nil, action: nil)
    private let dbPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let profilePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let dockCheck = NSButton(checkboxWithTitle: "Keep icon in Dock when window closes", target: nil, action: nil)
    private let pmaBtn = NSButton(title: "phpMyAdmin (:8081)", target: nil, action: nil)

    private var engineIDs: [String] = []
    private var recentPaths: [String] = []
    private let profiles = ["default", "eco", "import"]

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 570, height: 470),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "XamppLocal Control"
        win.center()
        win.isReleasedWhenClosed = true
        super.init(window: win)
        win.delegate = self
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        guard let content = window?.contentView else { return }
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: content.topAnchor),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        ])

        // Header with app logo + title/status
        let headerRow = NSStackView()
        headerRow.spacing = 12
        headerRow.alignment = .centerY
        logoView.image = appDelegate?.appLogoImage ?? NSApp.applicationIconImage
        logoView.imageScaling = .scaleProportionallyUpOrDown
        logoView.widthAnchor.constraint(equalToConstant: 48).isActive = true
        logoView.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let titleCol = NSStackView()
        titleCol.orientation = .vertical
        titleCol.alignment = .leading
        titleCol.spacing = 2
        let titleLbl = NSTextField(labelWithString: "XamppLocal")
        titleLbl.font = .boldSystemFont(ofSize: 16)
        summaryLabel.font = .systemFont(ofSize: 12)
        summaryLabel.textColor = .secondaryLabelColor
        titleCol.addArrangedSubview(titleLbl)
        titleCol.addArrangedSubview(summaryLabel)
        headerRow.addArrangedSubview(logoView)
        headerRow.addArrangedSubview(titleCol)
        root.addArrangedSubview(headerRow)

        let topActions = NSStackView()
        topActions.spacing = 8
        masterBtn.bezelStyle = .rounded
        masterBtn.target = self
        masterBtn.action = #selector(onMasterToggle)
        let refreshBtn = NSButton(title: "Refresh & Measure RAM", target: self, action: #selector(onRefresh))
        let doctorBtn = NSButton(title: "Run Doctor", target: self, action: #selector(onDoctor))
        topActions.addArrangedSubview(masterBtn)
        topActions.addArrangedSubview(refreshBtn)
        topActions.addArrangedSubview(doctorBtn)
        root.addArrangedSubview(topActions)

        root.addArrangedSubview(makeServiceRow(name: "Apache (httpd)", statusLabel: apacheLabel, button: apacheBtn, action: #selector(onApacheToggle)))
        root.addArrangedSubview(makeServiceRow(name: "PHP-FPM (8.4)", statusLabel: phpLabel, button: phpBtn, action: #selector(onPHPToggle)))
        root.addArrangedSubview(makeServiceRow(name: "Database", statusLabel: dbLabel, button: dbBtn, action: #selector(onDBToggle)))

        totalMemLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        totalMemLabel.textColor = .secondaryLabelColor
        root.addArrangedSubview(totalMemLabel)

        // Laragon-style DocumentRoot folder selector
        let rootBox = NSStackView()
        rootBox.orientation = .vertical
        rootBox.alignment = .leading
        rootBox.spacing = 6

        let pathRow = NSStackView()
        pathRow.spacing = 8
        let rootTitle = NSTextField(labelWithString: "Website Folder:")
        rootTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        webRootLabel.font = .monospacedSystemFont(ofSize: 11.5, weight: .regular)
        webRootLabel.lineBreakMode = .byTruncatingMiddle
        webRootLabel.widthAnchor.constraint(equalToConstant: 295).isActive = true
        browseRootBtn.target = self
        browseRootBtn.action = #selector(onBrowseRoot)
        pathRow.addArrangedSubview(rootTitle)
        pathRow.addArrangedSubview(webRootLabel)
        pathRow.addArrangedSubview(browseRootBtn)

        let recentRow = NSStackView()
        recentRow.spacing = 8
        recentRow.addArrangedSubview(NSTextField(labelWithString: "Recent Folders:"))
        recentRootPopup.widthAnchor.constraint(equalToConstant: 320).isActive = true
        recentRootPopup.target = self
        recentRootPopup.action = #selector(onSelectRecentRoot)
        let resetRootBtn = NSButton(title: "Default", target: self, action: #selector(onResetRoot))
        recentRow.addArrangedSubview(recentRootPopup)
        recentRow.addArrangedSubview(resetRootBtn)

        rootBox.addArrangedSubview(pathRow)
        rootBox.addArrangedSubview(recentRow)
        root.addArrangedSubview(rootBox)

        let dbRow = NSStackView()
        dbRow.spacing = 10
        dbRow.addArrangedSubview(NSTextField(labelWithString: "DB Engine:"))
        dbPopup.target = self
        dbPopup.action = #selector(onSelectEngine)
        dbRow.addArrangedSubview(dbPopup)
        dbRow.addArrangedSubview(NSTextField(labelWithString: "Profile:"))
        profilePopup.addItems(withTitles: ["Default (64M)", "Eco (32M)", "Heavy Import (256M)"])
        profilePopup.target = self
        profilePopup.action = #selector(onSelectProfile)
        dbRow.addArrangedSubview(profilePopup)
        root.addArrangedSubview(dbRow)

        let linksRow = NSStackView()
        linksRow.spacing = 8
        let webBtn = NSButton(title: "Open Site (:8080)", target: self, action: #selector(onOpenWeb))
        pmaBtn.target = self
        pmaBtn.action = #selector(onOpenPMA)
        let htdocsBtn = NSButton(title: "Open Folder", target: self, action: #selector(onOpenWebRoot))
        let logsBtn = NSButton(title: "Logs Folder", target: self, action: #selector(onOpenLogs))
        linksRow.addArrangedSubview(webBtn)
        linksRow.addArrangedSubview(pmaBtn)
        linksRow.addArrangedSubview(htdocsBtn)
        linksRow.addArrangedSubview(logsBtn)
        root.addArrangedSubview(linksRow)

        dockCheck.target = self
        dockCheck.action = #selector(onToggleDock)
        dockCheck.state = (appDelegate?.keepInDock ?? false) ? .on : .off
        root.addArrangedSubview(dockCheck)
    }

    private func makeServiceRow(name: String, statusLabel: NSTextField, button: NSButton, action: Selector) -> NSView {
        let row = NSStackView()
        row.spacing = 10
        let title = NSTextField(labelWithString: name)
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.widthAnchor.constraint(equalToConstant: 125).isActive = true

        statusLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.widthAnchor.constraint(equalToConstant: 310).isActive = true

        button.target = self
        button.action = action
        button.widthAnchor.constraint(equalToConstant: 70).isActive = true

        row.addArrangedSubview(title)
        row.addArrangedSubview(statusLabel)
        row.addArrangedSubview(button)
        return row
    }

    func update(status: StackStatus, busy: Bool) {
        let anyRunning = status.services.apache.isRunning || status.services.phpFpm.isRunning || status.services.db.isRunning
        summaryLabel.stringValue = busy ? "Working..." : (anyRunning ? "Running on http://127.0.0.1:\(status.httpPort)" : "Stopped (0 MB background RAM)")
        masterBtn.title = anyRunning ? "Stop All" : "Start All"
        masterBtn.isEnabled = !busy

        apacheLabel.stringValue = formatService(status.services.apache)
        apacheBtn.title = status.services.apache.isRunning ? "Stop" : "Start"
        apacheBtn.isEnabled = !busy

        phpLabel.stringValue = formatService(status.services.phpFpm)
        phpBtn.title = status.services.phpFpm.isRunning ? "Stop" : "Start"
        phpBtn.isEnabled = !busy

        let db = status.services.db
        if db.engine == "sqlite" {
            dbLabel.stringValue = "sqlite (built-in, 0 MB daemon)"
            dbBtn.title = "Built-in"
            dbBtn.isEnabled = false
        } else {
            let pidPart = db.pid.map { "PID \($0)" } ?? "-"
            let portPart = db.port.map { ":\($0)" } ?? ""
            let memPart = db.footprintMb > 0 ? String(format: " | %.1f MB", db.footprintMb) : ""
            dbLabel.stringValue = "\(db.engine) \(db.status) (\(pidPart)\(portPart))\(memPart)"
            dbBtn.title = db.isRunning ? "Stop" : "Start"
            dbBtn.isEnabled = !busy
        }

        let total = status.services.apache.footprintMb + status.services.phpFpm.footprintMb + status.services.db.footprintMb
        totalMemLabel.stringValue = anyRunning
            ? String(format: "Measured Footprint Total: %.2f MB (footprint --swapped)", total)
            : "Measured Footprint Total: 0.00 MB (all stopped)"

        webRootLabel.stringValue = status.webRoot
        webRootLabel.toolTip = status.webRoot
        browseRootBtn.isEnabled = !busy

        recentRootPopup.removeAllItems()
        recentPaths = status.recentWebRoots ?? [status.webRoot]
        if !recentPaths.contains(status.webRoot) { recentPaths.insert(status.webRoot, at: 0) }
        var activeRootIdx = 0
        for (i, p) in recentPaths.enumerated() {
            let folderName = (p as NSString).lastPathComponent
            recentRootPopup.addItem(withTitle: "\(folderName) — \(p)")
            if p == status.webRoot { activeRootIdx = i }
        }
        if !recentPaths.isEmpty { recentRootPopup.selectItem(at: activeRootIdx) }
        recentRootPopup.isEnabled = !busy

        dbPopup.removeAllItems()
        engineIDs = []
        var activeIdx = 0
        for (i, eng) in status.engines.enumerated() {
            let suffix = eng.state == "NOT_DOWNLOADED" ? " [Not Downloaded...]" : (eng.active ? " [Active]" : "")
            dbPopup.addItem(withTitle: "\(eng.name)\(suffix)")
            engineIDs.append(eng.id)
            if eng.active { activeIdx = i }
        }
        if !engineIDs.isEmpty { dbPopup.selectItem(at: activeIdx) }
        dbPopup.isEnabled = !busy

        if let pIdx = profiles.firstIndex(of: status.dbProfile) {
            profilePopup.selectItem(at: pIdx)
        }
        profilePopup.isEnabled = !busy
        pmaBtn.title = "phpMyAdmin (:\(status.pmaPort ?? 8081))"
        pmaBtn.isEnabled = status.phpmyadminAvailable
        dockCheck.state = (appDelegate?.keepInDock ?? false) ? .on : .off
    }

    private func formatService(_ svc: ServiceState) -> String {
        let pidPart = svc.pid.map { "PID \($0)" } ?? "-"
        let memPart = svc.footprintMb > 0 ? String(format: " | %.1f MB", svc.footprintMb) : ""
        return "\(svc.status) (\(pidPart))\(memPart)"
    }

    @objc private func onMasterToggle() { appDelegate?.toggleAll() }
    @objc private func onApacheToggle() { appDelegate?.toggleService("apache") }
    @objc private func onPHPToggle() { appDelegate?.toggleService("php") }
    @objc private func onDBToggle() { appDelegate?.toggleService("db") }
    @objc private func onRefresh() { appDelegate?.refreshStatus(includeMemory: true) }
    @objc private func onDoctor() { appDelegate?.runDoctor() }
    @objc private func onBrowseRoot() { appDelegate?.browseAndSwitchWebRoot() }
    @objc private func onResetRoot() { appDelegate?.resetWebRoot() }
    @objc private func onOpenWeb() { appDelegate?.openLocalhost() }
    @objc private func onOpenPMA() { appDelegate?.openPhpMyAdmin() }
    @objc private func onOpenWebRoot() { appDelegate?.openWebRoot() }
    @objc private func onOpenLogs() { appDelegate?.openLogs() }

    @objc private func onSelectRecentRoot() {
        let idx = recentRootPopup.indexOfSelectedItem
        guard idx >= 0, idx < recentPaths.count else { return }
        appDelegate?.switchWebRoot(recentPaths[idx])
    }

    @objc private func onSelectEngine() {
        let idx = dbPopup.indexOfSelectedItem
        guard idx >= 0, idx < engineIDs.count else { return }
        appDelegate?.selectDatabaseEngine(engineIDs[idx])
    }

    @objc private func onSelectProfile() {
        let idx = profilePopup.indexOfSelectedItem
        guard idx >= 0, idx < profiles.count else { return }
        appDelegate?.selectDatabaseProfile(profiles[idx])
    }

    @objc private func onToggleDock() {
        appDelegate?.setKeepInDock(dockCheck.state == .on)
    }

    func windowWillClose(_ notification: Notification) {
        appDelegate?.handleWindowClosed()
    }

    override func cancelOperation(_ sender: Any?) {
        window?.performClose(sender)
    }
}
