import 'package:gallery_saver/gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

class PhotoLibraryService {
  static Future<void> saveImageToAddressAlbum({
    required String imagePath,
    required String addressAlbumName,
  }) async {
    final photosPermission = await Permission.photos.status;
    if (!photosPermission.isGranted && !photosPermission.isLimited) {
      throw Exception('Geen toegang tot Foto\'s. Geef toestemming in Instellingen.');
    }

    final albumName = _sanitizeAlbumName(addressAlbumName);
    final result = await GallerySaver.saveImage(
      imagePath,
      albumName: albumName,
    );

    if (result != true) {
      throw Exception('Opslaan in iCloud Foto\'s is mislukt.');
    }

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
}
