# Logboek opname-app (blueprint collective)

Kort chronologisch overzicht van versies en beslissingen aan de app-kant.
Nieuwste bovenaan. De API-afspraken met de website staan in
`OneDrive/Apps/APP-API.md`; wensen richting de plugin-kant in
`APP-API-WENSEN.md`.

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
