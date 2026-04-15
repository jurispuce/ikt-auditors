# MedReg auditācijas pieraksti — AI un Dashboard demonstrācijas ceļvedis

## Mērķis

Šis dokuments apraksta, kā demonstrēt auditācijas datu analīzi ar:
1. **Mākslīgo intelektu** (ChatGPT, Claude, Gemini)
2. **Grafana dashboard**
3. **Atšķirībām** starp dažādām pieejām

**Lietojums kursā:** B8 sadaļā pēc Excel pamata vingrinājuma, lai parādītu papildu iespējas.

---

## 1. daļa — AI analīzes demonstrācija

### Sagatavošanās

1. Atveriet ChatGPT, Claude vai citu AI rīku
2. Ja ir pieejams, ielādējiet `medreg_audit_logs.json` failu
3. Ja failu ielāde nav iespējama — izmantojiet **1-2 ierakstu kopijas** kā piemēru un aprakstiet struktūru

### Prompts Nr. 1 — Vispārējā anomāliju analīze

```
Es esmu IS auditors. Man ir pievienotais JSON fails ar 823 auditācijas 
pierakstiem no MedReg (Veselības datu regulatīvā aģentūra) par 2026. gada martu.

Dati satur ierakstus no 3 avotiem:
- Windows Event Log (ISO 8601 UTC formātā)
- Web lietotnes (ISO 8601 ar offset)
- Datu bāze (lokāls formāts bez laika zonas)

Katrs ieraksts satur: event_id, timestamp_raw, timestamp_utc, timezone, 
source_system, source_type, user_id, user_ip, action, resource, result, details.

Lūdzu, analizē šos datus un identificē drošības anomālijas. 
Izmanto timestamp_utc laika normalizācijai.
Sakārto atklājumus no visizteiktākajiem uz smalkākajiem.
```

**Ko AI parasti pamana:**
- ✅ Bijušie darbinieki ar aktīviem kontiem (A1)
- ✅ Brute-force mēģinājumi (A3)
- ✅ Masveida datu eksports (A4)
- ✅ Brīvdienas aktivitāte (A5)
- ⚠ Daļēji: impossible travel (B1) — ja lūdz IP ģeolokāciju
- ⚠ Daļēji: "low and slow" modelis (B5) — var pamanīt laika modeli

**Ko AI NEPAMANA bez papildu norāžu:**
- ❌ Laika zīmogu pretrunas starp DB un AUTH (B2) — prasa krustsalīdzināšanu
- ❌ Dormant konti (B3) — prasa baseline analīzi
- ❌ Servisa konts ar cilvēka darbību (B4) — prasa kontekstu
- ❌ "Persons of interest" (p.liepa) — prasa atkārtotu kontekstu

---

### Prompts Nr. 2 — Fokusēta analīze

```
Šajos auditācijas pierakstos, lūdzu atrod:

1. Vai ir kādi lietotāji, kas veic darbības ārpus darba laika (pirms 06:00 UTC 
   vai pēc 18:00 UTC)? Norādi konkrētus event_id.

2. Vai ir kādi lietotāji, kas piesakās no vairāk nekā vienas ģeogrāfiskas 
   vietas ļoti īsā laika periodā? Analizē IP adreses.

3. Vai datu bāzes DELETE operācijām ir atbilstošas autentifikācijas darbības 
   tajā pašā dienā no tā paša lietotāja?
```

**Šādi fokusēti prompti strādā LABĀK nekā vispārīgi lūgumi.** Galvenā mācība: **AI nav maģija**, tas ir rīks, ko jāvada.

---

### Prompts Nr. 3 — Specifisks uzdevums

```
Analizē lietotāja p.liepa darbības šajos auditācijas pierakstos:

1. Cik daudz ierakstu ir no p.liepa?
2. Kuras ir parastākās darbības?
3. Vai ir kāda neparasta darbība vai laika zīmogs?
4. Vai ir kāda DB darbība, kurai nav atbilstoša autentifikācijas ieraksta 
   tajā pašā laikā (pēdējo 2 stundu laikā)?
```

**Mērķis:** parādīt, ka AI var fokusēti analizēt konkrētu "person of interest".

---

### AI lietošanas ierobežojumi

Svarīgi dalībniekiem saprast:

| ⚠ Ierobežojums | Skaidrojums |
|---------------|-------------|
| **Liela apjoma dati** | Lielākā daļa AI rīku nespēj vienā prompt analizēt vairāk par ~10,000 ierakstiem |
| **Halucinācijas** | AI var "izdomāt" nepastāvošus event_id vai datus |
| **Nevar palaist kodu** | Parastie AI neaprēķina statistiku precīzi (izņemot, ja ir Code Interpreter) |
| **Nav reāllaika** | Tas ir "snapshot" analīze, ne continuous monitoring |
| **Konteksta zudums** | Garos chat sesijās AI var aizmirst agrākos datus |
| **Privātuma risks** | Sensitīvi dati NEDRĪKST tikt augšupielādēti publiskos AI rīkos! |

**Galvenais princips:** AI ir **papildinājums** auditora instrumentiem, ne aizvietotājs. Auditors vienmēr **verificē** AI rezultātus.

---

## 2. daļa — Grafana dashboard demonstrācija

### Kāpēc Grafana?

Grafana ir populārs open-source dashboard rīks, ko bieži izmanto SIEM un monitoring kontekstā. To bieži kombinē ar:
- Elasticsearch / OpenSearch
- Loki (log aggregation)
- Prometheus (metrics)
- PostgreSQL / MySQL

