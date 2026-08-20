# Projekt: Appka na evidenciu meradiel (PLN/ELE/VOD)

Záznam stavu návrhu k 20.8.2026 — na obnovenie kontextu v novej konverzácii.

---

## 1. Základné prostredie

- **Flutter projekt**: `D:\DOCUMENTS\RUH-SYNOLOGY\DATA\CODING\FLUTTER\flutter_claude_mysql`
- **GitHub repo**: `ROBCON-Software/flutter-claude-mysql` (verzované cez Git)
- **Backend**: PHP 8.2.28, nginx 1.23.1, beží priamo na Synology NAS (lokálna IP `192.168.23.200`)
- **Databáza**: MariaDB 10.11.11, prístup cez UNIX socket, `root@localhost`, databáza sa volá **`tree`**
- **phpMyAdmin**: 5.2.2
- **Vývojové nástroje**: Android Studio + VS Code, obe s pluginom/rozšírením Claude Code
- **Claude Code**: nainštalovaný cez natívny Windows inštalátor (`irm https://claude.ai/install.ps1 | iex`), prihlásený cez Anthropic Console účet (API billing, zakúpený kredit 5 USD, nie mesačné predplatné)
- Appka bude mať v konfigurácii **`wan_ip`/`wan_port`** a **`lan_ip`/`lan_port`** s prepínačom, ktorý sa nastaví pred finálnym buildom (zatiaľ appka funguje len v lokálnej sieti, NAS zatiaľ nemá verejný prístup)

---

## 2. Databázová štruktúra

### Pôvodné tabuľky (existujú, nemenia sa)
- `plynomer` (plynomer_id, plynomer_value DECIMAL(11,3), plynomer_datetime TIMESTAMP)
- `elektromer` (elektromer_id, elektromer_value DECIMAL(11,1), elektromer_datetime TIMESTAMP)
- `vodomer` (vodomer_id, vodomer_value DECIMAL(11,3), vodomer_datetime TIMESTAMP) — pôvodne malo `ON UPDATE CURRENT_TIMESTAMP()`, **už opravené/odstránené**

### Nová zlúčená tabuľka: `pln_ele_vod`

Vytvorená spojením pôvodných troch tabuliek podľa dátumu (LEFT JOIN logika, žiadny záznam sa nestratí, aj neúplné dni ostávajú s NULL hodnotami). ID je nastavené vzostupne podľa dátumu (najstarší = najnižšie ID).

**Finálna štruktúra stĺpcov (prefix `mer_` kvôli budúcej prenositeľnosti):**

```sql
mer_id             INT AUTO_INCREMENT PRIMARY KEY
mer_datetime       TIMESTAMP

mer_pln            DECIMAL(11,3)   -- surová hodnota plynomera
mer_pln_global     DECIMAL(11,3)   -- kumulatívna globálna hodnota
mer_change_pln     TINYINT(1)      -- príznak výmeny meradla (0/1)
mer_removed_pln    DECIMAL(11,3)   -- hodnota z výmenného lístka (len pri change=1)
mer_start_pln      DECIMAL(11,3)   -- štart nového meradla (len pri change=1)

mer_ele            INT             -- elektromer nemá desatinné miesta
mer_ele_global     INT
mer_change_ele     TINYINT(1)
mer_removed_ele    INT
mer_start_ele      INT

mer_vod            DECIMAL(11,3)
mer_vod_global     DECIMAL(11,3)
mer_change_vod     TINYINT(1)
mer_removed_vod    DECIMAL(11,3)
mer_start_vod      DECIMAL(11,3)

mer_note           VARCHAR(255)
mer_note_pln       VARCHAR(255)
mer_note_ele       VARCHAR(255)
mer_note_vod       VARCHAR(255)
```

Tabuľka je v databáze **už reálne vytvorená a naplnená** (ALTER TABLE + UPDATE bolo spustené, historické riadky majú `mer_X_global = mer_X`, keďže dosiaľ nenastala žiadna výmena meradla).

### Plánovaná tabuľka cien (zatiaľ nevytvorená, len navrhnutá)

```sql
price_id INT AUTO_INCREMENT PRIMARY KEY
price_type ENUM('pln','ele','vod')
price_value DECIMAL(10,4)     -- cena za jednotku (m3/kWh)
valid_from DATE               -- odkedy platí táto cena
```

