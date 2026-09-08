# Logboek opname-app (blueprint collective)

Kort chronologisch overzicht van versies en beslissingen aan de app-kant.
Nieuwste bovenaan. De API-afspraken met de website staan in
`OneDrive/Apps/APP-API.md`; wensen richting de plugin-kant in
`APP-API-WENSEN.md`.

## 2026-09-08 — Veldbevindingen verwerkt (2.8.0+26)

Batch uit de logboeken (13 aug → 8 sep), in overleg met Paul in deze volgorde:

- **Adres-bug (opdracht 4, hoge prio).** `opname.json`/XML kreeg soms
  `straat:""` + `plaats:"Locatie"` ("53 Locatie 2101HL" op de site). Oorzaak:
  GPS-terugval in `start_screen` zette plaats op de letterlijke tekst 'Locatie'.
  Fix: placeholder weg; `BagService.resolveBagDataForExport` vult straat/plaats
  nu ook via `lookupByAddress` op postcode+huisnummer, en "Locatie" telt als
  leeg; afsluitscherm waarschuwt (Terug / Toch afsluiten) bij een onvolledig
  adres. Helper `heeftCompleetAdres` + test.
- **Eigenaar (opdracht 3).** Instellingen-veld Eigenaar (WP-user-ID + naam) +
  knop "Ophalen uit inlogaccount" (`GET /wp/v2/users/me`). `POST /entiteit`
  stuurt nu `eigenaar` mee; opname.json krijgt `eigenaar {id,naam}`. Meteen:
  BAG-pand-id → `bag_pand_id` i.p.v. `pand` (contract §3.3).
- **Afsluiten robuuster + afstemvraag opnames-zonder-object.** Website-stap
  toont bij een fout nu HTTP-status + tijdstip (matchbaar met Wordfence Live
  Traffic) + knop "Opnieuw naar website"; concept wordt pas gewist als de
  website-stap lukt. Antwoord op de pc-afstemvraag in APP-API-WENSEN (kernpunt:
  de app stuurt GEEN fotoserie naar de site — alleen 1× createEntiteit + 1 foto;
  Wordfence moet naar die entiteit-call kijken, niet naar fotoseries).
- **WWS-tellertjes per tegel (7 sep).** Live puntenteller per tegel via stil
  narekenen op `POST bd/v1/wws`; aangeleverd MET-TELLERS-bestand was exact de
  huidige versie + tellers, dus overgenomen.

- **Basis-URL (opdracht 21 aug):** bleek al een instelling (URL + namespace
  apart, in Instellingen; defaults in code). Migratie = instelling, geen
  release. Twee-sites-splitsing bewust nog niet gebouwd (wacht op besluit welke
  endpoints meeverhuizen).
