import 'package:flutter_test/flutter_test.dart';
import 'package:photo_organizer_app/services/pdok_locatieserver_service.dart';

/// Echte antwoordvorm van de PDOK Locatieserver (reverse) op het punt van
/// Ruysdaelkade 79, Amsterdam — acht appartementen op één huisnummer.
Map<String, dynamic> _doc({
  required String weergavenaam,
  required double afstand,
  String? huisletter,
  String? toevoeging,
}) {
  return <String, dynamic>{
    'weergavenaam': weergavenaam,
    'afstand': afstand,
    'postcode': '1072AL',
    'huisnummer': 79,
    if (huisletter != null) 'huisletter': huisletter,
    if (toevoeging != null) 'huisnummertoevoeging': toevoeging,
    'straatnaam': 'Ruysdaelkade',
    'woonplaatsnaam': 'Amsterdam',
    'nummeraanduiding_id': '0363200000260047',
  };
}

void main() {
  test('huisletter en toevoeging worden apart gelezen', () {
    final metLetter = PdokAdres.fromJson(_doc(
      weergavenaam: 'Ruysdaelkade 79A-1, 1072AL Amsterdam',
      afstand: 0,
      huisletter: 'A',
      toevoeging: '1',
    ));
    final zonderLetter = PdokAdres.fromJson(_doc(
      weergavenaam: 'Ruysdaelkade 79-1, 1072AL Amsterdam',
      afstand: 2.24,
      toevoeging: '1',
    ));

    expect(metLetter.huisletter, 'A');
    expect(metLetter.huisnummertoevoeging, '1');
    expect(metLetter.toevoegingSleutel, 'a1');

    expect(zonderLetter.huisletter, isNull);
    expect(zonderLetter.toevoegingSleutel, '1');

    // Cruciaal: deze twee appartementen mogen niet dezelfde sleutel krijgen.
    expect(metLetter.toevoegingSleutel == zonderLetter.toevoegingSleutel, isFalse);
  });

  test('adressen op hetzelfde huisnummer delen één BAG-verzoek', () {
    final adressen = [
      PdokAdres.fromJson(_doc(
          weergavenaam: 'a', afstand: 0, huisletter: 'A', toevoeging: 'H')),
      PdokAdres.fromJson(_doc(weergavenaam: 'b', afstand: 2.24, toevoeging: 'H')),
    ];

    final sleutels =
        adressen.map((a) => a.postcodeHuisnummerSleutel).toSet();
    expect(sleutels.length, 1, reason: 'één verzoek volstaat voor beide');
  });

  test('afstand bepaalt de volgorde en ontbrekende velden zijn veilig', () {
    final adres = PdokAdres.fromJson(<String, dynamic>{
      'weergavenaam': 'Kerklaan 53, 2101HL Heemstede',
      'postcode': '2101HL',
      'huisnummer': 53,
      'straatnaam': 'Kerklaan',
      'woonplaatsnaam': 'Heemstede',
      // geen afstand, geen letter of toevoeging
    });

    expect(adres.afstandMeters, double.infinity);
    expect(adres.toevoegingSleutel, '');
    expect(adres.postcodeHuisnummerSleutel, '2101HL|53');
  });
}
