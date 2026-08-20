<?php
declare(strict_types=1);

require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/meter_calc.php';

$method = $_SERVER['REQUEST_METHOD'];

try {
    $pdo = db_connect();

    switch ($method) {
        case 'GET':
            handle_get($pdo);
            break;
        case 'POST':
            handle_post($pdo);
            break;
        case 'PUT':
            handle_put($pdo);
            break;
        case 'DELETE':
            handle_delete($pdo);
            break;
        default:
            json_error('Method not allowed', 405);
    }
} catch (InvalidArgumentException $e) {
    json_error($e->getMessage(), 422);
} catch (PDOException $e) {
    json_error('Databazova chyba: ' . $e->getMessage(), 500);
}

function handle_get(PDO $pdo): void
{
    if (isset($_GET['last'])) {
        $result = [];
        foreach (array_keys(METER_LABELS) as $meter) {
            $stmt = $pdo->prepare(
                "SELECT * FROM pln_ele_vod WHERE mer_{$meter}_global IS NOT NULL ORDER BY mer_id DESC LIMIT 1"
            );
            $stmt->execute();
            $row = $stmt->fetch();

            if (!$row) {
                $result[$meter] = null;
                continue;
            }

            $result[$meter] = [
                'mer_id' => (int) $row['mer_id'],
                'mer_datetime' => $row['mer_datetime'],
                'raw' => $row["mer_$meter"] !== null ? (float) $row["mer_$meter"] : null,
                'global' => $row["mer_{$meter}_global"] !== null ? (float) $row["mer_{$meter}_global"] : null,
            ];
        }
        json_out($result);
        return;
    }

    $limit = isset($_GET['limit']) ? max(1, (int) $_GET['limit']) : 50;
    $stmt = $pdo->prepare('SELECT * FROM pln_ele_vod ORDER BY mer_id DESC LIMIT :limit');
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->execute();
    json_out($stmt->fetchAll());
}

/**
 * Precita a prepocita globalne hodnoty pre vsetky 3 meradla z JSON vstupu.
 * Neobsahuje ziadnu validaciu voci poslednym hodnotam - tu sa iba pocita.
 */
function compute_all_meters(PDO $pdo, array $input): array
{
    $meters = [];

    foreach (array_keys(METER_LABELS) as $meter) {
        $value = $input["mer_$meter"] ?? null;
        $change = !empty($input["mer_change_$meter"]);
        $removedInput = $input["mer_removed_$meter"] ?? null;
        $startInput = $input["mer_start_$meter"] ?? null;

        $meters[$meter] = compute_meter($pdo, $meter, $value, $change, $removedInput, $startInput);
    }

    return $meters;
}

/**
 * Porovna vypocitane globalne hodnoty s poslednymi ulozenymi.
 * Vrati zoznam textovych detailov ("ELE 1499 < 1500") pre kazde meradlo, ktore kleslo.
 * Pouziva sa iba pri POST - pri PUT sa validacia voci poslednym hodnotam nerobi.
 */
function validate_meters_against_last(PDO $pdo, array $meters): array
{
    $details = [];

    foreach ($meters as $meter => $computed) {
        if ($computed === null) {
            continue;
        }
        $lastGlobal = get_last_global($pdo, $meter);
        if ($lastGlobal !== null && $computed['global'] < $lastGlobal) {
            $details[] = strtoupper($meter) . ' '
                . format_meter_number($meter, $computed['global']) . ' < '
                . format_meter_number($meter, $lastGlobal);
        }
    }

    return $details;
}

function bind_meter_params(PDOStatement $stmt, array $input, array $meters): void
{
    foreach (array_keys(METER_LABELS) as $meter) {
        $computed = $meters[$meter];
        $stmt->bindValue(":mer_$meter", $computed['value'] ?? null);
        $stmt->bindValue(":mer_{$meter}_global", $computed['global'] ?? null);
        $stmt->bindValue(":mer_change_$meter", !empty($input["mer_change_$meter"]) ? 1 : 0, PDO::PARAM_INT);
        $stmt->bindValue(":mer_removed_$meter", $computed['removed'] ?? null);
        $stmt->bindValue(":mer_start_$meter", $computed['start'] ?? null);
    }
    $stmt->bindValue(':mer_note', $input['mer_note'] ?? null);
    $stmt->bindValue(':mer_note_pln', $input['mer_note_pln'] ?? null);
    $stmt->bindValue(':mer_note_ele', $input['mer_note_ele'] ?? null);
    $stmt->bindValue(':mer_note_vod', $input['mer_note_vod'] ?? null);
}

