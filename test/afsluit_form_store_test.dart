import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photo_organizer_app/services/afsluit_form_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('afsluitformulier onthoudt zijn waarden per dossier', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await AfsluitFormStore.bewaar('Dossier A', <String, dynamic>{
      'vloerType': 'Beton',
      'verwarmingType': 3,
      'renovatieVanToepassing': true,
    });

    final geladen = await AfsluitFormStore.laad('Dossier A');
    expect(geladen['vloerType'], 'Beton');
    expect(geladen['verwarmingType'], 3);
    expect(geladen['renovatieVanToepassing'], true);

    // Ander dossier deelt de staat niet.
    expect(await AfsluitFormStore.laad('Dossier B'), isEmpty);

    // Wissen na afsluiten.
    await AfsluitFormStore.wis('Dossier A');
    expect(await AfsluitFormStore.laad('Dossier A'), isEmpty);
  });
}
