# Native macOS `arm64` XAMPP Replacement Plan

> **Status:** Implementation-Ready Architectural & Verification Plan (No implementation code written yet)  
> **Target Machine:** MacBook Air M2 (`arm64`), 16 GB RAM, 228 GiB SSD (**44 GiB free**), macOS 27.2.1 (Build `26B131`)  
> **Strict Version-Preservation Rule:** **Do NOT upgrade, unlink, or alter ANY existing installed package or version on this Mac** (`php 8.4.8`, `composer 2.8.9`, `apr`, `apr-util`, `pcre2`, `lz4`, `abseil`, `protobuf`, `/Applications/XAMPP`, system configs). Use already-installed `arm64` binaries (`php 8.4.8` + built-in `/usr/sbin/httpd 2.4.67`), isolate everything new, keep **MySQL 8.4 LTS** as the default DB, and keep optional DBs (**MariaDB**, **PostgreSQL**, **SQLite**) dormant/undownloaded until explicitly downloaded and selected.

---

## 0. Verified Environment Baseline (Live Machine Inspection)

All claims below were measured directly on this machine before updating this plan:

| Check | Command Run | Observed Result |
| :--- | :--- | :--- |
| CPU & OS | `uname -m`, `sw_vers` | `arm64`, `macOS 27.2.1` (`BuildVersion: 26B131`) |
| Disk Space | `df -h ~` | `228Gi` total, `160Gi` used, **`44Gi` available** (`79%` capacity) |
| Swift Toolchain | `swiftc --version`, `xcrun --show-sdk-path` | Apple Swift `6.4.2` (`arm64-apple-macosx27.2.0`), CLT SDK `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk` |
| Built-in Apache (`httpd`) | `/usr/sbin/httpd -V`, `file /usr/sbin/httpd`, `ls /usr/libexec/apache2/` | **Already installed (`Apache/2.4.67`, universal incl. `arm64e`)**; includes `mod_mpm_event.so`, `mod_proxy_fcgi.so`, `mod_rewrite.so`, `mod_deflate.so`, `mod_headers.so`, `/usr/sbin/rotatelogs`, `/etc/apache2/mime.types` |
| Installed PHP | `/opt/homebrew/opt/php/bin/php -v`, `file ...`, `brew uses --installed php` | **Already installed (`PHP 8.4.8`, `arm64`, unlinked)**; used by `composer`; includes `mysqli`, `mysqlnd`, `pdo_mysql`, `pgsql`, `pdo_pgsql`, `sqlite3`, `pdo_sqlite`, `gd`, `mbstring`, `intl`, `curl`, `zip`, `openssl`, `Zend OPcache` |
| Existing DB Binaries | `which -a mysql mysqld mariadb`, `ls -d /opt/homebrew/Cellar/mysql*` | **None installed** (excluding Intel `/Applications/XAMPP` which is `x86_64` and stays untouched) |
| Homebrew Pin State | `brew list --pinned` | Empty (`php` is **not pinned** yet; latest Homebrew index `php` is `8.5.12_1`) |
| Homebrew Dry-Run Checks | `HOMEBREW_NO_AUTO_UPDATE=1 brew install --dry-run <pkg>` | `httpd` would upgrade 5 existing pkgs (`apr-util`, `brotli`, `libnghttp2`, `pcre2`, `ca-certificates`); `mysql@8.4` would upgrade 4 existing pkgs (`abseil`, `lz4`, `ca-certificates`, `protobuf`); `mariadb` would upgrade 4 (`lz4`, `simdjson`, `ca-certificates`, `pcre2`); `postgresql@18` would upgrade 4 (`ca-certificates`, `krb5`, `lz4`, `libunistring`) |
| Dependents of Shared Libs | `brew uses --installed lz4 pcre2 apr-util abseil protobuf` | `lz4` is used by `php`, `composer`, `node`, `ollama`, `ffmpeg` chain (`aom`, `libavif`, `libtiff`, etc.); `pcre2` by `php`, `composer`, `git`, `nmap`, `glib`; `apr-util` by `php`, `composer` |
| iCloud Desktop/Docs Sync | `defaults read com.apple.finder FXICloudDriveDesktop` / `Documents` | Both `0` (currently disabled; prior `CloudDocs/Desktop` directory exists from `Sep 2 2025`) |
| Built-in Tools & Paths | `which footprint ab lsof rotatelogs` | `/usr/bin/footprint`, `/usr/sbin/ab`, `/usr/sbin/lsof`, `/usr/sbin/rotatelogs` present; `run/mysql.sock` = **76 bytes**, `.s.PGSQL.5432` = **80 bytes** (`<= 104` byte limit) |

