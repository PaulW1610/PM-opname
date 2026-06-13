import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Manier van verbinden met Nextcloud.
enum NextcloudMode {
  /// Eigen account (gebruiker + app-wachtwoord), schrijft in `remote.php/dav`.
  account,

  /// Publieke deellink met upload-rechten, schrijft via `public.php/webdav`.
  link,
}

/// Resultaat van een dossier-upload naar Nextcloud.
class NextcloudUploadResult {
  final int uploadedCount;
  final int totalCount;
  final List<String> failedFiles;
  final String? message;

  /// Het volledige WebDAV-doelpad van de dossiermap (voor diagnose).
  final String? targetUrl;

  const NextcloudUploadResult({
    required this.uploadedCount,
    required this.totalCount,
    required this.failedFiles,
    this.message,
    this.targetUrl,
  });

  bool get isSuccess => uploadedCount == totalCount && failedFiles.isEmpty;
}

/// Verbinding met een Nextcloud-server via WebDAV.
///
/// Twee modes:
/// - **account**: gebruiker + app-wachtwoord (Basic auth) op `remote.php/dav`.
/// - **link**: een publieke deellink met upload-rechten op `public.php/webdav`
///   (geen account nodig; auth = link-token + eventueel link-wachtwoord).
///
/// Alle gegevens worden versleuteld opgeslagen in [FlutterSecureStorage].
class NextcloudService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _kMode = 'nextcloud_mode_v1';
  static const String _kBaseUrl = 'nextcloud_base_url_v1';
  static const String _kUsername = 'nextcloud_username_v1';
  static const String _kAppPassword = 'nextcloud_app_password_v1';
  static const String _kBasePath = 'nextcloud_base_path_v1';
  static const String _kLinkUrl = 'nextcloud_link_url_v1';
  static const String _kLinkPassword = 'nextcloud_link_password_v1';

  static String? _lastError;
  static String? get lastError => _lastError;

  static Future<void> saveAccountConfig({
    required String baseUrl,
    required String username,
    required String appPassword,
    String basePath = '',
  }) async {
    await _storage.write(key: _kMode, value: 'account');
    await _storage.write(key: _kBaseUrl, value: _normalizeBaseUrl(baseUrl));
    await _storage.write(key: _kUsername, value: username.trim());
    await _storage.write(key: _kAppPassword, value: appPassword.trim());
    await _storage.write(key: _kBasePath, value: _normalizePath(basePath));
  }

  static Future<void> saveLinkConfig({
    required String linkUrl,
    String linkPassword = '',
    String basePath = '',
  }) async {
    await _storage.write(key: _kMode, value: 'link');
    await _storage.write(key: _kLinkUrl, value: linkUrl.trim());
    await _storage.write(key: _kLinkPassword, value: linkPassword.trim());
    await _storage.write(key: _kBasePath, value: _normalizePath(basePath));
  }

  static Future<NextcloudConfig?> loadConfig() async {
    final mode = (await _storage.read(key: _kMode)) ?? 'account';
    final basePath = _normalizePath((await _storage.read(key: _kBasePath)) ?? '');
    if (mode == 'link') {
      final linkUrl = await _storage.read(key: _kLinkUrl);
      if (linkUrl == null || linkUrl.trim().isEmpty) return null;
      return NextcloudConfig(
        mode: NextcloudMode.link,
        linkUrl: linkUrl.trim(),
        linkPassword: (await _storage.read(key: _kLinkPassword)) ?? '',
        basePath: basePath,
      );
    }
    final baseUrl = await _storage.read(key: _kBaseUrl);
    final username = await _storage.read(key: _kUsername);
    final appPassword = await _storage.read(key: _kAppPassword);
    if (baseUrl == null ||
        username == null ||
        appPassword == null ||
        baseUrl.isEmpty ||
        username.isEmpty ||
        appPassword.isEmpty) {
      return null;
    }
    return NextcloudConfig(
      mode: NextcloudMode.account,
      baseUrl: baseUrl,
      username: username,
      appPassword: appPassword,
      basePath: basePath,
    );
  }

  static Future<bool> isConfigured() async => (await loadConfig()) != null;

  static Future<void> clearConfig() async {
    for (final k in [
      _kMode,
      _kBaseUrl,
      _kUsername,
      _kAppPassword,
      _kBasePath,
      _kLinkUrl,
      _kLinkPassword,
    ]) {
      await _storage.delete(key: k);
    }
  }

  static String _normalizeBaseUrl(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  /// Normaliseert een doelmap-pad: per segment opgeschoond, geen slashes om.
  static String _normalizePath(String raw) {
    return raw
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map(sanitizeSegment)
        .join('/');
  }

  // --- Mode-afhankelijke WebDAV-basis + auth ---

  static String _linkServerBase(String linkUrl) {
    final idx = linkUrl.indexOf('/s/');
    var base = idx >= 0 ? linkUrl.substring(0, idx) : linkUrl;
    if (base.endsWith('/index.php')) {
      base = base.substring(0, base.length - '/index.php'.length);
    }
    return _normalizeBaseUrl(base);
  }

  static String _linkToken(String linkUrl) {
    final idx = linkUrl.indexOf('/s/');
    if (idx < 0) return '';
    final rest = linkUrl.substring(idx + 3);
    return rest.split('/').first.split('?').first.trim();
  }

  static String _webdavRoot(NextcloudConfig cfg) {
    if (cfg.mode == NextcloudMode.link) {
      return '${_linkServerBase(cfg.linkUrl)}/public.php/webdav';
    }
    return '${cfg.baseUrl}/remote.php/dav/files/${Uri.encodeComponent(cfg.username)}';
  }

  static Map<String, String> _authHeaders(NextcloudConfig cfg) {
    final String user;
    final String pass;
    if (cfg.mode == NextcloudMode.link) {
      user = _linkToken(cfg.linkUrl);
      pass = cfg.linkPassword;
    } else {
      user = cfg.username;
      pass = cfg.appPassword;
    }
    final token = base64Encode(utf8.encode('$user:$pass'));
    return {'Authorization': 'Basic $token'};
  }

  static String _encodePath(String path) =>
      path.split('/').where((s) => s.isNotEmpty).map(Uri.encodeComponent).join('/');

  static String sanitizeSegment(String raw) {
    final value = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return value.isEmpty ? 'onbekend' : value;
  }

  /// Test of server + gegevens werken (WebDAV PROPFIND op de doelmap-root).
  static Future<bool> testConnection() async {
    _lastError = null;
    final cfg = await loadConfig();
    if (cfg == null) {
      _lastError = 'Geen Nextcloud-gegevens ingevuld.';
      return false;
    }
    if (cfg.mode == NextcloudMode.link && _linkToken(cfg.linkUrl).isEmpty) {
      _lastError = 'Ongeldige deellink — verwacht iets als https://server/s/AbC123';
      return false;
    }
    try {
      final uri = Uri.parse('${_webdavRoot(cfg)}/');
      final req = http.Request('PROPFIND', uri);
      req.headers.addAll(_authHeaders(cfg));
      req.headers['Depth'] = '0';
      final resp =
          await http.Client().send(req).timeout(const Duration(seconds: 20));
      await resp.stream.drain<void>();
      if (resp.statusCode == 207 || resp.statusCode == 200) {
        return true;
      }
      if (resp.statusCode == 401) {
        _lastError = cfg.mode == NextcloudMode.link
            ? 'Inloggen mislukt — klopt het link-wachtwoord (indien ingesteld)?'
            : 'Inloggen mislukt — controleer gebruiker en app-wachtwoord.';
        return false;
      }
      if (resp.statusCode == 404) {
        _lastError = 'WebDAV-pad niet gevonden — klopt de URL/link?';
        return false;
      }
      _lastError = 'Server gaf status ${resp.statusCode}.';
      return false;
    } catch (e) {
      _lastError = 'Kan de server niet bereiken: $e';
      return false;
    }
  }

  static Future<void> _ensureFolder(
    NextcloudConfig cfg,
    String webdavRoot,
    String folderPath,
  ) async {
    final segments =
        folderPath.split('/').where((s) => s.isNotEmpty).toList();
    var current = '';
    for (final seg in segments) {
      current = current.isEmpty ? seg : '$current/$seg';
      final uri = Uri.parse('$webdavRoot/${_encodePath(current)}');
      final req = http.Request('MKCOL', uri);
      req.headers.addAll(_authHeaders(cfg));
      final resp =
          await http.Client().send(req).timeout(const Duration(seconds: 30));
      await resp.stream.drain<void>();
      if (resp.statusCode != 201 &&
          resp.statusCode != 405 &&
          resp.statusCode != 200) {
        throw Exception('Map "$current" aanmaken mislukt (status ${resp.statusCode}).');
      }
    }
  }

  static Future<void> _putFile(
    NextcloudConfig cfg,
    String webdavRoot,
    File file,
    String remotePath,
  ) async {
    final uri = Uri.parse('$webdavRoot/${_encodePath(remotePath)}');
    final req = http.Request('PUT', uri)
      ..bodyBytes = await file.readAsBytes();
    req.headers.addAll(_authHeaders(cfg));
    final resp =
        await http.Client().send(req).timeout(const Duration(seconds: 120));
    await resp.stream.drain<void>();
    if (resp.statusCode != 201 &&
        resp.statusCode != 204 &&
        resp.statusCode != 200) {
      throw Exception('Upload "$remotePath" mislukt (status ${resp.statusCode}).');
    }
  }

  /// Maakt de dossiermap + standaard-submappen aan en uploadt de bestanden in
  /// de juiste submap. [filesBySubfolder] bv. {'EP': [xml, json, pdf...]}.
  static Future<NextcloudUploadResult> uploadDossier({
    required String rootFolderName,
    required Map<String, List<File>> filesBySubfolder,
    List<String> ensureSubfolders = const [],
  }) async {
    _lastError = null;
    final cfg = await loadConfig();
    final allFiles =
        filesBySubfolder.values.expand((files) => files).toList();
    if (cfg == null) {
      _lastError = 'Geen Nextcloud-gegevens ingevuld.';
      return NextcloudUploadResult(
        uploadedCount: 0,
        totalCount: allFiles.length,
        failedFiles: const [],
        message: _lastError,
      );
    }

    final webdavRoot = _webdavRoot(cfg);
    // rootFolderName mag meerdere segmenten bevatten (bv. "Lopend/1234AB ...").
    final safeRoot = _normalizePath(rootFolderName);
    final rootPath = cfg.basePath.isEmpty ? safeRoot : '${cfg.basePath}/$safeRoot';
    final targetUrl = '$webdavRoot/$rootPath';
    var uploaded = 0;
    final failed = <String>[];

    try {
      await _ensureFolder(cfg, webdavRoot, rootPath);
      final allSubfolders = <String>{
        ...filesBySubfolder.keys,
        ...ensureSubfolders,
      };
      for (final sub in allSubfolders) {
        await _ensureFolder(cfg, webdavRoot, '$rootPath/${sanitizeSegment(sub)}');
      }

      for (final entry in filesBySubfolder.entries) {
        final sub = sanitizeSegment(entry.key);
        for (final file in entry.value) {
          final name = file.path.split('/').last;
          try {
            await _putFile(cfg, webdavRoot, file, '$rootPath/$sub/$name');
            uploaded++;
          } catch (_) {
            failed.add(name);
          }
        }
      }
    } catch (e) {
      _lastError = e.toString();
      return NextcloudUploadResult(
        uploadedCount: uploaded,
        totalCount: allFiles.length,
        failedFiles: failed,
        message: e.toString(),
        targetUrl: targetUrl,
      );
    }

    return NextcloudUploadResult(
      uploadedCount: uploaded,
      totalCount: allFiles.length,
      failedFiles: failed,
      message: failed.isEmpty ? null : '${failed.length} bestand(en) mislukt.',
      targetUrl: targetUrl,
    );
  }
}

class NextcloudConfig {
  final NextcloudMode mode;
  final String baseUrl;
  final String username;
  final String appPassword;
  final String linkUrl;
  final String linkPassword;

  /// Optionele doelmap waaronder de dossiermappen komen (leeg = de gedeelde
  /// map zelf, of de hoofdmap bij account-modus).
  final String basePath;

  const NextcloudConfig({
    required this.mode,
    this.baseUrl = '',
    this.username = '',
    this.appPassword = '',
    this.linkUrl = '',
    this.linkPassword = '',
    this.basePath = '',
  });
}
