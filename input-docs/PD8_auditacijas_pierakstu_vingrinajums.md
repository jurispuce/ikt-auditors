# PD#8 — Auditācijas pierakstu analīzes vingrinājums

## Dalībnieku instrukcija

**Organizācija:** MedReg (Veselības datu regulatīvā aģentūra)
**Laiks:** 20 min darbs + 5 min apmaiņa + 2×5 min prezentācijas
**Fails:** `medreg_audit_logs.json` (823 ieraksti)
**Atbalsta materiāls:** `medreg_audit_logs_datu_vardnica.md`

---

## Scenārijs

Jūs esat IS auditora komanda, kas veic MedReg **drošības auditu**. MedReg CISO ir lūdzis jums veikt padziļinātu analīzi **2026. gada marta auditācijas pierakstiem** no trim galvenajām sistēmām:
- `Windows Domain Controller` (autentifikācija)
- Web lietotnes (`SudzibuPortals-WEB`, `MedAI-Check-API`)
- Datu bāze (`VDRIS-DB-PROD`)

**Jūsu uzdevums:** Identificēt anomālijas, kas liecina par drošības incidentiem, politikas pārkāpumiem vai citām problēmām.

---

## ⚠ Īpaša piezīme par datiem

Datu kopa satur **dažādus laika formātus** no dažādām sistēmām:

| Avots | `timestamp_raw` formāts | Laika zona |
|-------|------------------------|-----------|
| Windows Event Log | `2026-03-15T14:23:11Z` | **UTC** |
| Web app | `2026-03-15T16:23:11+02:00` | **EET+02:00 vai +03:00** |
| Database | `15.03.2026 16:23:11` | **"local" — BEZ skaidras norādes!** |

**⚠ SVARĪGI:** Izmantojiet `timestamp_utc` kolonnu analīzei, **NEVIS** `timestamp_raw`! `timestamp_utc` ir normalizēts UTC laika zīmogs. Ja salīdzināsit ierakstus ar `timestamp_raw`, jūs varat iegūt nepareizus rezultātus.

**Diskusijas jautājums:** "Ko darītu auditors, ja `timestamp_utc` kolonna nebūtu pieejama?"

---

## Uzdevuma soļi

### 1. fāze — Datu ielāde Excel (5 min)

1. Atveriet Microsoft Excel (2016 vai jaunāks)
2. **Data → Get Data → From File → From JSON**
3. Izvēlieties `medreg_audit_logs.json`
4. Power Query Editor atvērsies — klikšķiniet **"Convert to Table"**
5. Atvērsies tabula ar vienu kolonnu "Column1" — klikšķiniet uz ikona ar divām bultām augšā
6. Atķeksējiet "Use original column name as prefix"
7. Klikšķiniet **OK** → **Close & Load**

**Rezultāts:** Jums ir Excel tabula ar 823 rindām un visām kolonām.

### 2. fāze — Sākotnējā izpēte (5 min)

Atbildiet uz šiem jautājumiem:
- Cik ierakstu ir no katras sistēmas (`source_system`)?
- Kāds ir laika diapazons?
- Cik unikālu lietotāju ir datu kopā?
- Kāds ir `FAILURE` procents no visiem ierakstiem?

**Padoms:** Izmantojiet **Pivot Table** vai **COUNTIF/COUNTIFS**.

### 3. fāze — Anomāliju meklēšana (10 min)

Identificējiet **vismaz 5 anomālijas** datu kopā. Katrai anomālijai dokumentējiet:

| # | Anomālijas apraksts | Event ID(s) | Kā atrasts | Potenciāls risks |
|---|--------------------|-----------| -----------|------------------|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |

---

## Ieteicamās meklēšanas stratēģijas

### A. Vienkāršie meklējumi (Excel filtri un pivot)

1. **Bijušie darbinieki** — filtrē `user_id` ar suffix `_old` vai `_ex`
2. **Neveiksmīgas pieslēgšanās** — filtrē `result = "FAILURE"` + `action = "LOGIN"`, kārto pēc `user_ip`
3. **Ārpus darba laika** — pievieno kolonnu `=HOUR(timestamp_utc)`, filtrē < 6 vai > 18
4. **Brīvdienas** — pievieno kolonnu `=WEEKDAY(timestamp_utc)`, filtrē 1 (svētdiena) vai 7 (sestdiena)
5. **Lieli datu eksporti** — filtrē `resource = "/api/v2/export"`, kārto pēc `details.rows_exported`