---

## 1. Findings: Audit of the Earlier Draft & Version-Safety Risks

| # | Severity | Verdict | Draft Claim / Assumption | Verification & Technical Reality |
| :--- | :--- | :--- | :--- | :--- |
| **F1** | **HIGH** | **WRONG** | Apache `mpm_event`: `ServerLimit 1`, `ThreadsPerChild 8`, `MaxRequestWorkers 16` | Mathematically invalid (`16 <= 1 * 8` is false). Fixed to `ServerLimit 4`, `ThreadsPerChild 8`, `MaxRequestWorkers 32`. |
| **F2** | **HIGH** | **WRONG** | Unmeasured idle RAM guesses (`< 100 MB`, `25–45 MB`, etc.) | Unverified estimates only. Replaced with `/usr/bin/footprint` measurement protocol. |
| **F3** | **HIGH** | **WRONG** | Mutable `data/`, `logs/`, `run/` placed inside `~/Desktop/Xampp/` | Risks iCloud corruption if Desktop sync turns back on + macOS TCC prompts. Moved to `~/Library/Application Support/XamppLocal/`. |
| **F4** | **HIGH** | **WRONG** | `brew install httpd mariadb` assumed safe and non-destructive | **Verified via `--dry-run`:** `brew install httpd` upgrades 5 installed libs (`apr-util`, `pcre2`, `brotli`, `libnghttp2`, `ca-certificates`), and Homebrew DB installs upgrade `lz4`, `abseil`, `protobuf`, `pcre2`, etc. — directly conflicting with keeping existing Mac package versions untouched! |
| **F5** | **HIGH** | **WRONG / MISSING** | Draft pre-installed MariaDB only, omitted MySQL 8.4 default and optional PostgreSQL/SQLite choice | Updated: **MySQL 8.4 LTS** is default; **MariaDB** and **PostgreSQL 18** stay **undownloaded** until user explicitly installs & selects them (**SQLite 3** built into PHP `8.4.8`). |
| **F6** | **MEDIUM** | **WRONG** | Hardcoded `/opt/homebrew/Cellar/php/8.4.8` & false "self-contained" claim | Replaced Cellar path with `/opt/homebrew/opt/php`; pinned `php` (`8.4.8`) so `brew` never auto-bumps it to `8.5.12_1`; dropped false "self-contained" wording. |
| **F7** | **MEDIUM** | **VERIFIED** | Swift `6.4.2`, PHP `8.4.8` (`arm64` + full modules), and port `8080` unprivileged bind | Confirmed via `swiftc --version`, `php -m`, `file`. Additionally verified `/usr/sbin/httpd` (`2.4.67`, `arm64e`) already ships all required modules on this Mac (`0` extra installs). |

---

## 2. Final Architecture & Directory Layout

### 2.1 Zero-Version-Change Isolation Strategy

