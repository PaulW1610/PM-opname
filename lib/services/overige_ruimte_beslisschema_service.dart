import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import 'bag_service.dart';

class OverigeRuimteBeslisschemaData {
  final bool? s1GrenstAanThermischeZone;
  final bool? s1VerwarmdOfGekoeldVoorVerblijf;
  final bool? s1OpenVerbindingMetThermischeZone;

  final bool? s2OmslotenDoorIsolatieSpouwOfAlleenGlas;
  final bool? s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas;
  final bool? s2ConstructieNaarRekenzoneMetSpouwOfIsolatie;
  final bool? s2WarmteweerstandConstructieKleinerDanRuimte;

  final bool? s3OmslotenDoorIsolatieOfSpouw;
  final bool? s3ConstructieNaarRekenzoneMetSpouwOfIsolatie;
  final bool? s3GebouwgebondenWarmteafgiftesysteemAanwezig;

  final String notities;

  const OverigeRuimteBeslisschemaData({
    required this.s1GrenstAanThermischeZone,
    required this.s1VerwarmdOfGekoeldVoorVerblijf,
    required this.s1OpenVerbindingMetThermischeZone,
    required this.s2OmslotenDoorIsolatieSpouwOfAlleenGlas,
    required this.s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas,
    required this.s2ConstructieNaarRekenzoneMetSpouwOfIsolatie,
    required this.s2WarmteweerstandConstructieKleinerDanRuimte,
    required this.s3OmslotenDoorIsolatieOfSpouw,
    required this.s3ConstructieNaarRekenzoneMetSpouwOfIsolatie,
    required this.s3GebouwgebondenWarmteafgiftesysteemAanwezig,
    required this.notities,
  });

  Map<String, dynamic> toJson() {
    return {
      's1GrenstAanThermischeZone': s1GrenstAanThermischeZone,
      's1VerwarmdOfGekoeldVoorVerblijf': s1VerwarmdOfGekoeldVoorVerblijf,
      's1OpenVerbindingMetThermischeZone': s1OpenVerbindingMetThermischeZone,
      's2OmslotenDoorIsolatieSpouwOfAlleenGlas': s2OmslotenDoorIsolatieSpouwOfAlleenGlas,
      's2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas':
          s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas,
      's2ConstructieNaarRekenzoneMetSpouwOfIsolatie':
          s2ConstructieNaarRekenzoneMetSpouwOfIsolatie,
      's2WarmteweerstandConstructieKleinerDanRuimte':
          s2WarmteweerstandConstructieKleinerDanRuimte,
      's3OmslotenDoorIsolatieOfSpouw': s3OmslotenDoorIsolatieOfSpouw,
      's3ConstructieNaarRekenzoneMetSpouwOfIsolatie':
          s3ConstructieNaarRekenzoneMetSpouwOfIsolatie,
      's3GebouwgebondenWarmteafgiftesysteemAanwezig':
          s3GebouwgebondenWarmteafgiftesysteemAanwezig,
      'notities': notities,
    };
  }

  static OverigeRuimteBeslisschemaData fromJson(Map<String, dynamic> json) {
    return OverigeRuimteBeslisschemaData(
      s1GrenstAanThermischeZone: json['s1GrenstAanThermischeZone'] as bool?,
      s1VerwarmdOfGekoeldVoorVerblijf:
          json['s1VerwarmdOfGekoeldVoorVerblijf'] as bool?,
      s1OpenVerbindingMetThermischeZone:
          json['s1OpenVerbindingMetThermischeZone'] as bool?,
      s2OmslotenDoorIsolatieSpouwOfAlleenGlas:
          json['s2OmslotenDoorIsolatieSpouwOfAlleenGlas'] as bool?,
      s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas:
          json['s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas'] as bool?,
      s2ConstructieNaarRekenzoneMetSpouwOfIsolatie:
          json['s2ConstructieNaarRekenzoneMetSpouwOfIsolatie'] as bool?,
      s2WarmteweerstandConstructieKleinerDanRuimte:
          json['s2WarmteweerstandConstructieKleinerDanRuimte'] as bool?,
      s3OmslotenDoorIsolatieOfSpouw:
          json['s3OmslotenDoorIsolatieOfSpouw'] as bool?,
      s3ConstructieNaarRekenzoneMetSpouwOfIsolatie:
          json['s3ConstructieNaarRekenzoneMetSpouwOfIsolatie'] as bool?,
      s3GebouwgebondenWarmteafgiftesysteemAanwezig:
          json['s3GebouwgebondenWarmteafgiftesysteemAanwezig'] as bool?,
      notities: (json['notities'] as String? ?? '').trim(),
    );
  }
}

