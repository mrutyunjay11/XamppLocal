<?php
declare(strict_types=1);

$home = getenv('HOME') ?: (posix_getpwuid(posix_geteuid())['dir'] ?? '');
$appSupport = $home . '/Library/Application Support/XamppLocal';
$metaFile = $appSupport . '/run/generated/runtime_meta.json';
$stack = [];
if (is_readable($metaFile)) {
    $stack = json_decode((string) file_get_contents($metaFile), true) ?: [];
}
$engine = $stack['db_engine'] ?? 'mysql';
$profile = $stack['db_profile'] ?? 'default';
$pmaPort = (int) ($stack['pma_port'] ?? 8081);

$dbStatus = 'Not connected';
if ($engine === 'sqlite') {
    $dbStatus = 'SQLite 3 built-in (SQLite version ' . SQLite3::version()['versionString'] . ')';
} elseif ($engine === 'mysql' || $engine === 'mariadb') {
    $sock = $appSupport . '/run/mysql.sock';
    try {
        $mysqli = new mysqli('localhost', 'root', '', '', 0, $sock);
        $dbStatus = 'Connected (' . $mysqli->server_info . ')';
        $mysqli->close();
    } catch (Throwable $e) {
        $dbStatus = 'Offline (' . $e->getMessage() . ')';
    }
} elseif ($engine === 'postgresql') {
    if (function_exists('pg_connect')) {
        $conn = @pg_connect('host=127.0.0.1 port=5432 user=postgres dbname=postgres');
        if ($conn) {
            $ver = pg_version($conn);
            $dbStatus = 'Connected (PostgreSQL ' . ($ver['server'] ?? '') . ')';
            pg_close($conn);
        } else {
            $dbStatus = 'Offline (PostgreSQL port 5432 unreachable)';
        }
    }
}
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>XamppLocal Control Dashboard</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; margin: 2.5rem auto; max-width: 720px; color: #1d1d1f; background: #f5f5f7; padding: 0 1rem; }
  .card { background: #fff; border-radius: 14px; padding: 1.5rem; box-shadow: 0 2px 10px rgba(0,0,0,0.06); margin-bottom: 1rem; }
  h1 { margin-top: 0; font-size: 1.5rem; }
  .row { display: flex; justify-content: space-between; padding: 0.5rem 0; border-bottom: 1px solid #ececec; }
  .row:last-child { border-bottom: none; }
  .label { color: #6e6e73; }
  .val { font-weight: 600; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 0.9rem; }
  a.btn { display: inline-block; margin-right: 0.75rem; margin-top: 0.5rem; padding: 0.5rem 0.9rem; border-radius: 8px; background: #0071e3; color: #fff; text-decoration: none; font-size: 0.9rem; }
  a.btn.disabled { background: #c7c7cc; pointer-events: none; }
</style>
</head>
<body>
  <div class="card">
    <h1>XamppLocal (Native macOS <?= htmlspecialchars(php_uname('m')) ?>)</h1>
    <div class="row"><span class="label">Apache</span><span class="val"><?= htmlspecialchars($_SERVER['SERVER_SOFTWARE'] ?? 'Apache') ?></span></div>
    <div class="row"><span class="label">PHP Version</span><span class="val"><?= htmlspecialchars(PHP_VERSION) ?> (<?= htmlspecialchars(PHP_SAPI) ?>)</span></div>
    <div class="row"><span class="label">Active DB Engine</span><span class="val"><?= htmlspecialchars($engine) ?> (profile: <?= htmlspecialchars($profile) ?>)</span></div>
    <div class="row"><span class="label">Database Health</span><span class="val"><?= htmlspecialchars($dbStatus) ?></span></div>
    <div class="row"><span class="label">OPcache Enabled</span><span class="val"><?= (function_exists('opcache_get_status') && opcache_get_status(false)) ? 'Yes' : 'No' ?></span></div>
    <div>
      <?php if ($engine === 'mysql' || $engine === 'mariadb'): ?>
        <a class="btn" href="http://127.0.0.1:<?= $pmaPort ?>/">Open phpMyAdmin (Isolated :<?= $pmaPort ?>)</a>
      <?php else: ?>
        <a class="btn disabled" href="#">phpMyAdmin (MySQL/MariaDB only)</a>
      <?php endif; ?>
    </div>
  </div>
</body>
</html>
