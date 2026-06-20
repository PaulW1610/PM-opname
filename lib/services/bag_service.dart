import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

String? _findFirstValueByKeys(dynamic data, List<String> keys) {
  if (data is Map<String, dynamic>) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    for (final value in data.values) {
      final found = _findFirstValueByKeys(value, keys);
      if (found != null && found.trim().isNotEmpty) {
        return found;
      }
    }
  } else if (data is List) {
    for (final item in data) {
      final found = _findFirstValueByKeys(item, keys);
      if (found != null && found.trim().isNotEmpty) {
        return found;
      }
    }
  }
  return null;
}

String? _extractPandIdFromHref(String? href) {
  if (href == null || href.trim().isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(href.trim());
  if (uri == null) {
    return null;
  }
  final segments = uri.pathSegments;
  if (segments.isEmpty) {
    return null;
  }
  return segments.last;
}

bool _isValidBouwjaar(String? value) {
  if (value == null) return false;
  final parsed = int.tryParse(value.trim());
  if (parsed == null) return false;
  final currentYear = DateTime.now().year;
  return parsed >= 1000 && parsed <= max(currentYear + 1, 2100);
}

String? _extractFirstValidBouwjaarDeep(dynamic data) {
  if (data == null) {
    return null;
  }

  if (data is Map<String, dynamic>) {
    for (final entry in data.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains('bouwjaar')) {
        final candidate = _extractFirstValidBouwjaarDeep(entry.value);
        if (_isValidBouwjaar(candidate)) {
          return candidate;
        }
      }
    }

    for (final value in data.values) {
      final found = _extractFirstValidBouwjaarDeep(value);
      if (_isValidBouwjaar(found)) {
        return found;
      }
    }

    return null;
  }

  if (data is List) {
    for (final item in data) {
      final found = _extractFirstValidBouwjaarDeep(item);
      if (_isValidBouwjaar(found)) {
        return found;
      }
    }
    return null;
  }

  final text = data.toString().trim();
  if (_isValidBouwjaar(text)) {
    return text;
  }

  final match = RegExp(r'\b(1\d{3}|20\d{2}|2100)\b').firstMatch(text);
  if (match != null) {
    final year = match.group(1);
    if (_isValidBouwjaar(year)) {
      return year;
    }
  }

  return null;
}

class _PandInfo {
  final String? pandId;
  final String? bouwjaar;

  const _PandInfo({
    this.pandId,
    this.bouwjaar,
  });
}

/// Model to hold BAG response data.
class BagData {
  /// Street name from BAG response.
  final String? adres;

  /// House number from BAG response.
  final String? huisnummer;

  /// House letter/addition from BAG response.
  final String? huisletterHuisnummertoevoeging;

  /// Postcode from BAG response (e.g., "2101 HL").
  final String postcode;

  /// Place name from BAG response.
  final String plaatsnaam;

  /// BAG address identification.
  final String? bagIdentificatie;

  /// BAG adres identificatie (adressen endpoint identificatie).
  final String? bagAdresId;

  /// BAG adresseerbaar object identificatie.
  final String? adresseerbaarObjectId;

  /// BAG building identification.
  final String? bagPandId;

  /// Building year from BAG response.
  final String? oorspronkelijkBouwjaar;

  /// Use case from BAG response.
  final String? gebruiksdoel;

  /// Latitude in WGS84 if available from BAG payload.
  final double? latitude;

  /// Longitude in WGS84 if available from BAG payload.
  final double? longitude;

  /// Create BAG data model.
  BagData({
    this.adres,
    this.huisnummer,
    this.huisletterHuisnummertoevoeging,
    required this.postcode,
    required this.plaatsnaam,
    this.bagIdentificatie,
    this.bagAdresId,
    this.adresseerbaarObjectId,
    this.bagPandId,
    this.oorspronkelijkBouwjaar,
    this.gebruiksdoel,
    this.latitude,
    this.longitude,
  });

  /// Create from JSON response.
  factory BagData.fromJson(Map<String, dynamic> json) {
    final postcode =
        json['postcode']?.toString() ?? json['postCode']?.toString() ?? 'Unknown';
    final plaatsnaam = json['plaatsnaam']?.toString() ??
        json['woonplaatsNaam']?.toString() ??
      (json['woonplaats'] is Map<String, dynamic>
        ? (json['woonplaats']['naam']?.toString())
        : json['woonplaats']?.toString()) ??
        json['woonplaats']?.toString() ??
        'Unknown';
    final adres = json['openbareRuimteNaam']?.toString() ??
      json['straatnaam']?.toString() ??
      json['openbareruimteNaam']?.toString() ??
      json['adres']?.toString();
    final huisnummer = json['huisnummer']?.toString() ??
      json['huisNummer']?.toString();
    final huisletterHuisnummertoevoeging =
        json['huisletterHuisnummertoevoeging']?.toString() ??
        json['huisnummertoevoeging']?.toString() ??
        json['huisletter']?.toString();

    final selfHrefId = (() {
      final links = json['_links'];
      if (links is! Map<String, dynamic>) {
        return null;
      }
      final selfLink = links['self'];
      if (selfLink is Map<String, dynamic>) {
        return _extractPandIdFromHref(selfLink['href']?.toString());
      }
      if (selfLink is String) {
        return _extractPandIdFromHref(selfLink);
      }
      return null;
    })();

    final bagAdresId =
        json['identificatie']?.toString() ??
        json['nummeraanduidingIdentificatie']?.toString() ??
        selfHrefId;
    final adresseerbaarObjectId =
      json['adresseerbaarObjectIdentificatie']?.toString() ??
      json['adresseerbaarobjectIdentificatie']?.toString() ??
      json['adresseerbaar_object_identificatie']?.toString() ??
      _findFirstValueByKeys(
        json,
        const [
          'adresseerbaarObjectIdentificatie',
          'adresseerbaarobjectIdentificatie',
          'adresseerbaar_object_identificatie',
        ],
      );

    final bagIdentificatie =
      bagAdresId ??
      json['bagIdentificatie']?.toString() ??
      adresseerbaarObjectId;

    String? bagPandId =
        json['bagPandId']?.toString() ??
        json['pandId']?.toString();

    final pandIdentificaties = json['pandIdentificaties'];
    if ((bagPandId == null || bagPandId.isEmpty) &&
        pandIdentificaties is List &&
        pandIdentificaties.isNotEmpty) {
      final firstPandId = pandIdentificaties.first?.toString();
      if (firstPandId != null && firstPandId.trim().isNotEmpty) {
        bagPandId = firstPandId.trim();
      }
    }

    final panden = json['panden'];
    if ((bagPandId == null || bagPandId.isEmpty) && panden is List && panden.isNotEmpty) {
      final firstPand = panden.first;
      if (firstPand is Map<String, dynamic>) {
        bagPandId = firstPand['identificatie']?.toString() ?? firstPand['id']?.toString();
      } else {
        bagPandId = firstPand?.toString();
      }
    }

    if (bagPandId == null || bagPandId.isEmpty) {
      final links = json['_links'];
      if (links is Map<String, dynamic>) {
        final linkedPanden = links['panden'];
        if (linkedPanden is List && linkedPanden.isNotEmpty) {
          final firstLinkedPand = linkedPanden.first;
          if (firstLinkedPand is Map<String, dynamic>) {
            bagPandId = _extractPandIdFromHref(firstLinkedPand['href']?.toString());
          }
        }
      }
    }

    final oorspronkelijkBouwjaar =
        _findFirstValueByKeys(json, const ['oorspronkelijkBouwjaar', 'bouwjaar']);

    double? latitude;
    double? longitude;

    final wgsPoint = BagService._extractWgs84Point(json);
    if (wgsPoint != null) {
      latitude = wgsPoint['lat'];
      longitude = wgsPoint['lon'];
    } else {
      final rdPoint = BagService._extractRdPoint(json);
      if (rdPoint != null) {
        final converted = BagService._rdToWgs84(
          x: rdPoint['x']!,
          y: rdPoint['y']!,
        );
        latitude = converted['lat'];
        longitude = converted['lon'];
      }
    }

    return BagData(
      adres: adres,
      huisnummer: huisnummer,
      huisletterHuisnummertoevoeging: huisletterHuisnummertoevoeging,
      postcode: postcode,
      plaatsnaam: plaatsnaam,
      bagIdentificatie: bagIdentificatie,
      bagAdresId: bagAdresId,
      adresseerbaarObjectId: adresseerbaarObjectId,
      bagPandId: bagPandId,
      oorspronkelijkBouwjaar: oorspronkelijkBouwjaar,
      gebruiksdoel: json['gebruiksdoel']?.toString(),
      latitude: latitude,
      longitude: longitude,
    );
  }

