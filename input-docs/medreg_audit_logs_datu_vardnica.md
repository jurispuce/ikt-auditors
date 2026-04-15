# MedReg auditācijas pierakstu datu kopa — Datu vārdnīca

## Pārskats

**Fails:** `medreg_audit_logs.json`
**Formāts:** JSON (masīvs ar ierakstiem)
**Ierakstu skaits:** 823
**Laika diapazons:** 2026. gada marts
**Organizācija:** MedReg (Veselības datu regulatīvā aģentūra)

---

## Datu avoti (3 sistēmas)

Šī datu kopa apvieno auditācijas pierakstus no **3 dažādām MedReg sistēmām**. Reālā organizācijā šādi dati parasti tiek apvienoti SIEM (piemēram, Splunk, Graylog, Wazuh) vai CSV eksportos audita vajadzībām.

| # | Avota sistēma | Tips | Laika formāts | Piezīmes |
|---|--------------|------|--------------|---------|
| 1 | `Windows-DC-01`, `VDRIS-AUTH` | `authentication` | **ISO 8601 UTC** (`2026-03-15T14:23:11Z`) | Windows Event Log / AD |
| 2 | `SudzibuPortals-WEB`, `MedAI-Check-API` | `web_app` | **ISO 8601 ar offset** (`2026-03-15T16:23:11+02:00`) | Modernas web lietotnes |
| 3 | `VDRIS-DB-PROD` | `database` | **Lokāls formāts** (`15.03.2026 16:23:11`) **BEZ laika zonas norādes** | Novecojusi sistēma |

**⚠ SVARĪGI:** Laika formātu dažādība ir **apzināta** — tas atspoguļo reālo situāciju, kur dažādas sistēmas ģenerē dažādus laika formātus. Auditoram ir jānormalizē laika zīmogi vienā laika zonā (parasti UTC) pirms analīzes.

---

## Ierakstu struktūra

Katrs ieraksts ir JSON objekts ar šādām kolonām:

### Obligātās kolonnas

| Kolonna | Tips | Apraksts | Piemērs |
|---------|------|----------|---------|
| `event_id` | string | Unikāls ieraksta ID (secīgs) | `EVT-2026-00001` |
| `timestamp_raw` | string | **Oriģinālais laika zīmogs** no avota sistēmas (dažādos formātos!) | `2026-03-15T14:23:11Z` vai `15.03.2026 16:23:11` |
| `timestamp_utc` | string | **Normalizēts UTC laika zīmogs** ISO 8601 formātā | `2026-03-15T14:23:11Z` |
| `timezone` | string | Oriģinālā laika josla | `UTC`, `EET+02:00`, `EET+03:00`, `local` |
| `source_system` | string | Sistēma, kas ģenerēja ierakstu | `Windows-DC-01`, `VDRIS-DB-PROD` |
| `source_type` | string | Avota tips | `authentication`, `web_app`, `database` |
| `user_id` | string | Lietotāja ID | `a.berzins`, `svc_backup`, `SYSTEM` |
| `user_ip` | string | Lietotāja IP adrese | `10.0.1.45`, `193.26.117.88` |
| `action` | string | Veiktā darbība | `LOGIN`, `SELECT`, `POST` |
| `resource` | string | Objekts, ar kuru strādāts | `patient_records`, `/api/v2/predict` |
| `result` | string | Darbības rezultāts | `SUCCESS`, `FAILURE`, `ERROR` |
| `details` | object | Papildu informācija (dinamiska struktūra) | `{"rows_affected": 245, "duration_ms": 120}` |

---

## Vērtību saraksti

### `source_system`
- `Windows-DC-01` — Windows Domain Controller
- `VDRIS-AUTH` — VDRIS autentifikācijas sistēma
- `SudzibuPortals-WEB` — Sūdzību portāla web lietotne
- `MedAI-Check-API` — MedAI-Check API sistēma
- `VDRIS-DB-PROD` — VDRIS produkcijas datu bāze

### `source_type`
- `authentication` — Autentifikācijas notikumi (pieslēgšanās, izrakstīšanās)
- `web_app` — Web lietotnes notikumi
- `database` — Datu bāzes notikumi

### `action` (dažādi pa avota tipiem)

**Authentication:**
- `LOGIN` — Pieslēgšanās mēģinājums
- `LOGOUT` — Izrakstīšanās
- `PASSWORD_CHANGE` — Paroles maiņa
- `HEALTH_CHECK` — Sistēmas veselības pārbaude (servisa konti)

**Web app:**
- `GET`, `POST`, `PUT`, `DELETE` — HTTP metodes
- `VIEW`, `SEARCH`, `UPDATE` — Funkcionālas darbības

**Database:**
- `QUERY`, `SELECT` — Datu izlase
- `UPDATE` — Datu atjaunināšana
- `INSERT` — Datu pievienošana
- `DELETE` — Datu dzēšana
- `BACKUP` — Rezerves kopijas izveide

