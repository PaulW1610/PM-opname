import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/app_secrets.dart';

class DropboxUploadResult {
  final int uploadedCount;
  final int totalCount;
  final List<String> failedFiles;
  final String? message;

  const DropboxUploadResult({
    required this.uploadedCount,
    required this.totalCount,
    required this.failedFiles,
    this.message,
  });

  bool get isSuccess => uploadedCount == totalCount && failedFiles.isEmpty;
}

/// Dropbox OAuth 2 / PKCE service and file-upload helper.
///
/// Setup (one-time):
/// 1. Create a Dropbox app at https://www.dropbox.com/developers/apps
///    - Permission type: "Scoped access" → "App folder" (eigen app-map)
///    - OR "Full Dropbox" als je een custom pad wilt
/// 2. Under "OAuth 2" in your app settings, add redirect URI:
///      nl.paulweijers.photoorganizerapp://dropbox-auth
/// 3. Copy your App key and paste it below as [_kAppKey].
class DropboxService {
  // App key wordt meegegeven via --dart-define (DROPBOX_APP_KEY), zie AppSecrets.
  static const String _kAppKey = AppSecrets.dropboxAppKey;

  static const String _kRedirectUri =
      'nl.paulweijers.photoorganizerapp://dropbox-auth';

  static const String _kAccessTokenKey = 'dropbox_access_token_v1';
  static const String _kRefreshTokenKey = 'dropbox_refresh_token_v1';
  static const String _kCodeVerifierKey = 'dropbox_pkce_verifier_v1';
  static const String _kGrantedScopeKey = 'dropbox_granted_scope_v1';
  static const List<String> _requiredScopes = <String>[
    'account_info.read',
    'files.metadata.read',
    'files.content.read',
    'files.content.write',
  ];

  static const _storage = FlutterSecureStorage();

  static String? _lastError;

  static String? get lastError => _lastError;

  static void _setLastError(String? message) {
    _lastError = message?.trim().isEmpty ?? true ? null : message?.trim();
  }

