#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_SUPPORT="$HOME/Library/Application Support/XamppLocal"
WEB_ROOT="$HOME/Sites/Xampp"

MYSQL_VER="8.4.13"
MYSQL_TAR="mysql-${MYSQL_VER}-macos15-arm64.tar.gz"
MYSQL_URL="https://dev.mysql.com/get/Downloads/MySQL-8.4/${MYSQL_TAR}"
MYSQL_MD5="73926da59774274b5cdfe78cd2150840"

PMA_VER="5.2.3"
PMA_URL="https://files.phpmyadmin.net/phpMyAdmin/${PMA_VER}/phpMyAdmin-${PMA_VER}-all-languages.tar.gz"
PMA_SHA256="12ba1c425fa4071abbd4e7668c9ebdeac0b0755a467a6d6d5026122bb47c102b"

if [ "$(uname -m)" != "arm64" ]; then
  echo "Error: XamppLocal targets Apple Silicon (arm64) Macs." >&2
  exit 1
fi

echo "==> Creating protected runtime directories in $APP_SUPPORT"
mkdir -p "$APP_SUPPORT"/{data/mysql,engines,run/generated,logs/bench,tmp/phpmyadmin,apps} "$WEB_ROOT"
chmod 700 "$APP_SUPPORT" "$APP_SUPPORT/data" "$APP_SUPPORT/data/mysql" "$APP_SUPPORT/run" "$APP_SUPPORT/logs" "$APP_SUPPORT/tmp" "$APP_SUPPORT/tmp/phpmyadmin" "$APP_SUPPORT/apps" "$WEB_ROOT"

if [ ! -f "$APP_SUPPORT/logs/baseline-brew-versions.txt" ] && command -v brew >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew list --versions > "$APP_SUPPORT/logs/baseline-brew-versions.txt" || true
fi

# Preserve existing PHP if already installed; install only if missing
if [ ! -x "/opt/homebrew/opt/php/sbin/php-fpm" ]; then
  echo "==> Installing Homebrew PHP (php-fpm not found)"
  HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1 brew install php
fi
HOMEBREW_NO_AUTO_UPDATE=1 brew pin php >/dev/null 2>&1 || true

# Install MySQL 8.4 LTS precompiled arm64 tarball (zero changes to Homebrew libs)
MYSQL_DIR="$APP_SUPPORT/engines/mysql-8.4"
if [ ! -x "$MYSQL_DIR/bin/mysqld" ]; then
  echo "==> Downloading official MySQL $MYSQL_VER (macOS arm64)"
  TMP_MYSQL="/tmp/${MYSQL_TAR}"
  curl -fL "$MYSQL_URL" -o "$TMP_MYSQL"
  ACTUAL_MD5="$(md5 -q "$TMP_MYSQL")"
  if [ "$ACTUAL_MD5" != "$MYSQL_MD5" ]; then
    echo "Error: MySQL tarball MD5 mismatch ($ACTUAL_MD5 != $MYSQL_MD5)" >&2
    rm -f "$TMP_MYSQL"
    exit 1
  fi
  mkdir -p "$MYSQL_DIR"
  tar -xzf "$TMP_MYSQL" --strip-components=1 -C "$MYSQL_DIR"
  rm -f "$TMP_MYSQL"
fi

# Install official phpMyAdmin 5.2.3
PMA_DIR="$APP_SUPPORT/apps/phpmyadmin"
if [ ! -f "$PMA_DIR/index.php" ]; then
  echo "==> Downloading phpMyAdmin $PMA_VER"
  TMP_PMA="/tmp/pma-${PMA_VER}.tar.gz"
  curl -fL "$PMA_URL" -o "$TMP_PMA"
  ACTUAL_SHA="$(shasum -a 256 "$TMP_PMA" | awk '{print $1}')"
  if [ "$ACTUAL_SHA" != "$PMA_SHA256" ]; then
    echo "Error: phpMyAdmin SHA-256 mismatch ($ACTUAL_SHA != $PMA_SHA256)" >&2
    rm -f "$TMP_PMA"
    exit 1
  fi
  mkdir -p "$PMA_DIR"
  tar -xzf "$TMP_PMA" --strip-components=1 -C "$PMA_DIR"
  rm -f "$TMP_PMA"
fi

cat > "$PMA_DIR/config.inc.php" << 'EOF'
<?php
declare(strict_types=1);

$home = getenv('HOME') ?: (posix_getpwuid(posix_geteuid())['dir'] ?? '');
$generated = $home . '/Library/Application Support/XamppLocal/run/generated/phpmyadmin.inc.php';
if (is_readable($generated)) {
    require $generated;
}
EOF

# Copy dashboard files if web root is empty
if [ ! -f "$WEB_ROOT/index.php" ]; then
  cp "$ROOT/htdocs-template/index.php" "$WEB_ROOT/index.php"
fi
if [ ! -f "$WEB_ROOT/bench.php" ]; then
  cp "$ROOT/htdocs-template/bench.php" "$WEB_ROOT/bench.php"
fi

echo "==> Building XamppControl.app (arm64)"
"$ROOT/app/build.sh"

echo "==> Running doctor verification"
"$ROOT/bin/xamppctl" doctor