To honor **"do not change ANY existing version on my Mac (PHP, shared libs, existing apps)"**:
1. **Apache (`httpd`):** Use **macOS built-in `/usr/sbin/httpd` (`2.4.67`, `arm64e`)** with a completely separate `-f` config in `XamppLocal/run/generated/httpd.conf` — **zero** Homebrew installs, **zero** upgrades to `apr-util`/`pcre2`/`brotli`, **zero** edits to `/etc/apache2/`. *(Configurable in `stack.json` if a future macOS 28+ drops `/usr/sbin/httpd`.)*
2. **PHP (`8.4.8`):** Use **existing `/opt/homebrew/opt/php` (`8.4.8`)** directly. Pin it (`brew pin php`) so Homebrew cannot upgrade it to `8.5.12_1`. Never touch `/opt/homebrew/etc/php/`.
3. **phpMyAdmin (`5.2.3`):** Unpack official verified `phpMyAdmin-5.2.3-all-languages.tar.gz` into `Xampp/apps/phpmyadmin/` — avoids Homebrew formula dependencies touching PHP.
4. **MySQL 8.4 LTS (Default DB) & Optional Engines (`mariadb`, `postgresql@18`):**
   * Because `--dry-run` proved Homebrew `mysql@8.4` would upgrade `abseil`, `lz4`, `ca-certificates`, and `protobuf` globally in `/opt/homebrew`:
   * **Primary Zero-Touch Method (Recommended for MySQL 8.4 Default):** Download **Oracle's official precompiled `mysql-8.4.x-macos*-arm64.tar.gz` binary archive** (prebuilt Mach-O `arm64`, **NOT compiled from source**, and **0 changes** to any `/opt/homebrew` library or version!) into `~/Library/Application Support/XamppLocal/engines/mysql-8.4/`.
   * **Alternative Homebrew Method (Strict Explicit Consent Only):** `xamppctl` runs `brew install --dry-run <formula>` **first**, prints every package Homebrew wants to install/upgrade (e.g. `abseil`, `lz4`, `protobuf` for `mysql@8.4`; `lz4`, `simdjson`, `pcre2` for `mariadb`; `lz4`, `krb5`, `libunistring` for `postgresql@18`), refuses to proceed unless you explicitly pass `--allow-brew-dep-upgrades` (or confirm interactively), always pins existing `php`, and exports `HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1`.
   * **SQLite 3:** Uses `php 8.4.8`'s built-in `pdo_sqlite`/`sqlite3` (`0` downloads, `0` library changes, `0` daemon RAM).

### 2.2 Directory Split: Source vs. Mutable Data

```text
Project / Config / Source (Version-Controlled, Zero Runtime State):
/Users/mrutyunjayjoshi/Desktop/Xampp/
├── PLAN.md
├── bin/xamppctl                    # Single-source-of-truth Python 3 CLI
├── apps/
│   └── phpmyadmin/                 # Official 5.2.3 PHP tarball (only unpacked, no brew PHP dep)
├── config/
│   ├── stack.json                  # httpd_bin, php_formula ("php"), db_engine ("mysql"), db_source, db_profile, port (8080)
│   ├── httpd/                      # httpd.conf.tmpl, phpmyadmin.conf, vhosts.d/*.conf
│   ├── php/                        # php.ini.tmpl, php-fpm.conf.tmpl
│   ├── mysql/my.cnf.tmpl           # Active default (MySQL 8.4)
│   ├── mariadb/my.cnf.tmpl         # Dormant until downloaded & selected
│   ├── postgresql/postgresql.conf.tmpl # Dormant until downloaded & selected
│   ├── phpmyadmin/config.inc.php.tmpl
│   └── dnsmasq/xampp-test.conf
├── app/                            # Swift 6 source + build.sh -> XamppControl.app
├── htdocs/                         # Web root + sites/
└── scripts/benchmark.sh            # footprint + ab + SQL import benchmark

Mutable Data / Sockets / Downloaded Engines (Outside Desktop/iCloud):
~/Library/Application Support/XamppLocal/
├── state.lock                      # Advisory lock preventing CLI/GUI races
├── engines/
│   └── mysql-8.4/                  # Precompiled arm64 MySQL 8.4 archive (if Zero-Touch method used)
├── data/
│   ├── mysql/                      # Initialized in Phase 1 (DEFAULT)
│   ├── mariadb/                    # Created ONLY after download & selection
│   └── postgresql/                 # Created ONLY after download & selection
├── run/                            # mysql.sock (76B), .s.PGSQL.5432 (80B), php-fpm.sock, *.pid, generated/
├── logs/                           # apache, php-fpm, php-error, active db logs, bench/
└── tmp/phpmyadmin/                 # Blowfish secret & TempDir (chmod 700)
```

---

## 3. Component Choices & Database Selection Model

