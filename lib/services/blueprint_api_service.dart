import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/blueprint_entiteit.dart';

/// Configuratie voor de Blueprint Data REST-API.
class BlueprintApiConfig {
  /// Volledige `wp-json` basis-URL, zonder trailing slash.
  final String baseWpJsonUrl;

  /// Namespace binnen WordPress REST.
  final String namespace;

  /// Gebruikersnaam voor Application Password Basic auth.
  final String username;

  /// Application Password behorend bij [username].
  final String applicationPassword;

  /// Maakt een onwijzigbare API-configuratie.
  const BlueprintApiConfig({
    required this.baseWpJsonUrl,
    required this.namespace,
    required this.username,
    required this.applicationPassword,
  });

  /// Of beveiligde endpoints aangeroepen kunnen worden.
  bool get hasCredentials =>
      username.trim().isNotEmpty && applicationPassword.trim().isNotEmpty;

  /// Bouwt een endpointpad op basis van de namespace.
  String scopedPath(String path) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return '$baseWpJsonUrl/$namespace/$clean';
  }
}

/// Gestandaardiseerde fout van een WordPress REST-endpoint.
class BlueprintApiException implements Exception {
  /// Machinecode van de fout indien aanwezig.
  final String code;

  /// Menselijke foutmelding.
  final String message;

  /// HTTP-statuscode (of 0 als onbekend).
  final int status;

  /// Ruwe responsebody (handig voor diagnose).
  final String? body;

  /// Maakt een exception voor API-fouten.
  const BlueprintApiException({
    required this.code,
    required this.message,
    required this.status,
    this.body,
  });

  @override
  String toString() {
    return 'BlueprintApiException($status, $code): $message';
  }
}

/// Mogelijke uitkomsten van `POST /bd/v1/woz`.
enum WozStatus {
  /// WOZ is gevonden en geldig.
  ok,

  /// Adres niet gevonden of mismatch.
  nietGevonden,

  /// Geen openbare WOZ aanwezig.
  geenWoz,

  /// Invoer-, netwerk- of limietfout.
  fout,

  /// Onbekende statusstring uit backend.
  onbekend,
}

/// Responsemodel van `POST /bd/v1/woz`.
class WozLookupResult {
  /// Domeinstatus zoals contractueel vastgelegd.
  final WozStatus status;

  /// WOZ-waarde in euro's.
  final int? waarde;

  /// Peildatum als `YYYY-MM-DD`.
  final String peildatum;

  /// Geformatteerde adresweergave uit de API.
  final String weergavenaam;

  /// Genormaliseerde postcode zonder spatie.
  final String postcode;

  /// Menselijke melding bij afwijkingen.
  final String melding;

  /// Of de servercache is gebruikt.
  final bool uitCache;

  /// Ruwe payload voor debugging / opslag.
  final Map<String, dynamic> raw;

  /// Maakt een `woz` resultaatobject.
  const WozLookupResult({
    required this.status,
    required this.waarde,
    required this.peildatum,
    required this.weergavenaam,
    required this.postcode,
    required this.melding,
    required this.uitCache,
    required this.raw,
  });

  /// Parse helper voor de API-response.
  factory WozLookupResult.fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status'] ?? '').toString();
    final int? parsedWaarde = _toNullableInt(json['waarde']);
    return WozLookupResult(
      status: _parseWozStatus(statusRaw),
      waarde: parsedWaarde,
      peildatum: (json['peildatum'] ?? '').toString(),
      weergavenaam: (json['weergavenaam'] ?? '').toString(),
      postcode: (json['postcode'] ?? '').toString(),
      melding: (json['melding'] ?? '').toString(),
      uitCache: json['uit_cache'] == true,
      raw: Map<String, dynamic>.from(json),
    );
  }

  static WozStatus _parseWozStatus(String value) {
    switch (value) {
      case 'ok':
        return WozStatus.ok;
      case 'niet_gevonden':
        return WozStatus.nietGevonden;
      case 'geen_woz':
        return WozStatus.geenWoz;
      case 'fout':
        return WozStatus.fout;
      default:
        return WozStatus.onbekend;
    }
  }
}

