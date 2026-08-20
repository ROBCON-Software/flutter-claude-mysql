<?php
declare(strict_types=1);

require_once __DIR__ . '/db_connect.php';

const METER_LABELS = [
    'pln' => 'Plynomer',
    'ele' => 'Elektromer',
    'vod' => 'Vodomer',
];

/**
 * Zaokruhli hodnotu podla typu meradla (ele = cele cislo, pln/vod = 3 desatinne miesta).
 */
function meter_round(string $meter, $value)
{
    if ($value === null) {
        return null;
    }
    if ($meter === 'ele') {
        return (int) round((float) $value);
    }
    return round((float) $value, 3);
}

/**
 * Najde posledny riadok, kde bola zaznamenana vymena meradla ($meter),
 * a vrati "zamrznute" removed/start hodnoty pouzivane pre vypocet globalu.
 */
function get_last_change_row(PDO $pdo, string $meter): array
{
    $colChange = "mer_change_$meter";
    $colRemoved = "mer_removed_$meter";
    $colStart = "mer_start_$meter";

    $stmt = $pdo->prepare(
        "SELECT $colRemoved AS removed, $colStart AS start
         FROM pln_ele_vod
         WHERE $colChange = 1
         ORDER BY mer_id DESC LIMIT 1"
    );
    $stmt->execute();
    $row = $stmt->fetch();

    if (!$row) {
        return ['removed' => 0, 'start' => 0];
    }

    return ['removed' => (float) $row['removed'], 'start' => (float) $row['start']];
}

/**
 * Vrati poslednu znamu globalnu hodnotu pre dane meradlo (najnovsi riadok, kde nie je NULL).
 */
function get_last_global(PDO $pdo, string $meter): ?float
{
    $colGlobal = "mer_{$meter}_global";
    $stmt = $pdo->prepare(
        "SELECT $colGlobal AS g FROM pln_ele_vod WHERE $colGlobal IS NOT NULL ORDER BY mer_id DESC LIMIT 1"
    );
    $stmt->execute();
    $row = $stmt->fetch();

    return $row ? (float) $row['g'] : null;
}

/**
 * Formatuje hodnotu meradla pre chybove hlasky (ele bez desatinnych miest, pln/vod na 3 desatiny).
 */
function format_meter_number(string $meter, $value): string
{
    if ($meter === 'ele') {
        return (string) (int) round((float) $value);
    }
    return number_format((float) $value, 3, '.', '');
}

/**
 * Vypocita hodnotu, globalnu hodnotu a (pri vymene) removed/start pre jedno meradlo.
 * Vrati null, ak hodnota nebola zadana (mimoriadny/neuplny zapis).
 * Hodi InvalidArgumentException, ak pri zmene meradla chybaju removed/start udaje.
 */
function compute_meter(PDO $pdo, string $meter, $value, bool $change, $removedInput, $startInput): ?array
{
    if ($value === null || $value === '') {
        return null;
    }

    $value = meter_round($meter, $value);

    if ($change) {
        if ($removedInput === null || $removedInput === '' || $startInput === null || $startInput === '') {
            $label = METER_LABELS[$meter];
            throw new InvalidArgumentException(
                "$label: pri zmene meradla je potrebne zadat povodnu aj startovaciu hodnotu."
            );
        }
        $removed = meter_round($meter, $removedInput);
        $start = meter_round($meter, $startInput);
    } else {
        $last = get_last_change_row($pdo, $meter);
        $removed = $last['removed'];
        $start = $last['start'];
    }

    $global = meter_round($meter, $removed + ($value - $start));

    return [
        'value' => $value,
        'global' => $global,
        'removed' => $change ? $removed : null,
        'start' => $change ? $start : null,
    ];
}
