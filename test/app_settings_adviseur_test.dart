import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photo_organizer_app/services/app_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('adviseurnaam en examennummer overleven opslaan + opnieuw laden',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await AppSettingsService.saveSettings(
      const AppSettings(
        emailRecipient: 'test@pmlabels.nl',
        adviseurVoorletters: 'P.M',
        adviseurTussenvoegsel: 'van',
        adviseurAchternaam: 'Weijers',
        examenNummerWonen: '64513',
        examenNummerUtiliteit: '',
        eigenaarId: '',
        eigenaarNaam: '',
        photoStorageLocation: '',
        gpsBagRadiusMeters: 50.0,
      ),
    );

    final geladen = await AppSettingsService.loadSettings();
    expect(geladen.adviseurVoorletters, 'P.M');
    expect(geladen.adviseurTussenvoegsel, 'van');
    expect(geladen.adviseurAchternaam, 'Weijers');
    expect(geladen.examenNummerWonen, '64513');
  });
}