Dôvod: ceny sa menia v čase, historické štatistiky musia počítať so správnou cenou platnou v danom období (nie len s aktuálnou).

---

## 3. Metodika výpočtu globálnej (kumulatívnej) hodnoty

Platí nezávisle pre každé z troch meradiel (X = pln/ele/vod). **Dôležité: appka počíta a ukladá globálnu hodnotu pri zápise (nie SQL VIEW).**

### Bežný zápis (mer_change_X = 0)
Appka nájde posledný riadok, kde `mer_change_X = 1` (posledná zaznamenaná výmena), zoberie odtiaľ `mer_removed_X` a `mer_start_X`:

```
mer_X_global = mer_removed_X + (mer_X − mer_start_X)
```

Ak sa meradlo X ešte nikdy nemenilo: `mer_removed_X = 0`, `mer_start_X = 0` → `mer_X_global = mer_X`.

### Riadok s výmenou meradla (mer_change_X = 1)
- Hlavné pole `mer_X` **zostáva aktívne a vyplní sa** — je to aktuálny odpočet na NOVOM meradle v deň zápisu (nemusí byť deň fyzickej výmeny — môže byť aj neskôr, napr. najbližší pondelok)
- `mer_removed_X` = hodnota z výmenného lístka (posledná hodnota STARÉHO meradla v momente výmeny)
- `mer_start_X` = štartovacia hodnota NOVÉHO meradla (tiež z lístka, nemusí byť 0)
- Výpočet: `mer_X_global = mer_removed_X + (mer_X − mer_start_X)`

### Overený príklad výpočtu (odsúhlasené s používateľom)
- Predposledné odčítanie (staré meradlo): 2100 → global 2100
- Posledné odčítanie (staré meradlo): 2200 → global 2200
- Deň výmeny, lístok: staré = 2250, nové štartuje na 30
- Prvé odčítanie na novom meradle: 30 → global = 2250 + (30−30) = **2250**
- Ďalšie odčítanie: 50 → global = 2250 + (50−30) = **2270**
- Ďalšie odčítanie: 150 → global = 2250 + (150−30) = **2370**

**Kľúčové pravidlo:** `mer_removed_X` a `mer_start_X` sa "zamrznú" na riadku výmeny a používajú sa nezmenené pre výpočet globálnej hodnoty všetkých nasledujúcich riadkov až do ďalšej výmeny (nie iba pre prvý riadok po výmene).

### Validácia pri ukladaní (dôležité poradie kontrol!)
1. **Najprv**: pre každé pole, kde bola zadaná hodnota (vrátane 0 — nie len prázdne pole), sa prepočíta `mer_X_global` a porovná s poslednou uloženou globálnou hodnotou pre dané meradlo. Ak nová < posledná → **tvrdo zablokovať uloženie** (nesmie nastať diskrepancia).
2. **Až potom**: ak sú niektoré polia prázdne a iné vyplnené (nekompletný/mimoriadny zápis) → zobraziť potvrdzovací dialóg "Mimoriadny odpočet — si si istý? ÁNO/NIE".

### Zaokrúhľovanie
- `mer_pln`, `mer_vod` (aj removed/start varianty) → zaokrúhliť na **3 desatinné miesta**
- `mer_ele` (aj removed/start varianty) → zaokrúhliť na **celé číslo**
- Vstupný filter pre všetky číselné polia: iba `0–9` a `.` (žiadna čiarka, žiadne iné znaky, numerická klávesnica)

---

## 4. Architektúra appky — 5 kariet cez Drawer navigáciu

**Navigácia**: Drawer (hamburger menu vľavo hore v AppBar, vedľa názvu aktuálnej karty). Položky v Draweri:
1. Odpočty (CRUD)
2. Prehľad (tabuľka globálnych hodnôt)
3. Štatistiky
4. Grafy
5. Nastavenia
6. — oddeľovač —
7. Exit (s potvrdzovacím dialógom, appku úplne ukončí)

Karty sa budujú **postupne, jedna po druhej** (kvôli kontrole kvality aj šetreniu API kreditu) — poradie: **CRUD → Prehľad → Štatistiky → Nastavenia → Grafy**.

