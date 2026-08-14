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

  /// Compacte, machineleesbare vorm van een fotolabel voor in de bestandsnaam.
  /// Bv. "CV plaatje" → "CVPLAATJE", "HR++ Glas" → "HRPPGLAS". Zo kan de
  /// pc-keten het toestel/onderdeel uit de bestandsnaam lezen zonder de foto te
  /// hoeven analyseren.
  static String labelForFilename(String label) {
    final upper = label.toUpperCase().replaceAll('+', 'P');
    return upper.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// Leest het label (compacte code) terug uit een bestandsnaam die met
  /// [savePhoto] is gemaakt: `<prefix>_<0000>_<LABEL>.<ext>`. Geeft null als er
  /// geen label in de naam staat (oude foto's).
  static String? labelFromFilename(String path) {
    final base = path.split('/').last;
    final noExt = base.replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '');
    final parts = noExt.split('_');
    if (parts.length < 3) return null;
    final last = parts[parts.length - 1];
    final beforeLast = parts[parts.length - 2];
    // Het label is het laatste segment als het segment ervoor de 4-cijferige
    // volgnummer is (en het label zelf niet weer een volgnummer is).
    if (RegExp(r'^\d{4}$').hasMatch(beforeLast) &&
        !RegExp(r'^\d{4}$').hasMatch(last) &&
        last.isNotEmpty) {
      return last;
    }
    return null;
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
    String label = '',
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    final dir = await _dirForPrefix(prefix);
    final extMatch = RegExp(r'\.[A-Za-z0-9]+$').firstMatch(sourcePath);
    final ext = extMatch?.group(0)?.toLowerCase() ?? '.jpg';
    final seq = sequenceNumber.toString().padLeft(4, '0');
    final labelDeel = labelForFilename(label);
    final name = labelDeel.isEmpty
        ? '${_safe(prefix)}_$seq$ext'
        : '${_safe(prefix)}_${seq}_$labelDeel$ext';
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