class OverigeRuimteBeslisschemaService {
  static const String _outcomeThermischeZone = 'thermische_zone';
  static const String _outcomeNietThermischeZone = 'niet_thermische_zone';
  static const String _outcomeNaarSchema2 = 'naar_schema_2';
  static const String _outcomeNaarSchema3 = 'naar_schema_3';
  static const String _outcomePending = 'pending';

  static Future<File> _jsonFileForDossier(String dossierName) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final safeDossierName = _sanitizeName(dossierName);
    final dossierDir = Directory('${baseDir.path}/dossiers/$safeDossierName');
    await dossierDir.create(recursive: true);
    return File('${dossierDir.path}/beslisschema_overige_ruimte.json');
  }

  static Future<void> saveData({
    required String dossierName,
    required OverigeRuimteBeslisschemaData data,
  }) async {
    final file = await _jsonFileForDossier(dossierName);
    final payload = {
      'savedAt': DateTime.now().toIso8601String(),
      'data': data.toJson(),
    };
    await file.writeAsString(jsonEncode(payload), flush: true);
  }

  static Future<OverigeRuimteBeslisschemaData?> loadData(String dossierName) async {
    final file = await _jsonFileForDossier(dossierName);
    if (!await file.exists()) {
      return null;
    }
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) {
      return null;
    }
    return OverigeRuimteBeslisschemaData.fromJson(data);
  }

  static Future<File?> generatePdfFromSavedIfComplete({
    required String dossierName,
    required BagData bagData,
  }) async {
    final data = await loadData(dossierName);
    if (data == null) {
      return null;
    }
    return generatePdfIfComplete(
      dossierName: dossierName,
      bagData: bagData,
      data: data,
    );
  }

  static Future<File?> generatePdfIfComplete({
    required String dossierName,
    required BagData bagData,
    required OverigeRuimteBeslisschemaData data,
  }) async {
    final overallOutcomeCode = _overallOutcomeCode(data);
    if (overallOutcomeCode != _outcomeThermischeZone &&
        overallOutcomeCode != _outcomeNietThermischeZone) {
      return null;
    }

    final baseDir = await getApplicationDocumentsDirectory();
    final safeDossierName = _sanitizeName(dossierName);
    final dossierDir = Directory('${baseDir.path}/dossiers/$safeDossierName');
    await dossierDir.create(recursive: true);

    final file = File(
      '${dossierDir.path}/beslisschema_overige_ruimte_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    final now = DateTime.now();
    final opnameDatum =
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    final schema1Outcome = _schema1OutcomeCode(data);
    final schema2Outcome = _schema2OutcomeCode(data);
    final schema3Outcome = _schema3OutcomeCode(data);

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, text: 'Beslisschema - Overige ruimte'),
          pw.Text('Dossier: $dossierName'),
          pw.Text('Datum: $opnameDatum'),
          pw.SizedBox(height: 8),
          pw.Text('Adres: ${(bagData.adres ?? '-')} ${(bagData.huisnummer ?? '')}'.trim()),
          pw.Text('Postcode: ${bagData.postcode}'),
          pw.Text('Plaats: ${bagData.plaatsnaam}'),
          pw.SizedBox(height: 12),
          pw.Text('Beslisschema 1', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(
            '1. Grenst de ruimte aan een ruimte die hoort tot de thermische zone? '
            '${_jaNee(data.s1GrenstAanThermischeZone)}',
          ),
          if (data.s1GrenstAanThermischeZone == true)
            pw.Text(
              '2. Wordt de ruimte verwarmd of gekoeld voor het verblijf van mensen? '
              '${_jaNee(data.s1VerwarmdOfGekoeldVoorVerblijf)}',
            ),
          if (data.s1GrenstAanThermischeZone == true &&
              data.s1VerwarmdOfGekoeldVoorVerblijf == false)
            pw.Text(
              '3. Is er een open verbinding tussen de ruimte en een andere ruimte '
              'behorend bij de thermische zone? '
              '${_jaNee(data.s1OpenVerbindingMetThermischeZone)}',
            ),
          pw.Text('Uitkomst schema 1: ${_mapOutcomeCodeToText(schema1Outcome)}'),
          if (schema1Outcome == _outcomeNaarSchema2) ...[
            pw.SizedBox(height: 12),
            pw.Text('Beslisschema 2', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text(
              '1. Wordt de ruimte omsloten door isolatie (3a) of een spouwmuur (3a) '
              'of alleen raam/glas (3b)? ${_jaNee(data.s2OmslotenDoorIsolatieSpouwOfAlleenGlas)}',
            ),
            if (data.s2OmslotenDoorIsolatieSpouwOfAlleenGlas == true)
              pw.Text(
                '2. Is in de ruimte in de gevel(s) of dak meer dan 10% raamoppervlak '
                'aanwezig en bestaat meer dan 30% van de oppervlakte van het raam '
                'uit enkel glas (4)? '
                '${_jaNee(data.s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas)}',
              ),
            if (data.s2OmslotenDoorIsolatieSpouwOfAlleenGlas == true &&
                data.s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas == false)
              pw.Text(
                '3. Is de constructie tussen de ruimte en andere ruimte behorend bij '
                'de rekenzone van een spouw en/of isolatie voorzien (3a)? '
                '${_jaNee(data.s2ConstructieNaarRekenzoneMetSpouwOfIsolatie)}',
              ),
            if (data.s2OmslotenDoorIsolatieSpouwOfAlleenGlas == true &&
                data.s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas == false &&
                data.s2ConstructieNaarRekenzoneMetSpouwOfIsolatie == true)
              pw.Text(
                '4. Is de warmteweerstand van de constructie tussen de ruimte en '
                'andere ruimte behorend bij de thermische zone kleiner dan de '
                'warmteweerstand van de ruimte (5)? '
                '${_jaNee(data.s2WarmteweerstandConstructieKleinerDanRuimte)}',
              ),
            pw.Text('Uitkomst schema 2: ${_mapOutcomeCodeToText(schema2Outcome)}'),
          ],
          if (schema2Outcome == _outcomeNaarSchema3) ...[
            pw.SizedBox(height: 12),
            pw.Text('Beslisschema 3', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text(
              '1. Wordt de ruimte omsloten door isolatie (3a) of een spouwmuur (3a)? '
              '${_jaNee(data.s3OmslotenDoorIsolatieOfSpouw)}',
            ),
            if (data.s3OmslotenDoorIsolatieOfSpouw == false)
              pw.Text(
                '2. Is de constructie tussen de ruimte en andere ruimte behorend bij '
                'de rekenzone van een spouw en/of isolatie voorzien (3a)? '
                '${_jaNee(data.s3ConstructieNaarRekenzoneMetSpouwOfIsolatie)}',
              ),
            if (data.s3OmslotenDoorIsolatieOfSpouw == false &&
                data.s3ConstructieNaarRekenzoneMetSpouwOfIsolatie == false)
              pw.Text(
                '3. Is er in de ruimte een gebouwgebonden warmteafgiftesysteem (6) '
                'aanwezig? '
                '${_jaNee(data.s3GebouwgebondenWarmteafgiftesysteemAanwezig)}',
              ),
            pw.Text('Uitkomst schema 3: ${_mapOutcomeCodeToText(schema3Outcome)}'),
          ],
          pw.SizedBox(height: 12),
          pw.Text('Uitkomst', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(_overallOutcomeText(data)),
          pw.SizedBox(height: 12),
          pw.Text('Notities', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(data.notities.trim().isEmpty ? '-' : data.notities.trim()),
        ],
      ),
    );

    await file.writeAsBytes(await doc.save(), flush: true);
    return file;
  }

  static String _schema1OutcomeCode(OverigeRuimteBeslisschemaData data) {
    if (data.s1GrenstAanThermischeZone == null) {
      return _outcomePending;
    }
    if (data.s1GrenstAanThermischeZone == false) {
      return _outcomeNietThermischeZone;
    }
    if (data.s1VerwarmdOfGekoeldVoorVerblijf == null) {
      return _outcomePending;
    }
    if (data.s1VerwarmdOfGekoeldVoorVerblijf == true) {
      return _outcomeThermischeZone;
    }
    if (data.s1OpenVerbindingMetThermischeZone == null) {
      return _outcomePending;
    }
    if (data.s1OpenVerbindingMetThermischeZone == true) {
      return _outcomeThermischeZone;
    }
    return _outcomeNaarSchema2;
  }

  static String _schema2OutcomeCode(OverigeRuimteBeslisschemaData data) {
    if (_schema1OutcomeCode(data) != _outcomeNaarSchema2) {
      return _outcomePending;
    }
    if (data.s2OmslotenDoorIsolatieSpouwOfAlleenGlas == null) {
      return _outcomePending;
    }
    if (data.s2OmslotenDoorIsolatieSpouwOfAlleenGlas == false) {
      return _outcomeNaarSchema3;
    }
    if (data.s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas == null) {
      return _outcomePending;
    }
    if (data.s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas == true) {
      return _outcomeNaarSchema3;
    }
    if (data.s2ConstructieNaarRekenzoneMetSpouwOfIsolatie == null) {
      return _outcomePending;
    }
    if (data.s2ConstructieNaarRekenzoneMetSpouwOfIsolatie == false) {
      return _outcomeThermischeZone;
    }
    if (data.s2WarmteweerstandConstructieKleinerDanRuimte == null) {
      return _outcomePending;
    }
    if (data.s2WarmteweerstandConstructieKleinerDanRuimte == true) {
      return _outcomeThermischeZone;
    }
    return _outcomeNaarSchema3;
  }

  static String _schema3OutcomeCode(OverigeRuimteBeslisschemaData data) {
    if (_schema2OutcomeCode(data) != _outcomeNaarSchema3) {
      return _outcomePending;
    }
    if (data.s3OmslotenDoorIsolatieOfSpouw == null) {
      return _outcomePending;
    }
    if (data.s3OmslotenDoorIsolatieOfSpouw == true) {
      return _outcomeNietThermischeZone;
    }
    if (data.s3ConstructieNaarRekenzoneMetSpouwOfIsolatie == null) {
      return _outcomePending;
    }
    if (data.s3ConstructieNaarRekenzoneMetSpouwOfIsolatie == true) {
      return _outcomeNietThermischeZone;
    }
    if (data.s3GebouwgebondenWarmteafgiftesysteemAanwezig == null) {
      return _outcomePending;
    }
    return data.s3GebouwgebondenWarmteafgiftesysteemAanwezig == true
        ? _outcomeThermischeZone
        : _outcomeNietThermischeZone;
  }

  static String _overallOutcomeCode(OverigeRuimteBeslisschemaData data) {
    final schema1 = _schema1OutcomeCode(data);
    if (schema1 == _outcomeThermischeZone || schema1 == _outcomeNietThermischeZone) {
      return schema1;
    }
    if (schema1 != _outcomeNaarSchema2) {
      return _outcomePending;
    }
    final schema2 = _schema2OutcomeCode(data);
    if (schema2 == _outcomeThermischeZone || schema2 == _outcomeNietThermischeZone) {
      return schema2;
    }
    if (schema2 == _outcomeNaarSchema3) {
      return _schema3OutcomeCode(data);
    }
    return _outcomePending;
  }

  static String _overallOutcomeText(OverigeRuimteBeslisschemaData data) {
    final outcome = _overallOutcomeCode(data);
    switch (outcome) {
      case _outcomeThermischeZone:
        return 'Ruimte behoort tot thermische zone.';
      case _outcomeNietThermischeZone:
        return 'Ruimte behoort niet tot thermische zone.';
      default:
        return 'Nog geen uitkomst beschikbaar.';
    }
  }

  static String _jaNee(bool? value) {
    if (value == null) {
      return '-';
    }
    return value ? 'Ja' : 'Nee';
  }

  static String _mapOutcomeCodeToText(String code) {
    switch (code) {
      case _outcomeThermischeZone:
        return 'Ruimte behoort tot thermische zone';
      case _outcomeNietThermischeZone:
        return 'Ruimte behoort niet tot thermische zone';
      case _outcomeNaarSchema2:
        return 'Ga verder met Beslisschema 2';
      case _outcomeNaarSchema3:
        return 'Ga verder met Beslisschema 3';
      default:
        return 'Nog niet bepaald';
    }
  }

  static String _sanitizeName(String raw) {
    final sanitized = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (sanitized.isEmpty) {
      return 'Onbekend_dossier';
    }
    return sanitized;
  }
}