### 3.1 On-Demand Database Engines (MySQL Default)

| Engine ID | Source | Initial State | Connection Target | Role |
| :--- | :--- | :--- | :--- | :--- |
| **`mysql`** *(DEFAULT)* | Precompiled Oracle `mysql-8.4.x-macos-arm64.tar.gz` (Zero-Touch) **or** Homebrew `mysql@8.4` (`8.4.13`, explicit consent) | **Installed & selected in Phase 1** | `127.0.0.1:3306` + `run/mysql.sock` | College MySQL standard, WordPress, Laravel, `utf8mb4_0900_ai_ci` |
| **`mariadb`** | Homebrew `mariadb` (`13.0.2`, dry-run guarded) | **NOT downloaded** (`0` MB disk) | `127.0.0.1:3306` + `run/mysql.sock` | Classic XAMPP fork; works ONLY after `db install mariadb` + `db use mariadb` |
| **`postgresql`** | Homebrew `postgresql@18` (`18.6`, dry-run guarded) | **NOT downloaded** (`0` MB disk) | `127.0.0.1:5432` + `run/.s.PGSQL.5432` | Modern Laravel / `pdo_pgsql` apps; works ONLY after `db install postgresql` + `db use postgresql` |
| **`sqlite`** | Built-in `php 8.4.8` (`pdo_sqlite`) | **Always ready** (`0` disk, `0` RAM) | File-based (`.sqlite`) | Zero-daemon local DB (`db_engine = "sqlite"`) |

* **Gatekeeper ("Not Before Download & Selection"):** `mariadb` and `postgresql` cannot be started or selected until `xamppctl db install <engine>` completes and passes `arm64` verification.
* **Mutual Exclusion & Datadir Guard:** Only one DB daemon runs at a time; separate `data/<engine>/` directories contain `.engine` markers so mismatched binaries hard-refuse startup.
* **Collation Guard:** `xamppctl db import` detects `utf8mb4_0900_*` dumps targeting MariaDB and stops clearly unless `--convert-collation` is requested.
* **Memory Profiles:** `default` (`64M` InnoDB buffer / `32MB` PG `shared_buffers`), `eco` (`32M` / `16MB` PG — avoids `16M` MySQL/WordPress SSD thrashing), `import` (`256M` + `flush_trx=2` / `128MB` PG + `synchronous_commit=off`).

### 3.2 Web, PHP, Vhosts, Port 80 & GUI Summary

* **Apache + PHP-FPM:** Built-in `/usr/sbin/httpd` (`mpm_event`, `ServerLimit 4`, `ThreadsPerChild 8`, `MaxRequestWorkers 32`) -> `mod_proxy_fcgi` -> `/opt/homebrew/opt/php/sbin/php-fpm` (`8.4.8`, `pm = ondemand`, `max_children = 8`, `process_idle_timeout = 10s`, `32M` OPcache). Default port **`8080`** (no `sudo`).
* **Vhosts:** `config/httpd/vhosts.d/*.conf` (`Require local`), opt-in `dnsmasq` + `/etc/resolver/test` (`sudo` once) with `localhost:8080/<site>` / `/etc/hosts` fallback. Notice `brew install --dry-run dnsmasq` must also pass the dry-run upgrade check before opt-in install.
* **Port 80 (Optional):** Reversible `pf` anchor `/etc/pf.anchors/com.xampplocal` (`127.0.0.1:80 -> 8080`), OFF by default.
* **Multi-PHP Versions:** Deferred to Phase 2 (`stack.json` `php_formula` keeps existing `php 8.4.8` untouched while allowing future `php@8.x` selection).
* **Security:** Strict `127.0.0.1`-only listening ports, `chmod 0700` on `data/`, `run/`, `tmp/phpmyadmin/`, empty MySQL root password allowed **only** under localhost/socket isolation.

---

## 4. Config Templates

All templates live in `/Users/mrutyunjayjoshi/Desktop/Xampp/config/` and render into `~/Library/Application Support/XamppLocal/run/generated/` on start/reload (`{{HTTPD_ROOT}}` = `/usr` for built-in macOS Apache, modules from `/usr/libexec/apache2/`, `TypesConfig /etc/apache2/mime.types`, logs piped to `/usr/sbin/rotatelogs -n 3 ... 10M`):

