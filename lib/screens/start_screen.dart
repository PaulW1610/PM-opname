import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/bag_service.dart';
import '../services/location_service.dart';
import 'photo_selection_screen.dart';

/// Start screen to fetch current location and building address.
///
/// Users retrieve their address via GPS + BAG lookup before selecting
/// photo category (Wonen or Utiliteit).
class StartScreen extends StatefulWidget {
  /// Create the start screen for address lookup.
  const StartScreen({Key? key}) : super(key: key);

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  BagData? _bagData;
  bool _isLoading = false;

  /// Fetch GPS location and lookup BAG address data.
  Future<void> _fetchAddress() async {
    final perm = await Permission.locationWhenInUse.request();
    if (!perm.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Locatiepermissie geweigerd')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kon locatie niet bepalen')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Lookup BAG data
      BagData bagData;
      try {
        bagData = await BagService.lookupByCoords(
          pos.latitude,
          pos.longitude,
          'demo_key',
        );
      } catch (e) {
        bagData = BagData(
          postcode: 'Unknown',
          plaatsnaam: 'Unknown',
        );
      }

      setState(() {
        _bagData = bagData;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Adres opgehaald: ${bagData.getFolderName()}'),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fout bij ophalen adres')),
      );
    }
  }

  /// Navigate to photo selection screen with the fetched address.
  void _proceedToPhotos() {
    if (_bagData == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoSelectionScreen(bagData: _bagData!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo Organizer')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_bagData != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, size: 48, color: Colors.blue),
                    const SizedBox(height: 16),
                    Text(
                      'Adres opgehaald:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _bagData!.getFolderName(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    if (_bagData!.oorspronkelijkBouwjaar != null)
                      Text(
                        'Bouwjaar: ${_bagData!.oorspronkelijkBouwjaar}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (_bagData!.gebruiksdoel != null)
                      Text(
                        'Gebruik: ${_bagData!.gebruiksdoel}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              )
            else
              Text(
                'Haal eerst je adres op',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.gps_fixed),
              label: const Text('Ophalen Adres'),
              onPressed: _isLoading ? null : _fetchAddress,
            ),
            if (_bagData != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Foto\'s'),
                onPressed: _proceedToPhotos,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

