# Logboek opname-app (blueprint collective)

Kort chronologisch overzicht van versies en beslissingen aan de app-kant.
Nieuwste bovenaan. De API-afspraken met de website staan in
`OneDrive/Apps/APP-API.md`; wensen richting de plugin-kant in
`APP-API-WENSEN.md`.

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