* **Apache (`config/httpd/httpd.conf.tmpl`):** `Listen 127.0.0.1:8080`, `mpm_event` (`StartServers 1`, `ServerLimit 4`, `ThreadsPerChild 8`, `MinSpareThreads 4`, `MaxSpareThreads 16`, `MaxRequestWorkers 32`), `SetHandler "proxy:unix:{{APP_SUPPORT}}/run/php-fpm.sock|fcgi://localhost/"`, `Require local`.
* **PHP / PHP-FPM (`config/php/*.tmpl`):** `listen = {{APP_SUPPORT}}/run/php-fpm.sock` (`0600`), `pm = ondemand`, `pm.max_children = 8`, `pm.process_idle_timeout = 10s`, `mysqli.default_socket` & `pdo_mysql.default_socket` = `{{APP_SUPPORT}}/run/mysql.sock`, `opcache.memory_consumption = 32`.
* **MySQL 8.4 (`config/mysql/my.cnf.tmpl`):** `bind-address = 127.0.0.1`, `port = 3306`, `socket = {{APP_SUPPORT}}/run/mysql.sock`, `mysqlx = OFF`, `performance_schema = OFF`, `innodb_redo_log_capacity = 32M`, `innodb_buffer_pool_size = {{64M|32M|256M}}`.
* **MariaDB (`config/mariadb/my.cnf.tmpl`) & PostgreSQL 18 (`config/postgresql/postgresql.conf.tmpl`):** Dormant until installed & selected; MariaDB shares `127.0.0.1:3306` + `run/mysql.sock`, PostgreSQL uses `127.0.0.1:5432` + `run/.s.PGSQL.5432`.
* **phpMyAdmin (`config/phpmyadmin/config.inc.php.tmpl`):** Cookie auth + `AllowNoPassword = true` + socket `run/mysql.sock`, `AllowArbitraryServer = false`, active only when `mysql` or `mariadb` is selected.

---

## 5. `xamppctl` Command Specification & State Machine

* **Commands:** `start`, `stop`, `restart`, `status [--json] [--memory]`, `db list`, `db install <engine> [--dry-run] [--use]`, `db use <mysql|mariadb|postgresql|sqlite>`, `db profile <default|eco|import>`, `db import <file.sql> [--convert-collation]`, `vhost <add|remove|list|dns>`, `port80 <enable|disable|status>`, `logs`, `doctor`.
* **Version-Preservation Guard in `db install`:** Always pins `php` (`brew pin php`), executes `brew install --dry-run` first to display any shared-library changes before downloading optional engines, and pins newly installed formulas afterward.
* **Ordered Lifecycle:** `flock` lock -> pre-flight (`kill -0` stale PID/socket cleanup, `lsof` port check, `httpd -t`, `php-fpm -t`, DB config validation, `.engine` datadir check) -> ordered start (`php-fpm` -> `httpd` -> active DB) and ordered stop (`httpd -k graceful-stop` -> `php-fpm SIGQUIT` -> DB clean shutdown waiting up to `20s`).

---

## 6. Swift Control App Specification (`app/XamppControl.app`)

* **Single Native `arm64` AppKit App (`swiftc -O -target arm64-apple-macosx27.0`):** Supports **both** Menu Bar-only (`.accessory`) and Dock Window (`.regular`) via toggle; **zero polling timers** (`menuWillOpen`, `applicationDidBecomeActive`, and `DispatchSource.makeProcessSource(..., .exit)`).
* **Database Switcher:** Shows `MySQL 8.4 LTS (Default)` plus `MariaDB 13` / `PostgreSQL 18` as `Not Downloaded (Install & Select...)` (displays dependency preview & confirmation before downloading) and `SQLite 3 (0 MB Daemon RAM)`.
* **Signing:** Local ad-hoc `codesign --force --deep --sign -` (distribution requires Developer ID, hardened runtime, notarization).

---

## 7. Benchmark & Verification Plan

