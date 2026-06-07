# Onderhoud & toekomstplan — Opname App

> Levend document. Bijwerken wanneer we beslissingen nemen of stappen afronden.
> Laatste update: 2026-06-07.

## Context
Woningopname-app (energie/WWS) voor PM Realestate. Flutter, primair iOS.
Nu ~3 dagelijkse gebruikers; verwachting: snel meer. Doel van dit document:
de app schaalbaar, onderhoudbaar en toekomstvast maken vóór het team groeit.

Huidige situatie (kort):
- Distributie: handmatige lokale builds via Mac + kabel (+ TestFlight-script aanwezig).
- Geheimen: `tool/dart_defines.json` (gitignored); BAG-key is publiek met werkende default.
- Tests: alleen een smoke-test. Geen CI.
- Monitoring: Firebase Crashlytics ingebouwd (verifiëren of gekoppeld).
- Grootste bestand: `lib/services/bag_service.dart` (~2650 r.).
- Dependencies: ~58 verouderd; enkele mogelijk niet meer onderhouden (`gallery_saver`).

---

## Spoor 1 — Distributie (schaalt het naar meer mensen)
**Probleem:** lokaal bouwen schaalt niet (kabel + toestelregistratie, limiet ~100 devices/jaar).

- [ ] Team op **TestFlight**: uitnodigen per e-mail, auto-updates, geen kabel/Mac.
      Tot 100 interne testers zonder review; tot 10.000 extern met lichte review.
- [ ] Lokale builds reserveren voor **ontwikkelen/testen** ("Opname TEST", eigen bundle-id).
- [ ] Bij echte interne uitrol: **Apple Business Manager** (custom/unlisted app) overwegen.

**⚠ TestFlight verloopt — niet permanent:**
- Elke TestFlight-**build werkt 90 dagen** na upload; daarna "bèta verlopen". Upload dus
  periodiek (±elke 2 maanden) een nieuwe build met `./tool/build_testflight.sh --upload`.
- Vereist een **actief Apple Developer Program** (€99/jaar).
- Niet-verlopende installs = App Store of **Apple Business Manager** (account moet wel geldig blijven).
- Herinnering ingesteld: tweemaandelijkse Claude-routine "TestFlight build-herinnering (Opname-app)"
  (trig_01EGsUKyRNezbvnSvWTiH85W) — herinnert alleen, bouwt niet zelf.

## Spoor 2 — Onderhoud & stabiliteit (vangnet bij meer wijzigingen)
- [ ] **CI (GitHub Actions)**: bij elke push `flutter analyze` + `flutter test` + testbuild.
- [ ] **Tests** rond de kern: BAG-parsing, XML-export, JSON-export.
- [ ] **Crashlytics** verifiëren (GoogleService-Info.plist gekoppeld) → remote crashinzicht.
- [ ] **Lints** opschonen (nu 394 info-meldingen) en afdwingen voor consistente stijl.
- [ ] `bag_service.dart` opsplitsen; geleidelijk **state-management** invoeren.
- [ ] **Dependencies** periodiek bijwerken; `gallery_saver` e.d. heroverwegen.

## Spoor 3 — Fundament voor de toekomst (backend)
De ruggengraat voor de roadmap-features:
- [ ] **AI-fotoherkenning** (CV-ketel → type) serverzijdig (key veilig, niet in de app).
- [ ] **Centrale dossiers per gebruiker** i.p.v. lokaal-op-één-toestel (vervangt fragiele Dropbox).
- [ ] **Audittrail + KPI-dashboard** (uit de 12-maanden roadmap).
- [ ] **Versievaste datacontracten**: voortbouwen op `opname.json` (`schemaVersie`).

## Spoor 4 — Team & proces
- [ ] **Secrets** centraal & veilig delen (secrets manager) i.p.v. rondmailen; BAG-key mag publiek.
- [ ] **Versiebeheer**: vaste versie-bumps + korte changelog per release.
- [ ] **Documentatie**: dit plan + korte architectuur-/bijdragehandleiding.

---

## Voorgestelde volgorde
1. TestFlight voor het team (lost schaal direct op)
2. CI + Crashlytics verifiëren (vangnet)
3. Backend opzetten (AI + centrale data)
4. Refactor + dependencies (continu, stap voor stap)

## Beslissingenlogboek
- 2026-06-07: Plan opgesteld. Eerste keuze gebruiker: eerst dit plan vastleggen;
  volgorde van uitvoering nog te bepalen. Vabi-mapping + JSON-export lopen parallel.
