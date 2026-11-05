<?php
declare(strict_types=1);

require __DIR__ . '/config.php';

/**
 * Demo-website van het Ansible-lab van Eliyah Impelmans.
 * De pagina laat zien dat de webserver (Debian) en de databaseserver
 * (Rocky Linux) samenwerken: elke bezoeker wordt in MariaDB geteld.
 */

$dbOnline = false;
$bezoekers = 0;
$dbFout = '';

try {
    $pdo = new PDO(
        sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', DB_HOST, DB_PORT, DB_NAME),
        DB_USER,
        DB_PASS,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_TIMEOUT => 3]
    );

    $pdo->exec('INSERT INTO bezoekers (bezocht_op) VALUES (NOW())');
    $bezoekers = (int) $pdo->query('SELECT COUNT(*) FROM bezoekers')->fetchColumn();
    $dbOnline = true;
} catch (Throwable $e) {
    $dbFout = $e->getMessage();
}

$os = 'onbekend';
if (is_readable('/etc/os-release')) {
    $release = parse_ini_file('/etc/os-release');
    $os = $release['PRETTY_NAME'] ?? 'onbekend';
}

$uptimeSeconden = 0.0;
if (is_readable('/proc/uptime')) {
    $uptimeSeconden = (float) explode(' ', trim((string) file_get_contents('/proc/uptime')))[0];
}

$dagen = (int) floor($uptimeSeconden / 86400);
$uren = (int) floor(($uptimeSeconden % 86400) / 3600);
$minuten = (int) floor(($uptimeSeconden % 3600) / 60);

function e(string|int|float|null $waarde): string
{
    return htmlspecialchars((string) $waarde, ENT_QUOTES, 'UTF-8');
}
?>
<!DOCTYPE html>
<html lang="nl">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Eliyah Impelmans &middot; Ansible Lab</title>
    <link rel="stylesheet" href="assets/style.css">
</head>
<body>
<header class="hero">
    <p class="kicker">Ansible-lab &middot; Debian 12 &rarr; Rocky Linux 9</p>
    <h1>Eliyah Impelmans</h1>
    <p class="lead">
        Deze pagina is door Ansible op de webserver geplaatst en haalt haar gegevens
        live uit de databaseserver.
    </p>
    <span class="badge <?= $dbOnline ? 'badge-ok' : 'badge-fout' ?>">
        <?= $dbOnline ? 'Database verbonden' : 'Database niet bereikbaar' ?>
    </span>
</header>

<main class="grid">
    <section class="card">
        <h2>Webserver</h2>
        <dl>
            <dt>Hostname</dt><dd><?= e(gethostname()) ?></dd>
            <dt>Distributie</dt><dd><?= e($os) ?></dd>
            <dt>PHP-versie</dt><dd><?= e(PHP_VERSION) ?></dd>
            <dt>Uptime</dt><dd><?= e($dagen) ?>d <?= e($uren) ?>u <?= e($minuten) ?>m</dd>
        </dl>
    </section>

    <section class="card">
        <h2>Databaseserver</h2>
        <dl>
            <dt>Adres</dt><dd><?= e(DB_HOST) ?>:<?= e(DB_PORT) ?></dd>
            <dt>Database</dt><dd><?= e(DB_NAME) ?></dd>
            <dt>Gebruiker</dt><dd><?= e(DB_USER) ?></dd>
            <dt>Status</dt>
            <dd>
                <?php if ($dbOnline): ?>
                    verbonden &middot; <?= e($bezoekers) ?> bezoek<?= $bezoekers === 1 ? '' : 'en' ?> geteld
                <?php else: ?>
                    fout: <?= e($dbFout) ?>
                <?php endif; ?>
            </dd>
        </dl>
    </section>
</main>

<footer class="voet">
    <p>Uitgerold met <strong>Ansible</strong> vanaf <code>eliyah-ansible</code>.</p>
    <p class="klein">Pagina gegenereerd op <?= e(date('d-m-Y H:i:s')) ?>.</p>
</footer>
</body>
</html>