### Karta 1: Odpočty (CRUD) — DETAILNE DOLADENÉ, PRIPRAVENÉ NA IMPLEMENTÁCIU

- **Jeden spoločný formulár** pre všetky tri meradlá naraz (nie samostatné formuláre)
- Dátum/čas: predvyplnený na aktuálny moment zápisu, možnosť ručne zmeniť (spätný zápis)
- Pri každom poli (PLN/ELE/VOD hlavné, aj removed/start, aj poznámky):
  - Ikonka **clear (krížik v krúžku)** vpravo, objaví sa len keď pole obsahuje hodnotu
  - Ikonka **reload/refresh (šípka v krúžku)** vľavo — vloží poslednú SUROVÚ hodnotu daného meradla, kurzor skočí na koniec textu v danom poli
  - Nad poľom vľavo hore (súčasť orámovania) — popisok s poslednou hodnotou vo formáte: `GLOBÁLNA [SUROVÁ]`, napr. `2370 [150]`
- **Tlačidlo "Clear ALL"** — vymaže všetky polia naraz
- **Tlačidlo "RELOAD ALL"** — načíta posledné surové hodnoty do všetkých polí, kurzor skočí na koniec poľa PLN
- Pri každom meradle **checkbox "zmena meradla"** — po zaškrtnutí sa pod hlavným poľom rozbalia 2 extra polia: `mer_removed_X` (posledná hodnota starého meradla z lístka) a `mer_start_X` (štart nového meradla z lístka). Hlavné pole zostáva aktívne aj pri zaškrtnutom checkboxe.
- Validácia a poradie kontrol — pozri sekciu 3 vyššie

### Karta 2: Prehľad — koncept, detaily zatiaľ nedoladené
Tabuľka s globálnymi hodnotami: dátum, PLN, ELE, VOD (stĺpcový formát, čitateľný prehľad histórie).

### Karta 3: Štatistiky — koncept, detaily zatiaľ nedoladené
Tri úrovne agregácie:
1. **Denný priemer** — spotreba/cena vydelená počtom dní od predchádzajúceho odpočtu
2. **Medzi odpočtami** (aktuálne obdobie) — celková spotreba a cena za obdobie medzi dvoma po sebe idúcimi odpočtami
3. **Kalendárny mesiac** — spotreba/cena rozpočítaná pomerne podľa počtu dní, ktoré z obdobia medzi odpočtami patria do daného mesiaca (keďže odpočty nepadnú presne na 1./posledný deň mesiaca)

Ceny sa počítajú z plánovanej tabuľky `price_history` (viď sekcia 2) — pre každý dátum spotreby sa použije cena platná k danému dátumu (najbližší `valid_from` ≤ dátum spotreby).

### Karta 4: Nastavenia — koncept, detaily zatiaľ nedoladené
- Ceny PLN/ELE/VOD s históriou platnosti (cez `price_history` tabuľku)
- Config: LAN/WAN IP a port servera, prepínač medzi nimi

**Zavrhnutá myšlienka (na zváženie do budúcna, NIE pre v1):** univerzálna appka s dynamicky konfigurovateľným počtom/typom meradiel (checkbox zoznam meradiel, appka by sama generovala DB stĺpce). Rozhodnuté zostať pri pevnej štruktúre PLN/ELE/VOD pre v1 — dynamická schéma je výrazne komplexnejšia a rizikovejšia (SQL injection riziko pri dynamickom ALTER TABLE, komplikovanejšia validácia a štatistiky). Možné rozšírenie do budúcna po overení funkčného základu.

### Karta 5: Grafy — iba spomenuté, žiadne detaily zatiaľ
Vizualizácia spotreby namiesto číselných tabuliek — "lepšie čitateľný graf ako more čísiel".

---

## 5. Technické zistenia o NAS serveri (z phpinfo, 20.8.2026)