  BagData copyWith({
    String? adres,
    String? huisnummer,
    String? huisletterHuisnummertoevoeging,
    String? postcode,
    String? plaatsnaam,
    String? bagIdentificatie,
    String? bagAdresId,
    String? adresseerbaarObjectId,
    String? bagPandId,
    String? oorspronkelijkBouwjaar,
    String? gebruiksdoel,
    double? latitude,
    double? longitude,
  }) {
    return BagData(
      adres: adres ?? this.adres,
      huisnummer: huisnummer ?? this.huisnummer,
      huisletterHuisnummertoevoeging:
          huisletterHuisnummertoevoeging ?? this.huisletterHuisnummertoevoeging,
      postcode: postcode ?? this.postcode,
      plaatsnaam: plaatsnaam ?? this.plaatsnaam,
      bagIdentificatie: bagIdentificatie ?? this.bagIdentificatie,
      bagAdresId: bagAdresId ?? this.bagAdresId,
      adresseerbaarObjectId: adresseerbaarObjectId ?? this.adresseerbaarObjectId,
      bagPandId: bagPandId ?? this.bagPandId,
      oorspronkelijkBouwjaar: oorspronkelijkBouwjaar ?? this.oorspronkelijkBouwjaar,
      gebruiksdoel: gebruiksdoel ?? this.gebruiksdoel,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  /// Get album/folder name as "Adres Huisnummer Plaatsnaam Postcode".
  String getFolderName() {
    final parts = <String>[];

    final cleanAdres = (adres ?? '').trim();
    final cleanHuisnummer = (huisnummer ?? '').trim();
    final cleanToevoeging = (huisletterHuisnummertoevoeging ?? '').trim();
    final adresDeel = [cleanAdres, cleanHuisnummer, cleanToevoeging]
        .where((value) => value.isNotEmpty && value.toLowerCase() != 'unknown')
        .join(' ')
        .trim();
    if (adresDeel.isNotEmpty) {
      parts.add(adresDeel);
    }

    final cleanPlaats = plaatsnaam.trim();
    if (cleanPlaats.isNotEmpty && cleanPlaats.toLowerCase() != 'unknown') {
      parts.add(cleanPlaats);
    }

    final cleanPostcode = postcode.trim();
    if (cleanPostcode.isNotEmpty &&
        cleanPostcode != '-' &&
        cleanPostcode.toLowerCase() != 'unknown') {
      parts.add(cleanPostcode);
    }

    final value = parts.isEmpty ? 'Onbekend adres' : parts.join(' ');
    return value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  /// Dossier-mapnaam voor Nextcloud: "postcode straat huisnummer(toevoeging)".
  /// Postcode voorop (sorteren), daarachter het herkenbare adres.
  String getNextcloudDossierName() {
    final pc = postcode.trim();
    final straat = (adres ?? '').trim();
    final hnr = (huisnummer ?? '').trim();
    final toev = (huisletterHuisnummertoevoeging ?? '').trim();
    final nummer = [hnr, toev].where((s) => s.isNotEmpty).join('');
    final adresDeel = [straat, nummer].where((s) => s.isNotEmpty).join(' ').trim();
    final name = [pc, adresDeel].where((s) => s.isNotEmpty).join(' ').trim();
    final value = name.isEmpty ? getFolderName() : name;
    return value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  String _normalizedPostcodeForFiles() {
    final value = postcode.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (value.isEmpty || value == '-' || value == 'UNKNOWN') {
      return 'ONBEKEND';
    }
    return value;
  }

  String _normalizedHouseNumberForFiles() {
    final number = (huisnummer ?? '').trim();
    final addition = (huisletterHuisnummertoevoeging ?? '').trim();
    final joined = '$number$addition'
        .replaceAll(RegExp(r'\s+'), '')
        .toUpperCase();
    if (joined.isEmpty || joined == '-' || joined == 'UNKNOWN') {
      return '0';
    }
    return joined;
  }

  /// Key for per-address photo counters (postcode + huisnummer[+toevoeging]).
  String getPhotoCounterScope() {
    final postcodePart = _normalizedPostcodeForFiles();
    final housePart = _normalizedHouseNumberForFiles();
    return '${postcodePart}_$housePart';
  }

  /// Filename prefix for photos.
  String getPhotoFilePrefix() {
    return getPhotoCounterScope();
  }
}

/// Simple BAG client helpers.
///
/// Configure `baseUrl` to your BAG endpoint. Set `useQueryApiKey` to true
/// if your provider expects the API key in the query string.
class BagService {
  /// The BAG endpoint base URL (without query parameters).
  static String baseUrl =
      'https://api.bag.kadaster.nl/lvbag/individuelebevragingen/v2';

  /// If true, send the API key using the `api_key` query parameter.
  static bool useQueryApiKey = true;

  static String _normalizeHuisnummertoevoeging(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('-', '')
        .toLowerCase();
  }

  static Future<BagData> resolveBagDataForExport({
    required BagData bagData,
    required String apiKey,
  }) async {
    var resolved = bagData;

    try {
      resolved = await _enrichWithPandBouwjaarIfNeeded(
        bagData: resolved,
        apiKey: apiKey,
      );
    } catch (_) {}

    final needsBouwjaar = !_isValidBouwjaar(resolved.oorspronkelijkBouwjaar);
    final hasAddressLookupInput =
        resolved.postcode.trim().isNotEmpty &&
        (resolved.huisnummer ?? '').trim().isNotEmpty;

    if (needsBouwjaar && hasAddressLookupInput) {
      try {
        final lookedUp = await lookupByAddress(
          resolved.postcode,
          (resolved.huisnummer ?? '').trim(),
          apiKey,
        );

        resolved = resolved.copyWith(
          bagPandId: (resolved.bagPandId ?? '').trim().isNotEmpty
              ? resolved.bagPandId
              : lookedUp.bagPandId,
          bagAdresId: (resolved.bagAdresId ?? '').trim().isNotEmpty
              ? resolved.bagAdresId
              : lookedUp.bagAdresId,
          bagIdentificatie: (resolved.bagIdentificatie ?? '').trim().isNotEmpty
              ? resolved.bagIdentificatie
              : lookedUp.bagIdentificatie,
          adresseerbaarObjectId:
              (resolved.adresseerbaarObjectId ?? '').trim().isNotEmpty
                  ? resolved.adresseerbaarObjectId
                  : lookedUp.adresseerbaarObjectId,
          oorspronkelijkBouwjaar: _isValidBouwjaar(resolved.oorspronkelijkBouwjaar)
              ? resolved.oorspronkelijkBouwjaar
              : lookedUp.oorspronkelijkBouwjaar,
          gebruiksdoel: (resolved.gebruiksdoel ?? '').trim().isNotEmpty
              ? resolved.gebruiksdoel
              : lookedUp.gebruiksdoel,
        );
      } catch (_) {}
    }

    return resolved;
  }

  /// Genereert een BAG PDF op basis van gecombineerde endpoint-data.
  ///
  /// Er wordt data gecombineerd uit panden/nummeraanduidingen/openbareruimten
  /// en vervolgens een PDF gegenereerd met samenvatting + JSON payload.
  static Future<File> downloadBagPdfForDossier({
    required String apiKey,
    required String dossierName,
    required BagData bagData,
  }) async {
    final safeDossierName = _sanitizeName(dossierName);
    final baseDir = await getApplicationDocumentsDirectory();
    final dossierDir = Directory('${baseDir.path}/dossiers/$safeDossierName');
    await dossierDir.create(recursive: true);
    final file = File(
      '${dossierDir.path}/bag_kaart_export_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    try {
    var resolvedBagData = bagData;
    try {
      resolvedBagData = await _enrichWithPandBouwjaarIfNeeded(
        bagData: resolvedBagData,
        apiKey: apiKey,
      );
    } catch (_) {}

    if ((resolvedBagData.bagPandId ?? '').trim().isEmpty ||
        !_isValidBouwjaar(resolvedBagData.oorspronkelijkBouwjaar)) {
      try {
        final lookedUp = await lookupByAddress(
          resolvedBagData.postcode,
          (resolvedBagData.huisnummer ?? '').trim(),
          apiKey,
        );
        resolvedBagData = resolvedBagData.copyWith(
          bagPandId: (resolvedBagData.bagPandId ?? '').trim().isNotEmpty
              ? resolvedBagData.bagPandId
              : lookedUp.bagPandId,
          bagAdresId: (resolvedBagData.bagAdresId ?? '').trim().isNotEmpty
              ? resolvedBagData.bagAdresId
              : lookedUp.bagAdresId,
          bagIdentificatie: (resolvedBagData.bagIdentificatie ?? '').trim().isNotEmpty
              ? resolvedBagData.bagIdentificatie
              : lookedUp.bagIdentificatie,
          adresseerbaarObjectId:
              (resolvedBagData.adresseerbaarObjectId ?? '').trim().isNotEmpty
                  ? resolvedBagData.adresseerbaarObjectId
                  : lookedUp.adresseerbaarObjectId,
          oorspronkelijkBouwjaar:
              _isValidBouwjaar(resolvedBagData.oorspronkelijkBouwjaar)
                  ? resolvedBagData.oorspronkelijkBouwjaar
                  : lookedUp.oorspronkelijkBouwjaar,
          gebruiksdoel: (resolvedBagData.gebruiksdoel ?? '').trim().isNotEmpty
              ? resolvedBagData.gebruiksdoel
              : lookedUp.gebruiksdoel,
        );
      } catch (_) {}
    }

    var cleanPandId = (resolvedBagData.bagPandId ?? '').trim();
    String? cleanNummeraanduidingId = (resolvedBagData.bagAdresId ?? '').trim();
    String? cleanAdresseerbaarObjectId = (resolvedBagData.adresseerbaarObjectId ?? '').trim();
    String? cleanOpenbareRuimteId;

    final cleanBagIdentificatie = (resolvedBagData.bagIdentificatie ?? '').trim();
    final cleanBagAdresId = (resolvedBagData.bagAdresId ?? '').trim();

    if (cleanPandId.isEmpty) {
      final adresIdForChain = cleanBagAdresId.isNotEmpty
          ? cleanBagAdresId
          : cleanBagIdentificatie;
      if (adresIdForChain.isNotEmpty) {
        final resolved = await _lookupPandIdViaAdresChain(
          adresId: adresIdForChain,
          apiKey: apiKey,
        );
        if (resolved != null && resolved.trim().isNotEmpty) {
          cleanPandId = resolved.trim();
        }
      }
    }


    final gecombineerdeJson = <String, dynamic>{};

    final addressIdsToTry = <String>{
      if (cleanBagAdresId.isNotEmpty) cleanBagAdresId,
      if (cleanBagIdentificatie.isNotEmpty) cleanBagIdentificatie,
    };

    for (final addressId in addressIdsToTry) {
      final adresObject = await _requestBagObject(
        path: 'adressen/$addressId',
        apiKey: apiKey,
        extraQueryParameters: const {'expand': 'true'},
      );
      if (adresObject != null) {
        gecombineerdeJson['adressen_$addressId'] = adresObject;
        cleanNummeraanduidingId ??= _extractFirstLinkedId(
          adresObject,
          const ['nummeraanduiding', 'nummeraanduidingen'],
        );
        cleanAdresseerbaarObjectId ??=
            _findFirstValueByKeys(adresObject, const [
              'adresseerbaarObjectIdentificatie',
              'adresseerbaarobjectIdentificatie',
              'adresseerbaar_object_identificatie',
            ])
                ?.trim();
      }
    }

    if (cleanPandId.isNotEmpty) {
      final pandDebug = await _probePandEndpointStatuses(
        pandId: cleanPandId,
        apiKey: apiKey,
      );
      if (pandDebug.trim().isNotEmpty) {
        gecombineerdeJson['_pandEndpointDebug'] = pandDebug;
      }

      final pandObject = await _requestPandById(
        pandId: cleanPandId,
        apiKey: apiKey,
      );
      if (pandObject != null) {
        gecombineerdeJson['panden'] = pandObject;

        final pandBouwjaar = _extractBouwjaarFromPandObject(pandObject);
        if (_isValidBouwjaar(pandBouwjaar)) {
          resolvedBagData = resolvedBagData.copyWith(
            oorspronkelijkBouwjaar: pandBouwjaar,
          );
        }
      }

      if (!_isValidBouwjaar(resolvedBagData.oorspronkelijkBouwjaar)) {
        final pandBouwjaar = await _lookupPandBouwjaar(
          pandId: cleanPandId,
          apiKey: apiKey,
        );
        if (_isValidBouwjaar(pandBouwjaar)) {
          resolvedBagData = resolvedBagData.copyWith(
            oorspronkelijkBouwjaar: pandBouwjaar,
          );
        }
      }
    }

    if ((cleanNummeraanduidingId ?? '').isNotEmpty) {
      final nummeraanduidingObject = await _requestBagObject(
        path: 'nummeraanduidingen/$cleanNummeraanduidingId',
        apiKey: apiKey,
      );
      if (nummeraanduidingObject != null) {
        gecombineerdeJson['nummeraanduidingen'] = nummeraanduidingObject;
        cleanOpenbareRuimteId = _extractFirstLinkedId(
          nummeraanduidingObject,
          const ['openbareRuimte', 'openbareruimte', 'openbareruimten'],
        );
        cleanAdresseerbaarObjectId ??= _extractFirstLinkedId(
          nummeraanduidingObject,
          const [
            'adresseerbareObjecten',
            'adresseerbareobjecten',
            'adresseerbaarobjecten',
            'verblijfsobjecten',
          ],
        );
      }
    }

    if ((cleanAdresseerbaarObjectId ?? '').isNotEmpty) {
      final objId = cleanAdresseerbaarObjectId!.trim();
      final endpointCandidates = const [
        'adresseerbareobjecten',
        'adresseerbaarobjecten',
        'verblijfsobjecten',
      ];
      for (final endpoint in endpointCandidates) {
        final object = await _requestBagObject(
          path: '$endpoint/$objId',
          apiKey: apiKey,
        );
        if (object != null) {
          gecombineerdeJson[endpoint] = object;
          break;
        }
      }
    }

    if ((cleanOpenbareRuimteId ?? '').isNotEmpty) {
      final openbareruimteObject = await _requestBagObject(
        path: 'openbareruimten/$cleanOpenbareRuimteId',
        apiKey: apiKey,
      );
      if (openbareruimteObject != null) {
        gecombineerdeJson['openbareruimten'] = openbareruimteObject;
      }
    }

    final payload = _buildPdfPayload(
      bagData: resolvedBagData,
      combined: gecombineerdeJson,
    );

    await _writePdfFromPayload(
      outputFile: file,
      dossierName: dossierName,
      payload: payload,
      rawCombinedJson: gecombineerdeJson,
    );
    return file;
    } catch (error) {
      final fallbackPayload = <String, dynamic>{
        'adres': [
          (bagData.adres ?? '').trim(),
          (bagData.huisnummer ?? '').trim(),
          (bagData.huisletterHuisnummertoevoeging ?? '').trim(),
        ].where((part) => part.isNotEmpty).join(' ').trim().isEmpty
            ? 'Onbekend'
            : [
                (bagData.adres ?? '').trim(),
                (bagData.huisnummer ?? '').trim(),
                (bagData.huisletterHuisnummertoevoeging ?? '').trim(),
              ].where((part) => part.isNotEmpty).join(' ').trim(),
        'status': 'Fallback PDF gegenereerd',
        'fout': error.toString(),
        'postcode': bagData.postcode,
        'plaatsnaam': bagData.plaatsnaam,
        'bagPandId': bagData.bagPandId,
        'bagAdresId': bagData.bagAdresId,
        'bagIdentificatie': bagData.bagIdentificatie,
      };

      await _writePdfFromPayload(
        outputFile: file,
        dossierName: dossierName,
        payload: fallbackPayload,
        rawCombinedJson: {
          'error': error.toString(),
        },
      );
      return file;
    }
  }

  static Map<String, dynamic> _buildPdfPayload({
    required BagData bagData,
    required Map<String, dynamic> combined,
  }) {
    final pandObject = combined['panden'];
    final nummeraanduidingObject = combined['nummeraanduidingen'];
    final openbareruimteObject = combined['openbareruimten'];
    final adresseerbaarObject =
      combined['verblijfsobjecten'] ??
      combined['adresseerbareobjecten'] ??
      combined['adresseerbaarobjecten'];

    final addressText = [
      (bagData.adres ?? '').trim(),
      (bagData.huisnummer ?? '').trim(),
      (bagData.huisletterHuisnummertoevoeging ?? '').trim(),
    ].where((part) => part.isNotEmpty).join(' ').trim();

    String? resolveValidBouwjaar(dynamic source) {
      final yearKeys = <String>[
        'oorspronkelijkBouwjaar',
        'oorspronkelijkbouwjaar',
        'bouwjaar',
      ];
      for (final key in yearKeys) {
        final candidate = _findFirstValueByKeys(source, [key])?.trim();
        if (_isValidBouwjaar(candidate)) {
          return candidate;
        }
      }
      return _extractFirstValidBouwjaarDeep(source);
    }

    final pandBouwjaarHard = _extractBouwjaarFromPandObject(pandObject);

    final bouwjaarFromBagData = (_isValidBouwjaar(bagData.oorspronkelijkBouwjaar)
      ? bagData.oorspronkelijkBouwjaar!.trim()
      : null);
    final bouwjaarFromPand = pandBouwjaarHard ?? resolveValidBouwjaar(pandObject);
    final bouwjaarFromNummeraanduiding = resolveValidBouwjaar(nummeraanduidingObject);
    final bouwjaarFromCombined = resolveValidBouwjaar(combined);

    final bouwjaarText =
      bouwjaarFromBagData ??
      bouwjaarFromPand ??
      bouwjaarFromNummeraanduiding ??
      bouwjaarFromCombined ??
      'Onbekend';

    final bouwjaarBron = bouwjaarFromBagData != null
      ? 'bagData'
      : (bouwjaarFromPand != null
        ? 'pand'
        : (bouwjaarFromNummeraanduiding != null
          ? 'nummeraanduiding'
          : (bouwjaarFromCombined != null ? 'combined' : 'onbekend')));

    final rdPoint = _extractRdPoint([
      pandObject,
      nummeraanduidingObject,
      openbareruimteObject,
      combined,
    ]);

    final wgsPoint = rdPoint == null
        ? null
        : _rdToWgs84(
            x: rdPoint['x']!,
            y: rdPoint['y']!,
          );

    final kaartUrl = wgsPoint == null
        ? null
        : Uri.https('staticmap.openstreetmap.de', '/staticmap.php', {
            'center': '${wgsPoint['lat']},${wgsPoint['lon']}',
            'zoom': '19',
            'size': '1200x700',
            'markers': '${wgsPoint['lat']},${wgsPoint['lon']},red-pushpin',
          }).toString();

    final oppervlakteText =
        _findFirstValueByKeys(
              adresseerbaarObject,
              const [
                'oppervlakte',
                'gebruiksoppervlakte',
                'oppervlakteObject',
                'oppervlakteverblijfsobject',
              ],
            )
            ?.trim() ??
        _findFirstValueByKeys(
              nummeraanduidingObject,
              const [
                'oppervlakte',
                'gebruiksoppervlakte',
                'oppervlakteObject',
                'oppervlakteverblijfsobject',
              ],
            )
            ?.trim() ??
        _findFirstValueByKeys(
              pandObject,
              const ['oppervlakte', 'gebruiksoppervlakte'],
            )
            ?.trim() ??
        'Onbekend';

    final statusText = (bagData.gebruiksdoel ?? '').trim().isNotEmpty
        ? (bagData.gebruiksdoel ?? '').trim()
        : (_findFirstValueByKeys(
              adresseerbaarObject,
              const [
                'status',
                'statusOmschrijving',
                'statusNaam',
                'gebruiksdoel',
                'gebruiksdoelen',
              ],
            )
                ?.trim() ??
            _findFirstValueByKeys(
              nummeraanduidingObject,
              const [
                'status',
                'statusOmschrijving',
                'statusNaam',
                'gebruiksdoel',
                'gebruiksdoelen',
              ],
            )
                ?.trim() ??
            _findFirstValueByKeys(
              pandObject,
              const ['status', 'statusOmschrijving', 'statusNaam'],
            )
                ?.trim() ??
            'Onbekend');

    final payload = <String, dynamic>{
      'adres': addressText.isEmpty ? 'Onbekend' : addressText,
      'bouwjaar': int.tryParse(bouwjaarText) ?? bouwjaarText,
      'oppervlakte': int.tryParse(oppervlakteText) ?? oppervlakteText,
      'status': statusText,
      'postcode': bagData.postcode,
      'plaatsnaam': bagData.plaatsnaam,
      'bagPandId': bagData.bagPandId,
      'bagAdresId': bagData.bagAdresId,
      'bagIdentificatie': bagData.bagIdentificatie,
      'kaartUrl': kaartUrl,
      'bouwjaarBron': bouwjaarBron,
      'pandEndpointDebug': combined['_pandEndpointDebug'],
      'rdX': rdPoint?['x']?.round(),
      'rdY': rdPoint?['y']?.round(),
      'lat': wgsPoint?['lat'],
      'lon': wgsPoint?['lon'],
      'endpointSamenvatting': {
        'panden': pandObject != null,
        'nummeraanduidingen': nummeraanduidingObject != null,
        'openbareruimten': openbareruimteObject != null,
      },
    };

    return payload;
  }

  static Future<void> _writePdfFromPayload({
    required File outputFile,
    required String dossierName,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> rawCombinedJson,
  }) async {
    final doc = pw.Document();
    var effectiveLat = _toDouble(payload['lat']);
    var effectiveLon = _toDouble(payload['lon']);
    var kaartUrl = payload['kaartUrl']?.toString();
    if (kaartUrl == null || kaartUrl.trim().isEmpty) {
      final geocoded = await _geocodeAddressToWgs84(
        adres: payload['adres']?.toString() ?? '',
        postcode: payload['postcode']?.toString() ?? '',
        plaatsnaam: payload['plaatsnaam']?.toString() ?? '',
      );
      if (geocoded != null) {
        effectiveLat ??= geocoded['lat'];
        effectiveLon ??= geocoded['lon'];
        kaartUrl = Uri.https('staticmap.openstreetmap.de', '/staticmap.php', {
          'center': '${geocoded['lat']},${geocoded['lon']}',
          'zoom': '19',
          'size': '1200x700',
          'markers': '${geocoded['lat']},${geocoded['lon']},red-pushpin',
        }).toString();
      }
    }

    if (kaartUrl == null || kaartUrl.trim().isEmpty) {
      final query = [
        payload['adres']?.toString() ?? '',
        payload['postcode']?.toString() ?? '',
        payload['plaatsnaam']?.toString() ?? '',
      ].where((part) => part.trim().isNotEmpty).join(' ');
      if (query.isNotEmpty) {
        kaartUrl = Uri.https(
          'www.openstreetmap.org',
          '/search',
          {'query': query},
        ).toString();
      }
    }

    if ((kaartUrl == null || kaartUrl.trim().isEmpty) &&
        (payload['bagPandId']?.toString() ?? '').trim().isNotEmpty) {
      kaartUrl =
          'https://bagviewer.kadaster.nl/lvbag/bag-viewer/?searchQuery=${Uri.encodeQueryComponent(payload['bagPandId'].toString())}';
    }

    final mapImageBytes = await _downloadMapImageBytes(
      kaartUrl,
      lat: effectiveLat,
      lon: effectiveLon,
      preferSatellite: false,
    );

    final satelliteImageBytes = await _downloadMapImageBytes(
      null,
      lat: effectiveLat,
      lon: effectiveLon,
      preferSatellite: true,
    );

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, text: 'BAG kaart/PDF rapport'),
          pw.Text('Dossier: $dossierName'),
          pw.SizedBox(height: 8),
          pw.Text('Samenvatting', style: pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 4),
          pw.Text('Adres: ${payload['adres'] ?? '-'}'),
          pw.Text('Bouwjaar: ${payload['bouwjaar'] ?? '-'}'),
          if ((payload['pandEndpointDebug']?.toString() ?? '').trim().isNotEmpty)
            pw.Text('Pand endpoint debug: ${payload['pandEndpointDebug']}'),
          pw.Text('Oppervlakte: ${payload['oppervlakte'] ?? '-'}'),
          pw.Text('Status: ${payload['status'] ?? '-'}'),
          if ((payload['bagPandId']?.toString() ?? '').trim().isNotEmpty)
            pw.Text('Pand ID: ${payload['bagPandId']}'),
          if ((payload['bagAdresId']?.toString() ?? '').trim().isNotEmpty)
            pw.Text('Adres ID: ${payload['bagAdresId']}'),
          if ((payload['rdX']?.toString() ?? '').trim().isNotEmpty &&
              (payload['rdY']?.toString() ?? '').trim().isNotEmpty)
            pw.Text('RD coördinaten: X=${payload['rdX']} Y=${payload['rdY']}'),
          if ((kaartUrl ?? '').trim().isNotEmpty)
            pw.UrlLink(
              destination: kaartUrl!,
              child: pw.Text(
                'Open kaart in browser',
                style: pw.TextStyle(
                  decoration: pw.TextDecoration.underline,
                ),
              ),
            ),
          pw.SizedBox(height: 10),
          if (mapImageBytes != null)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Kaartweergave', style: pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 4),
                pw.Image(
                  pw.MemoryImage(mapImageBytes),
                  height: 240,
                  fit: pw.BoxFit.contain,
                ),
              ],
            )
          else
            pw.Text('Kaart niet beschikbaar voor dit BAG-object.'),
          pw.SizedBox(height: 10),
          if (satelliteImageBytes != null)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Luchtfoto', style: pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 4),
                pw.Image(
                  pw.MemoryImage(satelliteImageBytes),
                  height: 240,
                  fit: pw.BoxFit.contain,
                ),
              ],
            )
          else
            pw.Text('Luchtfoto niet beschikbaar voor dit BAG-object.'),
          pw.SizedBox(height: 12),
          pw.Text(
            'BAG-data gecontroleerd via pand/nummeraanduiding/openbareruimte endpoints.',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );

