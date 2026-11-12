<?php
declare(strict_types=1);

$home = getenv('HOME') ?: (posix_getpwuid(posix_geteuid())['dir'] ?? '');
$appSupport = $home . '/Library/Application Support/XamppLocal';
$mysqli = new mysqli('localhost', 'root', '', '', 0, $appSupport . '/run/mysql.sock');
$res = $mysqli->query('SELECT 1 AS ok');
$row = $res ? $res->fetch_assoc() : null;
$mysqli->close();
echo ($row && (int)$row['ok'] === 1) ? "BENCH_OK\n" : "BENCH_FAIL\n";

