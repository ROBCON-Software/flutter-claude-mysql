KONTEXT PROJEKTU:
Flutter appka na zaznamenavanie stavov plynomera (PLN), elektromera (ELE) a vodomera (VOD).
Cielove platformy: Android, iOS, Windows desktop, macOS, Web (jeden kod pre vsetky).
Backend: PHP 8.2.28 (FPM/FastCGI, nginx 1.23.1) bezi na Synology NAS, lokalna adresa 192.168.23.200.
Databaza: MariaDB 10.11.11, databaza sa vola "tree".

DOLEZITE TECHNICKE DETAILY SERVERA:
- DOCUMENT_ROOT na NAS: /var/services/web (sem sa umiestnuju PHP subory pre nginx)
- POUZIT PDO (pdo_mysql driver je zapnuty a otestovany, funguje spravne)
- MySQL socket cesta: /run/mysqld/mysqld.sock (pripajat sa cez tento socket, nie cez TCP/localhost)
- Overeny funkcny connection string: mysql:unix_socket=/run/mysqld/mysqld.sock;dbname=tree;charset=utf8mb4
- POUZIT prepared statements vsade, kvoli bezpecnosti pred SQL injection
- POUZIT PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION a try/catch osetrenie chyb

SPRAVA HESLA (DOLEZITE):
- Databazove heslo sa NESMIE zapisat priamo v kode, ktory ide do Gitu
- Vytvor subor backend_php/db_config.php s konstantami DB_SOCKET, DB_NAME, DB_USER, DB_PASSWORD (realne heslo tam doplnim ja rucne po vytvoreni suboru)
- Vytvor aj vzorovy subor backend_php/db_config.example.php s rovnakou strukturou ale placeholder hodnotami (napr. DB_PASSWORD = 'your_password_here'), tento subor MOZE ist do Gitu
- Priprav/uprav .gitignore v koreni projektu tak, aby obsahoval riadok "backend_php/db_config.php" (subor so skutocnym heslom sa nesmie commitnut)
- Ostatne PHP subory nacitaju db_config.php cez require_once a pouziju tieto konstanty

VYVOJOVY POSTUP (dolezite):
- Vsetok kod (PHP aj Flutter) sa pise LOKALNE v priecinku Flutter projektu, NIE priamo na NAS
- Pre PHP vytvor podpriecinok "backend_php" v koreni projektu, tam umiestni vsetky PHP subory
- Az ked bude PHP kod hotovy, ja ho manualne skopirujem na NAS na testovanie

DATABAZOVA TABULKA (uz existuje v databaze, NEVYTVARAJ ju, len s nou pracuj):
Tabulka: pln_ele_vod

Stlpce:
- mer_id INT AUTO_INCREMENT PRIMARY KEY
- mer_datetime TIMESTAMP
- mer_pln DECIMAL(11,3)          -- surova hodnota plynomera
- mer_pln_global DECIMAL(11,3)   -- kumulativna globalna hodnota
- mer_change_pln TINYINT(1)      -- priznak vymeny meradla (0/1)
- mer_removed_pln DECIMAL(11,3)  -- hodnota z vymenneho listka (len pri change=1)
- mer_start_pln DECIMAL(11,3)    -- start noveho meradla (len pri change=1)
- mer_ele INT                    -- elektromer nema desatinne miesta
- mer_ele_global INT
- mer_change_ele TINYINT(1)
- mer_removed_ele INT
- mer_start_ele INT
- mer_vod DECIMAL(11,3)
- mer_vod_global DECIMAL(11,3)
- mer_change_vod TINYINT(1)
- mer_removed_vod DECIMAL(11,3)
- mer_start_vod DECIMAL(11,3)
- mer_note VARCHAR(255)
- mer_note_pln VARCHAR(255)
- mer_note_ele VARCHAR(255)
- mer_note_vod VARCHAR(255)

DATABAZOVA TABULKA PRE PRIHLASOVANIE (uz existuje v databaze, NEVYTVARAJ ju):
Tabulka: mer_pins
- mer_pin_id INT AUTO_INCREMENT PRIMARY KEY
- mer_username VARCHAR(50) NOT NULL UNIQUE
- mer_pin CHAR(4) NOT NULL

METODIKA VYPOCTU GLOBALNEJ HODNOTY (plati nezavisle pre PLN/ELE/VOD, X = pln/ele/vod):

1. Bezny zapis (mer_change_X = 0):
   - Najdi posledny riadok, kde mer_change_X = 1, zoberie odtial mer_removed_X a mer_start_X
   - mer_X_global = mer_removed_X + (mer_X - mer_start_X)
   - Ak meradlo X sa este nikdy nemenilo: mer_removed_X = 0 a mer_start_X = 0, teda mer_X_global = mer_X