  static String _extractDropboxErrorSummary(String rawBody) {
    final body = rawBody.trim();
    if (body.isEmpty) {
      return 'onbekende fout';
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final summary = decoded['error_summary']?.toString().trim();
        if (summary != null && summary.isNotEmpty) {
          return summary;
        }
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final tag = error['.tag']?.toString().trim();
          if (tag != null && tag.isNotEmpty) {
            return tag;
          }
        }
      }
    } catch (_) {}
    return body;
  }

  static bool _hasAllRequiredScopes(String? grantedScope) {
    if (grantedScope == null || grantedScope.trim().isEmpty) {
      return false;
    }
    final granted = grantedScope
        .split(RegExp(r'\s+'))
        .where((item) => item.trim().isNotEmpty)
        .toSet();
    return _requiredScopes.every(granted.contains);
  }

  static String _missingScopeMessage([String? detail]) {
    final suffix = (detail != null && detail.trim().isNotEmpty)
        ? ' ($detail)'
        : '';
    return 'Dropbox is wel gekoppeld, maar mist uploadrechten$suffix. Zet in de Dropbox App Console de permissie files.content.write aan en verbind Dropbox daarna opnieuw.';
  }

  // ── PKCE helpers ─────────────────────────────────────────────────────────────

  static String _generateVerifier() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String _challenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  // ── Auth flow ─────────────────────────────────────────────────────────────────

  /// Builds the Dropbox OAuth 2 / PKCE authorization URL and stores the code
  /// verifier in secure storage so it survives app backgrounding.
  static Future<String> buildAuthUrl() async {
    final verifier = _generateVerifier();
    await _storage.write(key: _kCodeVerifierKey, value: verifier);
    final params = {
      'client_id': _kAppKey,
      'response_type': 'code',
      'code_challenge': _challenge(verifier),
      'code_challenge_method': 'S256',
      'redirect_uri': _kRedirectUri,
      'token_access_type': 'offline',
      'scope': _requiredScopes.join(' '),
      'include_granted_scopes': 'user',
      'force_reapprove': 'true',
    };
    return Uri.https('www.dropbox.com', '/oauth2/authorize', params).toString();
  }

  /// Exchanges the authorization code from [callbackUri] for access + refresh
  /// tokens. Returns true on success.
  static Future<bool> handleAuthCallback(Uri callbackUri) async {
    final code = callbackUri.queryParameters['code'];
    if (code == null || code.isEmpty) return false;

    final verifier = await _storage.read(key: _kCodeVerifierKey);
    if (verifier == null) return false;
    await _storage.delete(key: _kCodeVerifierKey);

    try {
      final response = await http.post(
        Uri.parse('https://api.dropboxapi.com/oauth2/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': code,
          'grant_type': 'authorization_code',
          'client_id': _kAppKey,
          'redirect_uri': _kRedirectUri,
          'code_verifier': verifier,
        },
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        await _storage.write(
          key: _kAccessTokenKey,
          value: json['access_token'] as String,
        );
        final refresh = json['refresh_token'] as String?;
        if (refresh != null) {
          await _storage.write(key: _kRefreshTokenKey, value: refresh);
        }
        final grantedScope = json['scope'] as String?;
        if (grantedScope != null && grantedScope.trim().isNotEmpty) {
          await _storage.write(key: _kGrantedScopeKey, value: grantedScope.trim());
        }
        final validated = await validateConnection();
        if (!validated) {
          await disconnect();
        }
        return validated;
      }
      _setLastError(
        'Dropbox OAuth mislukt (${response.statusCode}): ${_extractDropboxErrorSummary(response.body)}',
      );
      return false;
    } catch (error) {
      _setLastError('Dropbox OAuth exceptie: $error');
      return false;
    }
  }

  // ── Connection status ─────────────────────────────────────────────────────────

  static Future<bool> isConnected() async {
    return validateConnection();
  }

  static Future<bool> validateConnection() async {
    final token = await _storage.read(key: _kAccessTokenKey);
    if (token == null || token.isEmpty) {
      _setLastError('Geen Dropbox access token gevonden.');
      return false;
    }

    Future<http.Response> requestWithToken(String accessToken) {
      return http.post(
        Uri.parse('https://api.dropboxapi.com/2/users/get_current_account'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: 'null',
      );
    }

    try {
      var response = await requestWithToken(token);
      if (response.statusCode == 200) {
        final canUpload = await validateUploadAccess();
        if (!canUpload) {
          return false;
        }
        _setLastError(null);
        return true;
      }
      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed == null) {
          _setLastError('Dropbox token verlopen en refresh mislukt.');
          return false;
        }
        response = await requestWithToken(refreshed);
        if (response.statusCode == 200) {
          final canUpload = await validateUploadAccess();
          if (!canUpload) {
            return false;
          }
          _setLastError(null);
          return true;
        }
      }
      _setLastError(
        'Dropbox verbinding ongeldig (${response.statusCode}): ${_extractDropboxErrorSummary(response.body)}',
      );
      return false;
    } catch (error) {
      _setLastError('Dropbox verbindingstest exceptie: $error');
      return false;
    }
  }

  static Future<bool> validateUploadAccess() async {
    final token = await _storage.read(key: _kAccessTokenKey);
    if (token == null || token.isEmpty) {
      _setLastError('Geen Dropbox access token gevonden.');
      return false;
    }

    final grantedScope = await _storage.read(key: _kGrantedScopeKey);
    if (grantedScope != null && grantedScope.trim().isNotEmpty) {
      if (!_hasAllRequiredScopes(grantedScope)) {
        _setLastError(_missingScopeMessage(grantedScope));
        return false;
      }
    }

    Future<http.Response> requestWithToken(String accessToken) {
      return http.post(
        Uri.parse('https://api.dropboxapi.com/2/files/get_temporary_upload_link'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'commit_info': {
            'path': '/upload_permission_probe.txt',
            'mode': 'add',
            'autorename': true,
            'mute': true,
          },
          'duration': 60,
        }),
      );
    }

    try {
      var response = await requestWithToken(token);
      if (response.statusCode == 200) {
        _setLastError(null);
        return true;
      }
      if (response.statusCode == 401) {
        final refreshed = await _refreshAccessToken();
        if (refreshed == null) {
          _setLastError('Dropbox token verlopen en refresh mislukt.');
          return false;
        }
        response = await requestWithToken(refreshed);
        if (response.statusCode == 200) {
          _setLastError(null);
          return true;
        }
      }

      final detail = _extractDropboxErrorSummary(response.body);
      if (response.statusCode == 403 ||
          detail.contains('missing_scope') ||
          detail.contains('insufficient_scope') ||
          detail.contains('no_permission')) {
        _setLastError(_missingScopeMessage(detail));
        return false;
      }

      _setLastError(
        'Dropbox uploadcheck mislukt (${response.statusCode}): $detail',
      );
      return false;
    } catch (error) {
      _setLastError('Dropbox uploadcheck exceptie: $error');
      return false;
    }
  }

  static Future<void> disconnect() async {
    final token = await _storage.read(key: _kAccessTokenKey);
    if (token != null) {
      try {
        await http.post(
          Uri.parse('https://api.dropboxapi.com/2/auth/token/revoke'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } catch (_) {}
    }
    await _storage.delete(key: _kAccessTokenKey);
    await _storage.delete(key: _kRefreshTokenKey);
    await _storage.delete(key: _kCodeVerifierKey);
    await _storage.delete(key: _kGrantedScopeKey);
    _setLastError(null);
  }

  // ── File upload ───────────────────────────────────────────────────────────────

  static String _sanitizeDropboxSegment(String raw) {
    final cleaned = raw
        .replaceAll('\\', '_')
        .replaceAll('/', '_')
        .replaceAll(':', '_')
        .replaceAll('*', '_')
        .replaceAll('?', '_')
        .replaceAll('"', '_')
        .replaceAll('<', '_')
        .replaceAll('>', '_')
        .replaceAll('|', '_')
        .trim();
    return cleaned.isEmpty ? 'Onbekend' : cleaned;
  }

  static String _asciiSafeDropboxName(String raw, {required String fallback}) {
    final normalized = _sanitizeDropboxSegment(raw)
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    return normalized.isEmpty ? fallback : normalized;
  }

  static String _buildFlatDropboxPath({
    required String addressFolderName,
    required String fileName,
  }) {
    final safeAddress = _asciiSafeDropboxName(
      addressFolderName,
      fallback: 'adres',
    );
    final safeFileName = _asciiSafeDropboxName(
      fileName,
      fallback: 'bestand.dat',
    );
    return '/${safeAddress}__${safeFileName}';
  }

  static String _buildFallbackDropboxPath({
    required String fileName,
    required int index,
  }) {
    final extMatch = RegExp(r'(\.[A-Za-z0-9]+)$').firstMatch(fileName);
    final ext = extMatch?.group(1)?.toLowerCase() ?? '.dat';
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return '/upload_${stamp}_${index.toString().padLeft(2, '0')}$ext';
  }

  /// Uploads [file] to [dropboxPath] in the Dropbox app folder.
  /// Returns true on success; retries once with a refreshed token on 401.
  static Future<bool> uploadFile(File file, String dropboxPath) async {
    final token = await _storage.read(key: _kAccessTokenKey);
    if (token == null) return false;

    final status = await _doUpload(file, dropboxPath, token);
    if (status == 401) {
      final refreshed = await _refreshAccessToken();
      if (refreshed == null) return false;
      return await _doUpload(file, dropboxPath, refreshed) == 200;
    }
    return status == 200;
  }

  static Future<int> _doUpload(
    File file,
    String dropboxPath,
    String token,
  ) async {
    try {
      final bytes = await file.readAsBytes();
      final response = await http.post(
        Uri.parse('https://content.dropboxapi.com/2/files/upload'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/octet-stream',
          'Dropbox-API-Arg': jsonEncode({
            'path': dropboxPath,
            'mode': 'overwrite',
            'autorename': false,
            'mute': false,
          }),
        },
        body: bytes,
      );
      if (response.statusCode != 200) {
        final detail = _extractDropboxErrorSummary(response.body);
        if (response.statusCode == 403 ||
            detail.contains('missing_scope') ||
            detail.contains('insufficient_scope') ||
            detail.contains('no_permission')) {
          _setLastError(_missingScopeMessage(detail));
        } else {
          _setLastError(
            'Dropbox upload mislukt voor $dropboxPath (${response.statusCode}): $detail',
          );
        }
      } else {
        _setLastError(null);
      }
      return response.statusCode;
    } catch (error) {
      _setLastError('Dropbox upload exceptie voor $dropboxPath: $error');
      return 500;
    }
  }

  static Future<String?> _refreshAccessToken() async {
    final refresh = await _storage.read(key: _kRefreshTokenKey);
    if (refresh == null) return null;
    try {
      final response = await http.post(
        Uri.parse('https://api.dropboxapi.com/oauth2/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refresh,
          'client_id': _kAppKey,
        },
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final newToken = json['access_token'] as String;
        await _storage.write(key: _kAccessTokenKey, value: newToken);
        _setLastError(null);
        return newToken;
      }
      _setLastError(
        'Dropbox token refresh mislukt (${response.statusCode}): ${_extractDropboxErrorSummary(response.body)}',
      );
      return null;
    } catch (error) {
      _setLastError('Dropbox token refresh exceptie: $error');
      return null;
    }
  }

  /// Uploads each file in [files] directly into the Dropbox app folder.
  /// Bestandsnamen krijgen een adresprefix zodat ze gegroepeerd blijven.
  static Future<DropboxUploadResult> uploadDossierFiles({
    required String addressFolderName,
    required List<File> files,
  }) async {
    int uploaded = 0;
    final failedFiles = <String>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      if (!await file.exists()) {
        failedFiles.add(file.path.split('/').last);
        _setLastError('Bestand bestaat niet meer: ${file.path}');
        continue;
      }
      final name = file.path.split('/').last;
      final dropboxPath = _buildFlatDropboxPath(
        addressFolderName: addressFolderName,
        fileName: name,
      );
      if (await uploadFile(file, dropboxPath)) {
        uploaded++;
      } else {
        // Fallback naar een korte, veilige bestandsnaam als Dropbox het pad afwijst.
        final fallbackPath = _buildFallbackDropboxPath(
          fileName: name,
          index: i + 1,
        );
        if (await uploadFile(file, fallbackPath)) {
          uploaded++;
        } else {
          failedFiles.add(name);
        }
      }
    }
    return DropboxUploadResult(
      uploadedCount: uploaded,
      totalCount: files.length,
      failedFiles: failedFiles,
      message: failedFiles.isEmpty ? null : lastError,
    );
  }
}
