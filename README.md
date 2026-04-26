# Photo Organizer App

## Overzicht
Photo Organizer App is een Flutter-app voor iPhone waarmee je gelabelde foto’s maakt en direct opslaat in Foto’s/iCloud.
De app gebruikt het BAG-adres (met geocoding fallback) als albumnaam.

## Huidige workflow
1. Adres ophalen via GPS + BAG (of handmatig invoeren)
2. Categorie kiezen (Wonen, Utiliteit, WWS Punten)
3. Live camera gebruiken met:
   - zoom
   - camera omdraaien
   - zaklamp aan/uit (blijft actief tijdens fotograferen)
4. Label-knop indrukken = direct foto maken + opslaan
5. Foto wordt opgeslagen in Foto’s/iCloud album met adresnaam

## Belangrijke permissies (iOS)
- Camera
- Foto’s toevoegen/lezen
- Locatie tijdens gebruik

## Structuur (belangrijkste bestanden)
- `lib/screens/start_screen.dart` – adres ophalen en doorsturen
- `lib/services/bag_service.dart` – BAG lookup + adresnaam opbouw
- `lib/services/photo_library_service.dart` – opslaan naar Foto’s/iCloud album
- `lib/widgets/tagged_camera_capture_view.dart` – live camera + labels + zoom/flip/torch
- `lib/screens/wonen_screen.dart` – labels Wonen
- `lib/screens/utiliteit_screen.dart` – labels Utiliteit
- `lib/screens/wws_punten_screen.dart` – labels WWS Punten

## Starten
```bash
flutter pub get
flutter run -d <device-id>
```

### Stabiel starten op iPhone (workaround)
Gebruik dit commando om automatisch de bekende iOS build-map issues op te vangen:

```bash
./tool/run_ios.sh
```

Optioneel voor release mode:

```bash
./tool/run_ios.sh --release
```

Met expliciete device-id:

```bash
./tool/run_ios.sh 00008150-000C09AE0205401C --debug
```

Optioneel met device-id:

```bash
./tool/run_ios.sh 00008150-000C09AE0205401C
```

### App starten zonder debugger (launch only)
Gebruik dit als fallback als `flutter run` de verbinding verliest:

```bash
./tool/launch_ios_only.sh
```

Met expliciete device-id:

```bash
./tool/launch_ios_only.sh 00008150-000C09AE0205401C
```

### Aanbevolen: robuuste iPhone start
Dit script probeert eerst launch-only en controleert of het app-proces echt draait:

```bash
./tool/start_ios.sh
```

Safe mode is standaard actief: dit commando doet **geen herinstallatie**.

Alleen als je expliciet wilt repareren met release rebuild + herinstallatie:

```bash
./tool/start_ios.sh --allow-reinstall
```

### Camera stabiliteitstest (handmatig + monitor)
Start de monitor en voer tijdens de test de camera-acties in de app uit:

```bash
./tool/camera_stability_check.sh
```

Optioneel met duur in seconden (bijv. 300 seconden):

```bash
./tool/camera_stability_check.sh 00008150-000C09AE0205401C 300
```

### Soak stabiliteitstest (automatisch monitoren)
Voor langere stabiliteitsruns (standaard 30 minuten):

```bash
./tool/soak_stability_check.sh
```

Optioneel met device-id, duur (seconden), check-interval en max relaunches:

```bash
./tool/soak_stability_check.sh 00008150-000C09AE0205401C 3600 5 3
```

Soak logs worden opgeslagen in:

```bash
build/soak_logs/
```

Lokale crash- en event-logs in de app (voor post-mortem analyse) worden opgeslagen in:

```bash
<app-documents>/stability/crash_log.jsonl
```

### Firebase Crashlytics (remote crash tracking)
Crashlytics is nu in de app geïntegreerd met een veilige fallback.

- Als Firebase juist is geconfigureerd, worden crashes/events ook remote doorgestuurd.
- Als Firebase nog niet is geconfigureerd, blijft de app stabiel en logt lokaal naar `crash_log.jsonl`.

Voor iOS is minimaal nodig:

1. Voeg `GoogleService-Info.plist` toe in `ios/Runner/` (en koppel in Xcode target Runner).
2. Gebruik een geldig provisioning-profiel/teambinding op het toestel.
3. Bouw opnieuw en start de app.

Optioneel (aanrader):

- Configureer project via FlutterFire CLI om ook web/android/macOS goed te ondersteunen.

### TestFlight release (iOS)
De app is nu voorbereid voor TestFlight met automatische signing.

Benodigd:

- Apple Developer account met App Store Connect toegang
- Geldige bundle id: `nl.paulweijers.photoorganizerapp`
- In Xcode onder `Runner > Signing & Capabilities`: Team geselecteerd en Automatic Signing aan

Build IPA (zonder upload):

```bash
./tool/build_testflight.sh
```

Build + direct upload:

```bash
./tool/build_testflight.sh --upload
```

Optioneel expliciete versie/buildnummer meegeven:

```bash
./tool/build_testflight.sh --build-name 2.0.1 --build-number 3 --upload
```

Voor upload moet je één van deze credentialsets in je shell zetten:

1. App Store Connect API key

```bash
export ASC_API_KEY_ID="JOUW_KEY_ID"
export ASC_API_ISSUER_ID="JOUW_ISSUER_ID"
```

2. Apple ID + app-specifiek wachtwoord

```bash
export APPLE_ID="jij@domein.nl"
export APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

Als je upload via VS Code taak doet (nieuwe shell), zet credentials dan in een bestand
in de projectroot: `.env.testflight`

```bash
APPLE_ID="jij@domein.nl"
APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

Snel invullen via helper-script:

```bash
./tool/setup_testflight_env.sh
```

Of geef ze direct mee aan het script:

```bash
./tool/build_testflight.sh --upload --apple-id "jij@domein.nl" --app-password "xxxx-xxxx-xxxx-xxxx"
```

Na upload verschijnt de build in App Store Connect > TestFlight (verwerking kan enkele minuten duren).

Als starten via Flutter CLI soms vastloopt op iOS debug-timeout, open dan:
```bash
open ios/Runner.xcworkspace
```
en start via Xcode met Product > Run.
