import 'package:flutter_test/flutter_test.dart';
import 'package:photo_organizer_app/services/bag_service.dart';

/// Echt antwoord van Kadaster `/adressenuitgebreid` voor postcode 1072AL,
/// huisnummer 79 — acht appartementen in één pand, waarvan vier paren eerder
/// dezelfde naam en dezelfde fotomap kregen.
Map<String, dynamic> _adres({
  String? huisletter,
  String? toevoeging,
  required int oppervlakte,
}) {
  return <String, dynamic>{
    'openbareRuimteNaam': 'Ruysdaelkade',
    'huisnummer': 79,
    if (huisletter != null) 'huisletter': huisletter,
    if (toevoeging != null) 'huisnummertoevoeging': toevoeging,
    'postcode': '1072AL',
    'woonplaatsNaam': 'Amsterdam',
    'nummeraanduidingIdentificatie': '0363200000${oppervlakte}00',
    'oorspronkelijkBouwjaar': <String>['1878'],
    'oppervlakte': oppervlakte,
    'gebruiksdoelen': <String>['woonfunctie'],
    'pandIdentificaties': <String>['0363100012168960'],
  };
}

void main() {
  test('huisletter en toevoeging blijven gescheiden', () {
    final zonderLetter = BagData.fromJson(_adres(toevoeging: '1', oppervlakte: 43));
    final metLetter =
        BagData.fromJson(_adres(huisletter: 'A', toevoeging: '1', oppervlakte: 37));

    expect(zonderLetter.huisletterHuisnummertoevoeging, '1');
    expect(metLetter.huisletterHuisnummertoevoeging, 'A1');
    expect(metLetter.huisletter, 'A');
    expect(metLetter.huisnummertoevoeging, '1');
  });

  test('twee appartementen krijgen niet dezelfde dossier- en fotomap', () {
    final adressen = <BagData>[
      BagData.fromJson(_adres(toevoeging: '1', oppervlakte: 43)),
      BagData.fromJson(_adres(toevoeging: '2', oppervlakte: 43)),
      BagData.fromJson(_adres(toevoeging: '3', oppervlakte: 75)),
      BagData.fromJson(_adres(toevoeging: 'H', oppervlakte: 87)),
      BagData.fromJson(_adres(huisletter: 'A', toevoeging: '1', oppervlakte: 37)),
      BagData.fromJson(_adres(huisletter: 'A', toevoeging: '2', oppervlakte: 43)),
      BagData.fromJson(_adres(huisletter: 'A', toevoeging: '3', oppervlakte: 79)),
      BagData.fromJson(_adres(huisletter: 'A', toevoeging: 'H', oppervlakte: 80)),
    ];

    final namen = adressen.map((a) => a.getFolderName()).toSet();
    final fotomappen = adressen.map((a) => a.getPhotoCounterScope()).toSet();

    expect(namen.length, 8, reason: 'elk appartement een eigen dossiernaam');
    expect(fotomappen.length, 8, reason: 'elk appartement een eigen fotomap');
  });

  test('bouwjaar, oppervlakte en gebruiksdoel komen mee', () {
    final adres =
        BagData.fromJson(_adres(huisletter: 'A', toevoeging: 'H', oppervlakte: 80));

    expect(adres.oorspronkelijkBouwjaar, '1878');
    expect(adres.oppervlakte, 80);
    expect(adres.gebruiksdoel, 'woonfunctie');
    expect(adres.bagPandId, '0363100012168960');
  });

  test('eerder opgeslagen dossiers blijven leesbaar', () {
    // Oude opslagvorm kent alleen het samengevoegde veld.
    final oud = BagData.fromJson(<String, dynamic>{
      'openbareRuimteNaam': 'Kerklaan',
      'huisnummer': '53',
      'huisletterHuisnummertoevoeging': 'A1',
      'postcode': '2101HL',
      'plaatsnaam': 'Heemstede',
    });

    expect(oud.huisletterHuisnummertoevoeging, 'A1');
    expect(oud.getFolderName(), contains('Kerklaan 53 A1'));
  });
}