2. Riadok vymeny meradla (mer_change_X = 1):
   - Hlavne pole mer_X ZOSTAVA AKTIVNE a VYPLNA SA - je to aktualny odpocet na NOVOM meradle v den zapisu (nemusi byt den fyzickej vymeny, moze byt aj neskor)
   - mer_removed_X = hodnota z vymenneho listka (posledna hodnota STAREHO meradla v momente vymeny), zadava uzivatel
   - mer_start_X = startovacia hodnota NOVEHO meradla (tiez z listka, nemusi byt 0), zadava uzivatel
   - Vypocet: mer_X_global = mer_removed_X + (mer_X - mer_start_X)
   - DOLEZITE: mer_removed_X a mer_start_X sa "zamrznu" na riadku vymeny a pouzivaju sa NEZMENENE pre vypocet globalnej hodnoty VSETKYCH nasledujucich riadkov az do dalsej vymeny (nie iba pre prvy riadok po vymene)

PRIKLAD VYPOCTU (over si spravnost implementacie na tomto priklade):
- Predposledne odcitanie (stare meradlo): 2100 -> global 2100
- Posledne odcitanie (stare meradlo): 2200 -> global 2200
- Den vymeny, listok: stare = 2250, nove startuje na 30
- Prve odcitanie na novom meradle: 30 -> global = 2250 + (30-30) = 2250
- Dalsie odcitanie: 50 -> global = 2250 + (50-30) = 2270
- Dalsie odcitanie: 150 -> global = 2250 + (150-30) = 2370

VALIDACIA PRI UKLADANI (presne v tomto poradi):
1. NAJPRV: pre kazde pole, kde bola zadana hodnota (vratane 0, nie len prazdne pole), sa prepocita mer_X_global a porovna s poslednou ulozenou globalnou hodnotou pre dane meradlo (najdi posledny riadok, kde mer_X_global nie je NULL). Ak nova globalna hodnota je NIZSIA ako posledna -> TVRDO ZABLOKOVAT ulozenie s chybovou hlaskou (napr. "Elektromer: nova hodnota je nizsia ako posledny zaznam"). Toto plati nezavisle pre kazde z troch meradiel.
2. AZ POTOM (ked validacia zadanych hodnot presla): ak su niektore polia prazdne a ine vyplnene (nekompletny/mimoriadny zapis) -> zobrazit potvrdzovaci dialog "Mimoriadny odpocet - si si isty? ANO/NIE". Pri potvrdeni sa zaznam ulozi s NULL hodnotami pre nevyplnene meradla.

ZAOKRUHLOVANIE:
- mer_pln, mer_vod (aj removed/start varianty) -> zaokruhlit na 3 desatinne miesta
- mer_ele (aj removed/start varianty) -> zaokruhlit na cele cislo
- Vstupny filter pre vsetky ciselne polia: iba znaky 0-9 a bodka (ziadna ciarka, ziadne ine znaky, numericka klavesnica na mobile)

---

ULOHA 1 - PHP API (v priecinku backend_php/ v ramci Flutter projektu):

Vytvor db_config.example.php a db_config.php (viz sekcia SPRAVA HESLA vyssie) a db_connect.php s funkciou vracajucou PDO instanciu.

Vytvor tieto endpointy (PDO, prepared statements, JSON vstup/vystup, osetrenie chyb):
- GET readings.php - vrati zoznam poslednych zaznamov (zoradenych od najnovsieho, s volitelnym limit parametrom cez query string, default napr. 50), vsetky stlpce
- GET readings.php?last=1 - vrati iba posledny zaznam pre kazde meradlo (najnovsi riadok, kde mer_pln_global nie je NULL / mer_ele_global nie je NULL / mer_vod_global nie je NULL - moze to byt 3 rozne riadky), potrebne na "reload last" funkciu v appke
- POST readings.php - vytvorenie noveho zaznamu. Prijme JSON s poliami pre mer_datetime, mer_pln, mer_change_pln, mer_removed_pln, mer_start_pln, mer_ele, mer_change_ele, mer_removed_ele, mer_start_ele, mer_vod, mer_change_vod, mer_removed_vod, mer_start_vod, mer_note, mer_note_pln, mer_note_ele, mer_note_vod. Na strane servera precita globalne hodnoty podla metodiky vyssie a vykona validaciu (bod 1 z validacie - vrat chybu 422 s popisom, ak je nova globalna hodnota nizsia). Volanie s neuplnymi udajmi (niektore meradla NULL) je v poriadku, o potvrdeni "mimoriadny odpocet" rozhoduje uz Flutter pred odoslanim.
- PUT readings.php?id=X - uprava existujuceho zaznamu
- DELETE readings.php?id=X - zmazanie zaznamu

- POST login.php - prijme JSON {"pin": "2314"}, overi voci tabulke mer_pins (SELECT podla mer_pin), ak zhoda existuje vrati JSON {"success": true, "username": "roberto"}, inak {"success": false} so status kodom 401

---

ULOHA 2 - FLUTTER APPKA:

Zaklad appky:

