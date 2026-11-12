#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$ROOT/bin/xamppctl"
APP_SUPPORT="$HOME/Library/Application Support/XamppLocal"
REPORT="$APP_SUPPORT/logs/bench/report-$(date +%Y%m%d-%H%M%S).md"
MYSQL_BIN="$APP_SUPPORT/engines/mysql-8.4/bin/mysql"
SOCK="$APP_SUPPORT/run/mysql.sock"

mkdir -p "$(dirname "$REPORT")"

measure_tree_footprint() {
  /usr/bin/footprint -p httpd -p php-fpm -p mysqld --swapped --noCategories 2>/dev/null | tail -n 1 || echo "Summary Footprint: 0 MB"
}

{
  echo "# XamppLocal Benchmark & Verification Report"
  echo ""
  echo "- **Date:** $(date)"
  echo "- **Host:** $(uname -m), $(sw_vers -productVersion)"
  echo ""

  echo "## P0 & Doctor Checks"
  "$CLI" doctor
  echo ""

  echo "## P3 Undownloaded DB Gate Checks"
  set +e
  "$CLI" db use mariadb >/dev/null 2>&1
  MARIADB_EXIT=$?
  "$CLI" db use postgresql >/dev/null 2>&1
  PG_EXIT=$?
  set -e
  echo "- \`xamppctl db use mariadb\` (not installed): exit=$MARIADB_EXIT (expected 2)"
  echo "- \`xamppctl db use postgresql\` (not installed): exit=$PG_EXIT (expected 2)"
  echo ""

  echo "## B1. Stopped Baseline"
  "$CLI" stop all >/dev/null
  sleep 2
  LEFTOVER_SOCKS=$(find "$APP_SUPPORT/run" -maxdepth 1 -name '*.sock' | wc -l | tr -d ' ')
  LEFTOVER_PIDS=$(find "$APP_SUPPORT/run" -maxdepth 1 -name '*.pid' | wc -l | tr -d ' ')
  echo "- Leftover sockets: $LEFTOVER_SOCKS (expected 0)"
  echo "- Leftover PIDs: $LEFTOVER_PIDS (expected 0)"
  echo ""

  echo "## B2. Idle Footprint (After 12s PHP-FPM Worker Idle Expiry)"
  for PROF in default eco; do
    "$CLI" db use mysql >/dev/null
    "$CLI" db profile "$PROF" >/dev/null
    "$CLI" start all >/dev/null
    curl -fsS http://127.0.0.1:8080/bench.php >/dev/null
    sleep 12
    echo "### MySQL 8.4 (profile=$PROF)"
    "$CLI" status --memory
    echo "- Full tree: $(measure_tree_footprint)"
    "$CLI" stop all >/dev/null
  done

  "$CLI" db use sqlite >/dev/null
  "$CLI" start all >/dev/null
  curl -fsS "http://127.0.0.1:8080/" >/dev/null
  sleep 12
  echo "### SQLite Built-in (0 MB DB Daemon)"
  "$CLI" status --memory
  echo "- Full tree: $(measure_tree_footprint)"
  "$CLI" stop all >/dev/null
  echo ""

  echo "## B3. Persistence Across Restart & PHP + phpMyAdmin Smoke Test"
  "$CLI" db use mysql >/dev/null
  "$CLI" db profile default >/dev/null
  "$CLI" start all >/dev/null
  "$MYSQL_BIN" --socket="$SOCK" -u root -e "CREATE DATABASE IF NOT EXISTS xampp_verify; USE xampp_verify; CREATE TABLE IF NOT EXISTS items (id INT AUTO_INCREMENT PRIMARY KEY, val VARCHAR(64)); TRUNCATE TABLE items; INSERT INTO items (val) VALUES ('persisted_ok');"
  "$CLI" restart all >/dev/null
  PERSISTED=$("$MYSQL_BIN" --socket="$SOCK" -u root -N -e "SELECT val FROM xampp_verify.items LIMIT 1;")
  PMA_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8081/)
  echo "- Persistence check after full restart: \`$PERSISTED\`"
  echo "- phpMyAdmin HTTP status: \`$PMA_CODE\`"
  echo ""

  echo "## B4. 50 Concurrent Requests (/usr/sbin/ab -n 1000 -c 50)"
  /usr/sbin/ab -n 1000 -c 50 http://127.0.0.1:8080/bench.php | grep -E "Complete requests|Failed requests|Requests per second|Time per request|95%|99%"
  echo "- Peak/post-load footprint: $(measure_tree_footprint)"
  echo ""

  echo "## B5. Bulk SQL Import Benchmark (~20 MB Dump)"
  TMP_SQL="/tmp/xampp_bench_import.sql"
  python3 -c "
with open('$TMP_SQL', 'w') as f:
    f.write('CREATE DATABASE IF NOT EXISTS xampp_verify;\nUSE xampp_verify;\nDROP TABLE IF EXISTS bulk_t;\nCREATE TABLE bulk_t (id INT AUTO_INCREMENT PRIMARY KEY, pad CHAR(180));\n')
    row = \"('\" + ('x'*180) + \"')\"
    batch = 'INSERT INTO bulk_t (pad) VALUES ' + ','.join([row]*500) + ';\n'
    for _ in range(200):
        f.write(batch)
"
  for PROF in default import; do
    "$CLI" db profile "$PROF" >/dev/null
    "$CLI" restart db >/dev/null
    T0=$(python3 -c 'import time; print(time.monotonic())')
    "$CLI" db import "$TMP_SQL" xampp_verify >/dev/null
    T1=$(python3 -c 'import time; print(time.monotonic())')
    DUR=$(python3 -c "print(f'{($T1 - $T0):.2f}s')")
    echo "- Import duration (profile=$PROF): $DUR | $(measure_tree_footprint)"
  done
  rm -f "$TMP_SQL"

  "$MYSQL_BIN" --socket="$SOCK" -u root -e "DROP DATABASE IF EXISTS xampp_verify;"
  "$CLI" db profile default >/dev/null
  "$CLI" stop all >/dev/null
  echo ""
  echo "## Final Stopped Clean Check"
  echo "- Stopped cleanly with exit 0."
} | tee "$REPORT"

echo "Report written to: $REPORT"