* **Tooling:** `/usr/bin/footprint --pid ... --swapped --noCategories` + `/usr/sbin/ab -n 1000 -c 50`.
* **Scenarios (`B1`–`B5`):** Stopped baseline, 15s post-idle (`mysql` `default` `64M` vs `eco` `32M`, plus `sqlite` `0` DB RAM), dynamic WordPress/Laravel load, 50 concurrent requests, ~100 MB SQL import + undownloaded-DB gate test.
* **Pass/Fail (`P1`–`P7`):**
  * **P0 (Version Preservation):** `brew list --versions` confirms `php 8.4.8`, `composer 2.8.9`, `apr-util 1.6.3_1`, `pcre2 10.48`, `lz4 1.10.0`, `abseil 20260107.1`, `protobuf 35.1` are **100% unchanged** after setup (`Zero-Touch` path)!
  * **P1–P7:** 100% `arm64` execution (`0` Rosetta), valid `mpm_event` (`httpd -t`), undownloaded DB gate refuses cleanly, persistent WordPress/phpMyAdmin under MySQL 8.4, `< 20s` clean stop & `SIGKILL` recovery, `127.0.0.1`-only sockets/ports (`0700` dirs), `0.0%` GUI idle CPU.

---

## 8. Top 5 Risks

1. **Homebrew Shared-Library Upgrades (`--dry-run` Verified):** Installing `httpd`, `mysql@8.4`, `mariadb`, or `postgresql@18` via Homebrew upgrades shared libs (`lz4`, `pcre2`, `apr-util`, `abseil`, `protobuf`) used by existing tools (`php`, `node`, `ollama`, `git`). Mitigated by using macOS built-in `/usr/sbin/httpd` + existing `php 8.4.8` + precompiled `mysql-8.4` binary tarball (or explicit `--dry-run` approval).
2. **Tight Disk Space (`44 GiB` free):** Keeping `mariadb` and `postgresql@18` undownloaded saves space; logs remain capped (`10M × 3`).
3. **macOS `/usr/sbin/httpd` Future Deprecation / SIP Quirks:** Built-in `/usr/sbin/httpd` (`2.4.67`, `arm64e`) saves disk and keeps Homebrew untouched today, though Phase 1.1 must verify `httpd -f ... -t` works cleanly as a normal user (fallback: configurable `httpd_bin` in `stack.json`).
4. **iCloud Desktop Sync Re-Enablement:** Currently `0` (disabled), though stale `CloudDocs/Desktop` exists; mutable DBs live safely in `~/Library/Application Support/XamppLocal/`.
5. **macOS 28+ Security Tightening:** Ad-hoc `codesign --sign -` works locally today; future macOS versions or distribution may require Developer ID signing + notarization.

---

## 9. Phased Implementation Checklist

1. **Phase 1 (Zero-Touch Setup):** Pin `php` (`brew pin php`) and baseline snapshot `brew list --versions`; verify `/usr/sbin/httpd -f ... -t` passes non-root with `mpm_event` + `mod_proxy_fcgi`; install **only** default MySQL 8.4 (`arm64` precompiled tarball to preserve 100% of existing Mac library versions, or `mysql@8.4` with explicit consent) + SHA-256 verified `phpMyAdmin 5.2.3`; scaffold `0700` dirs in `XamppLocal/`.
2. **Phase 2 (Configs):** Author active `httpd`, `php`, `mysql`, `phpmyadmin` templates + dormant `mariadb`/`postgresql` templates; pass all syntax checks.
3. **Phase 3 (`xamppctl`):** Build `stack.json`, `doctor` (including version-drift check), `db install` (dry-run guarded), `db use` gatekeeper, ordered `start`/`stop`, `db import`, `vhost`, and `port80`.
4. **Phase 4 (`XamppControl.app`):** Compile `arm64` Swift app with `NSStatusItem`, Dock window toggle, `DispatchSource` exit watchers, and DB install confirmation prompt.
5. **Phase 5 (Verification):** Verify **P0** (zero unintended package changes) + **P1–P7** + `/usr/bin/footprint` benchmarks.