### Demonstrācijas pieejas

Ja nav laika dzīvajai demonstrācijai, rādiet **screenshotus** ar šādiem dashboardu piemēriem:

#### Dashboard #1: Pieslēgšanās aktivitāte

**Vizualizācija:** Laika sērija ar SUCCESS vs FAILURE pieslēgšanās mēģinājumiem
**Ko tas parāda:**
- Brute-force uzbrukums (A3) — acīmredzams pīķis 2026-03-12 10:15
- Normāls darba dienas modelis ~08:00-17:00 UTC
- Svētdienas aktivitāte (A5) — atšķirīgs pīķis

**Query piemērs (Loki):**
```logql
sum by (result) (
  count_over_time(
    {source_system=~"VDRIS-AUTH|Windows-DC-01"} |= "LOGIN" [5m]
  )
)
```

---

#### Dashboard #2: Lietotāju aktivitātes heatmap

**Vizualizācija:** Heatmap ar lietotājiem (y-ass) × stundām (x-ass)
**Ko tas parāda:**
- Dormant konti (B3) — pēkšņs aktivitātes pieaugums k.liepina
- Ārpus darba laika darbs (A2) — j.kalnins nakts aktivitāte
- Regulāri eksporti (B5) — g.liepins katru dienu 15:42

---

#### Dashboard #3: Ģeogrāfiskā karte

**Vizualizācija:** Pasaules karte ar IP ģeolokāciju, krāsu kods pēc lietotāja
**Ko tas parāda:**
- Impossible travel (B1) — i.krumina savienojumi no Rīgas un Maskavas
- Aizdomīgi IP (Tor exit nodes)

---

#### Dashboard #4: Anomāliju skaitītāji

**Vizualizācija:** Single-value panels ar threshold brīdinājumiem
**Ko tas parāda:**
- "Aktīvo bijušo darbinieku skaits": **2** (kritisks!)
- "FAILURE % pēdējās 24h": 3.2% (normāli)
- "DELETE operācijas audit_log tabulā": **1** (kritisks!)
- "Eksporti > 1000 ierakstu": **3** (jāpārbauda)

---

### Kritiskā atšķirība no Excel

| Excel | Grafana |
|-------|---------|
| Statisks snapshot | **Reāllaika dashboards** |
| Manuāla atjaunošana | **Automātiska refresh** |
| Viens fails | **Datu avoti no daudzām sistēmām** |
| Grūti koplietot | **Web URL, var dalīt** |
| Bez brīdinājumiem | **Alerts un notifikācijas** |

---

## 3. daļa — Salīdzinājuma diskusija

Pēc abu demonstrāciju noslēguma, vadīt diskusiju ar dalībniekiem:

### Diskusijas jautājumi

1. **"Kura pieeja (Excel / AI / Dashboard) būtu visātrākā atrast brute-force uzbrukumu?"**
   - Atbilde: Dashboard ar alerts — reāllaikā
   - Excel — lēni, post-factum
   - AI — labi vispārīgai analīzei

2. **"Kura pieeja labāk spēj atpazīt `p.liepa` kā 'person of interest'?"**
   - Atbilde: AI ar labu prompt — var pamanīt, ka viens lietotājs parādās vairākās problemātiskās darbībās
   - Excel — prasa manuālu analīzi
   - Dashboard — ja ir speciāli izveidots lietotāja skats

3. **"Vai var paļauties tikai uz AI?"**
   - Atbilde: NĒ
     - AI halucinē
     - Nevar verificēt ar 100% precizitāti
     - Sensitīvi dati nedrīkst tikt atklāti ārējos AI
   - **Princips:** AI = assistant, nav aizvietotājs

4. **"Kādus rīkus jūs izvēlētos SAVAI organizācijai?"**
   - Diskutēt: ja maza organizācija — Excel + manuāli
   - Vidēja — Power BI + Power Query
   - Liela — pilns SIEM (Splunk/Grafana) + AI assistēta analīze

---

## Sagatavošanās piezīmes pasniedzējam

### Demonstrācijas plāns (~15 min kopā)

1. **0-5 min:** AI prompt demonstrācija (Prompts Nr. 1)
2. **5-8 min:** Rezultātu analīze — ko AI pamanīja, ko ne
3. **8-12 min:** Grafana dashboard screenshoti + skaidrojums
4. **12-15 min:** Diskusija ar dalībniekiem

### Alternatīvas, ja AI nav pieejams:

- Izmantot **iepriekš sagatavotus AI output screenshots**
- Parādīt, kā AI RISINĀJA problēmu, nevis dzīvojot to
- Fokusēt uz **principiem**, ne rīku specifiku

### Alternatīvas, ja Grafana nav pieejama:

- Izmantot **iepriekš sagatavotus dashboard screenshots**
- Parādīt publiskus Grafana piemērus (`grafana.com/demo`)
- Akcentēt **koncepcijas** — real-time, alerts, dashboards

---

## Nobeigums

**Galvenā mācība dalībniekiem:**

> "Audita dati paši neatbild uz jautājumiem. Rīki ir tikai tad, cik labi auditors prot tos izmantot. Excel, AI, dashboards — visi ir noderīgi, bet profesionāla audita spriedums paliek cilvēka rokās."

---

*Šis materiāls tapis ar Eiropas Savienības finansiālu atbalstu. Par tā saturu atbild tikai autors(-i).*
