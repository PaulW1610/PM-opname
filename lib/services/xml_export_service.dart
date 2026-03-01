import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class XmlExportService {
  static Future<File> createXmlForDossier({
    required String dossierName,
    required String straat,
    required String huisnummer,
    required String huisletterToevoeging,
    required String postcode,
    required String plaatsnaam,
    required String bouwjaar,
    required String bagId,
    required String bagPandId,
  }) async {
    final template = await rootBundle.loadString('assets/import_template.xml');

    var xml = template;
    final bouwjaarTagRegex = RegExp(
      r'<Bouwjaar>\s*([^<]*)\s*</Bouwjaar>',
      caseSensitive: false,
    );
    final templateBouwjaarValues = bouwjaarTagRegex
        .allMatches(template)
        .map((m) => (m.group(1) ?? '').trim())
        .toList(growable: false);
    final templateBouwjaar3000Indexes = <int>[];
    for (var i = 0; i < templateBouwjaarValues.length; i++) {
      if (templateBouwjaarValues[i] == '3000') {
        templateBouwjaar3000Indexes.add(i);
      }
    }
    final cleanStraat = straat.trim();
    final cleanHuisnummer = huisnummer.trim();
    final cleanHuisletterToevoeging = huisletterToevoeging.trim();
    final cleanPostcode = postcode.trim();
    final cleanPlaatsnaam = plaatsnaam.trim();
    final cleanBouwjaar = bouwjaar.trim();
    final cleanBagId = bagId.trim();
    final cleanBagPandId = bagPandId.trim();
    final naamObject = [cleanStraat, cleanHuisnummer, cleanPostcode]
      .where((part) => part.isNotEmpty)
      .join(' ')
      .trim();
    final installatieNaamMetAdres = [cleanStraat, cleanHuisnummer]
        .where((part) => part.isNotEmpty)
        .join(' ')
        .trim();

    xml = _replaceFirstTagValue(xml, 'NaamObject', naamObject);
    if (installatieNaamMetAdres.isNotEmpty) {
      xml = xml.replaceFirst(
        'Installatie NAAM MET ADRES',
        _escapeXml(installatieNaamMetAdres),
      );
    }

    xml = _replaceAdresgegevensTagValue(xml, 'Straat', cleanStraat);
    xml = _replaceAdresgegevensTagValue(xml, 'Huisnummer', cleanHuisnummer);
    xml = _replaceAdresgegevensTagValue(
      xml,
      'HuisletterHuisnummertoevoeging',
      cleanHuisletterToevoeging,
    );
    xml = _replaceAdresgegevensTagValue(xml, 'Postcode', cleanPostcode);
    xml = _replaceAdresgegevensTagValue(xml, 'Woonplaats', cleanPlaatsnaam);
    // BAG-ID velden in import_template.xml ongemoeid laten.
    // Vabi-import blijkt gevoelig voor exacte formaat/placeholderwaarden van:
    // BagIdentificatie, BagPandId, BagObjectId, AfwijkendeBagIdentificatie.

    if (cleanBouwjaar.isNotEmpty) {
      if (templateBouwjaar3000Indexes.length != 1) {
        throw Exception(
          'Template moet exact 1 Bouwjaar-placeholder 3000 bevatten; gevonden: ${templateBouwjaar3000Indexes.length}',
        );
      }

      xml = _replaceBouwjaarPlaceholder(xml, cleanBouwjaar);

      if (RegExp(r'<Bouwjaar>\s*3000\s*</Bouwjaar>', caseSensitive: false)
          .hasMatch(xml)) {
        throw Exception('Bouwjaar placeholder 3000 niet vervangen in XML');
      }

      final outputBouwjaarValues = bouwjaarTagRegex
          .allMatches(xml)
          .map((m) => (m.group(1) ?? '').trim())
          .toList(growable: false);

      if (outputBouwjaarValues.length != templateBouwjaarValues.length) {
        throw Exception('Aantal Bouwjaar-velden gewijzigd; export gestopt');
      }

      final placeholderIndex = templateBouwjaar3000Indexes.single;
      for (var i = 0; i < templateBouwjaarValues.length; i++) {
        final expected = i == placeholderIndex
            ? cleanBouwjaar
            : templateBouwjaarValues[i];
        if (outputBouwjaarValues[i] != expected) {
          throw Exception(
            'Bouwjaar op positie $i is onterecht gewijzigd (${templateBouwjaarValues[i]} -> ${outputBouwjaarValues[i]}); export gestopt',
          );
        }
      }
    }

    final safeDossierName = _sanitizeName(dossierName);
    final baseDir = await getApplicationDocumentsDirectory();
    final dossierDir = Directory('${baseDir.path}/dossiers/$safeDossierName');
    await dossierDir.create(recursive: true);

    final file = File('${dossierDir.path}/metadata_export.xml');
    await file.writeAsString(xml, flush: true);
    return file;
  }

  static String _replaceAdresgegevensTagValue(
    String xml,
    String tagName,
    String value,
  ) {
    final sectionRegex = RegExp(
        r'(<Adresgegevens[^>]*>)([\s\S]*?)(</Adresgegevens>)',
      caseSensitive: false,
    );
    final sectionMatch = sectionRegex.firstMatch(xml);
    if (sectionMatch == null) {
      return xml;
    }

    final sectionOpen = sectionMatch.group(1)!;
    final sectionBody = sectionMatch.group(2)!;
    final sectionClose = sectionMatch.group(3)!;

    final replacedBody = _replaceTagValueInSection(sectionBody, tagName, value);
    final replacedSection = '$sectionOpen$replacedBody$sectionClose';

    return xml.replaceRange(sectionMatch.start, sectionMatch.end, replacedSection);
  }

  static String _replaceTagValueInSection(
    String section,
    String tagName,
    String value,
  ) {
    final escapedValue = _escapeXml(value);
    final regex = RegExp(
      '<$tagName>.*?</$tagName>',
      dotAll: true,
      caseSensitive: false,
    );

    if (!regex.hasMatch(section)) {
      return section;
    }

    return section.replaceAllMapped(
      regex,
      (_) => '<$tagName>$escapedValue</$tagName>',
    );
  }

  static String _replaceFirstTagValue(String xml, String tagName, String value) {
    final escapedValue = _escapeXml(value);
    final fullTagRegex = RegExp(
      '<$tagName>.*?</$tagName>',
      dotAll: true,
      caseSensitive: false,
    );

    final fullTagMatch = fullTagRegex.firstMatch(xml);
    if (fullTagMatch != null) {
      return xml.replaceRange(
        fullTagMatch.start,
        fullTagMatch.end,
        '<$tagName>$escapedValue</$tagName>',
      );
    }

    final selfClosingRegex = RegExp(
      '<$tagName(?:\\s+[^>]*)?\\s*/>',
      caseSensitive: false,
    );
    final selfClosingMatch = selfClosingRegex.firstMatch(xml);
    if (selfClosingMatch == null) {
      return xml;
    }

    return xml.replaceRange(
      selfClosingMatch.start,
      selfClosingMatch.end,
      '<$tagName>$escapedValue</$tagName>',
    );
  }

  static String _replaceBouwjaarPlaceholder(String xml, String bouwjaar) {
    final escapedValue = _escapeXml(bouwjaar);
    final placeholderRegex = RegExp(
      r'<Bouwjaar>\s*3000\s*</Bouwjaar>',
      caseSensitive: false,
    );
    return xml.replaceFirst(
      placeholderRegex,
      '<Bouwjaar>$escapedValue</Bouwjaar>',
    );
  }

  static String _sanitizeName(String raw) {
    final sanitized = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (sanitized.isEmpty) {
      return 'Onbekend_dossier';
    }
    return sanitized;
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}