### B. Padziļināti meklējumi (krustsalīdzināšana)

1. **Lietotāji no vairākiem IP** — pivot tabula `user_id` × `user_ip`, meklē unikālo IP skaitu > 1 īsā laika periodā
2. **Servisa konti ar cilvēka darbībām** — filtrē `user_id` sākas ar `svc_`, analizē `source_type`
3. **DB darbības bez autentifikācijas** — grupē pa lietotājiem, salīdzini DB un AUTH ierakstus
4. **Aizdomīgas IP adreses** — meklē ārējos IP (ne `10.*`, ne `192.168.*`)

### C. Modeļu analīze

1. **Dormant konti** — atrodi lietotājus ar niecīgu aktivitāti, kas pēkšņi kļūst aktīvi
2. **Regulāri eksporta modeļi** — meklē eksportus, kas notiek vienā stundā vairākas dienas pēc kārtas
3. **Privileģētas darbības** — admin darbības bez atbilstoša ticket ID

---

## Prezentācijas struktūra (5 min)

1. **Kādas metodes lietojāt?** (1 min)
2. **3 galvenās atrastās anomālijas** (2 min) — konkrēti event_id, pierādījumi
3. **Ko auditors ieteiktu?** (1 min) — konkrēti risinājumi
4. **Ko jūs nebijāt spējīgi atklāt ar Excel vien?** (1 min) — refleksija par rīka ierobežojumiem

---

## Papildu uzdevums (ja ir laiks)

### Bonus #1: Laika zīmogu analīze
Atrodiet ierakstus, kur `timezone` ir `"local"` un pārbaudiet, vai `timestamp_raw` un `timestamp_utc` atbilst. **Vai ir kādi ieraksti, kur laika zonu interpretācija var maldināt auditoru?**

### Bonus #2: Person of interest
Identificējiet lietotāju(s), kas parādās vairākās aizdomīgās darbībās. Sastādiet "persons of interest" sarakstu ar pamatojumu.

### Bonus #3: Timeline
Sagatavojiet hronoloģisko timeline 2026-03-12 10:00-11:00 UTC notikumiem. Ko jūs redzat?

---

## Ieteicamie Excel rīki

### Pivot tabulas
**Ievietot → Pivot Table**

Piemēri:
- `user_id` rindās × `source_system` kolonnās → vērtība: Count
- `user_id` rindās × `result` kolonnās → redzēt FAILURE proporciju
- Stunda (aprēķināta kolonna) rindās × `action` kolonnās → redzēt darba laika modeli

### Filtri un kārtošana
**Data → Filter**

Piemēri:
- Filtrēt `action = "DELETE"` → kas dzēš ko?
- Kārtot `timestamp_utc` ascending → hronoloģisks skats

### Nosacījumformatēšana
**Home → Conditional Formatting**

Piemēri:
- Izcelt `FAILURE` sarkanā krāsā
- Izcelt stundas < 6 vai > 18 dzeltenā krāsā
- Duplikātu atrašana `user_ip` kolonnā

### Formulas
```
=HOUR(timestamp_utc)              # izvilkt stundu
=WEEKDAY(timestamp_utc, 2)        # nedēļas diena (1=pirmdiena)
=COUNTIF(user_id_col, "svc_*")   # cik ierakstu no svc kontiem
=COUNTIFS(result_col,"FAILURE",user_ip_col,"185.220.101.42")  # kombinēta skaitīšana
```

---

## Kas jādara, ja paliek grūti?

Ja 15 minūšu laikā nevarat atrast vismaz 3 anomālijas, pajautājiet pasniedzējam par **A līmeņa mājieniem**. A līmeņa anomālijas ir paredzētas kā "vienkāršas" — tās jāspēj atrast ar pamata Excel rīkiem.

**Padoms:** Sāciet ar acīmredzamām lietām — bijušiem darbiniekiem, daudz FAILURE, lieliem eksportiem. Tad virzāties uz grūtākiem.

---

*Šis materiāls tapis ar Eiropas Savienības finansiālu atbalstu. Par tā saturu atbild tikai autors(-i).*
