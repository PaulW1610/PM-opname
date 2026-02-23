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
class PhotoSelectionScreen extends StatelessWidget {
  /// The fetched BAG address data for the current location.
  final BagData bagData;

  /// Create photo selection screen with address data.
  const PhotoSelectionScreen({Key? key, required this.bagData})
      : super(key: key);

  /// Request camera permission and open Wonen screen.
  Future<void> _openWonen(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WonenScreen(bagData: bagData),
        ),
      );
      return;
    }

    if (status.isPermanentlyDenied) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Permission required'),
          content: const Text(
            'Camera permission is permanently denied. '
            'Open settings to enable it.',
          ),
          actions: [
            TextButton(
              onPressed: () => openAppSettings(),
              child: const Text('Open Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Camera permission denied')),
    );
  }

  /// Request camera permission and open Utiliteit screen.
  Future<void> _openUtiliteit(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UtiiteitScreen(bagData: bagData),
        ),
      );
      return;
    }

    if (status.isPermanentlyDenied) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Permission required'),
          content: const Text(
            'Camera permission is permanently denied. '
            'Open settings to enable it.',
          ),
          actions: [
            TextButton(
              onPressed: () => openAppSettings(),
              child: const Text('Open Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Camera permission denied')),
    );
  }

  /// Request camera permission and open WWS Punten screen.
  Future<void> _openWwsPunten(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WwsPuntenScreen(bagData: bagData),
        ),
      );
      return;
    }

    if (status.isPermanentlyDenied) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Permission required'),
          content: const Text(
            'Camera permission is permanently denied. '
            'Open settings to enable it.',
          ),
          actions: [
            TextButton(
              onPressed: () => openAppSettings(),
              child: const Text('Open Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Camera permission denied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Foto\'s - Selecteer Type')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Locatie: ${bagData.getFolderName()}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.home),
              label: const Text('Foto\'s - Wonen'),
              onPressed: () => _openWonen(context),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.business),
              label: const Text('Foto\'s - Utiliteit'),
              onPressed: () => _openUtiliteit(context),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.location_city),
              label: const Text('Foto\'s - WWS Punten'),
              onPressed: () => _openWwsPunten(context),
            ),
          ],
        ),
      ),
    );
  }
}
