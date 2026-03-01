import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'photo_library_service.dart';

class OpnameAfsluitingSaveResult {
  final String textFilePath;
  final String imageFilePath;

  const OpnameAfsluitingSaveResult({
    required this.textFilePath,
    required this.imageFilePath,
  });
}

class DossierService {
  static const List<String> _documentOpties = [
    'Zonnepanelen',
    'Fotos verbouwing',
    'Fotos isolatie',
    'Facturen aannemer',
  ];

  static Future<OpnameAfsluitingSaveResult> saveOpnameAfsluitingWithAlbumImage({
    required String dossierName,
    required String vloerType,
    required String ventilatieType,
    required String verwarmingType,
    required String tapwaterType,
    required bool? koelingAanwezig,
    required bool? zonneEnergieAanwezig,
    required bool renovatieVanToepassing,
    required bool alleRamenHetzelfde,
    required List<String> aangeleverdeGegevens,
  }) async {
    final txtFile = await saveOpnameAfsluiting(
      dossierName: dossierName,
      vloerType: vloerType,
      ventilatieType: ventilatieType,
      verwarmingType: verwarmingType,
      tapwaterType: tapwaterType,
      koelingAanwezig: koelingAanwezig,
      zonneEnergieAanwezig: zonneEnergieAanwezig,
      renovatieVanToepassing: renovatieVanToepassing,
      alleRamenHetzelfde: alleRamenHetzelfde,
      aangeleverdeGegevens: aangeleverdeGegevens,
    );

    final imageFile = await _createOpnameAfsluitingImage(
      txtFile: txtFile,
      dossierName: dossierName,
    );

    await PhotoLibraryService.saveImageToAddressAlbum(
      imagePath: imageFile.path,
      addressAlbumName: dossierName,
    );

    return OpnameAfsluitingSaveResult(
      textFilePath: txtFile.path,
      imageFilePath: imageFile.path,
    );
  }

  static Future<File> saveOpnameAfsluiting({
    required String dossierName,
    required String vloerType,
    required String ventilatieType,
    required String verwarmingType,
    required String tapwaterType,
    required bool? koelingAanwezig,
    required bool? zonneEnergieAanwezig,
    required bool renovatieVanToepassing,
    required bool alleRamenHetzelfde,
    required List<String> aangeleverdeGegevens,
  }) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final safeDossierName = _sanitizeName(dossierName);
    final dossierDir = Directory('${baseDir.path}/dossiers/$safeDossierName');
    await dossierDir.create(recursive: true);

    final file = File('${dossierDir.path}/opname_afsluiting.txt');
    final now = DateTime.now();
    final opnameDatum =
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    final content = StringBuffer()
      ..writeln('Opname - $safeDossierName')
      ..writeln('Opname Datum: $opnameDatum')
      ..writeln('Dossier: $safeDossierName')
      ..writeln('')
      ..writeln('1. Vloer: $vloerType')
      ..writeln('')
      ..writeln('Onderdeel installatie')
      ..writeln('1. Ventilatie: $ventilatieType')
      ..writeln('2. Verwarming: $verwarmingType')
      ..writeln('3. Tapwater: $tapwaterType')
      ..writeln('4. Koeling: ${_boolToJaNee(koelingAanwezig)}')
      ..writeln('5. Zonne energie: ${_boolToJaNee(zonneEnergieAanwezig)}')
      ..writeln('')
      ..writeln(
        'Renovatie jaar van toepassing: ${renovatieVanToepassing ? 'Ja' : 'Nee'}',
      )
      ..writeln('Alle ramen het zelfde: ${alleRamenHetzelfde ? 'Ja' : 'Nee'}')
      ..writeln('')
      ..writeln('Door opdrachtgever ter beschikking gestelde documenten:');

    for (final optie in _documentOpties) {
      content.writeln(
        '- $optie: ${aangeleverdeGegevens.contains(optie) ? 'Ja' : 'Nee'}',
      );
    }

    await file.writeAsString(content.toString(), flush: true);
    return file;
  }

  static Future<File> _createOpnameAfsluitingImage({
    required File txtFile,
    required String dossierName,
  }) async {
    final content = await txtFile.readAsString();
    final lines = content
        .split('\n')
        .expand((line) => _wrapLine(line, 70))
        .toList(growable: false);

    final image = img.Image(1600, 2200);
    img.fill(image, img.getColor(255, 255, 255));

    final font = img.arial_24;
    var y = 60;
    for (final line in lines) {
      img.drawString(
        image,
        font,
        60,
        y,
        line,
        color: img.getColor(0, 0, 0),
      );
      y += 34;
      if (y > image.height - 80) {
        break;
      }
    }

    final safeName = _sanitizeName(dossierName);
    final imageFile = File('${txtFile.parent.path}/opname_afsluiting_$safeName.png');
    final pngBytes = img.encodePng(image, level: 3);
    await imageFile.writeAsBytes(pngBytes, flush: true);
    return imageFile;
  }

  static List<String> _wrapLine(String text, int maxChars) {
    final trimmed = text.trimRight();
    if (trimmed.isEmpty) {
      return const [''];
    }

    final words = trimmed.split(RegExp(r'\s+'));
    final result = <String>[];
    final current = StringBuffer();

    for (final word in words) {
      final candidate = current.isEmpty ? word : '${current.toString()} $word';
      if (candidate.length <= maxChars) {
        current
          ..clear()
          ..write(candidate);
      } else {
        if (current.isNotEmpty) {
          result.add(current.toString());
          current
            ..clear()
            ..write(word);
        } else {
          result.add(word.substring(0, maxChars));
          current
            ..clear()
            ..write(word.substring(maxChars));
        }
      }
    }

    if (current.isNotEmpty) {
      result.add(current.toString());
    }

    return result;
  }

  static String _sanitizeName(String raw) {
    final sanitized = raw
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    if (sanitized.isEmpty) {
      return 'Onbekend_dossier';
    }
    return sanitized;
  }

  static String _boolToJaNee(bool? value) {
    if (value == null) {
      return 'Niet ingevuld';
    }
    return value ? 'Ja' : 'Nee';
  }
}