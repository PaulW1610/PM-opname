import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import 'bag_service.dart';

class OpmerkingenFormulierService {
  static Future<File> _jsonFileForDossier(String dossierName) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final safeDossierName = _sanitizeName(dossierName);
    final dossierDir = Directory('${baseDir.path}/dossiers/$safeDossierName');
    await dossierDir.create(recursive: true);
    return File('${dossierDir.path}/opmerkingen_formulier.json');
  }

  static Future<void> saveOpmerkingen({
    required String dossierName,
    required String opmerkingen,
  }) async {
    final file = await _jsonFileForDossier(dossierName);
    final payload = {
      'savedAt': DateTime.now().toIso8601String(),
      'opmerkingen': opmerkingen,
    };
    await file.writeAsString(jsonEncode(payload), flush: true);
  }

  static Future<String> loadOpmerkingen(String dossierName) async {
    final file = await _jsonFileForDossier(dossierName);
    if (!await file.exists()) {
      return '';
    }
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return (decoded['opmerkingen'] as String? ?? '').trim();
  }

  static Future<File?> generatePdfFromSavedIfAny({
    required String dossierName,
    required BagData bagData,
  }) async {
    final opmerkingen = await loadOpmerkingen(dossierName);
    if (opmerkingen.trim().isEmpty) {
      return null;
    }
    return generatePdf(
      dossierName: dossierName,
      bagData: bagData,
      opmerkingen: opmerkingen,
    );
  }

  static Future<File?> generatePdf({
    required String dossierName,
    required BagData bagData,
    required String opmerkingen,
  }) async {
    final normalized = opmerkingen.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final baseDir = await getApplicationDocumentsDirectory();
    final safeDossierName = _sanitizeName(dossierName);
    final dossierDir = Directory('${baseDir.path}/dossiers/$safeDossierName');
    await dossierDir.create(recursive: true);

    final file = File(
      '${dossierDir.path}/opmerkingen_formulier_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    final now = DateTime.now();
    final opnameDatum =
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, text: 'Formulier - Opmerkingen'),
          pw.Text('Dossier: $dossierName'),
          pw.Text('Datum: $opnameDatum'),
          pw.SizedBox(height: 8),
          pw.Text('Adres: ${(bagData.adres ?? '-')} ${(bagData.huisnummer ?? '')}'.trim()),
          pw.Text('Postcode: ${bagData.postcode}'),
          pw.Text('Plaats: ${bagData.plaatsnaam}'),
          pw.SizedBox(height: 12),
          pw.Text('Opmerkingen', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(normalized),
        ],
      ),
    );

    await file.writeAsBytes(await doc.save(), flush: true);
    return file;
  }

  static String _sanitizeName(String raw) {
    final sanitized = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (sanitized.isEmpty) {
      return 'Onbekend_dossier';
    }
    return sanitized;
  }
}
