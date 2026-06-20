import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Bewaart gemaakte foto's lokaal als bestand (naast iOS Foto's), zodat ze
/// later naar Nextcloud (map foto's/) geüpload kunnen worden.
///
/// Gegroepeerd op de foto-prefix van het adres (stabiel en hetzelfde in zowel
/// het camerascherm als het afsluitscherm).
class DossierPhotoStore {
  static String _safe(String raw) {
    final s = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return s.isEmpty ? 'onbekend' : s;
  }

  static Future<Directory> _dirForPrefix(String prefix) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/fotos_cache/${_safe(prefix)}');
    await dir.create(recursive: true);
    return dir;
  }

  /// Bewaar een kopie van [sourcePath] onder de gegeven adres-prefix.
  /// Geeft het opgeslagen bestand terug (of null als de bron niet bestaat).
  static Future<File?> savePhoto({
    required String sourcePath,
    required String prefix,
    required int sequenceNumber,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    final dir = await _dirForPrefix(prefix);
    final extMatch = RegExp(r'\.[A-Za-z0-9]+$').firstMatch(sourcePath);
    final ext = extMatch?.group(0)?.toLowerCase() ?? '.jpg';
    final name = '${_safe(prefix)}_${sequenceNumber.toString().padLeft(4, '0')}$ext';
    return source.copy('${dir.path}/$name');
  }

  /// Alle lokaal bewaarde foto's voor deze adres-prefix (op naam gesorteerd).
  static Future<List<File>> photosForPrefix(String prefix) async {
    final dir = await _dirForPrefix(prefix);
    if (!await dir.exists()) return const [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => RegExp(r'\.(jpe?g|png)$', caseSensitive: false)
            .hasMatch(f.path))
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }
}