PIN OBRAZOVKA (zobrazi sa PRED Drawer navigaciou, pri kazdom starte appky):
- Jednoducha obrazovka s 4 policami/keypadom na zadanie 4-ciferneho PIN kodu (numericka klavesnica, iba cislice)
- Po zadani 4 cislic automaticky odosle POST na login.php
- Ak success=true, presmeruje na hlavnu appku (Drawer + Odpocty karta), ulozi username do app state (napr. Provider alebo jednoduchy static/singleton) pre pripadne buduce pouzitie (viac appiek/lokacii)
- Ak success=false, zobrazi chybu "Nespravny PIN" a vycisti zadane cislice
- Ziadne "zapamataj si ma" zatial, PIN sa pyta pri kazdom starte appky

- Config subor (napr. lib/config.dart) s premennymi lanIp, lanPort, wanIp, wanPort a bool prepinacom useWan (zatial false, appka pouziva LAN)
- Hlavna navigacia: Drawer (hamburger ikona vlavo hore v AppBar, vedla nej nazov aktualne zobrazenej karty). Polozky v Draweri v tomto poradi:
  1. Odpocty (FUNKCNE - CRUD karta, popisane nizsie)
  2. Prehlad (NEFUNKCNE - polozka viditelna ale seda/disabled, neda sa kliknut)
  3. Statistiky (NEFUNKCNE - rovnako disabled)
  4. Grafy (NEFUNKCNE - rovnako disabled)
  5. Nastavenia (NEFUNKCNE - rovnako disabled)
  6. -- oddelovac --
  7. Exit (FUNKCNE - zobrazi potvrdzovaci dialog "Naozaj chces ukoncit appku?", po potvrdeni appku uplne zatvori)

KARTA "ODPOCTY" (CRUD) - DETAILNA SPECIFIKACIA:

- Jeden spolocny formular pre vsetky tri meradla naraz (PLN, ELE, VOD), nie samostatne formulare
- Datum/cas: pole predvyplnene na aktualny moment otvorenia formulara, s moznostou rucne zmenit (date/time picker) pre spatny zapis
- Pre kazde z troch hlavnych poli (PLN, ELE, VOD):
  - Numericky vstup, filter iba 0-9 a bodka
  - Ikonka CLEAR (kriz v kruzku) vpravo v poli, zobrazi sa len ked pole obsahuje text, po kliknuti vycisti dane pole
  - Ikonka RELOAD (sipka v kruzku) vlavo v poli, po kliknuti nacita do pola poslednu SUROVU hodnotu dopoloha meradla (z API endpointu GET readings.php?last=1) a kurzor sa nastavi na koniec textu v tomto poli (aktivny/focused)
  - Nad polom (v ramoveni, vlavo hore) popisok s formatom "GLOBALNA [SUROVA]" napr. "2370 [150]" - zobrazuje poslednu znamu hodnotu z API
  - Vedla pola checkbox "Zmena meradla" - po zaskrtnuti sa pod hlavnym polom rozbalia 2 dalsie polia rovnakeho typu (numericky vstup s clear ikonkou): "Posledna hodnota povodneho meradla" (mer_removed_X) a "Startovacia hodnota noveho meradla" (mer_start_X)
- Kazde z troch meradiel ma aj svoje poznamkove pole (mer_note_pln/ele/vod) - kratky text
- Jedno spolocne poznamkove pole na konci formulara (mer_note)
- Tlacidlo "Clear ALL" - vymaze vsetky polia formulara naraz (vratane checkboxov zmena meradla a ich rozbalenych poli, aj poznamok)
- Tlacidlo "RELOAD ALL" - nacita posledne surove hodnoty do PLN/ELE/VOD poli naraz, kurzor po dokonceni skoci do pola PLN na koniec textu
- Tlacidlo "Ulozit" - spusti validaciu a odosle POST/PUT na API:
  - Ak API vrati chybu 422 (nizsia globalna hodnota) -> zobrazit chybovu hlasku pouzivatelovi, neuklada sa
  - Ak su niektore z PLN/ELE/VOD polí prazdne (a ine vyplnene) -> pred odoslanim zobrazit potvrdzovaci dialog "Mimoriadny odpocet - si si isty? ANO/NIE", pokracovat len po potvrdeni
  - Po uspesnom ulozeni vycistit formular (rovnako ako Clear ALL) a zobrazit potvrdenie (napr. snackbar "Zaznam ulozeny")

Pouzi balicek http alebo dio na komunikaciu s PHP API. Struktura kodu nech je pripravena na jednoduche pridavanie dalsich kariet v buducnosti (kazda karta ako samostatny widget/subor).

Zacni prosim vytvorenim PHP backend vrstvy (db_config.example.php, db_connect.php, readings.php), potom pokracuj Flutter Drawer navigaciou a napokon CRUD formularom. Po kazdej vacsej casti mi strucne zhrň co si vytvoril, aby som mohol priebezne kontrolovat.