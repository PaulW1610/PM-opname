import 'package:flutter_test/flutter_test.dart';
import 'package:photo_organizer_app/models/blueprint_entiteit.dart';

/// Bewaakt de labelwaarschuwing uit contract §3.1b: de app hoort bij
/// `verlopen` en `verloopt_binnenkort` een duidelijk signaal te tonen, en bij
/// de overige statussen juist NIET (anders wordt de lijst één zee van rood).
void main() {
  BlueprintEntiteit maakEenheid(String? status) => BlueprintEntiteit.fromJson({
        'id': 1,
        'titel': 'Kerklaan 53',
        'adres': 'Kerklaan 53',
        'plaats': 'Heemstede',
        'postcode': '2101HL',
        'url': 'https://blueprint-data.nl/entiteit/kerklaan-53/',
        'ep_label': 'C',
        'ep_geldig_tot': '2027-03-14',
        if (status != null) 'ep_status': status,
      });

  test('verlopen label vraagt aandacht', () {
    final eenheid = maakEenheid('verlopen');
    expect(eenheid.labelVraagtAandacht, isTrue);
    expect(eenheid.labelWaarschuwing, 'Energielabel verlopen');
  });

  test('bijna verlopen label vraagt aandacht', () {
    final eenheid = maakEenheid('verloopt_binnenkort');
    expect(eenheid.labelVraagtAandacht, isTrue);
    expect(eenheid.labelWaarschuwing, 'Label verloopt binnenkort');
  });

  test('geldig label geeft geen waarschuwing', () {
    final eenheid = maakEenheid('ok');
    expect(eenheid.labelVraagtAandacht, isFalse);
    expect(eenheid.labelWaarschuwing, isEmpty);
  });

  test('nog niet gecheckt of veld ontbreekt geeft geen waarschuwing', () {
    expect(maakEenheid('').labelVraagtAandacht, isFalse);
    expect(maakEenheid(null).labelVraagtAandacht, isFalse);
  });

  test('geldigheidsdatum en label worden ingelezen', () {
    final eenheid = maakEenheid('verlopen');
    expect(eenheid.epLabel, 'C');
    expect(eenheid.epGeldigTot, '2027-03-14');
  });
}