### `result`
- `SUCCESS` — Darbība izdevās
- `FAILURE` — Darbība neizdevās (piemēram, nepareiza parole)
- `ERROR` — Sistēmas kļūda

### `timezone`
- `UTC` — Koordinētais pasaules laiks (GMT+0)
- `EET+02:00` — Austrumeiropas laiks (ziemā, Rīga)
- `EET+03:00` — Austrumeiropas vasaras laiks (vasarā, Rīga)
- `local` — **Lokāls laiks BEZ norādes** (ambiguous — auditors nezina!)

---

## Lietotāju kategorijas

### Aktīvie darbinieki (15)

| User ID | Vārds | Nodaļa | Loma |
|---------|-------|--------|------|
| `a.berzins` | Anna Bērziņš | IT | standarts |
| `j.kalnins` | Jānis Kalniņš | IT | admin |
| `m.ozolina` | Marta Ozoliņa | Veselības dati | standarts |
| `p.liepa` | Pēteris Liepa | IT | admin |
| `i.krumina` | Ieva Krūmiņa | Sūdzības | standarts |
| `r.vanags` | Roberts Vanags | Veselības dati | standarts |
| `l.skujina` | Laura Skujiņa | MedAI-Check | standarts |
| `d.zarins` | Dāvis Zariņš | IT | standarts |
| `k.liepina` | Katrīna Liepiņa | Juridiskā | standarts |
| `n.berzs` | Normunds Bērzs | Veselības dati | standarts |
| `s.ozols` | Sanita Ozols | Vadība | standarts |
| `e.kalnite` | Evita Kalnīte | Sūdzības | standarts |
| `t.vitols` | Tomass Vītols | MedAI-Check | admin |
| `g.liepins` | Gunārs Liepiņš | IT | standarts |
| `b.rozite` | Baiba Rozīte | Veselības dati | standarts |

### "Bijušie" darbinieki (HR atlaisto sarakstā, bet AD kontos)

| User ID | Vārds | Atlaists | Piezīme |
|---------|-------|----------|---------|
| `a.kalnina_old` | Anita Kalniņa | 2025-08-15 | **Konts nav deaktivēts!** |
| `r.ozols_old` | Roberts Ozols | 2025-09-30 | **Konts nav deaktivēts!** |
| `m.berzins_ex` | Mārtiņš Bērziņš | 2025-11-10 | Pareizi deaktivēts (kontrole) |

### Servisa konti

| User ID | Mērķis |
|---------|--------|
| `svc_backup` | Automātiski rezerves kopijas |
| `svc_monitoring` | Sistēmu monitorings |
| `svc_integration` | Sistēmu integrācija |
| `svc_medai` | MedAI-Check backend |
| `SYSTEM` | Windows sistēmas konts |

---

## IP adrešu diapazoni

| Diapazons | Kategorija | Piemēri |
|-----------|-----------|---------|
| `10.0.x.x` | Iekšējais MedReg tīkls | `10.0.1.45`, `10.0.2.18` |
| `192.168.1.x` | Biroja WiFi | `192.168.1.15`, `192.168.1.22` |
| `88.135.42.18`, `193.26.117.88`, `78.84.103.11` | LV ārējie ISP (normāli) | Darbinieki no mājām |
| `185.220.101.42`, `5.188.206.15`, `45.95.169.73` | **Aizdomīgi** (Tor/VPN exit nodes) | Potenciāli uzbrukumi |
| `5.45.196.120` | **Maskavas IP** | "Impossible travel" anomālija |

---

## Ieteikumi darbam ar datiem

### Import Excel
1. Atveriet Excel
2. **Data → Get Data → From File → From JSON**
3. Izvēlieties `medreg_audit_logs.json`
4. Power Query Editor atvērsies — klikšķiniet **"Convert to Table"**
5. Izvērsiet (**Expand**) kolonnas, kuras vēlaties redzēt
6. Klikšķiniet **"Close & Load"**

### Laika normalizācija
**KRITISKA:** Pirms analīzes pārbaudiet, vai visi laika zīmogi ir vienā laika zonā!

- `timestamp_utc` jau ir normalizēts — lietojiet **šo** analīzei
- `timestamp_raw` ir oriģinālais formāts no avota — lietojams tikai demonstrācijai
- `VDRIS-DB-PROD` ieraksti (ar `timezone: "local"`) ir īpaši problemātiski — bez `timestamp_utc` jūs nevarētu zināt laiku

### Ieteicamie audita jautājumi
1. Vai ir sesijas ārpus darba laika? (izmantojiet `timestamp_utc`, nevis `timestamp_raw`)
2. Vai ir lietotāji ar aizdomīgi daudz neveiksmīgām pieslēgšanām?
3. Vai visu avotu laika zīmogi ir vienā laika zonā?
4. Vai ir lietotāji, kas lieto kontus pēc oficiālās atlaišanas datuma?
5. Vai datubāzes dzēšanas operācijām ir atbilstošas autentifikācijas?

---

*Šis materiāls tapis ar Eiropas Savienības finansiālu atbalstu. Par tā saturu atbild tikai autors(-i).*
