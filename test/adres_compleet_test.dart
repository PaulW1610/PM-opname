import 'package:flutter_test/flutter_test.dart';

import 'package:photo_organizer_app/services/bag_service.dart';

void main() {
  group('heeftCompleetAdres', () {
    test('compleet adres is goed', () {
      final bag = BagData(
        adres: 'Nassaulaan',
        huisnummer: '41',
        postcode: '3743CB',
        plaatsnaam: 'Baarn',
      );
      expect(BagService.heeftCompleetAdres(bag), isTrue);
    });

    test('lege straat is niet compleet', () {
      final bag = BagData(
        adres: '',
        huisnummer: '41',
        postcode: '3743CB',
        plaatsnaam: 'Baarn',
      );
      expect(BagService.heeftCompleetAdres(bag), isFalse);
    });

    test('placeholder "Locatie" telt niet als plaats', () {
      final bag = BagData(
        adres: '',
        huisnummer: '53',
        postcode: '2101HL',
        plaatsnaam: 'Locatie',
      );
      expect(BagService.heeftCompleetAdres(bag), isFalse);
    });
  });
}
