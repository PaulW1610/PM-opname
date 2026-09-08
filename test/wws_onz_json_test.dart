import 'package:flutter_test/flutter_test.dart';

import 'package:photo_organizer_app/models/wws_onz_data.dart';

void main() {
  test('WwsOnzDossier.toJson heeft het verwachte invoerformaat', () {
    final d = WwsOnzDossier(
      adres: 'Teststraat 1',
      postcode: '1234AB',
      plaats: 'Utrecht',
      gbo: 420,
      woz: 1500000,
      occupants: 16,
      corop: 'Utrecht',
      label: 'A+',
    );
    d.units.first.rooms.first
      ..soort = 'Vertrek'
      ..oppervlakte = 46.125;

    final json = d.toJson();
    expect(json['tool_type'], 'wws_onzelfstandige_woonruimte');
    expect(json['version'], 1);

    final building = json['building'] as Map;
    expect(building['occupants'], 16);
    expect(building['gbo'], 420.0);
    expect(building['label'], 'A+');
    expect((building['shared_facilities'] as Map)['heated_hall_count'], 0);

    expect(json['shared_facility_rows'], isA<List>());
    expect(json['shared_rooms'], isA<List>());
    expect(json['outdoor'], isA<List>());

    final unit = (json['units'] as List).first as Map;
    expect(unit['kitchen'], 'Gedeelde keuken');
    expect(unit['sanitary'], 'Gedeeld sanitair');
    expect(unit['deductions'], isA<List>());
    final room = (unit['rooms'] as List).first as Map;
    expect(room['Soort'], 'Vertrek');
    expect(room['Oppervlakte m2'], 46.125);
  });
}
