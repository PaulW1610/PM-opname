import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/bag_service.dart';

/// Screen for tagging photos with building types (Utiliteit category).
///
/// Users pick a photo and tag it with building type for utility analysis.
class UtiiteitScreen extends StatefulWidget {
  /// The fetched BAG address data for the current location.
  final BagData bagData;

  /// Create a Utiliteit photo tagging screen.
  const UtiiteitScreen({Key? key, required this.bagData}) : super(key: key);

  @override
  State<UtiiteitScreen> createState() => _UtiiteitScreenState();
}

class _UtiiteitScreenState extends State<UtiiteitScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;
  String? _selectedBuildingType;

  /// Pick a photo from device storage.
  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _selectedBuildingType = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fout bij selecteren foto')),
      );
    }
  }

  /// Save the selected image with building type using the provided address.
  Future<void> _saveWithBuildingType(String buildingType) async {
    if (_selectedImage == null) return;

    try {
      // Show loading dialog
      showDialog<void>(
        context: context,
        builder: (c) => const AlertDialog(
          content: SizedBox(
            height: 72,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );

      // Use the provided BAG data (already fetched on start screen)
      final bagData = widget.bagData;

      // Create folder with category + address + postcode
      final baseDir = Directory('C:\\Users\\Public\\Pictures\\PhotoOrganizer');
      final folderName = bagData.getFolderName();
      final categoryFolder = '${baseDir.path}\\Utiliteit\\$folderName';
      final appDir = Directory(categoryFolder);
      await appDir.create(recursive: true);

      // Save photo with building type name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newPath =
          '${appDir.path}\\photo_${buildingType.replaceAll(' ', '_')}_$timestamp.jpg';
      await File(_selectedImage!.path).copy(newPath);

      Navigator.pop(context); // close loading

      setState(() {
        _selectedBuildingType = buildingType;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Foto opgeslagen!\n'
            'Type: $buildingType\n'
            'Locatie: ${bagData.getFolderName()}',
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij opslaan: $e')),
      );
    }
  }

  /// Build building type button with consistent styling.
  Widget _buildBuildingButton(String buildingType) {
    final isSelected = _selectedBuildingType == buildingType;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Colors.green : Colors.grey[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          onPressed: () => _saveWithBuildingType(buildingType),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check, size: 16),
              const SizedBox(height: 2),
              Text(
                buildingType,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Utiliteit - Gebouwtype')),
      body: Column(
        children: [
          // Preview of selected image or empty state
          Expanded(
            child: _selectedImage != null
                ? Image.file(File(_selectedImage!.path), fit: BoxFit.cover)
                : const Center(
                    child: Text('Geen foto geselecteerd'),
                  ),
          ),
          // Building type selection buttons
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedBuildingType != null)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Geselecteerd: $_selectedBuildingType',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      _buildBuildingButton('Gezondheid'),
                      _buildBuildingButton('Hotel'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildBuildingButton('Kantoor'),
                      _buildBuildingButton('Winkel'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildBuildingButton('Hulpfunctie'),
                    ],
                  ),
                ],
              ),
            ),
          // Pick image button
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Foto Selecteren'),
              onPressed: _pickImage,
            ),
          ),
        ],
      ),
    );
  }
}