    await outputFile.writeAsBytes(await doc.save(), flush: true);
  }

  static Future<Uint8List?> _downloadMapImageBytes(
    String? url, {
    double? lat,
    double? lon,
    bool preferSatellite = false,
  }) async {
    if (url == null || url.trim().isEmpty) {
      if (lat == null || lon == null) {
        return null;
      }
    }

    Future<Uint8List?> tryGet(Uri uri, {Map<String, String>? headers}) async {
      try {
        final resp = await http.get(uri, headers: headers);
        if (resp.statusCode == 200 &&
            resp.bodyBytes.isNotEmpty &&
            _isImageHttpResponse(resp)) {
          return resp.bodyBytes;
        }
      } catch (_) {}
      return null;
    }

    try {
      if (!preferSatellite && url != null && url.trim().isNotEmpty) {
        final uri = Uri.tryParse(url.trim());
        if (uri != null) {
          final direct = await tryGet(
            uri,
            headers: const {
              'User-Agent': 'photo_organizer_app/1.0 (BAG PDF map)',
            },
          );
          if (direct != null) {
            return direct;
          }
        }
      }

      if (lat == null || lon == null) {
        return null;
      }

      if (!preferSatellite) {
        final composite = await _buildOsmTileComposite(
          lat: lat,
          lon: lon,
          zoom: 19,
          radius: 1,
        );
        if (composite != null) {
          return composite;
        }
      }

      final yandexSatelliteUri = Uri.https('static-maps.yandex.ru', '/1.x/', {
        'll': '$lon,$lat',
        'z': '19',
        'l': 'sat,skl',
        'size': '650,450',
        'pt': '$lon,$lat,pm2rdm',
      });

      if (preferSatellite) {
        final satellite = await tryGet(
          yandexSatelliteUri,
          headers: const {
            'User-Agent': 'photo_organizer_app/1.0 (BAG PDF map)',
          },
        );
        if (satellite != null) {
          return satellite;
        }
      }

      final staticOsmUri = Uri.https('staticmap.openstreetmap.de', '/staticmap.php', {
        'center': '$lat,$lon',
        'zoom': '19',
        'size': '1200x700',
        'markers': '$lat,$lon,red-pushpin',
      });
      final staticOsm = await tryGet(
        staticOsmUri,
        headers: const {
          'User-Agent': 'photo_organizer_app/1.0 (BAG PDF map)',
        },
      );
      if (staticOsm != null) {
        return staticOsm;
      }

      final yandexUri = Uri.https('static-maps.yandex.ru', '/1.x/', {
        'll': '$lon,$lat',
        'z': '18',
        'l': 'map',
        'size': '650,450',
        'pt': '$lon,$lat,pm2rdm',
      });
      final yandex = await tryGet(
        yandexUri,
        headers: const {
          'User-Agent': 'photo_organizer_app/1.0 (BAG PDF map)',
        },
      );
      if (yandex != null) {
        return yandex;
      }

      if (!preferSatellite) {
        final yandexSatelliteFallback = await tryGet(
          yandexSatelliteUri,
          headers: const {
            'User-Agent': 'photo_organizer_app/1.0 (BAG PDF map)',
          },
        );
        if (yandexSatelliteFallback != null) {
          return yandexSatelliteFallback;
        }
      }

      final zoom = 19;
      final tileX = ((lon + 180.0) / 360.0 * pow(2.0, zoom)).floor();
      final tileY =
          ((1.0 - log(tan(lat * pi / 180.0) + 1 / cos(lat * pi / 180.0)) / pi) /
                  2.0 *
                  pow(2.0, zoom))
              .floor();

      final tileUri = Uri.https(
        'tile.openstreetmap.org',
        '/$zoom/$tileX/$tileY.png',
      );
      return await tryGet(
        tileUri,
        headers: const {
          'User-Agent': 'photo_organizer_app/1.0 (BAG PDF map)',
        },
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _buildOsmTileComposite({
    required double lat,
    required double lon,
    required int zoom,
    int radius = 1,
  }) async {
    try {
      const tileSize = 256;
      final sideCount = radius * 2 + 1;
      final canvas = img.Image(
        tileSize * sideCount,
        tileSize * sideCount,
      );

      final n = pow(2.0, zoom).toDouble();
      final centerTileX = ((lon + 180.0) / 360.0 * n).floor();
      final centerTileY =
          ((1.0 - log(tan(lat * pi / 180.0) + 1 / cos(lat * pi / 180.0)) / pi) /
                  2.0 *
                  n)
              .floor();

      var loadedTiles = 0;
      for (var dy = -radius; dy <= radius; dy++) {
        for (var dx = -radius; dx <= radius; dx++) {
          final tx = centerTileX + dx;
          final ty = centerTileY + dy;
          if (tx < 0 || ty < 0 || tx >= n || ty >= n) {
            continue;
          }

          final tileUri = Uri.https(
            'tile.openstreetmap.org',
            '/$zoom/$tx/$ty.png',
          );

          final resp = await http.get(
            tileUri,
            headers: const {
              'User-Agent': 'photo_organizer_app/1.0 (BAG PDF map)',
            },
          );

          if (resp.statusCode != 200 ||
              resp.bodyBytes.isEmpty ||
              !_isImageHttpResponse(resp)) {
            continue;
          }

          final tileImage = img.decodeImage(resp.bodyBytes);
          if (tileImage == null) {
            continue;
          }

          img.copyInto(
            canvas,
            tileImage,
            dstX: (dx + radius) * tileSize,
            dstY: (dy + radius) * tileSize,
          );
          loadedTiles++;
        }
      }

      if (loadedTiles == 0) {
        return null;
      }

      final centerPx = canvas.width ~/ 2;
      final centerPy = canvas.height ~/ 2;
      img.fillCircle(canvas, centerPx, centerPy, 8, img.getColor(220, 20, 60));
      img.drawCircle(canvas, centerPx, centerPy, 10, img.getColor(255, 255, 255));

      return Uint8List.fromList(img.encodePng(canvas));
    } catch (_) {
      return null;
    }
  }

  static bool _isImageHttpResponse(http.Response response) {
    final contentType =
        (response.headers['content-type'] ?? '').toLowerCase().trim();
    if (contentType.startsWith('image/')) {
      return true;
    }
    return _looksLikeImageBytes(response.bodyBytes);
  }

  static bool _looksLikeImageBytes(Uint8List bytes) {
    if (bytes.length < 4) {
      return false;
    }

    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;

    final isJpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;

    final isGif =
        bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38;

    final isWebp =
        bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;

    return isPng || isJpeg || isGif || isWebp;
  }

  static String? _extractBouwjaarFromPandObject(dynamic pandObject) {
    if (pandObject == null) {
      return null;
    }

    String? candidate;

    candidate = _toPathString(pandObject, const ['oorspronkelijkBouwjaar']);
    if (_isValidBouwjaar(candidate)) {
      return candidate!.trim();
    }

    candidate = _toPathString(
      pandObject,
      const ['pand', 'oorspronkelijkBouwjaar'],
    );
    if (_isValidBouwjaar(candidate)) {
      return candidate!.trim();
    }

    candidate = _toPathString(
      pandObject,
      const ['_embedded', 'panden', 0, 'oorspronkelijkBouwjaar'],
    );
    if (_isValidBouwjaar(candidate)) {
      return candidate!.trim();
    }

    candidate = _toPathString(pandObject, const ['bouwjaar']);
    if (_isValidBouwjaar(candidate)) {
      return candidate!.trim();
    }

    candidate = _extractFirstValidBouwjaarDeep(pandObject);
    if (_isValidBouwjaar(candidate)) {
      return candidate!.trim();
    }

    return null;
  }

  static String? _toPathString(dynamic source, List<dynamic> path) {
    dynamic current = source;
    for (final segment in path) {
      if (current is Map && segment is String) {
        current = current[segment];
        continue;
      }
      if (current is List && segment is int) {
        if (segment < 0 || segment >= current.length) {
          return null;
        }
        current = current[segment];
        continue;
      }
      return null;
    }
    if (current == null) {
      return null;
    }
    return current.toString();
  }

  static Future<Map<String, double>?> _geocodeAddressToWgs84({
    required String adres,
    required String postcode,
    required String plaatsnaam,
  }) async {
    final queryCandidates = <String>{
      [adres.trim(), postcode.trim(), plaatsnaam.trim(), 'Nederland']
          .where((part) => part.isNotEmpty)
          .join(' '),
      [adres.trim(), plaatsnaam.trim(), 'Nederland']
          .where((part) => part.isNotEmpty)
          .join(' '),
      [postcode.trim(), plaatsnaam.trim(), 'Nederland']
          .where((part) => part.isNotEmpty)
          .join(' '),
    }.where((q) => q.trim().isNotEmpty).toSet();

    for (final query in queryCandidates) {
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
          'q': query,
          'format': 'jsonv2',
          'limit': '1',
          'countrycodes': 'nl',
        });
        final resp = await http.get(
          uri,
          headers: const {
            'User-Agent': 'photo_organizer_app/1.0 (BAG PDF geocoder)',
            'Accept-Language': 'nl-NL,nl;q=0.9,en;q=0.8',
          },
        );
        if (resp.statusCode != 200) {
          continue;
        }
        final decoded = json.decode(resp.body);
        if (decoded is! List || decoded.isEmpty) {
          continue;
        }
        final first = decoded.first;
        if (first is! Map) {
          continue;
        }
        final lat = _toDouble(first['lat']);
        final lon = _toDouble(first['lon']);
        if (lat == null || lon == null) {
          continue;
        }
        return {'lat': lat, 'lon': lon};
      } catch (_) {}
    }

    return null;
  }

  static Map<String, double>? _extractRdPoint(dynamic source) {
    if (source is List) {
      for (final item in source) {
        final found = _extractRdPoint(item);
        if (found != null) {
          return found;
        }
      }
      return null;
    }

    if (source is Map<String, dynamic>) {
      final x = _toDouble(source['x']);
      final y = _toDouble(source['y']);
      if (_looksLikeRd(x, y)) {
        return {'x': x!, 'y': y!};
      }

      final point = source['point'];
      if (point is Map<String, dynamic>) {
        final px = _toDouble(point['x']);
        final py = _toDouble(point['y']);
        if (_looksLikeRd(px, py)) {
          return {'x': px!, 'y': py!};
        }
      }

      final coordinates = source['coordinates'];
      if (coordinates is List && coordinates.length >= 2) {
        final cx = _toDouble(coordinates[0]);
        final cy = _toDouble(coordinates[1]);
        if (_looksLikeRd(cx, cy)) {
          return {'x': cx!, 'y': cy!};
        }
      }

      for (final value in source.values) {
        final found = _extractRdPoint(value);
        if (found != null) {
          return found;
        }
      }
    }

    return null;
  }

  static Map<String, double>? _extractWgs84Point(dynamic source) {
    if (source is List) {
      for (final item in source) {
        final found = _extractWgs84Point(item);
        if (found != null) {
          return found;
        }
      }
      return null;
    }

    if (source is Map<String, dynamic>) {
      final lat = _toDouble(source['lat']) ?? _toDouble(source['latitude']);
      final lon = _toDouble(source['lon']) ?? _toDouble(source['lng']) ?? _toDouble(source['longitude']);
      if (_looksLikeWgs84(lat, lon)) {
        return {'lat': lat!, 'lon': lon!};
      }

      final point = source['point'];
      if (point is Map<String, dynamic>) {
        final pLat = _toDouble(point['lat']) ?? _toDouble(point['latitude']) ?? _toDouble(point['y']);
        final pLon = _toDouble(point['lon']) ?? _toDouble(point['lng']) ?? _toDouble(point['longitude']) ?? _toDouble(point['x']);
        if (_looksLikeWgs84(pLat, pLon)) {
          return {'lat': pLat!, 'lon': pLon!};
        }
      }

      final coordinates = source['coordinates'];
      if (coordinates is List && coordinates.length >= 2) {
        final first = _toDouble(coordinates[0]);
        final second = _toDouble(coordinates[1]);

        // GeoJSON uses [lon, lat]. Some payloads use [lat, lon].
        if (_looksLikeWgs84(second, first)) {
          return {'lat': second!, 'lon': first!};
        }
        if (_looksLikeWgs84(first, second)) {
          return {'lat': first!, 'lon': second!};
        }
      }

      for (final value in source.values) {
        final found = _extractWgs84Point(value);
        if (found != null) {
          return found;
        }
      }
    }

    return null;
  }

  static bool _looksLikeRd(double? x, double? y) {
    if (x == null || y == null) {
      return false;
    }
    return x >= 0 && x <= 300000 && y >= 300000 && y <= 650000;
  }

  static bool _looksLikeWgs84(double? lat, double? lon) {
    if (lat == null || lon == null) {
      return false;
    }
    return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180;
  }

  static double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static Map<String, double> _rdToWgs84({
    required double x,
    required double y,
  }) {
    final dx = (x - 155000.0) / 100000.0;
    final dy = (y - 463000.0) / 100000.0;

    final lat = 52.15517440 +
        (3235.65389 * dy +
                -32.58297 * pow(dx, 2) +
                -0.2475 * pow(dy, 2) +
                -0.84978 * pow(dx, 2) * dy +
                -0.0655 * pow(dy, 3) +
                -0.01709 * pow(dx, 2) * pow(dy, 2) +
                -0.00738 * dx +
                0.0053 * pow(dx, 4) +
                -0.00039 * pow(dx, 2) * pow(dy, 3) +
                0.00033 * pow(dx, 4) * dy +
                -0.00012 * dx * dy) /
            3600.0;

    final lon = 5.38720621 +
        (5260.52916 * dx +
                105.94684 * dx * dy +
                2.45656 * dx * pow(dy, 2) +
                -0.81885 * pow(dx, 3) +
                0.05594 * dx * pow(dy, 3) +
                -0.05607 * pow(dx, 3) * dy +
                0.01199 * dy +
                -0.00256 * pow(dx, 3) * pow(dy, 2) +
                0.00128 * dx * pow(dy, 4) +
                0.00022 * pow(dy, 2) +
                -0.00022 * pow(dx, 2) +
                0.00026 * pow(dx, 5)) /
            3600.0;

    return {
      'lat': lat,
      'lon': lon,
    };
  }

  static String _sanitizeName(String raw) {
    final sanitized = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (sanitized.isEmpty) {
      return 'Onbekend_dossier';
    }
    return sanitized;
  }

  /// Lookup BAG address by [postcode]/[huisnummer] using [apiKey].
  static Future<BagData> lookupByAddress(
    String postcode,
    String huisnummer,
    String apiKey,
  ) async {
    final normalizedPostcode = postcode.replaceAll(' ', '').toUpperCase();
    final normalizedHuisnummer = huisnummer.trim();
    if (normalizedPostcode.isEmpty || normalizedHuisnummer.isEmpty) {
      throw Exception('Postcode of huisnummer ontbreekt voor BAG lookup');
    }

    final query = <String, String>{
      'postcode': normalizedPostcode,
      'huisnummer': normalizedHuisnummer,
      'exacteMatch': 'true',
    };
    if (useQueryApiKey) {
      query['api_key'] = apiKey;
    }

    final uri = Uri.parse('$baseUrl/adressen').replace(queryParameters: query);
    final headers = <String, String>{'Accept': 'application/hal+json'};
    if (!useQueryApiKey) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    headers['X-Api-Key'] = apiKey;

    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode != 200) {
      throw Exception('BAG request failed: ${resp.statusCode}');
    }

    final decoded = json.decode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Onverwachte BAG response');
    }

    final embedded = decoded['_embedded'];
    if (embedded is Map<String, dynamic>) {
      final adressen = embedded['adressen'];
      if (adressen is List && adressen.isNotEmpty) {
        final first = adressen.first;
        if (first is Map<String, dynamic>) {
          return _enrichWithPandBouwjaarIfNeeded(
            bagData: BagData.fromJson(first),
            apiKey: apiKey,
          );
        }
      }
    }

    final adressenTopLevel = decoded['adressen'];
    if (adressenTopLevel is List && adressenTopLevel.isNotEmpty) {
      final first = adressenTopLevel.first;
      if (first is Map<String, dynamic>) {
        return _enrichWithPandBouwjaarIfNeeded(
          bagData: BagData.fromJson(first),
          apiKey: apiKey,
        );
      }
    }

    return _enrichWithPandBouwjaarIfNeeded(
      bagData: BagData.fromJson(decoded),
      apiKey: apiKey,
    );
  }

  /// Lookup mogelijke BAG-adressen op basis van [postcode]/[huisnummer].
  ///
  /// Geeft meerdere kandidaten terug zodat de gebruiker handmatig kan kiezen,
  /// bijvoorbeeld bij appartementen waar GPS onnauwkeurig is.
  static Future<List<BagData>> lookupCandidatesByAddressExact(
    String postcode,
    String huisnummer,
    String apiKey, {
    String? huisnummertoevoeging,
  }) async {
    final normalizedPostcode = postcode.replaceAll(' ', '').toUpperCase();
    final normalizedHuisnummer = huisnummer.trim();
    if (normalizedPostcode.isEmpty || normalizedHuisnummer.isEmpty) {
      throw Exception('Postcode of huisnummer ontbreekt voor BAG lookup');
    }

    final rawAddresses = await _requestAddressRecords(
      postcode: normalizedPostcode,
      huisnummer: normalizedHuisnummer,
      apiKey: apiKey,
      exacteMatch: true,
    );

    final results = <BagData>[];
    final seenKeys = <String>{};
    for (final rawAddress in rawAddresses) {
      final bagData = BagData.fromJson(rawAddress);
      final key = [
        (bagData.bagAdresId ?? '').trim(),
        (bagData.bagIdentificatie ?? '').trim(),
        (bagData.adres ?? '').trim().toLowerCase(),
        (bagData.huisnummer ?? '').trim().toLowerCase(),
        (bagData.huisletterHuisnummertoevoeging ?? '').trim().toLowerCase(),
        bagData.postcode.trim().toUpperCase(),
        bagData.plaatsnaam.trim().toLowerCase(),
      ].join('|');
      if (seenKeys.add(key)) {
        results.add(bagData);
      }
    }

    if (results.isEmpty) {
      return const <BagData>[];
    }

    final normalizedToevoeging =
        _normalizeHuisnummertoevoeging(huisnummertoevoeging ?? '');
    if (normalizedToevoeging.isEmpty) {
      return results;
    }

    final filtered = results.where((item) {
      final itemToevoeging = _normalizeHuisnummertoevoeging(
        item.huisletterHuisnummertoevoeging ?? '',
      );
      return itemToevoeging == normalizedToevoeging;
    }).toList(growable: false);

    return filtered.isNotEmpty ? filtered : results;
  }

  static Future<List<BagData>> lookupCandidatesByAddress(
    String postcode,
    String huisnummer,
    String apiKey,
  ) async {
    final normalizedPostcode = postcode.replaceAll(' ', '').toUpperCase();
    final normalizedHuisnummer = huisnummer.trim();
    if (normalizedPostcode.isEmpty || normalizedHuisnummer.isEmpty) {
      throw Exception('Postcode of huisnummer ontbreekt voor BAG lookup');
    }

    // Keep lookup fast and deterministic: exact house number first,
    // then only a small numeric fallback range around it.
    final candidateHouseNumbers = <String>[];
    final seenHouseNumbers = <String>{};

    void addCandidate(String value) {
      final v = value.trim();
      if (v.isEmpty) {
        return;
      }
      if (seenHouseNumbers.add(v)) {
        candidateHouseNumbers.add(v);
      }
    }

    addCandidate(normalizedHuisnummer);
    final numericPart = RegExp(r'^\d+').stringMatch(normalizedHuisnummer) ?? '';
    final parsedNumeric = int.tryParse(numericPart);
    if (parsedNumeric != null) {
      addCandidate(parsedNumeric.toString());
      const fallbackRadius = 3;
      for (var offset = 1; offset <= fallbackRadius; offset++) {
        final lower = parsedNumeric - offset;
        final upper = parsedNumeric + offset;
        if (lower > 0) {
          addCandidate(lower.toString());
        }
        if (upper > 0) {
          addCandidate(upper.toString());
        }
      }
    }

    final results = <BagData>[];
    final seenKeys = <String>{};

    for (final candidateHuisnummer in candidateHouseNumbers) {
      final rawAddresses = await _requestAddressRecords(
        postcode: normalizedPostcode,
        huisnummer: candidateHuisnummer,
        apiKey: apiKey,
        exacteMatch: false,
      );

      for (final rawAddress in rawAddresses) {
        final bagData = BagData.fromJson(rawAddress);
        final key = [
          (bagData.bagAdresId ?? '').trim(),
          (bagData.bagIdentificatie ?? '').trim(),
          (bagData.adres ?? '').trim().toLowerCase(),
          (bagData.huisnummer ?? '').trim().toLowerCase(),
          (bagData.huisletterHuisnummertoevoeging ?? '').trim().toLowerCase(),
          bagData.postcode.trim().toUpperCase(),
          bagData.plaatsnaam.trim().toLowerCase(),
        ].join('|');
        if (seenKeys.add(key)) {
          results.add(bagData);
        }
      }

      // Exact result is usually sufficient (e.g. apartment additions).
      if (candidateHuisnummer == normalizedHuisnummer && results.isNotEmpty) {
        return results;
      }
    }

    if (results.isNotEmpty) {
      return results;
    }

    return [
      await lookupByAddress(
        normalizedPostcode,
        normalizedHuisnummer,
        apiKey,
      ),
    ];
  }

  /// Lookup mogelijke BAG-adressen op basis van vrije zoektekst.
  ///
  /// Gebruikt het `q`-queryveld van de BAG API en retourneert meerdere
  /// kandidaten (bijv. straat + plaats voor appartementencomplexen).
  static Future<List<BagData>> lookupCandidatesByQuery(
    String queryText,
    String apiKey,
  ) async {
    final normalizedQuery = queryText.trim();
    if (normalizedQuery.isEmpty) {
      return const <BagData>[];
    }

    final rawAddresses = await _requestAddressRecordsByQuery(
      queryText: normalizedQuery,
      apiKey: apiKey,
    );

    final results = <BagData>[];
    final seenKeys = <String>{};

    for (final rawAddress in rawAddresses) {
      final bagData = BagData.fromJson(rawAddress);
      final key = [
        (bagData.bagAdresId ?? '').trim(),
        (bagData.bagIdentificatie ?? '').trim(),
        (bagData.adres ?? '').trim().toLowerCase(),
        (bagData.huisnummer ?? '').trim().toLowerCase(),
        (bagData.huisletterHuisnummertoevoeging ?? '').trim().toLowerCase(),
        bagData.postcode.trim().toUpperCase(),
        bagData.plaatsnaam.trim().toLowerCase(),
      ].join('|');
      if (seenKeys.add(key)) {
        results.add(bagData);
      }
    }

    return results;
  }

  static Future<List<Map<String, dynamic>>> _requestAddressRecords({
    required String postcode,
    required String huisnummer,
    required String apiKey,
    required bool exacteMatch,
  }) async {
    final query = <String, String>{
      'postcode': postcode,
      'huisnummer': huisnummer,
      'exacteMatch': exacteMatch ? 'true' : 'false',
    };
    if (useQueryApiKey) {
      query['api_key'] = apiKey;
    }

    final uri = Uri.parse('$baseUrl/adressen').replace(queryParameters: query);
    final headers = <String, String>{'Accept': 'application/hal+json'};
    if (!useQueryApiKey) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    headers['X-Api-Key'] = apiKey;

    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode != 200) {
      throw Exception('BAG request failed: ${resp.statusCode}');
    }

    final decoded = json.decode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Onverwachte BAG response');
    }

    final extracted = <Map<String, dynamic>>[];

    final embedded = decoded['_embedded'];
    if (embedded is Map<String, dynamic>) {
      final adressen = embedded['adressen'];
      if (adressen is List) {
        for (final item in adressen) {
          if (item is Map<String, dynamic>) {
            extracted.add(item);
          }
        }
      }
    }

    final adressenTopLevel = decoded['adressen'];
    if (adressenTopLevel is List) {
      for (final item in adressenTopLevel) {
        if (item is Map<String, dynamic>) {
          extracted.add(item);
        }
      }
    }

    if (extracted.isNotEmpty) {
      return extracted;
    }

    if (decoded.containsKey('postcode') || decoded.containsKey('identificatie')) {
      return [decoded];
    }

    return const [];
  }

  static Future<List<Map<String, dynamic>>> _requestAddressRecordsByQuery({
    required String queryText,
    required String apiKey,
  }) async {
    final query = <String, String>{
      'q': queryText,
    };
    if (useQueryApiKey) {
      query['api_key'] = apiKey;
    }

    final uri = Uri.parse('$baseUrl/adressen').replace(queryParameters: query);
    final headers = <String, String>{'Accept': 'application/hal+json'};
    if (!useQueryApiKey) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    headers['X-Api-Key'] = apiKey;

    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode != 200) {
      throw Exception('BAG request failed: ${resp.statusCode}');
    }

    final decoded = json.decode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Onverwachte BAG response');
    }

    final extracted = <Map<String, dynamic>>[];

    final embedded = decoded['_embedded'];
    if (embedded is Map<String, dynamic>) {
      final adressen = embedded['adressen'];
      if (adressen is List) {
        for (final item in adressen) {
          if (item is Map<String, dynamic>) {
            extracted.add(item);
          }
        }
      }
    }

    final adressenTopLevel = decoded['adressen'];
    if (adressenTopLevel is List) {
      for (final item in adressenTopLevel) {
        if (item is Map<String, dynamic>) {
          extracted.add(item);
        }
      }
    }

    if (extracted.isNotEmpty) {
      return extracted;
    }

    if (decoded.containsKey('postcode') || decoded.containsKey('identificatie')) {
      return [decoded];
    }

    return const [];
  }

  static Future<BagData> _enrichWithPandBouwjaarIfNeeded({
    required BagData bagData,
    required String apiKey,
  }) async {
    final existing = (bagData.oorspronkelijkBouwjaar ?? '').trim();
    if (_isValidBouwjaar(existing)) {
      return bagData;
    }

    var bouwjaar = existing;

    var pandId = (bagData.bagPandId ?? '').trim();
    final bagIdentificatie = (bagData.bagIdentificatie ?? '').trim();
    final bagAdresId = (bagData.bagAdresId ?? '').trim();
    final adresseerbaarObjectId = (bagData.adresseerbaarObjectId ?? '').trim();

    final adresLookupId = bagAdresId.isNotEmpty ? bagAdresId : bagIdentificatie;
    if (adresLookupId.isNotEmpty) {
      final fromAdresDetail = await _lookupPandInfoByAdresId(
        bagIdentificatie: adresLookupId,
        apiKey: apiKey,
      );
      if ((pandId.isEmpty) && (fromAdresDetail?.pandId ?? '').trim().isNotEmpty) {
        pandId = fromAdresDetail!.pandId!.trim();
      }
      if (!_isValidBouwjaar(bouwjaar) && _isValidBouwjaar(fromAdresDetail?.bouwjaar)) {
        bouwjaar = fromAdresDetail!.bouwjaar!.trim();
      }
    }

    if (_isValidBouwjaar(bouwjaar)) {
      return bagData.copyWith(
        bagPandId: pandId.isEmpty ? null : pandId,
        oorspronkelijkBouwjaar: bouwjaar,
      );
    }

    if (pandId.isEmpty) {
      final adresseerbaarObjectLookupId =
          adresseerbaarObjectId.isNotEmpty ? adresseerbaarObjectId : bagIdentificatie;
      if (adresseerbaarObjectLookupId.isNotEmpty) {
        final resolvedPandId = await _lookupPandIdByAdresseerbaarObject(
          bagIdentificatie: adresseerbaarObjectLookupId,
          apiKey: apiKey,
        );
        if (resolvedPandId != null && resolvedPandId.trim().isNotEmpty) {
          pandId = resolvedPandId.trim();
          bagData = bagData.copyWith(bagPandId: pandId);
        }
      }
    }

    if (pandId.isEmpty) {
      final adresIdForChain = bagAdresId.isNotEmpty ? bagAdresId : bagIdentificatie;
      if (adresIdForChain.isNotEmpty) {
        final resolvedViaAdresChain = await _lookupPandIdViaAdresChain(
          adresId: adresIdForChain,
          apiKey: apiKey,
        );
        if (resolvedViaAdresChain != null && resolvedViaAdresChain.trim().isNotEmpty) {
          pandId = resolvedViaAdresChain.trim();
          bagData = bagData.copyWith(bagPandId: pandId);
        }
      }
    }

    if (pandId.isEmpty) {
      return bagData;
    }

    final pandBouwjaar = await _lookupPandBouwjaar(
      pandId: pandId,
      apiKey: apiKey,
    );
    if (!_isValidBouwjaar(pandBouwjaar)) {
      return bagData;
    }

    return bagData.copyWith(
      bagPandId: pandId,
      oorspronkelijkBouwjaar: pandBouwjaar?.trim(),
    );
  }

  static Future<_PandInfo?> _lookupPandInfoByAdresId({
    required String bagIdentificatie,
    required String apiKey,
  }) async {
    final query = <String, String>{};
    if (useQueryApiKey) {
      query['api_key'] = apiKey;
    }

    final uri = Uri.parse('$baseUrl/adressen/$bagIdentificatie')
        .replace(queryParameters: query);

    final headers = <String, String>{'Accept': 'application/hal+json'};
    if (!useQueryApiKey) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    headers['X-Api-Key'] = apiKey;

    try {
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode != 200) {
        return null;
      }
      final decoded = json.decode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      var pandId = _findFirstValueByKeys(decoded, const ['bagPandId', 'pandId']);
      if ((pandId == null || pandId.trim().isEmpty)) {
        final links = decoded['_links'];
        if (links is Map<String, dynamic>) {
          final linkedPanden = links['panden'];
          if (linkedPanden is List && linkedPanden.isNotEmpty) {
            final firstLinkedPand = linkedPanden.first;
            if (firstLinkedPand is Map<String, dynamic>) {
              pandId = _extractPandIdFromHref(firstLinkedPand['href']?.toString());
            }
          }
        }
      }

      final bouwjaar = _findFirstValueByKeys(
        decoded,
        const ['oorspronkelijkBouwjaar', 'bouwjaar'],
      );

      return _PandInfo(
        pandId: pandId?.trim(),
        bouwjaar: bouwjaar?.trim(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _lookupPandIdByAdresseerbaarObject({
    required String bagIdentificatie,
    required String apiKey,
  }) async {
    final endpointCandidates = <String>[
      'adresseerbareobjecten',
      'adresseerbaarobjecten',
      'verblijfsobjecten',
    ];

    for (final endpoint in endpointCandidates) {
      final object = await _requestBagObject(
        path: '$endpoint/$bagIdentificatie',
        apiKey: apiKey,
      );
      if (object == null) {
        continue;
      }

      final pandId = _extractPandIdFromObject(object);
      if (pandId != null && pandId.trim().isNotEmpty) {
        return pandId.trim();
      }
    }

    return null;
  }

  static Future<String?> _lookupPandIdViaAdresChain({
    required String adresId,
    required String apiKey,
  }) async {
    final adresObject = await _requestBagObject(
      path: 'adressen/$adresId',
      apiKey: apiKey,
    );
    if (adresObject == null) {
      return null;
    }

    final directPand = _extractPandIdFromObject(adresObject);
    if (directPand != null && directPand.trim().isNotEmpty) {
      return directPand.trim();
    }

    final nummeraanduidingId = _extractFirstLinkedId(
      adresObject,
      const ['nummeraanduiding', 'nummeraanduidingen'],
    );
    if (nummeraanduidingId == null || nummeraanduidingId.trim().isEmpty) {
      return null;
    }

    final nummeraanduidingObject = await _requestBagObject(
      path: 'nummeraanduidingen/${nummeraanduidingId.trim()}',
      apiKey: apiKey,
    );
    if (nummeraanduidingObject == null) {
      return null;
    }

    final objectId = _extractFirstLinkedId(
      nummeraanduidingObject,
      const [
        'adresseerbareObjecten',
        'adresseerbareobjecten',
        'adresseerbaarobjecten',
        'verblijfsobjecten',
      ],
    );
    if (objectId == null || objectId.trim().isEmpty) {
      return null;
    }

    return _lookupPandIdByAdresseerbaarObject(
      bagIdentificatie: objectId.trim(),
      apiKey: apiKey,
    );
  }

  static Future<Map<String, dynamic>?> _requestBagObject({
    required String path,
    required String apiKey,
    Map<String, String>? extraQueryParameters,
  }) async {
    final query = <String, String>{
      ...?extraQueryParameters,
    };
    if (useQueryApiKey) {
      query['api_key'] = apiKey;
    }

    final uri = Uri.parse('$baseUrl/$path').replace(queryParameters: query);
    final headers = <String, String>{'Accept': 'application/hal+json'};
    if (!useQueryApiKey) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    headers['X-Api-Key'] = apiKey;

    try {
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode != 200) {
        return null;
      }
      final decoded = json.decode(resp.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _requestPandById({
    required String pandId,
    required String apiKey,
  }) async {
    final cleanPandId = pandId.trim();
    if (cleanPandId.isEmpty) {
      return null;
    }

    try {
      final rawBody = await _fetchPandResponseBody(
        pandId: cleanPandId,
        apiKey: apiKey,
      );
      if (rawBody == null || rawBody.trim().isEmpty) {
        return null;
      }

      final rawYearMatch = RegExp(
        r'"oorspronkelijkBouwjaar"\s*:\s*(\d{4})',
      ).firstMatch(rawBody);
      final rawYear = rawYearMatch?.group(1);

      final decoded = json.decode(rawBody);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      if (_isValidBouwjaar(rawYear) &&
          !_isValidBouwjaar(_extractBouwjaarFromPandObject(decoded))) {
        decoded['oorspronkelijkBouwjaar'] = rawYear;
      }

      final directBouwjaar = _findFirstValueByKeys(
        decoded,
        const ['oorspronkelijkBouwjaar', 'bouwjaar'],
      );
      if (_isValidBouwjaar(directBouwjaar) ||
          _isValidBouwjaar(_extractFirstValidBouwjaarDeep(decoded))) {
        return decoded;
      }

      final embedded = decoded['_embedded'];
      if (embedded is Map<String, dynamic>) {
        final panden = embedded['panden'];
        if (panden is List && panden.isNotEmpty) {
          final first = panden.first;
          if (first is Map<String, dynamic>) {
            return first;
          }
        }
      }

      return decoded;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _fetchPandResponseBody({
    required String pandId,
    required String apiKey,
  }) async {
    final base = Uri.parse('$baseUrl/panden/$pandId');
    final baseExpand = Uri.parse('$baseUrl/panden/$pandId').replace(
      queryParameters: {'expand': 'true'},
    );

    final attempts = <Map<String, dynamic>>[
      {
        'uri': base,
        'headers': {
          'Accept': 'application/hal+json, application/json',
          'Accept-Crs': 'epsg:28992',
          'X-Api-Key': apiKey,
        },
      },
      {
        'uri': base,
        'headers': {
          'Accept': 'application/hal+json, application/json',
          'Accept-Crs': 'epsg:28992',
          'Authorization': 'Bearer $apiKey',
          'X-Api-Key': apiKey,
        },
      },
      {
        'uri': baseExpand,
        'headers': {
          'Accept': 'application/hal+json, application/json',
          'Accept-Crs': 'epsg:28992',
          'X-Api-Key': apiKey,
        },
      },
      {
        'uri': base,
        'headers': {
          'Accept': 'application/hal+json, application/json',
          'X-Api-Key': apiKey,
        },
      },
      {
        'uri': base,
        'headers': {
          'Accept': 'application/hal+json, application/json',
          'x-api-key': apiKey,
        },
      },
      {
        'uri': base,
        'headers': {
          'Accept': 'application/json',
          'Accept-Crs': 'epsg:28992',
          'X-Api-Key': apiKey,
        },
      },
      {
        'uri': base,
        'headers': {
          'Accept': 'application/json',
          'apikey': apiKey,
        },
      },
      {
        'uri': base,
        'headers': {
          'Accept': 'application/hal+json, application/json',
          'Authorization': 'Bearer $apiKey',
          'X-Api-Key': apiKey,
        },
      },
      {
        'uri': base.replace(queryParameters: {'api_key': apiKey}),
        'headers': const {
          'Accept': 'application/hal+json, application/json',
        },
      },
      {
        'uri': base.replace(queryParameters: {'api_key': apiKey, 'expand': 'true'}),
        'headers': const {
          'Accept': 'application/hal+json, application/json',
        },
      },
      {
        'uri': base.replace(queryParameters: {'apikey': apiKey}),
        'headers': const {
          'Accept': 'application/hal+json, application/json',
        },
      },
    ];

    for (final attempt in attempts) {
      try {
        final uri = attempt['uri'] as Uri;
        final headers = attempt['headers'] as Map<String, String>;
        final resp = await http.get(uri, headers: headers);
        if (resp.statusCode == 200 && resp.body.trim().isNotEmpty) {
          return resp.body;
        }
      } catch (_) {}
    }

    return null;
  }

  static Future<String> _probePandEndpointStatuses({
    required String pandId,
    required String apiKey,
  }) async {
    final base = Uri.parse('$baseUrl/panden/$pandId');
    final baseExpand = Uri.parse('$baseUrl/panden/$pandId').replace(
      queryParameters: {'expand': 'true'},
    );
    final attempts = <Map<String, dynamic>>[
      {
        'label': 'header:X-Api-Key+crs',
        'uri': base,
        'headers': {
          'Accept': 'application/hal+json, application/json',
          'Accept-Crs': 'epsg:28992',
          'X-Api-Key': apiKey,
        },
      },
      {
        'label': 'bearer+header+crs',
        'uri': base,
        'headers': {
          'Accept': 'application/hal+json, application/json',
          'Accept-Crs': 'epsg:28992',
          'Authorization': 'Bearer $apiKey',
          'X-Api-Key': apiKey,
        },
      },
      {
        'label': 'query:api_key',
        'uri': base.replace(queryParameters: {'api_key': apiKey}),
        'headers': const {
          'Accept': 'application/hal+json, application/json',
        },
      },
      {
        'label': 'query:api_key+expand',
        'uri': base.replace(queryParameters: {'api_key': apiKey, 'expand': 'true'}),
        'headers': const {
          'Accept': 'application/hal+json, application/json',
        },
      },
      {
        'label': 'query:apikey',
        'uri': base.replace(queryParameters: {'apikey': apiKey}),
        'headers': const {
          'Accept': 'application/hal+json, application/json',
        },
      },
      {
        'label': 'header:X-Api-Key+expand',
        'uri': baseExpand,
        'headers': {
          'Accept': 'application/hal+json, application/json',
          'X-Api-Key': apiKey,
        },
      },
      {
        'label': 'header:X-Api-Key',
        'uri': base,
        'headers': {
          'Accept': 'application/hal+json, application/json',
          'X-Api-Key': apiKey,
        },
      },
      {
        'label': 'header:x-api-key',
        'uri': base,
        'headers': {
          'Accept': 'application/hal+json, application/json',
          'x-api-key': apiKey,
        },
      },
      {
        'label': 'header:X-Api-Key+json+crs',
        'uri': base,
        'headers': {
          'Accept': 'application/json',
          'Accept-Crs': 'epsg:28992',
          'X-Api-Key': apiKey,
        },
      },
      {
        'label': 'header:apikey',
        'uri': base,
        'headers': {
          'Accept': 'application/json',
          'apikey': apiKey,
        },
      },
      {
        'label': 'bearer+header',
        'uri': base,
        'headers': {
          'Accept': 'application/hal+json, application/json',
          'Authorization': 'Bearer $apiKey',
          'X-Api-Key': apiKey,
        },
      },
    ];

    final results = <String>[];
    for (final attempt in attempts) {
      final label = attempt['label'] as String;
      final uri = attempt['uri'] as Uri;
      final headers = attempt['headers'] as Map<String, String>;
      try {
        final resp = await http.get(uri, headers: headers);
        results.add('$label=${resp.statusCode}');
      } catch (_) {
        results.add('$label=ERR');
      }
    }

    return results.join(', ');
  }

  static String? _extractPandIdFromObject(Map<String, dynamic> decoded) {
    final directPanden = decoded['panden'];
    if (directPanden is List && directPanden.isNotEmpty) {
      final first = directPanden.first;
      if (first is Map<String, dynamic>) {
        final id = first['identificatie']?.toString() ?? first['id']?.toString();
        if (id != null && id.trim().isNotEmpty) {
          return id;
        }
        final hrefId = _extractPandIdFromHref(first['href']?.toString());
        if (hrefId != null && hrefId.trim().isNotEmpty) {
          return hrefId;
        }
      } else {
        final text = first?.toString();
        if (text != null && text.trim().isNotEmpty) {
          return text;
        }
      }
    }

    final links = decoded['_links'];
    if (links is Map<String, dynamic>) {
      final linkedPanden = links['panden'];
      if (linkedPanden is List && linkedPanden.isNotEmpty) {
        final firstLinkedPand = linkedPanden.first;
        if (firstLinkedPand is Map<String, dynamic>) {
          final hrefId = _extractPandIdFromHref(firstLinkedPand['href']?.toString());
          if (hrefId != null && hrefId.trim().isNotEmpty) {
            return hrefId;
          }
        }
      }
    }

    return null;
  }

  static String? _extractFirstLinkedId(
    Map<String, dynamic> decoded,
    List<String> keys,
  ) {
    final links = decoded['_links'];
    if (links is! Map<String, dynamic>) {
      return null;
    }

    for (final key in keys) {
      final link = links[key];
      if (link is Map<String, dynamic>) {
        final hrefId = _extractPandIdFromHref(link['href']?.toString());
        if (hrefId != null && hrefId.trim().isNotEmpty) {
          return hrefId.trim();
        }
      }
      if (link is String) {
        final hrefId = _extractPandIdFromHref(link);
        if (hrefId != null && hrefId.trim().isNotEmpty) {
          return hrefId.trim();
        }
      }
      if (link is List && link.isNotEmpty) {
        final first = link.first;
        if (first is Map<String, dynamic>) {
          final hrefId = _extractPandIdFromHref(first['href']?.toString());
          if (hrefId != null && hrefId.trim().isNotEmpty) {
            return hrefId.trim();
          }
        }
        if (first is String) {
          final hrefId = _extractPandIdFromHref(first);
          if (hrefId != null && hrefId.trim().isNotEmpty) {
            return hrefId.trim();
          }
        }
      }
    }

    return null;
  }

  static Future<String?> _lookupPandBouwjaar({
    required String pandId,
    required String apiKey,
  }) async {
    try {
      final rawBody = await _fetchPandResponseBody(
        pandId: pandId.trim(),
        apiKey: apiKey,
      );
      if (rawBody != null) {
        final rawYearMatch = RegExp(
          r'"oorspronkelijkBouwjaar"\s*:\s*(\d{4})',
        ).firstMatch(rawBody);
        final rawYear = rawYearMatch?.group(1);
        if (_isValidBouwjaar(rawYear)) {
          return rawYear;
        }
      }

      final pandObject = await _requestPandById(
        pandId: pandId,
        apiKey: apiKey,
      );
      if (pandObject == null) {
        return null;
      }

      final hard = _extractBouwjaarFromPandObject(pandObject);
      if (_isValidBouwjaar(hard)) {
        return hard;
      }

      return _extractFirstValidBouwjaarDeep(pandObject);
    } catch (_) {
      return null;
    }
  }

  /// Lookup BAG data by [lat]/[lon] using [apiKey]. Returns [BagData].
  static Future<BagData> lookupByCoords(
    double lat,
    double lon,
    String apiKey,
  ) async {
    throw UnimplementedError(
      'Gebruik lookupByAddress(postcode, huisnummer, apiKey) voor Kadaster BAG v2.',
    );
  }
}
