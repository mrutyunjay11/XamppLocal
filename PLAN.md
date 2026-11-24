# Native macOS `arm64` XAMPP Replacement Plan: The Universal Dynamic Model

> **Project Name:** `XamppLocal`  
> **Repository:** [https://github.com/mrutyunjay11/XamppLocal](https://github.com/mrutyunjay11/XamppLocal)  
> **Current Version:** `v1.0.0` (Native Apple Silicon baseline released)  
> **Target Release:** `v1.1.0` (The Universal Dynamic Model — Zero-Terminal, Zero-Homebrew, Any Mac Consumer Ready)  
> **Target Architecture:** Apple Silicon (`arm64`) on macOS 14.0+ (Sonoma, Sequoia, and macOS 26/27/28+)  
> **License:** MIT License (`Copyright (c) 2026 Mrutyunjay Joshi`)

---

## 1. Executive Vision & The "Universal Dynamic" Philosophy

Traditional macOS development stacks (XAMPP, MAMP, Bitnami) fail on modern Apple Silicon Macs because they rely on legacy Intel/Rosetta 2 translation, hardcoded `/Applications/` absolute paths, invasive root/sudo prompts, or manual terminal commands that alienate non-technical users.

The **Universal Dynamic Model** transforms `XamppLocal` into a frictionless, consumer-grade developer environment:
1. **Zero Terminal Requirement:** Any user who downloads `XamppLocal.dmg` can drag `XamppControl.app` to `/Applications`, open it, and click a single button to have a full local stack running.
2. **Zero Homebrew Dependency:** While existing Homebrew installations are detected and utilized if available, Homebrew is **not required**. Standalone precompiled Apple Silicon binaries (PHP 8.4, MySQL 8.4 LTS, and phpMyAdmin) are acquired and isolated automatically in `~/Library/Application Support/XamppLocal/`.
3. **Laragon-Style Webroot & Drag-and-Drop:** Drag any project folder from Finder onto the Dock icon or select it from the menu. Frameworks like Laravel, Symfony, or Bedrock (`public/` directory) are automatically detected and DocumentRoot is swapped gracefully in < 200ms without server downtime.
4. **Intelligent Port Conflict Resolver:** If port 8080 or 3306 is occupied by another app (e.g., AirPlay Receiver, Docker, Tomcat), XamppLocal identifies the conflicting process and dynamically re-binds to the next free port without failing.
5. **Zero Host Mutation:** Never breaks, upgrades, or alters any pre-existing tool or library on the host machine.

```
                              +-----------------------------------+
                              |          XamppLocal.dmg           |
                              |    (Drag to /Applications)        |
                              +-----------------+-----------------+
                                                |
                                                v
                              +-----------------------------------+
                              |        XamppControl.app           |
                              |    (Native Swift AppKit GUI)      |
                              +-----------------+-----------------+
                                                |
                               Probes stack readiness on launch
                                                |
                       +------------------------+------------------------+
                       |                                                 |
                [ Stack Ready ]                                 [ Setup Required ]
                       |                                                 |
             Standard Control UI                         Native In-App Onboarding Wizard
          (Menu Bar + Status Window)                  (1-Click Download & Bootstrap Stream)
                       |                                                 |
                       +------------------------+------------------------+
                                                |
                                                v
                         +---------------------------------------------+
                         |   bin/xamppctl (Unified Engine Controller)  |
                         +----------------------+----------------------+
                                                |
             +-----------------+----------------+-----------------+
             |                 |                |                 |
             v                 v                v                 v
        [ macOS Apache ]  [ Standalone PHP ] [ Standalone MySQL ] [ phpMyAdmin ]
        /usr/sbin/httpd     arm64 PHP 8.4     MySQL 8.4 LTS       Port 8081
         (Built-in)        (Zero-Brew Tar)   (Official Tarball)   (Isolated)
```

---

## 2. Dynamic Component Architecture

### 2.1 Multi-Tier Dynamic PHP Engine (Solving the Missing macOS PHP)
macOS removed built-in PHP in macOS 12 Monterey. To ensure XamppLocal functions on every Mac without forcing users to install developer package managers:

```
                      +---------------------------------------+
                      |       Check PHP Availability          |
                      +-------------------+-------------------+
                                          |
        +---------------------------------+---------------------------------+
        |                                 |                                 |
        v                                 v                                 v
[ Tier 1: Local Engine ]         [ Tier 2: System / Brew ]        [ Tier 3: In-App Download ]
Application Support/engines/php/  /opt/homebrew/opt/php/           Download precompiled arm64 tarball
(Used if already downloaded)      (Used if user already has it)    (Extracted to engines/php/)
```

* **Extensions Matrix:** Includes all standard web extensions: `pdo_mysql`, `mysqli`, `sqlite3`, `pdo_sqlite`, `pgsql`, `pdo_pgsql`, `curl`, `openssl`, `mbstring`, `intl`, `zip`, `gd`, `zlib`, and `Zend OPcache` (`revalidate_freq=0` for instant live code reloading).
* **FPM Tuning:** `pm = ondemand`, `max_children = 8`, `process_idle_timeout = 10s` (drops to 0 worker memory after 10s idle, saving RAM).

### 2.2 Default MySQL 8.4 LTS & On-Demand Engines
* **MySQL 8.4 LTS (Default Engine):**
  * Official precompiled Oracle macOS 15 `arm64` binary tarball.
  * Verified via MD5/SHA-256 before extraction into `~/Library/Application Support/XamppLocal/engines/mysql-8.4/`.
  * Initialized securely on first run via `mysqld --initialize-insecure --datadir=...`.
  * Sockets confined to `~/Library/Application Support/XamppLocal/run/mysql.sock` ($\le 76$ bytes).
* **MariaDB & PostgreSQL 18 (On-Demand Engines):**
  * Remain dormant (0 MB disk, 0 MB RAM) until explicitly installed by the user.
  * In the GUI, selecting MariaDB or PostgreSQL displays an in-app download sheet: "Download and Enable MariaDB (10.11 LTS)".
  * Download and setup run asynchronously in the background.
* **SQLite 3:**
  * Embedded directly in PHP (`pdo_sqlite`); zero download, zero daemon RAM.

### 2.3 Isolated phpMyAdmin 5.2
* Official release tarball unpacked into `~/Library/Application Support/XamppLocal/apps/phpmyadmin/`.
* Bound strictly to dedicated port `8081` (`http://127.0.0.1:8081/`) with `SameSite=Strict` cookie headers and dynamic `blowfish_secret` in `0700` tmp storage to prevent local cross-site script hijacking from port `8080`.

---

## 3. Native AppKit First-Run Onboarding Wizard

### 3.1 First-Run Detection
On launch, `XamppControl.app` invokes `xamppctl readiness --json`. If any component (`php`, `mysql`, `phpmyadmin`) is missing:
1. The app orders the Control Window front.
2. A sleek native modal sheet attaches to the window:
   * **Hero Header:** High-resolution squircle XamppLocal logo + "Welcome to XamppLocal".
   * **Component Checklist:** Real-time visual status of components (Apache, PHP, MySQL, phpMyAdmin).
   * **Primary Action:** `[ ⚡ Set Up Local Stack (One-Click) ]`.
3. Clicking the button initiates `xamppctl bootstrap --json`.

### 3.2 Streaming Progress Protocol
The CLI emits newline-delimited JSON (NDJSON) progress events over standard output:
```json
{"phase": "init", "percent": 5, "message": "Creating protected runtime directories..."}
{"phase": "php", "percent": 30, "message": "Setting up Apple Silicon PHP 8.4 engine..."}
{"phase": "mysql", "percent": 65, "message": "Downloading official MySQL 8.4 LTS (75 MB / 150 MB)..."}
{"phase": "mysql", "percent": 85, "message": "Initializing database storage..."}
{"phase": "pma", "percent": 95, "message": "Configuring isolated phpMyAdmin 5.2..."}
{"phase": "complete", "percent": 100, "message": "Stack setup complete!"}
```
The AppKit UI binds this stream to `NSProgressIndicator` and a status text label, ensuring the user is fully informed without freezing the interface.

---

## 4. Intelligent Port Conflict Resolver

### 4.1 Diagnostic Inspection
Before binding Apache (`8080`), phpMyAdmin (`8081`), or MySQL (`3306`), `xamppctl` runs non-blocking kernel socket inspections:
```bash
/usr/sbin/lsof -nP -iTCP:<port> -sTCP:LISTEN
```
If a port is occupied:
1. `xamppctl` extracts the occupying command and PID (e.g. `COMMAND: java, PID: 4321`).
2. Instead of crashing, `xamppctl` activates the **Smart Port Re-allocator**:
   * Probes sequential alternate ports (e.g. 8080 $\to$ 8082 $\to$ 8084).
   * Updates `http_port` in `stack.json`.
   * Re-renders Apache configuration and starts cleanly.
3. In the GUI, a notification badge alerts the user:
   * *"Port 8080 occupied by 'java' (PID 4321). XamppLocal started on port 8082."*
   * All "Open in Browser" buttons (`⌘O`, `⌘P`) open the active port automatically.

---

## 5. Laragon-Style Dynamic Project Switcher

### 5.1 Smart Framework Entrypoint Detection
When switching the active project (via `⌘L`, Menu Bar, or CLI `xamppctl webroot <path>`):
* If `<path>/public/index.php` exists (Laravel, Symfony, Bedrock), Apache DocumentRoot is automatically set to `<path>/public`.
* If `<path>/web/index.php` exists (Yii, Drupal), DocumentRoot is set to `<path>/web`.
* If standard `index.php` or `index.html` exists at root (WordPress, custom PHP), DocumentRoot is set to `<path>`.

### 5.2 Finder Drag-and-Drop & Recent Projects Menu
* **Dock Icon / Window Drop Target:** Developers can drag any project folder directly onto the `XamppControl` Dock icon or the Control Window. `AppDelegate.application(_:openFile:)` catches the URL, validates it, updates `stack.json`, triggers a graceful Apache reload (`httpd -k graceful`), and opens the local site in the browser in < 200ms.
* **Recent Projects Menu:** Stores the last 5 active projects in `stack.json` and displays them in a dedicated Menu Bar submenu for instant switching.

---

## 6. Bundled Priority & Self-Healing Runtime

### 6.1 Bundled CLI Priority Fix
Inside `XamppCLI.swift`, ensure bundled resources take precedence when running inside `/Applications/XamppControl.app`:
```swift
if let bundledCli = Bundle.main.resourceURL?.appendingPathComponent("stack/bin/xamppctl").path,
   FileManager.default.isExecutableFile(atPath: bundledCli) {
    return bundledCli
}
```

### 6.2 Self-Healing Defaults
* If `stack.json` is missing or corrupted, `xamppctl` regenerates default configuration without throwing unhandled exceptions.
* If `~/Sites/Xampp` does not exist on first run, it is automatically created and populated from `htdocs-template/index.php`.
* Optional Terminal Integration: An in-app button ("Install xamppctl CLI Command") symlinks the executable to `~/.local/bin/xamppctl`.

---

## 7. Security & APFS Hardening

1. **APFS Case-Insensitive Protection:**
   * All Apache `<FilesMatch>` and `<DirectoryMatch>` rules enforce `(?i)` case-insensitivity:
   * Protects against `.ENV`, `.SQL`, `.Git`, `.PHP`, `.SWP`, and `*~` source disclosure.
2. **Symlink Traversal Defense:**
   * Enforces `SymLinksIfOwnerMatch` across the active web root and virtual hosts to prevent arbitrary filesystem escapes.
3. **Safe DocumentRoot Validation:**
   * Strict path validation (`validate_docroot`) prevents setting DocumentRoot to sensitive user or system directories (`~`, `~/Library`, `/etc`, `/System`, `/usr`).
4. **Database Name Sanitization:**
   * Strict regex `^[A-Za-z0-9_][A-Za-z0-9_$-]{0,63}$` prevents command and SQL injection during database creation and imports.
5. **Restricted Sockets & Tmp Storage:**
   * All runtime directories (`run/`, `data/`, `tmp/phpmyadmin/`) are enforced with `chmod 0700` ownership.
   * Socket paths are strictly validated to remain $\le 104$ bytes (macOS `sockaddr_un` limit).

---

## 8. Verification Protocol for Consumer Clean Macs

To guarantee that any user downloading the DMG experiences a 100% flawless launch:

| Test Case | Scenario | Expected Result |
| :--- | :--- | :--- |
| **TC-1: Brand New Mac** | Simulate completely fresh Mac (remove `~/Library/Application Support/XamppLocal`, no Homebrew on PATH). | Launching `XamppControl.app` opens the Onboarding Wizard; clicking Setup acquires PHP, MySQL, and phpMyAdmin; services start cleanly on port 8080/8081. |
| **TC-2: Existing Homebrew Mac** | User has Homebrew PHP 8.4 already installed. | Onboarding Wizard detects existing PHP in < 1 second, reuses it without redundant download, and provisions MySQL. |
| **TC-3: Port Collision** | Another service binds port 8080 (e.g., `nc -l 8080`). | XamppLocal identifies conflict, shifts Apache to port 8082, alerts user in GUI, and opens `http://127.0.0.1:8082`. |
| **TC-4: Laravel Drag & Drop** | User drags a Laravel repository folder onto the Dock icon. | App detects `public/index.php`, sets DocumentRoot to `/public`, reloads Apache in < 200ms, and serves the Laravel application. |
| **TC-5: MySQL to MariaDB Import** | User imports a MySQL dump with `utf8mb4_0900_ai_ci` into MariaDB. | Collation translator translates dump to `utf8mb4_unicode_ci` and imports without collation errors. |
| **TC-6: Process Exit Watcher** | A service daemon is killed externally via `kill -9`. | `DispatchSource` exit watcher catches event instantly without polling loops and updates GUI status. |

---

## 9. Phased Implementation Roadmap

* **Phase 1: CLI Dynamic Engine (`bin/xamppctl`)**
  * Implement `xamppctl readiness` and `xamppctl bootstrap --json`.
  * Implement multi-tier PHP engine discovery and standalone downloader.
  * Implement intelligent port conflict detector and auto-reallocation.
* **Phase 2: Swift AppKit Onboarding Wizard (`app/Sources/`)**
  * Fix bundled CLI priority in `XamppCLI.swift`.
  * Build `SetupSheetController` with animated `NSProgressIndicator` and status labels.
  * Implement Finder drag-and-drop on Dock icon and Control Window.
* **Phase 3: Database & Framework Switcher Polish**
  * Add in-app MariaDB/PostgreSQL download sheets.
  * Integrate automatic framework entrypoint detection (`public/`, `web/`).
* **Phase 4: Build, Packaging & Distribution**
  * Update `app/build.sh` and `make_dmg.sh` to package updated assets.
  * Ad-hoc deep sign the application bundle.
  * Test clean DMG install.
* **Phase 5: Release & Verification**
  * Run full test suite across all 6 verification test cases.
  * Commit, tag `v1.1.0`, push to GitHub, and attach updated `XamppLocal.dmg` to GitHub Releases.
