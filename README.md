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

Als starten via Flutter CLI soms vastloopt op iOS debug-timeout, open dan:
```bash
open ios/Runner.xcworkspace
```
en start via Xcode met Product > Run.
