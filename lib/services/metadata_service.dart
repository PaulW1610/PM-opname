import 'dart:io';
import 'package:intl/intl.dart';
import 'bag_service.dart';

/// Service to generate XML metadata files with BAG data.
///
/// Creates XML files that contain location info and photo metadata
/// for each photo session.
class MetadataService {
  /// Generate and save XML metadata for a photo session.
  static Future<void> generateSessionMetadata({
    required BagData bagData,
    required String category,
    required String folderPath,
    List<String> photoFilenames = const [],
  }) async {
    try {
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final fileName = 'metadata_${DateTime.now().millisecondsSinceEpoch}.xml';
      final filePath = '$folderPath\\$fileName';

      // Build photo entries XML
      final photoEntries = photoFilenames.map((filename) {
        return '''    <PhotoEntry>
      <FileName>$filename</FileName>
      <Type>${filename.split('_')[1] ?? 'Unknown'}</Type>
      <Timestamp>$timestamp</Timestamp>
      <FilePath>$folderPath\\$filename</FilePath>
    </PhotoEntry>''';
      }).join('\n');

      // Prepare XML content with BAG data
      final xmlContent = '''<?xml version="1.0" encoding="utf-8"?>
<PhotoOrganizer>
  <SessionInfo>
    <CreatedDate>$timestamp</CreatedDate>
    <PhotoCategory>$category</PhotoCategory>
  </SessionInfo>
  
  <LocationData>
    <Plaatsnaam>${bagData.plaatsnaam}</Plaatsnaam>
    <Postcode>${bagData.postcode}</Postcode>
    <OorspronkelijkBouwjaar>${bagData.oorspronkelijkBouwjaar ?? 'N/A'}</OorspronkelijkBouwjaar>
    <Gebruiksdoel>${bagData.gebruiksdoel ?? 'N/A'}</Gebruiksdoel>
  </LocationData>
  
  <Photos>
$photoEntries
  </Photos>
  
  <FolderStructure>
    <BasePath>C:\\Users\\Public\\Pictures\\PhotoOrganizer</BasePath>
    <CategoryFolder>$category</CategoryFolder>
    <AddressFolder>${bagData.getFolderName()}</AddressFolder>
  </FolderStructure>
</PhotoOrganizer>
''';

      // Write XML file
      final file = File(filePath);
      await file.writeAsString(xmlContent);
    } catch (e) {
      print('Error generating metadata: $e');
    }
  }

  /// Add a photo entry to existing XML metadata.
  static Future<void> addPhotoToMetadata({
    required String metadataPath,
    required String photoFilename,
    required String photoType,
  }) async {
    try {
      final file = File(metadataPath);
      if (!file.existsSync()) return;

      final content = await file.readAsString();
      final timestamp =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final newEntry = '''    <PhotoEntry>
      <FileName>$photoFilename</FileName>
      <Type>$photoType</Type>
      <Timestamp>$timestamp</Timestamp>
      <FilePath>${metadataPath.replaceAll('\\metadata', '')}\\$photoFilename</FilePath>
    </PhotoEntry>
''';

      // Insert new entry before closing Photos tag
      final updated =
          content.replaceFirst('  </Photos>', '$newEntry  </Photos>');
      await file.writeAsString(updated);
    } catch (e) {
      print('Error adding photo to metadata: $e');
    }
  }
}