function handle_post(PDO $pdo): void
{
    $input = read_json_body();
    $datetime = $input['mer_datetime'] ?? date('Y-m-d H:i:s');

    $meters = compute_all_meters($pdo, $input);

    $details = validate_meters_against_last($pdo, $meters);
    if (!empty($details)) {
        json_out([
            'success' => false,
            'error' => 'validation_failed',
            'message' => 'Tieto hodnoty sú nižšie ako posledné:',
            'details' => $details,
            'http_status' => 422,
        ]);
        return;
    }

    $sql = 'INSERT INTO pln_ele_vod (
        mer_datetime,
        mer_pln, mer_pln_global, mer_change_pln, mer_removed_pln, mer_start_pln,
        mer_ele, mer_ele_global, mer_change_ele, mer_removed_ele, mer_start_ele,
        mer_vod, mer_vod_global, mer_change_vod, mer_removed_vod, mer_start_vod,
        mer_note, mer_note_pln, mer_note_ele, mer_note_vod
    ) VALUES (
        :mer_datetime,
        :mer_pln, :mer_pln_global, :mer_change_pln, :mer_removed_pln, :mer_start_pln,
        :mer_ele, :mer_ele_global, :mer_change_ele, :mer_removed_ele, :mer_start_ele,
        :mer_vod, :mer_vod_global, :mer_change_vod, :mer_removed_vod, :mer_start_vod,
        :mer_note, :mer_note_pln, :mer_note_ele, :mer_note_vod
    )';

    $stmt = $pdo->prepare($sql);
    $stmt->bindValue(':mer_datetime', $datetime);
    bind_meter_params($stmt, $input, $meters);
    $stmt->execute();

    json_out(['success' => true, 'mer_id' => (int) $pdo->lastInsertId()], 201);
}

function handle_put(PDO $pdo): void
{
    $id = isset($_GET['id']) ? (int) $_GET['id'] : 0;
    if ($id <= 0) {
        json_error('Chybajuce alebo neplatne id.', 400);
        return;
    }

    $check = $pdo->prepare('SELECT mer_id FROM pln_ele_vod WHERE mer_id = :id');
    $check->execute([':id' => $id]);
    if (!$check->fetch()) {
        json_error('Zaznam nebol najdeny.', 404);
        return;
    }

    $input = read_json_body();

    // Poznamka: pri PUT sa uz nerobi validacia voci poslednej globalnej hodnote
    // (uprava historickeho zaznamu moze legitimne znizit jeho vlastnu hodnotu).
    $meters = compute_all_meters($pdo, $input);

    $sql = 'UPDATE pln_ele_vod SET
        mer_datetime = COALESCE(:mer_datetime, mer_datetime),
        mer_pln = :mer_pln, mer_pln_global = :mer_pln_global, mer_change_pln = :mer_change_pln, mer_removed_pln = :mer_removed_pln, mer_start_pln = :mer_start_pln,
        mer_ele = :mer_ele, mer_ele_global = :mer_ele_global, mer_change_ele = :mer_change_ele, mer_removed_ele = :mer_removed_ele, mer_start_ele = :mer_start_ele,
        mer_vod = :mer_vod, mer_vod_global = :mer_vod_global, mer_change_vod = :mer_change_vod, mer_removed_vod = :mer_removed_vod, mer_start_vod = :mer_start_vod,
        mer_note = :mer_note, mer_note_pln = :mer_note_pln, mer_note_ele = :mer_note_ele, mer_note_vod = :mer_note_vod
        WHERE mer_id = :id';

    $stmt = $pdo->prepare($sql);
    $stmt->bindValue(':mer_datetime', $input['mer_datetime'] ?? null);
    bind_meter_params($stmt, $input, $meters);
    $stmt->bindValue(':id', $id, PDO::PARAM_INT);
    $stmt->execute();

    json_out(['success' => true]);
}

function handle_delete(PDO $pdo): void
{
    $id = isset($_GET['id']) ? (int) $_GET['id'] : 0;
    if ($id <= 0) {
        json_error('Chybajuce alebo neplatne id.', 400);
        return;
    }

    $stmt = $pdo->prepare('DELETE FROM pln_ele_vod WHERE mer_id = :id');
    $stmt->execute([':id' => $id]);

    if ($stmt->rowCount() === 0) {
        json_error('Zaznam nebol najdeny.', 404);
        return;
    }

    json_out(['success' => true]);
}
