import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/bag_service.dart';

/// Screen for tagging photos with glass types (Wonen category).
///
/// Users pick a photo and tag it with glass type for residential analysis.
class WonenScreen extends StatefulWidget {
  /// The fetched BAG address data for the current location.
  final BagData bagData;

  /// Create a Wonen photo tagging screen.
  const WonenScreen({Key? key, required this.bagData}) : super(key: key);

  @override
  State<WonenScreen> createState() => _WonenScreenState();
}

class _WonenScreenState extends State<WonenScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;
  String? _selectedGlassType;
  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _selectedGlassType = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fout bij selecteren foto')),
      );
    }
  }

  /// Save the selected image with glass type using the provided address.
  Future<void> _saveWithGlassType(String glassType) async {
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
      final categoryFolder = '${baseDir.path}\\Wonen\\$folderName';
      final appDir = Directory(categoryFolder);
      await appDir.create(recursive: true);

      // Save photo with glass type name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newPath =
          '${appDir.path}\\photo_${glassType.replaceAll(' ', '_')}_$timestamp.jpg';
      await File(_selectedImage!.path).copy(newPath);

      Navigator.pop(context); // close loading

      setState(() {
        _selectedGlassType = glassType;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Foto opgeslagen!\n'
            'Type: $glassType\n'
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

  /// Build glass type button with consistent styling.
  Widget _buildGlassButton(String glassType) {
    final isSelected = _selectedGlassType == glassType;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Colors.blue : Colors.grey[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          onPressed: () => _saveWithGlassType(glassType),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check, size: 16),
              const SizedBox(height: 2),
              Text(
                glassType,
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
      appBar: AppBar(title: const Text('Wonen - Glassoort')),
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
          // Glass type selection buttons
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedGlassType != null)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Geselecteerd: $_selectedGlassType',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      _buildGlassButton('Enkel Glas'),
                      _buildGlassButton('Dubbel Glas'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildGlassButton('HR Glas'),
                      _buildGlassButton('HR+ Glas'),
                      _buildGlassButton('HR++ Glas'),
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