- **DOCUMENT_ROOT** (kam ukladať PHP súbory, aby ich nginx obsluhoval): `/var/services/web`
- **⚠️ PDO nemá driver pre MySQL** (`PDO drivers: no value` — chýba `pdo_mysql` rozšírenie). **Rozhodnuté použiť `mysqli` namiesto PDO** — je už funkčné, netreba nič doinštalovať, prepared statements (bezpečnosť voči SQL injection) mysqli podporuje rovnako ako PDO.
- **MySQL socket cesta**: `/run/mysqld/mysqld.sock` (použiť v mysqli pripojení namiesto TCP/localhost)
- PHP beží ako **FPM/FastCGI**, verzia potvrdená: **8.2.28**
- Dostupné rozšírenia relevantné pre projekt: `mysqli`, `mysqlnd`, `curl`, `json`, `mbstring`, `session` — všetko potrebné je k dispozícii

### Architektonické rozhodnutie: prečo HTTP/PHP API (nie priame DB pripojenie z Flutteru)

Okrem bezpečnostných dôvodov (heslo v appke, otvorený DB port) je toto **jediný funkčný spôsob** pre cieľ používateľa mať appku na **všetkých platformách vrátane Flutter Web**:
- Flutter balíčky na priame MySQL pripojenie (napr. `mysql1`) fungujú len na natívnych platformách (Windows/Android/iOS/desktop)
- **Flutter Web nemôže nikdy** otvárať surové TCP sokety na DB port — ide o bezpečnostné obmedzenie webových prehliadačov (browser sandboxing), netýka sa to len Flutteru, platí to univerzálne pre všetky webové appky
- HTTP/JSON komunikácia s PHP API funguje identicky na **Android, iOS, Windows, macOS, Linux aj Web** — toto je jediná cesta k skutočnému "one code base" naprieč všetkými platformami, vrátane budúceho plánovaného portovania na iOS/macOS

### Konektivita — LAN/WAN/VPN rozhodnutie

- Server je aktuálne dostupný aj **verejne cez internet** (verejná IP + forwardnutý port), ale **rozhodnuté vyvíjať a testovať cez LAN** (`192.168.23.200`) kvôli jednoduchosti
- Config prepínač `lanIp/lanPort` + `wanIp/wanPort` + `useWan` bool **zostáva súčasťou appky** tak, ako bolo pôvodne navrhnuté
- Do budúcna pri používaní appky mimo domácej siete: buď prepnúť na verejnú IP priamo (jednoduchšie, ale nezašifrované — momentálne bez HTTPS), alebo (preferovaná voľba) **VPN na telefóne** pripojená na domácu sieť — appka by v tom prípade stále volala `lanIp`, keďže VPN sa postará o zvyšok na sieťovej úrovni, appka o WAN adrese ani nemusí vedieť
- **HTTPS zatiaľ nie je nastavené** (server beží na HTTP) — akceptované ako dočasné riziko pre vývoj/osobné použitie, možnosť doriešiť neskôr cez Let's Encrypt (Synology DSM to podporuje natívne)

### Vývojový postup (dohodnuté poradie krokov)
1. Claude Code píše PHP aj Flutter kód **lokálne** vo Flutter projekte (nie priamo na NAS) — dôvod: bezpečnejšie, jednoduchšie sledovanie zmien cez Git, žiadne riziko prepísania produkčných súborov na NAS
2. Syntaktická kontrola PHP kódu lokálne (`php -l súbor.php`), ak bude k dispozícii lokálna PHP inštalácia
3. Funkčné testovanie: hotové PHP súbory sa **manuálne skopírujú do testovacieho podpriečinka na NAS** (napr. `/var/services/web/api_test/`), nie rovno do produkcie
4. Testovanie cez appku/prehliadač voči testovaciemu endpointu na NAS
5. Po overení funkčnosti — presun/premenovanie do finálneho umiestnenia

---

## 6. Ďalší krok

Pripraviť a spustiť v Claude Code (vo VS Code termináli, v priečinku Flutter projektu) **prvý zacielený prompt LEN na kartu 1 (Odpočty/CRUD)** — obsahujúci celý kontext z tohto dokumentu (schéma DB, metodika výpočtu, validácia, UI detaily CRUD karty) plus zadanie na vytvorenie PHP API vrstvy (GET/POST/PUT/DELETE pre `pln_ele_vod`, PDO s prepared statements) a Flutter formulára.

**Prompt ešte nebol vygenerovaný ani odoslaný** — čaká sa na pokyn používateľa.
