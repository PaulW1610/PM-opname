import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Schrijft alle opnamegegevens als één leesbaar JSON-bestand naar het dossier.
///
/// Staat los van de Vabi-XML: dit is een complete, machineleesbare dump van de
/// opname (adres, BAG, formuliervelden) die als bijlage meegaat in de mail en
/// later door andere systemen ingelezen kan worden.
class JsonExportService {
  static const int schemaVersie = 1;

  /// Genereert `opname.json` in `dossiers/<dossierName>/` en geeft het bestand
  /// terug. [data] is de volledige inhoud die als JSON wordt weggeschreven.
  static Future<File> createJsonForDossier({
    required String dossierName,
    required Map<String, dynamic> data,
  }) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final dossierDir =
        Directory('${baseDir.path}/dossiers/${_sanitizeName(dossierName)}');
    await dossierDir.create(recursive: true);

    final file = File('${dossierDir.path}/opname.json');
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(data), flush: true);
    return file;
  }

  static String _sanitizeName(String raw) {
    final sanitized = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return sanitized.isEmpty ? 'Onbekend_dossier' : sanitized;
  }
}
