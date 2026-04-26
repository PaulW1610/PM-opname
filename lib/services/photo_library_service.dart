import 'dart:io';

import 'package:gallery_saver/gallery_saver.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class PhotoLibraryService {
  static const MethodChannel _photoChannel =
      MethodChannel('photo_library_channel');

  static Future<void> saveImageToAddressAlbum({
    required String imagePath,
    required String addressAlbumName,
    String? photoFilePrefix,
    int? photoSequenceNumber,
  }) async {
    final photosPermission = await Permission.photos.status;
    if (!photosPermission.isGranted && !photosPermission.isLimited) {
      throw Exception('Geen toegang tot Foto\'s. Geef toestemming in Instellingen.');
    }

    final albumName = _sanitizeAlbumName(addressAlbumName);
    final targetPath = await _prepareImagePathForSave(
      imagePath: imagePath,
      photoFilePrefix: photoFilePrefix,
      photoSequenceNumber: photoSequenceNumber,
    );
    if (Platform.isIOS) {
      try {
        final fileName = targetPath.split('/').last;
        final saved = await _photoChannel.invokeMethod<bool>(
          'saveImageWithFilename',
          <String, dynamic>{
            'imagePath': targetPath,
            'albumName': albumName,
            'fileName': fileName,
          },
        );
        if (saved != true) {
          throw Exception('Opslaan in iOS Foto\'s is mislukt.');
        }
        return;
      } on MissingPluginException {
        // Fallback keeps photo capture working even if iOS channel is not ready.
      } on PlatformException {
        // Fallback for runtime channel errors.
      }
    }

    final result = await GallerySaver.saveImage(
      targetPath,
      albumName: albumName,
    );

    if (result != true) {
      throw Exception('Opslaan in iCloud Foto\'s is mislukt.');
    }

  }

  static Future<String> _prepareImagePathForSave({
    required String imagePath,
    String? photoFilePrefix,
    int? photoSequenceNumber,
  }) async {
    final prefix = _sanitizeFilePrefix(photoFilePrefix ?? 'foto');
    final number = photoSequenceNumber;
    if (number == null || number < 1) {
      return imagePath;
    }

    final source = File(imagePath);
    if (!await source.exists()) {
      return imagePath;
    }

    final extensionMatch = RegExp(r'\.[A-Za-z0-9]+$').firstMatch(imagePath);
    final extension = extensionMatch?.group(0)?.toLowerCase() ?? '.jpg';
    final fileName = '${prefix}_${number.toString().padLeft(4, '0')}$extension';

    final tmpDir = await getTemporaryDirectory();
    final renamedCopy = File('${tmpDir.path}/$fileName');
    await source.copy(renamedCopy.path);
    return renamedCopy.path;
  }

  static String _sanitizeAlbumName(String raw) {
    final sanitized = raw
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    if (sanitized.isEmpty) {
      return 'Onbekend adres';
    }
    return sanitized;
  }

  static String _sanitizeFilePrefix(String raw) {
    final sanitized = raw
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    if (sanitized.isEmpty) {
      return 'foto';
    }
    return sanitized;
  }
}
