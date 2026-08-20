<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    json_error('Method not allowed', 405);
}

$input = read_json_body();
$pin = $input['pin'] ?? null;

if (!is_string($pin) && !is_int($pin)) {
    json_error('Neplatny PIN format.', 400);
}
$pin = (string) $pin;

if (!preg_match('/^\d{4}$/', $pin)) {
    json_error('Neplatny PIN format.', 400);
}

try {
    $pdo = db_connect();
    $stmt = $pdo->prepare('SELECT mer_username FROM mer_pins WHERE mer_pin = :pin LIMIT 1');
    $stmt->execute([':pin' => $pin]);
    $row = $stmt->fetch();

    if ($row) {
        json_out(['success' => true, 'username' => $row['mer_username']]);
    } else {
        json_out(['success' => false], 401);
    }
} catch (PDOException $e) {
    json_error('Databazova chyba: ' . $e->getMessage(), 500);
}