/// Compacte wrapper om een te uploaden bestand te beschrijven.
class BlueprintUploadFile {
  /// Lokale bestandslocatie.
  final File file;

  /// Form-fieldnaam in multipart (bijv. `xml`, `label_pdf`).
  final String fieldName;

  /// Optionele override voor bestandsnaam.
  final String? fileName;

  /// Maakt een uploadbeschrijving voor multipart-calls.
  const BlueprintUploadFile({
    required this.file,
    required this.fieldName,
    this.fileName,
  });
}

/// Contractconforme client voor `bd/v1` endpoints.
class BlueprintApiService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _kBaseWpJsonUrl = 'blueprint_api_base_wp_json_url_v1';
  static const String _kNamespace = 'blueprint_api_namespace_v1';
  static const String _kUsername = 'blueprint_api_username_v1';
  static const String _kApplicationPassword =
      'blueprint_api_application_password_v1';

  /// Contract-default uit APP-API.md.
  static const String defaultBaseWpJsonUrl =
      'https://blueprint-data.nl/wp-json';

  /// Contract-default namespace.
  static const String defaultNamespace = 'bd/v1';

  /// Slaat API-config op in secure storage.
  static Future<void> saveConfig(BlueprintApiConfig config) async {
    await _storage.write(
      key: _kBaseWpJsonUrl,
      value: _normalizeBase(config.baseWpJsonUrl),
    );
    await _storage.write(
      key: _kNamespace,
      value: _normalizeNamespace(config.namespace),
    );
    await _storage.write(key: _kUsername, value: config.username.trim());
    await _storage.write(
      key: _kApplicationPassword,
      value: config.applicationPassword.trim(),
    );
  }

  /// Laadt API-config, met contract-defaults voor URL/namespace.
  static Future<BlueprintApiConfig> loadConfig() async {
    final base = await _storage.read(key: _kBaseWpJsonUrl);
    final ns = await _storage.read(key: _kNamespace);
    final user = await _storage.read(key: _kUsername);
    final pass = await _storage.read(key: _kApplicationPassword);
    return BlueprintApiConfig(
      baseWpJsonUrl: _normalizeBase(base ?? defaultBaseWpJsonUrl),
      namespace: _normalizeNamespace(ns ?? defaultNamespace),
      username: (user ?? '').trim(),
      applicationPassword: (pass ?? '').trim(),
    );
  }

  /// Wist alleen credentials; URL + namespace blijven staan.
  static Future<void> clearCredentials() async {
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kApplicationPassword);
  }

  /// Volledige reset van opgeslagen API-config.
  static Future<void> clearConfig() async {
    for (final key in [
      _kBaseWpJsonUrl,
      _kNamespace,
      _kUsername,
      _kApplicationPassword,
    ]) {
      await _storage.delete(key: key);
    }
  }

  /// Test van Basic auth via `GET /wp/v2/users/me`.
  static Future<bool> testCredentials() async {
    final config = await loadConfig();
    if (!config.hasCredentials) {
      return false;
    }
    final uri = Uri.parse('${config.baseWpJsonUrl}/wp/v2/users/me');
    final response = await http
        .get(uri, headers: _authHeaders(config))
        .timeout(const Duration(seconds: 20));
    return response.statusCode == 200;
  }

  /// `POST /bd/v1/woz` (publiek).
  static Future<WozLookupResult> lookupWoz({
    required String postcode,
    required String huisnummer,
    String toevoeging = '',
  }) async {
    final config = await loadConfig();
    final payload = <String, dynamic>{
      'postcode': postcode,
      'huisnummer': huisnummer,
      if (toevoeging.trim().isNotEmpty) 'toevoeging': toevoeging,
    };
    final data = await _postJson(
      url: config.scopedPath('woz'),
      payload: payload,
      withAuth: false,
      expectedStatusCodes: const <int>{200},
    );
    return WozLookupResult.fromJson(data);
  }

  /// `POST /bd/v1/wws` (publiek, JSON body verplicht).
  static Future<Map<String, dynamic>> calculateWws(
    Map<String, dynamic> requestPayload,
  ) async {
    final config = await loadConfig();
    final data = await _postJson(
      url: config.scopedPath('wws'),
      payload: requestPayload,
      withAuth: false,
      expectedStatusCodes: const <int>{200},
    );
    return data;
  }

  /// `POST /bd/v1/entiteit` (beveiligd, multipart/form-data).
  static Future<Map<String, dynamic>> createEntiteit({
    Map<String, String> fields = const <String, String>{},
    List<BlueprintUploadFile> files = const <BlueprintUploadFile>[],
  }) async {
    final config = await loadConfig();
    final data = await _postMultipart(
      url: config.scopedPath('entiteit'),
      fields: fields,
      files: files,
      expectedStatusCodes: const <int>{200},
    );
    return data;
  }

  /// `POST /bd/v1/entiteit/{id}` (beveiligd, update).
  static Future<Map<String, dynamic>> updateEntiteit({
    required int id,
    Map<String, String> fields = const <String, String>{},
    List<BlueprintUploadFile> files = const <BlueprintUploadFile>[],
  }) async {
    final config = await loadConfig();
    final data = await _postMultipart(
      url: config.scopedPath('entiteit/$id'),
      fields: fields,
      files: files,
      expectedStatusCodes: const <int>{200},
    );
    return data;
  }

  /// `DELETE /bd/v1/entiteit/{id}` (beveiligd).
  static Future<Map<String, dynamic>> deleteEntiteit(int id) async {
    final config = await loadConfig();
    final data = await _sendJsonRequest(
      method: 'DELETE',
      url: config.scopedPath('entiteit/$id'),
      payload: null,
      withAuth: true,
      expectedStatusCodes: const <int>{200},
    );
    return data;
  }

  /// `POST /bd/v1/entiteit/{id}/verversen` (beveiligd).
  static Future<Map<String, dynamic>> refreshEntiteit(int id) async {
    final config = await loadConfig();
    final data = await _postJson(
      url: config.scopedPath('entiteit/$id/verversen'),
      payload: const <String, dynamic>{},
      withAuth: true,
      expectedStatusCodes: const <int>{200},
    );
    return data;
  }

  /// `GET /bd/v1/entiteit/{id}/documenten` (beveiligd).
  static Future<List<Map<String, dynamic>>> listDocumenten(int id) async {
    final config = await loadConfig();
    final data = await _sendJsonRequest(
      method: 'GET',
      url: config.scopedPath('entiteit/$id/documenten'),
      payload: null,
      withAuth: true,
      expectedStatusCodes: const <int>{200},
    );
    final rawList = data['documenten'];
    if (rawList is! List) {
      return const <Map<String, dynamic>>[];
    }
    return rawList
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  /// `POST /bd/v1/entiteit/{id}/document` (beveiligd, multipart).
  static Future<Map<String, dynamic>> uploadDocument({
    required int entiteitId,
    required File bestand,
    String categorie = 'overig',
  }) async {
    final config = await loadConfig();
    final data = await _postMultipart(
      url: config.scopedPath('entiteit/$entiteitId/document'),
      fields: <String, String>{'categorie': categorie},
      files: <BlueprintUploadFile>[
        BlueprintUploadFile(fieldName: 'bestand', file: bestand),
      ],
      expectedStatusCodes: const <int>{200},
    );
    return data;
  }

  /// `GET /bd/v1/document/{att}` (beveiligd, bytes payload).
  static Future<List<int>> downloadDocument(int attachmentId) async {
    final config = await loadConfig();
    final uri = Uri.parse(config.scopedPath('document/$attachmentId'));
    final response = await http
        .get(uri, headers: _authHeaders(config))
        .timeout(const Duration(seconds: 60));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw _buildExceptionFromResponse(response);
  }

  /// `DELETE /bd/v1/document/{att}` (beveiligd, definitief).
  static Future<Map<String, dynamic>> deleteDocument(int attachmentId) async {
    final config = await loadConfig();
    final data = await _sendJsonRequest(
      method: 'DELETE',
      url: config.scopedPath('document/$attachmentId'),
      payload: null,
      withAuth: true,
      expectedStatusCodes: const <int>{200},
    );
    return data;
  }

  /// `POST /bd/v1/entiteit/{id}/verhuur` (beveiligd, JSON).
  static Future<Map<String, dynamic>> saveVerhuur({
    required int entiteitId,
    required Map<String, dynamic> fields,
  }) async {
    final config = await loadConfig();
    final data = await _postJson(
      url: config.scopedPath('entiteit/$entiteitId/verhuur'),
      payload: fields,
      withAuth: true,
      expectedStatusCodes: const <int>{200},
    );
    return data;
  }

  /// `GET /bd/v1/entiteiten` (beveiligd, portfolio-lijst met paginatie).
  static Future<List<BlueprintEntiteit>> getEntiteiten({
    int page = 1,
    int perPage = 20,
    String? search,
  }) async {
    final config = await loadConfig();
    if (!config.hasCredentials) {
      throw const BlueprintApiException(
        code: 'bd_auth_required',
        message: 'Geen credentials ingesteld.',
        status: 401,
      );
    }
    final uri = Uri.parse(config.scopedPath('entiteiten')).replace(queryParameters: {
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final response = await http
        .get(uri, headers: _authHeaders(config))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw _buildExceptionFromResponse(response);
    }
    final decoded = _decodeJsonBody(response.body);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => BlueprintEntiteit.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    }
    if (decoded is Map && decoded['eenheden'] is List) {
      final eenheden = decoded['eenheden'] as List;
      return eenheden
          .whereType<Map>()
          .map((e) => BlueprintEntiteit.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    }
    return const <BlueprintEntiteit>[];
  }

  /// `GET /bd/v1/entiteit/{id}` (beveiligd, volledige detail).
  static Future<BlueprintEntiteitDetail> getEntiteit(int id) async {
    final config = await loadConfig();
    if (!config.hasCredentials) {
      throw const BlueprintApiException(
        code: 'bd_auth_required',
        message: 'Geen credentials ingesteld.',
        status: 401,
      );
    }
    final uri = Uri.parse(config.scopedPath('entiteit/$id'));
    final response = await http
        .get(uri, headers: _authHeaders(config))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 404) {
      throw BlueprintApiException(
        code: 'bd_not_found',
        message: 'Eenheid niet gevonden.',
        status: 404,
        body: response.body,
      );
    }
    if (response.statusCode != 200) {
      throw _buildExceptionFromResponse(response);
    }
    final decoded = _decodeJsonBody(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw BlueprintApiException(
        code: 'bd_parse_error',
        message: 'Ongeldige response van server.',
        status: 0,
      );
    }
    return BlueprintEntiteitDetail.fromJson(decoded);
  }

  /// `POST /bd/v1/reken/{id}` (beveiligd, scenario-berekening EP2).
  static Future<BlueprintRekenResultaat> calculateReken({
    required int entiteitId,
    required Map<String, dynamic> scenario,
  }) async {
    final config = await loadConfig();
    if (!config.hasCredentials) {
      throw const BlueprintApiException(
        code: 'bd_auth_required',
        message: 'Geen credentials ingesteld.',
        status: 401,
      );
    }
    final data = await _postJson(
      // Contract §3.8: de reken-body moet het scenario in een `scenario`-sleutel
      // verpakken (net als saveScenario). Zonder wrapper rekent de server niets.
      url: config.scopedPath('reken/$entiteitId'),
      payload: <String, dynamic>{'scenario': scenario},
      withAuth: true,
      expectedStatusCodes: const <int>{200},
    );
    return BlueprintRekenResultaat.fromJson(data);
  }

  /// `POST /bd/v1/entiteit/{id}/scenario` (beveiligd, scenario opslaan).
  static Future<void> saveScenario({
    required int entiteitId,
    required Map<String, dynamic> scenario,
    Map<String, dynamic>? resultaat,
    String? notitie,
  }) async {
    final config = await loadConfig();
    if (!config.hasCredentials) {
      throw const BlueprintApiException(
        code: 'bd_auth_required',
        message: 'Geen credentials ingesteld.',
        status: 401,
      );
    }
    final payload = <String, dynamic>{
      'scenario': scenario,
      if (resultaat != null) 'resultaat': resultaat,
      if (notitie != null && notitie.isNotEmpty) 'notitie': notitie,
    };
    await _postJson(
      url: config.scopedPath('entiteit/$entiteitId/scenario'),
      payload: payload,
      withAuth: true,
      expectedStatusCodes: const <int>{200},
    );
  }

  static Map<String, String> _authHeaders(BlueprintApiConfig config) {
    final token = base64Encode(
      utf8.encode('${config.username}:${config.applicationPassword}'),
    );
    return <String, String>{'Authorization': 'Basic $token'};
  }

  static String _normalizeBase(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static String _normalizeNamespace(String raw) {
    final value = raw.trim();
    return value.replaceAll(RegExp(r'^/+|/+$'), '');
  }

  static Future<Map<String, dynamic>> _postJson({
    required String url,
    required Map<String, dynamic> payload,
    required bool withAuth,
    required Set<int> expectedStatusCodes,
  }) async {
    return _sendJsonRequest(
      method: 'POST',
      url: url,
      payload: payload,
      withAuth: withAuth,
      expectedStatusCodes: expectedStatusCodes,
    );
  }

  static Future<Map<String, dynamic>> _sendJsonRequest({
    required String method,
    required String url,
    required Map<String, dynamic>? payload,
    required bool withAuth,
    required Set<int> expectedStatusCodes,
  }) async {
    final config = await loadConfig();
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (withAuth) {
      if (!config.hasCredentials) {
        throw const BlueprintApiException(
          code: 'bd_auth_missing',
          message: 'Geen Application Password credentials ingesteld.',
          status: 401,
        );
      }
      headers.addAll(_authHeaders(config));
    }

    final uri = Uri.parse(url);
    final request = http.Request(method, uri);
    request.headers.addAll(headers);
    if (payload != null) {
      request.body = jsonEncode(payload);
    }

    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);
    if (!expectedStatusCodes.contains(response.statusCode)) {
      throw _buildExceptionFromResponse(response);
    }

    final decoded = _decodeJsonBody(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw BlueprintApiException(
      code: 'bd_bad_response',
      message: 'Response is geen JSON-object.',
      status: response.statusCode,
      body: response.body,
    );
  }

  static Future<Map<String, dynamic>> _postMultipart({
    required String url,
    required Map<String, String> fields,
    required List<BlueprintUploadFile> files,
    required Set<int> expectedStatusCodes,
  }) async {
    final config = await loadConfig();
    if (!config.hasCredentials) {
      throw const BlueprintApiException(
        code: 'bd_auth_missing',
        message: 'Geen Application Password credentials ingesteld.',
        status: 401,
      );
    }

    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers.addAll(_authHeaders(config));
    request.fields.addAll(fields);

    for (final entry in files) {
      final length = await entry.file.length();
      final stream = http.ByteStream(entry.file.openRead());
      final filename = entry.fileName ?? entry.file.uri.pathSegments.last;
      final part = http.MultipartFile(
        entry.fieldName,
        stream,
        length,
        filename: filename,
      );
      request.files.add(part);
    }

    final streamed = await request.send().timeout(const Duration(seconds: 120));
    final response = await http.Response.fromStream(streamed);
    if (!expectedStatusCodes.contains(response.statusCode)) {
      throw _buildExceptionFromResponse(response);
    }
    final decoded = _decodeJsonBody(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw BlueprintApiException(
      code: 'bd_bad_response',
      message: 'Response is geen JSON-object.',
      status: response.statusCode,
      body: response.body,
    );
  }

  static BlueprintApiException _buildExceptionFromResponse(
    http.Response response,
  ) {
    final decoded = _decodeJsonBody(response.body);
    if (decoded is Map<String, dynamic>) {
      final code = (decoded['code'] ?? 'bd_http_error').toString();
      final message =
          (decoded['message'] ?? 'HTTP ${response.statusCode}').toString();
      int status = response.statusCode;
      final data = decoded['data'];
      if (data is Map && data['status'] != null) {
        final parsed = int.tryParse(data['status'].toString());
        if (parsed != null) {
          status = parsed;
        }
      }
      return BlueprintApiException(
        code: code,
        message: message,
        status: status,
        body: response.body,
      );
    }
    return BlueprintApiException(
      code: 'bd_http_error',
      message: 'HTTP ${response.statusCode}',
      status: response.statusCode,
      body: response.body,
    );
  }

  static dynamic _decodeJsonBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }

}

/// Contractuele referentiewaarden voor WWS-keuzevelden.
class BlueprintWwsContract {
  /// `binnenruimtes.type` voor verblijfsruimtes.
  static const List<String> verblijfsruimteTypen = <String>[
    'Woonkamer',
    'Woonkamer met open keuken',
    'Keuken',
    'Slaapkamer',
    'Badkamer',
    'Doucheruimte',
    'Eetkamer',
    'Studeerkamer',
    'Hobbykamer',
    'Zolder als vertrek (vaste trap)',
  ];

  /// `binnenruimtes.type` voor overige ruimten.
  static const List<String> overigeRuimteTypen = <String>[
    'Toiletruimte',
    'Hal/gang/overloop',
    'Berging/bijkeuken',
    'Wasruimte',
    'Zolder met vaste trap',
    'Zolder zonder vaste trap',
    'Kelder',
    'Overige binnenruimte',
  ];

  /// `buitenruimtes.type` contractwaarden.
  static const List<String> buitenruimteTypen = <String>[
    'Geen buitenruimte',
    'Balkon',
    'Dakterras',
    'Achtertuin',
    'Voortuin',
    'Zijtuin',
    'Patio',
    'Loggia',
    'Fietsenberging',
    'Overige buitenruimte',
  ];

  /// `keuken_kenmerken[].kenmerk` contractwaarden.
  static const List<String> keukenKenmerken = <String>[
    'Inbouw afzuiginstallatie',
    'Inbouw kookplaat inductie',
    'Inbouw kookplaat keramisch',
    'Inbouw kookplaat gas',
    'Inbouw koelkast',
    'Inbouw vrieskast',
    'Inbouw oven elektrisch',
    'Inbouw oven gas',
    'Inbouw magnetron',
    'Inbouw vaatwasmachine',
    'Extra kastruimte boven minimum per 60 cm',
    'Eenhandsmengkraan',
    'Thermostatische mengkraan',
    'Kokend waterfunctie',
  ];

  /// `sanitair_basis[].kenmerk` contractwaarden.
  static const List<String> sanitairBasisKenmerken = <String>[
    'Toilet in aparte ruimte',
    'Toilet in badkamer',
    'Hangend toilet in aparte ruimte',
    'Hangend toilet in badkamer',
    'Wastafels (badkamer, slaapkamers en toilet)',
    'Meerpersoonswastafel',
    'Douche',
    'Bad',
    'Bad en afzonderlijke douche',
  ];

  /// `sanitair_extra[].kenmerk` contractwaarden.
  static const List<String> sanitairExtraKenmerken = <String>[
    'Bubbelfunctie van het bad',
    'Gemonteerde volledige afscheiding van de douche',
    'Handdoekenradiator',
    'Ingebouwd kastje met in- of opgebouwde wastafel',
    'Kastruimte',
    'Stopcontact',
    'Eenhandsmengkraan',
    'Thermostatische mengkraan',
  ];

  /// Geldige waarden voor `aanrechtlengte`.
  static const List<String> aanrechtLengtes = <String>[
    'Minder dan 1 meter',
    '1 tot 2 meter',
    '2 meter of langer',
  ];

  /// Documentcategorieen voor `POST /entiteit/{id}/document`.
  static const List<String> documentCategorieen = <String>[
    'energielabel',
    'huurcontract',
    'taxatie',
    'onderhoud',
    'foto',
    'overig',
  ];

  /// Geldige woningtypen voor WWS.
  static const List<String> woningTypen = <String>[
    'Eengezinswoning',
    'Meergezinswoning',
  ];

  /// Geldige WOZ-bronnen voor WWS.
  static const List<String> wozBronnen = <String>[
    'WOZ-beschikking',
    'Minimum WOZ-waarde',
    '85% taxatiewaarde',
  ];

  /// Geldige WOZ-jaren voor WWS.
  static const List<String> wozJaren = <String>[
    '2023',
    '2024',
    '2025',
    '2026',
  ];


}
int? _toNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  return int.tryParse(value.toString());
}
