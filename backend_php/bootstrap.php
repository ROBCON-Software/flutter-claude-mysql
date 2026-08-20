<?php
declare(strict_types=1);

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

require_once __DIR__ . '/db_connect.php';

/**
 * $status je iba logicky/informativny (prilozi sa do tela ako http_status pri chybach).
 * Fyzicky sa vzdy posiela HTTP 200, pretoze Synology DSM Web Station nahradza akukolvek
 * non-2xx odpoved vlastnou HTML chybovou strankou a JSON telo by sa k appke vobec nedostalo.
 * Appka preto vyhodnocuje uspech/chybu podla obsahu JSON tela (napr. 'success' alebo 'error'),
 * nie podla HTTP status kodu.
 */
function json_out($data, int $status = 200): void
{
    http_response_code(200);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function json_error(string $message, int $status = 400): void
{
    json_out(['success' => false, 'error' => $message, 'http_status' => $status]);
}

function read_json_body(): array
{
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        json_error('Neplatny JSON vstup.', 400);
    }
    return $data;
}
