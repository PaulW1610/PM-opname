import 'package:flutter_test/flutter_test.dart';

import 'package:photo_organizer_app/services/dossier_photo_store.dart';

void main() {
  group('fotolabel in bestandsnaam', () {
    test('labelForFilename maakt een compacte, machineleesbare code', () {
      expect(DossierPhotoStore.labelForFilename('CV plaatje'), 'CVPLAATJE');
      expect(DossierPhotoStore.labelForFilename('Boiler plaatje'), 'BOILERPLAATJE');
      expect(DossierPhotoStore.labelForFilename('HR++ Glas'), 'HRPPGLAS');
      expect(DossierPhotoStore.labelForFilename('Meter'), 'METER');
      expect(DossierPhotoStore.labelForFilename(''), '');
    });

    test('labelFromFilename leest het label terug', () {
      expect(
        DossierPhotoStore.labelFromFilename('1018TA_102_0031_CVPLAATJE.jpg'),
        'CVPLAATJE',
      );
      expect(
        DossierPhotoStore.labelFromFilename('1018TA_102_0007_METER.jpeg'),
        'METER',
      );
    });

    test('ongelabelde (oude) foto geeft null', () {
      expect(DossierPhotoStore.labelFromFilename('1018TA_102_0031.jpg'), null);
    });
  });
}
