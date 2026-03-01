import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/bag_service.dart';
import 'wonen_screen.dart';
import 'utiliteit_screen.dart';
import 'wws_punten_screen.dart';

/// Screen to select photo category (Wonen or Utiliteit).
///
/// After fetching the address, users choose which photo category
/// to start tagging photos for.
class PhotoSelectionScreen extends StatefulWidget {
  /// The fetched BAG address data for the current location.
  final BagData bagData;
  final int initialPhotoCount;

  /// Create photo selection screen with address data.
  const PhotoSelectionScreen({
    Key? key,
    required this.bagData,
    this.initialPhotoCount = 0,
  })
      : super(key: key);

  @override
  State<PhotoSelectionScreen> createState() => _PhotoSelectionScreenState();
}

class _PhotoSelectionScreenState extends State<PhotoSelectionScreen> {
  late final TextEditingController _albumNameController;
  int _capturedPhotoCount = 0;

  @override
  void initState() {
    super.initState();
    _albumNameController = TextEditingController(
      text: widget.bagData.getFolderName(),
    );
    _capturedPhotoCount = widget.initialPhotoCount;
  }

  String _currentAlbumName() {
    final value = _albumNameController.text.trim();
    final source = value.isEmpty ? widget.bagData.getFolderName() : value;
    final sanitized = source
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    return sanitized.isEmpty ? 'Onbekend adres' : sanitized;
  }

  @override
  void dispose() {
    _albumNameController.dispose();
    super.dispose();
  }

  Future<bool> _ensurePhotosPermission() async {
    final status = await Permission.photos.request();
    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status.isPermanentlyDenied || status.isDenied || status.isRestricted) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Toestemming nodig'),
          content: const Text(
            'Foto\'s-toestemming ontbreekt. '
            'Open Instellingen om opslag in iCloud/Foto\'s toe te staan.',
          ),
          actions: [
            TextButton(
              onPressed: () => openAppSettings(),
              child: const Text('Open Instellingen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Sluiten'),
            ),
          ],
        ),
      );
    }

    return false;
  }

  Future<void> _requestCameraAndOpen(Widget Function(VoidCallback onPhotoSaved) builder) async {
    final hasPhotosPermission = await _ensurePhotosPermission();
    if (!hasPhotosPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto\'s-toestemming geweigerd')),
      );
      return;
    }

    final status = await Permission.camera.request();
    if (status.isGranted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => builder(() {
            if (!mounted) return;
            setState(() {
              _capturedPhotoCount += 1;
            });
          }),
        ),
      );
      return;
    }

    if (status.isPermanentlyDenied || status.isDenied || status.isRestricted) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Toestemming nodig'),
          content: const Text(
            'Camera-toestemming ontbreekt. '
            'Open Instellingen om toegang te geven.',
          ),
          actions: [
            TextButton(
              onPressed: () => openAppSettings(),
              child: const Text('Open Instellingen'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Sluiten'),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Camera-toestemming geweigerd')),
    );
  }

  /// Request camera permission and open Wonen screen.
  Future<void> _openWonen(BuildContext context) async {
    await _requestCameraAndOpen(
      (onPhotoSaved) => WonenScreen(
        bagData: widget.bagData,
        albumName: _currentAlbumName(),
        onPhotoSaved: onPhotoSaved,
      ),
    );
  }

  /// Request camera permission and open Utiliteit screen.
  Future<void> _openUtiliteit(BuildContext context) async {
    await _requestCameraAndOpen(
      (onPhotoSaved) => UtiiteitScreen(
        bagData: widget.bagData,
        albumName: _currentAlbumName(),
        onPhotoSaved: onPhotoSaved,
      ),
    );
  }

  /// Request camera permission and open WWS Punten screen.
  Future<void> _openWwsPunten(BuildContext context) async {
    await _requestCameraAndOpen(
      (onPhotoSaved) => WwsPuntenScreen(
        bagData: widget.bagData,
        albumName: _currentAlbumName(),
        onPhotoSaved: onPhotoSaved,
      ),
    );
  }

  Future<bool> _onWillPop() async {
    Navigator.of(context).pop(_capturedPhotoCount);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Selecteer categorie'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_capturedPhotoCount),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Adres-album: ${widget.bagData.getFolderName()}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                'Foto\'s gemaakt: $_capturedPhotoCount',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _albumNameController,
                  decoration: const InputDecoration(
                    labelText: 'Mapnaam aanpassen',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.home),
                label: const Text('Categorie: Wonen'),
                onPressed: () => _openWonen(context),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.business),
                label: const Text('Categorie: Utiliteit'),
                onPressed: () => _openUtiliteit(context),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.location_city),
                label: const Text('Categorie: WWS Punten'),
                onPressed: () => _openWwsPunten(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