- **Polish (2.8.1+27):** na een `CV`-foto een hint om ook het CV-typeplaatje te
  maken (frontklep). Losse-foto's: app schrijft altijd naar `foto's/`-submap —
  een losse foto in de dossier-root is handmatig, niet door de app (afgevangen,
  genoteerd in WENSEN).

## 2026-09-08 — WWS keuze zelfstandig/onzelfstandig + onzelfstandig-scherm (2.9.0+29)

- **WWS-knop → keuze** zelfstandig / onzelfstandig (bottom sheet in
  `start_screen`).
- **WWS onzelfstandig gebouwd** (veldspec `REGELS.md` + `testdossier.json`
  kwamen binnen): `lib/models/wws_onz_data.dart` (model + alle keuzelijsten,
  `toJson` exact in het dossier-formaat) + `lib/screens/wws_onz_screen.dart`
  (2.9.1: tegel/blokjes-opzet zoals de zelfstandige WWS — tegels Gebouw, Gedeelde ruimtes, Extra gedeelde ruimtes, Buitenruimtes,
  Kamers met eigen voorzieningen + geneste ruimten). "Bereken punten" →
  `BlueprintApiService.rekenWwsOnz` (`POST /bd/v1/wws-onz`, server rekent) →
  totaal + per kamer punten/max huur. `saveWwsOnz` (`POST /entiteit/{id}/wws-onz`)
  staat klaar als service. Voorgevuld met adres/postcode/plaats/bouwjaar/WOZ/label.
- v1-vereenvoudigingen: voorzieningen aan/uit (aantal 1); COROP handmatig
  (default Utrecht); opslaan-bij-eenheid nog niet als knop. Test
  `wws_onz_json_test`. 22 tests groen.

## 2026-08-15 — Volumeknop-sluiter blijft werken (2.7.1+23)

Klacht Paul: de volumeknop-sluiter stopte "na een tijdje" (juist lastig bij
weggewerkte ketels/typeplaatjes). Oorzaak: iOS deactiveert de
`AVCaptureEventInteraction` bij een korte onderbreking (melding,
Bedieningspaneel, scherm dimt) en zette 'm niet terug; de app stelde 'm alleen
bij het openen scherp, en de `resumed`-tak sloeg juist over als de camera nog
leefde. Fix op twee lagen:
- **Dart** (`tagged_camera_capture_view`): `_rearmVolumeButton()` bij élke
  `resumed` (ook als de camera nog draait) én na een verse camerastart.
- **Native** (`AppDelegate.swift`): observer op
  `UIApplication.didBecomeActiveNotification` bouwt de capture-interaction
  opnieuw op zodra de app weer actief is — zelfhelend, ook als Flutters
  levenscyclus net niet meepakt. Observer netjes opgeruimd in `stop()`.

## 2026-08-15 — Afsluitscherm herzien (2.7.0+22)

Drie wensen van Paul:
1. **Formulier onthoudt de invoer** (sprong eerst op nul). `initState` vulde
   alles opnieuw uit `widget.bagData` bij elk heropenen. Nieuw
   `lib/services/afsluit_form_store.dart`: bewaart de afsluit-formulierstaat
   per dossier (autosave 500 ms bij wijziging + save in `dispose` als vangnet);
   `_restoreForm()` zet 'm terug in initState. Concept wordt gewist zodra de
   opname is afgesloten. Test `afsluit_form_store_test.dart`.
2. **Drie afsluitknoppen → één knop "Opname afsluiten".** `_afsluiten()` doet
   alles best-effort: XML+PDF's+JSON → mail → Nextcloud-upload → formulier-
   samenvatting opslaan → eenheid op de website (blueprint-data.nl). Eén
   resultaatvenster toont per onderdeel wat lukte. `_save` en
   `_uploadToNextcloud` verwijderd. (Website-koppeling zit er bewust in — keuze
   Paul.)
3. **Continue foto-upload zichtbaar + betrouwbaar.** Bestond al (elke foto →
   `Lopend/<dossier>` op Nextcloud) maar slikte fouten stil weg. Nu: teller
   (bezig/geüpload/mislukt) als statusregel in het camerascherm, en 2
   uploadpogingen i.p.v. 1. Mislukte foto's gaan alsnog mee bij het afsluiten.

18 tests groen. iOS + Android bouwen.

**Naar TestFlight**: build 22 (2.7.0+22) geüpload naar App Store Connect
(tag `testflight-2.7.0-build22`, Delivery UUID 15bdff59). Ging nu vlot via
`tool/build_testflight.sh --upload` omdat het Apple Distribution-certificaat er
sinds 13 aug weer in staat. (iOS-13-waarschuwing blijft — voorjaar 2027 ≥15.0.)

## 2026-08-14 — Eerste Android-build lukt (2.6.1+21)

Doel: `flutter build apk`. De Mac had **geen Android SDK** (alleen Xcode/iOS).
Setup via Homebrew: `android-commandlinetools` (sdkmanager) + `openjdk@17`
(JDK) + `sdkmanager` platform-tools/android-35/build-tools;35.0.0 + licenties
geaccepteerd + `flutter config --android-sdk` en `--jdk-dir`. JDK-home:
`/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`,
SDK: `/opt/homebrew/share/android-commandlinetools`.

Twee verouderde plugins braken de moderne Android-build (AGP 8.11 / Kotlin
2.2.20 / Gradle 8.14):
- **gallery_saver 2.3.2** (geen namespace, niet onderhouden) → vervangen door
  **gal**; `PhotoLibraryService` gebruikt nu `Gal.putImage(album:)`. iOS
  gebruikt nog eerst de native `photo_library_channel`; gal is de terugval.
- **permission_handler 10.3.6** (verwijderde v1-embedding) → **11.3.1**. v13
  vereist een nieuwere Kotlin-Gradle-DSL dan dit project (`compilerOptions`);
  11.x werkt en heeft de v1-embedding er ook al uit. Publieke API ongewijzigd.

Resultaat: `build/app/outputs/flutter-apk/app-debug.apk` (~150 MB debug, alle
ABI's). iOS bouwt nog gewoon (geverifieerd). Alle 17 tests groen.

**Nog nodig voor een echte Android-release (Play Store):** applicationId van
placeholder `com.example.photo_organizer_app` → `nl.paulweijers...`; Android
launcher-icoon; keystore + signingConfig; Google Play Console-account (€25);
testen op een Android-toestel; en de **volumeknop-sluiter** heeft nog geen
Android-kant (MainActivity.kt is leeg — Kotlin onKeyDown VOLUME_UP/DOWN →
EventChannel `blueprint/volume_button`).

## 2026-08-14 — Foto-labels als data (2.6.0+20)

Koerswijziging uit de pc-kant (`OneDrive/Apps/LEESMIJ-VOOR-CLAUDE.md` +
`APP-FORMULIER-VELDEN.md`): **de app-XML is de basis, de PC-kant doet de
foto-herkenning; GEEN Claude-API in de app.** De app hoeft alleen de foto's
goed te labelen en dat label als DATA mee te geven (scheelt ~90% AI-kosten).

- **Nieuw submenu "Installatie/meter"** in het opnamescherm
  (`lib/screens/wonen2_screen.dart`): CV, CV plaatje, Boiler, Boiler plaatje,
  Geiser, WP, Meter, Gasmeter, MV, Zon. (Meter = label, niet verplicht — keuze
  Paul.)
- **Label in de bestandsnaam**: `1018TA_102_0031_CVPLAATJE.jpg`, zowel in de
  Foto's-albumkopie (`PhotoLibraryService`) als de dossier-/Nextcloud-kopie
  (`DossierPhotoStore`). Helpers `labelForFilename`/`labelFromFilename` +
  `test/foto_label_test.dart`.
- **opname.json** krijgt een `fotos`-lijst met per foto `{bestand, label}`.
- **Ingetrokken**: de CV-herkenning-endpointwens bij de website-kant (13 aug) —
  de PC doet het, geen site-endpoint nodig. Genoteerd in APP-API-WENSEN.

Openstaand (komt van Paul, zelfde Excel-opzet schermtekst|code|sub):
ventilatie-varianten + resterende gebouwgegevens-enums; plus de "annotaties →
data" voor glas/muurconstructie/kozijn per gevel (nu nog in beeld gebrand).

## 2026-08-13 — Build 19 naar TestFlight + herstel distributie-certificaat

- **2.5.3+19 geüpload naar App Store Connect / TestFlight** (tag
  `testflight-2.5.3-build19`, Delivery UUID f9cfc8d5-…). Upload via
  `xcrun altool` met de App Store Connect API-key (8MMFTK5BXF).
- **Certificaat-herstel:** de App Store-upload faalde eerst ("No signing
  certificate iOS Distribution found"). Oorzaak: het **Apple Distribution**-
  certificaat was uit de Sleutelhanger verdwenen (alleen Apple Development
  restte). Opgelost door in Xcode → Settings → Accounts → Manage Certificates →
  `+` → Apple Distribution een nieuw certificaat aan te maken. Daarna
  `xcodebuild -exportArchive -allowProvisioningUpdates` → getekende IPA →
  altool-upload. Bij het tekenen vraagt de Sleutelhanger eenmalig toegang tot
  de private key → **Sta altijd toe** (Mac-inlogwachtwoord). Command-line
  cloud-signing via de API-key kon het cert NIET aanmaken ("Cloud signing
  permission error"); het certificaat moet lokaal in de keychain staan.
- **Waarschuwing bij upload (geen actie nu):** MinimumOSVersion is 13.0; vanaf
  **voorjaar 2027** eist Apple minimaal iOS 15.0. T.z.t. de deployment target
  in `ios/` naar 15.0 bumpen.

## 2026-08-13 — XML-opnamevelden: gebouwtype, examennummer, adviseur (versies 2.5.0 → 2.5.3)

Blok werk rond het VABI-monitorbestand dat de app aanlevert (via de Nextcloud).
De app vult een template (`assets/import_template.xml`, een VABI-projectbestand
v11.2) door gerichte tag-vervanging — zie `lib/services/xml_export_service.dart`.

- **2.5.0+16 — Examennummer + gebouwtype-keuzelijsten.**
  - Examennummer (Wonen) uit Instellingen → `<Vakbekwaamheidsnummer>`. Bevestigd
    werkend in VABI.
  - Twee getrapte keuzelijsten in het afsluitscherm (categorie → type),
    `lib/models/gebouwtype_optie.dart`, o.b.v. Pauls Excel *Variabelen vabi
    template*. Kernvondst: die Excel geeft de EP-Online **BuildingCategory**,
    maar de app-XML gebruikt het **ObjectClassificatie**-blok
    (Gebouwtype/Subtype/Ligging/Daktype) — een ander nummersysteem.
- **2.5.1+17 — Gebouwtype-codes geoogst + adviseurnaamvelden.**
  - Uit 148 echte monitorbestanden de koppeling BuildingCategory ↔
    ObjectClassificatie afgeleid. Gebouwtype: 0 eengezins / 1 appartement.
    Subtype: 0 vrijstaand / 1 kop-eind-hoek / 2 tussen.
  - Instellingen: velden Voorletters/Tussenvoegsel/Achternaam adviseur
    toegevoegd (boven de examennummers).
- **2.5.2+18 — Ligging compleet + adviseurnaam naar `<Adviseur>`-blok.**
  - Via `<BuildingCategorySupplement>` (Pauls "sub") de volledige
    appartement-mapping geoogst: Ligging = 2 bovenste / 1 tussen / 0 onderste.
    `Daktype` blijft -1 (per woning; adviseur bevestigt in VABI). Gebouwtype
    werkt nu bevestigd in VABI.
  - Adviseurnaam ook naar het `<Adviseur>`-blok (Algemeen) i.p.v. alleen de
    BezoekendeEpAdviseur-registratievelden. **NB: nog niet zichtbaar in VABI —
    open punt**, Paul levert een reverse-oracle-XML aan om het juiste veld te
    vinden.
- **2.5.3+19 — Instellingen slaan automatisch op.**
  - Adviseur-, examen- en e-mailvelden: stille autosave (onChanged, 600 ms
    debounce) via gedeelde `_currentSettings`-helper. Reden: de adviseurnaam
    bleef niet bewaard omdat op Opslaan gedrukt moest worden. Round-trip-test
    `test/app_settings_adviseur_test.dart` bewijst dat de opslaglaag klopt.

**Openstaand:**
- Adviseurnaam in de VABI-XML: juiste doelveld nog te bepalen (reverse-oracle).
- Gebouwtype "Twee onder 1 kap" (BC4) en appartement sub 3/7: niet in de
  dataset, codes afgeleid uit het patroon — verifiëren bij zo'n opname.
- **Volgende (13 aug, middag): CV-installatie via typeplaatje-herkenning.**
  Besluit: via de site (endpoint `POST /bd/v1/toestel-herkennen`, staat in
  APP-API-WENSEN), niet met een API-sleutel in de app. Zie `TYPEPLAATJE-PLAN.md`.

Borging 13 aug: git bundle + broncode-zip + dart_defines in
`OneDrive/Backups/photo_organizer_app/` (gedateerd), LEESMIJ bijgewerkt.

## Eerder

- **2.4.3+15** — Volumeknop als camerasluiter via de officiële Apple-API
  `AVCaptureEventInteraction` (iOS 17.2+), met de oude volume-observatie als
  terugval.
- **2.4.2+14** — Zelfherstel eenheidsnaam als de site de BAG-pandcode als naam
  gebruikte (later aan websitekant opgelost: `pand` ≠ naam, veld `bag_pand_id`).
- **2.4.x** — Adresvelden los meesturen bij intake, BAG via
  `/adressenuitgebreid`, GPS-adres via PDOK Locatieserver, BAG-sleutel uit de
  broncode.
- **2.3.0+11 (TestFlight)** — Energielabel klikbaar met detail-sheet;
  project verhuisd naar interne SSD.

_Voor de volledige geschiedenis: `git log` en de git bundle in de backupmap._
