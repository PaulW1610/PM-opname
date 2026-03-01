import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/bag_service.dart';
import '../services/location_service.dart';
import 'opname_afsluiten_screen.dart';
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
  static const String _bagApiKey =
      String.fromEnvironment('BAG_API_KEY', defaultValue: 'l79175a82fbd564ef8b7ac64e4b7857001');
  static const String _savedDossiersKey = 'saved_dossiers_v1';

  BagData? _bagData;
  List<BagData> _bagCandidates = const <BagData>[];
  bool _isLoading = false;
  int _lastPhotoCount = 0;
  String _bagDebugInfo = '';
  int _activeFetchId = 0;
  final TextEditingController _manualAddressController = TextEditingController();
  final TextEditingController _manualPostcodeController = TextEditingController();
  final TextEditingController _manualHuisnummerController = TextEditingController();
  List<BagData> _savedDossiers = const <BagData>[];

  @override
  void initState() {
    super.initState();
    _loadSavedDossiers();
  }

  Future<void> _loadSavedDossiers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedDossiersKey);
    if (raw == null || raw.trim().isEmpty) {
      return;
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) {
        return;
      }
      final loaded = <BagData>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          loaded.add(BagData.fromJson(item));
          continue;
        }
        if (item is Map) {
          loaded.add(BagData.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      if (!mounted) return;
      setState(() {
        _savedDossiers = loaded;
      });
    } catch (_) {}
  }

  Future<void> _saveDossierAddress(BagData bagData) async {
    final unique = <String, BagData>{};
    unique[_candidateIdentityKey(bagData)] = bagData;
    for (final existing in _savedDossiers) {
      unique.putIfAbsent(_candidateIdentityKey(existing), () => existing);
    }
    final items = unique.values.take(30).toList(growable: false);
    final encoded = json.encode(
      items
          .map(
            (item) => <String, dynamic>{
              'openbareRuimteNaam': item.adres,
              'huisnummer': item.huisnummer,
              'huisletterHuisnummertoevoeging': item.huisletterHuisnummertoevoeging,
              'postcode': item.postcode,
              'plaatsnaam': item.plaatsnaam,
              'identificatie': item.bagAdresId,
              'bagIdentificatie': item.bagIdentificatie,
              'bagPandId': item.bagPandId,
              'oorspronkelijkBouwjaar': item.oorspronkelijkBouwjaar,
            },
          )
          .toList(growable: false),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedDossiersKey, encoded);
    if (!mounted) return;
    setState(() {
      _savedDossiers = items;
    });
  }

  Future<void> _selectSavedDossier(BagData bagData) async {
    final savedCount = await _loadPhotoCountForAddress(bagData.getFolderName());
    if (!mounted) return;
    setState(() {
      _bagData = bagData;
      _bagCandidates = <BagData>[bagData, ..._bagCandidates]
          .fold<List<BagData>>(<BagData>[], (acc, candidate) {
        if (acc.any(
          (existing) => _candidateIdentityKey(existing) == _candidateIdentityKey(candidate),
        )) {
          return acc;
        }
        return <BagData>[...acc, candidate];
      });
      _lastPhotoCount = savedCount;
    });
  }

  Future<void> _saveCurrentAddressForLater() async {
    if (_bagData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Haal of kies eerst een adres.')),
      );
      return;
    }
    await _saveDossierAddress(_bagData!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Adres opgeslagen: ${_bagData!.getFolderName()}')),
    );
  }

  Future<void> _removeSavedDossier(BagData bagData) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adres verwijderen?'),
        content: Text(
          'Weet je zeker dat je dit bewaarde adres wilt verwijderen?\n\n${_formatBagCandidate(bagData)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) {
      return;
    }

    final removeKey = _candidateIdentityKey(bagData);
    final updated = _savedDossiers
        .where((item) => _candidateIdentityKey(item) != removeKey)
        .toList(growable: false);

    final encoded = json.encode(
      updated
          .map(
            (item) => <String, dynamic>{
              'openbareRuimteNaam': item.adres,
              'huisnummer': item.huisnummer,
              'huisletterHuisnummertoevoeging': item.huisletterHuisnummertoevoeging,
              'postcode': item.postcode,
              'plaatsnaam': item.plaatsnaam,
              'identificatie': item.bagAdresId,
              'bagIdentificatie': item.bagIdentificatie,
              'bagPandId': item.bagPandId,
              'oorspronkelijkBouwjaar': item.oorspronkelijkBouwjaar,
            },
          )
          .toList(growable: false),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedDossiersKey, encoded);
    if (!mounted) return;
    setState(() {
      _savedDossiers = updated;
    });
  }

  void _cancelFetch() {
    _activeFetchId++;
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _bagDebugInfo = 'Adres ophalen geannuleerd';
    });
  }

  String _counterKeyForAddress(String addressFolderName) {
    final encoded = Uri.encodeComponent(addressFolderName.trim());
    return 'photo_count_$encoded';
  }

  Future<int> _loadPhotoCountForAddress(String addressFolderName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_counterKeyForAddress(addressFolderName)) ?? 0;
  }

  Future<void> _savePhotoCountForAddress({
    required String addressFolderName,
    required int count,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_counterKeyForAddress(addressFolderName), count);
  }

  String _extractHouseNumber(Placemark? placemark) {
    final raw = (placemark?.subThoroughfare ?? '').trim();
    if (raw.isEmpty) {
      return '';
    }
    return raw;
  }

  String _extractPostcode(Placemark? placemark) {
    final direct = (placemark?.postalCode ?? '').trim().toUpperCase();
    if (direct.isNotEmpty) {
      return direct;
    }

    final candidates = <String>[
      (placemark?.name ?? ''),
      (placemark?.street ?? ''),
      (placemark?.thoroughfare ?? ''),
      (placemark?.subLocality ?? ''),
      (placemark?.locality ?? ''),
    ];

    final regex = RegExp(r'\b\d{4}\s?[A-Z]{2}\b', caseSensitive: false);
    for (final candidate in candidates) {
      final match = regex.firstMatch(candidate.toUpperCase());
      if (match != null) {
        return match.group(0)!.replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    }

    return '';
  }

  String _extractHouseNumberFallback(Placemark? placemark) {
    final direct = _extractHouseNumber(placemark);
    if (direct.isNotEmpty) {
      return direct;
    }

    final candidates = <String>[
      (placemark?.name ?? ''),
      (placemark?.street ?? ''),
      (placemark?.thoroughfare ?? ''),
      (placemark?.subLocality ?? ''),
    ];

    for (final candidate in candidates) {
      final match = RegExp(r'\b\d{1,5}[A-Za-z]?\b').firstMatch(candidate);
      if (match != null) {
        return (match.group(0) ?? '').trim();
      }
    }

    return '';
  }

  /// Gebruik handmatig ingevoerd adres om verder te gaan.
  Future<void> _useManualAddress() async {
    final input = _manualAddressController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voer een adres in.')),
      );
      return;
    }
    final bagData = BagData(
      adres: input,
      huisnummer: '',
      postcode: '-',
      plaatsnaam: '',
    );
    final savedCount = await _loadPhotoCountForAddress(bagData.getFolderName());
    if (!mounted) return;
    setState(() {
      _bagData = bagData;
      _bagCandidates = <BagData>[bagData];
      _lastPhotoCount = savedCount;
    });
    await _proceedToPhotos();
  }

  String _formatBagCandidate(BagData data) {
    final straat = (data.adres ?? '').trim();
    final huisnummer = (data.huisnummer ?? '').trim();
    final toevoeging = (data.huisletterHuisnummertoevoeging ?? '').trim();
    final postcode = data.postcode.trim();
    final plaats = data.plaatsnaam.trim();

    final straatDeel = [straat, huisnummer, toevoeging]
        .where((value) => value.isNotEmpty && value.toLowerCase() != 'unknown')
        .join(' ')
        .trim();

    final locatieDeel = [postcode, plaats]
        .where((value) => value.isNotEmpty && value.toLowerCase() != 'unknown')
        .join(' ')
        .trim();

    final combined = [straatDeel, locatieDeel]
        .where((value) => value.isNotEmpty)
        .join(', ')
        .trim();
    return combined.isEmpty ? data.getFolderName() : combined;
  }

  String _candidateSortKey(BagData data) {
    final straat = (data.adres ?? '').trim().toLowerCase();
    final huisnummerRaw = (data.huisnummer ?? '').trim();
    final huisnummerNumeric =
        int.tryParse(RegExp(r'^\d+').stringMatch(huisnummerRaw) ?? '') ?? 0;
    final huisnummerText = huisnummerRaw.toLowerCase();
    final toevoeging =
        (data.huisletterHuisnummertoevoeging ?? '').trim().toLowerCase();
    final postcode = data.postcode.trim().toUpperCase();
    final plaats = data.plaatsnaam.trim().toLowerCase();

    return [
      straat,
      huisnummerNumeric.toString().padLeft(6, '0'),
      huisnummerText,
      toevoeging,
      postcode,
      plaats,
    ].join('|');
  }

  String _candidateIdentityKey(BagData data) {
    return [
      (data.bagAdresId ?? '').trim(),
      (data.bagIdentificatie ?? '').trim(),
      (data.adres ?? '').trim().toLowerCase(),
      (data.huisnummer ?? '').trim().toLowerCase(),
      (data.huisletterHuisnummertoevoeging ?? '').trim().toLowerCase(),
      data.postcode.trim().toUpperCase(),
      data.plaatsnaam.trim().toLowerCase(),
    ].join('|');
  }

  List<MapEntry<String, String>> _collectLookupPairs(List<Placemark> placemarks) {
    final pairs = <MapEntry<String, String>>[];
    final seen = <String>{};

    for (final placemark in placemarks.take(6)) {
      final postcode = _extractPostcode(placemark);
      final huisnummer = _extractHouseNumberFallback(placemark);
      if (postcode.isEmpty || huisnummer.isEmpty) {
        continue;
      }
      final key = '${postcode.toUpperCase()}|${huisnummer.toLowerCase()}';
      if (seen.add(key)) {
        pairs.add(MapEntry(postcode, huisnummer));
      }
    }

    return pairs;
  }

  Future<void> _searchBagByManualPair() async {
    if (_isLoading) return;

    final postcode =
        _manualPostcodeController.text.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final huisnummer = _manualHuisnummerController.text.trim();
    if (postcode.isEmpty || huisnummer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vul postcode en huisnummer in.')),
      );
      return;
    }

    final fetchId = ++_activeFetchId;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _bagDebugInfo = 'BAG handmatig zoeken: postcode=$postcode, huisnummer=$huisnummer';
    });

    try {
      final candidates = await BagService.lookupCandidatesByAddress(
        postcode,
        huisnummer,
        _bagApiKey,
      ).timeout(const Duration(seconds: 15));
      if (!mounted || fetchId != _activeFetchId) return;

      candidates.sort(
        (left, right) => _candidateSortKey(left).compareTo(_candidateSortKey(right)),
      );
      final selected = candidates.isNotEmpty ? candidates.first : null;

      var photoCount = 0;
      if (selected != null) {
        photoCount = await _loadPhotoCountForAddress(selected.getFolderName());
        if (!mounted || fetchId != _activeFetchId) return;
      }

      setState(() {
        _bagCandidates = candidates;
        _bagData = selected;
        _lastPhotoCount = photoCount;
        _bagDebugInfo =
            'BAG handmatig: ${candidates.length} kandidaten voor $postcode $huisnummer';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            candidates.isEmpty
                ? 'Geen BAG-adressen gevonden voor $postcode $huisnummer'
                : 'BAG-adressen gevonden: ${candidates.length}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted || fetchId != _activeFetchId) return;
      setState(() {
        _bagDebugInfo = 'BAG handmatig fout: $error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('BAG handmatig zoeken mislukt: $error')),
      );
    } finally {
      if (!mounted || fetchId != _activeFetchId) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectBagCandidate(BagData candidate) async {
    final savedCount = await _loadPhotoCountForAddress(candidate.getFolderName());
    if (!mounted) return;
    setState(() {
      _bagData = candidate;
      _lastPhotoCount = savedCount;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Adres gekozen: ${candidate.getFolderName()}')),
    );
  }

  /// Fetch GPS location and lookup BAG address data.
  Future<void> _fetchAddress() async {
    if (_isLoading) return;
    final fetchId = ++_activeFetchId;

    if (kIsWeb) {
      // Demo-adres voor web
      if (fetchId != _activeFetchId) return;
      setState(() {
        _bagData = BagData(
          postcode: '1234 AB',
          plaatsnaam: 'Demo-stad',
          oorspronkelijkBouwjaar: '2020',
          gebruiksdoel: 'Wonen',
        );
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo-adres opgehaald voor web')),
      );
      return;
    }

    final perm = await Permission.locationWhenInUse.request();
    if (!perm.isGranted) {
      if (fetchId != _activeFetchId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Locatiepermissie geweigerd')),
      );
      return;
    }

    if (!mounted || fetchId != _activeFetchId) return;
    setState(() {
      _isLoading = true;
      _bagDebugInfo = 'Adres ophalen gestart...';
    });

    try {
      final pos = await LocationService.getCurrentPosition().timeout(
        const Duration(seconds: 15),
      );
      if (fetchId != _activeFetchId || !mounted) return;
      if (pos == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kon locatie niet bepalen')),
        );
        return;
      }

      // Lookup BAG data
      BagData? selectedBagData;
      List<BagData> candidateBagData = <BagData>[];
      List<Placemark> placemarks = const <Placemark>[];
      try {
        placemarks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        ).timeout(const Duration(seconds: 12));
      } catch (_) {
        placemarks = const <Placemark>[];
      }
      if (fetchId != _activeFetchId || !mounted) return;
      final placemark = placemarks.isNotEmpty ? placemarks.first : null;
      final gpsAddressCandidate = BagData(
        adres: placemark?.thoroughfare,
        huisnummer: _extractHouseNumber(placemark),
        postcode: _extractPostcode(placemark).isEmpty
            ? '${pos.latitude.toStringAsFixed(5)},${pos.longitude.toStringAsFixed(5)}'
            : _extractPostcode(placemark),
        plaatsnaam: placemark?.locality ??
            placemark?.subAdministrativeArea ??
            placemark?.administrativeArea ??
            'Locatie',
      );
      if (_manualAddressController.text.trim().isEmpty) {
        _manualAddressController.text = _formatBagCandidate(gpsAddressCandidate);
      }

      final postcode = _extractPostcode(placemark);
      final huisnummer = _extractHouseNumberFallback(placemark);
      if (_manualPostcodeController.text.trim().isEmpty && postcode.isNotEmpty) {
        _manualPostcodeController.text = postcode;
      }
      if (_manualHuisnummerController.text.trim().isEmpty && huisnummer.isNotEmpty) {
        _manualHuisnummerController.text = huisnummer;
      }
      _bagDebugInfo = 'BAG input: postcode=$postcode, huisnummer=$huisnummer';
      final lookupPairs = _collectLookupPairs(placemarks);

      if (lookupPairs.isNotEmpty) {
        try {
          final seenCandidateKeys = <String>{};
          for (var index = 0; index < lookupPairs.length; index++) {
            final pair = lookupPairs[index];
            final pairCandidates = await BagService.lookupCandidatesByAddress(
              pair.key,
              pair.value,
              _bagApiKey,
            ).timeout(const Duration(seconds: 10));

            for (final candidate in pairCandidates) {
              final key = _candidateIdentityKey(candidate);
              if (seenCandidateKeys.add(key)) {
                candidateBagData.add(candidate);
              }
            }

            if (selectedBagData == null && index == 0 && pairCandidates.isNotEmpty) {
              selectedBagData = pairCandidates.first;
            }
          }

          if (fetchId != _activeFetchId || !mounted) return;
          _bagDebugInfo =
              'BAG kandidaten: ${candidateBagData.length} via ${lookupPairs.length} GPS-inputs';
          if (candidateBagData.length == 1) {
            selectedBagData = candidateBagData.first;
          }
        } catch (error) {
          _bagDebugInfo =
              'BAG fout: postcode=$postcode, huisnummer=$huisnummer, error=$error';
          selectedBagData = BagData(
            adres: placemark?.thoroughfare,
            huisnummer: huisnummer,
            postcode: postcode,
            plaatsnaam: placemark?.locality ??
                placemark?.subAdministrativeArea ??
                placemark?.administrativeArea ??
                'Unknown',
          );
          candidateBagData = <BagData>[selectedBagData!];
        }
      } else {
        selectedBagData = BagData(
          adres: placemark?.thoroughfare,
          huisnummer: huisnummer,
          postcode: postcode.isEmpty
              ? '${pos.latitude.toStringAsFixed(5)},${pos.longitude.toStringAsFixed(5)}'
              : postcode,
          plaatsnaam: placemark?.locality ??
              placemark?.subAdministrativeArea ??
              placemark?.administrativeArea ??
              'Locatie',
        );
        candidateBagData = <BagData>[selectedBagData!];
      }

      setState(() {
        candidateBagData.sort(
          (left, right) => _candidateSortKey(left).compareTo(_candidateSortKey(right)),
        );
        final gpsKey = _formatBagCandidate(gpsAddressCandidate).toLowerCase();
        final containsGpsCandidate = candidateBagData.any(
          (item) => _formatBagCandidate(item).toLowerCase() == gpsKey,
        );
        if (!containsGpsCandidate) {
          candidateBagData = <BagData>[gpsAddressCandidate, ...candidateBagData];
        }
        _bagCandidates = candidateBagData;
        _bagData = selectedBagData;
      });

      if (selectedBagData != null) {
        final savedCount = await _loadPhotoCountForAddress(
          selectedBagData.getFolderName(),
        );
        if (!mounted || fetchId != _activeFetchId) return;
        setState(() {
          _lastPhotoCount = savedCount;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Adres opgehaald: ${selectedBagData.getFolderName()}'),
          ),
        );
      } else {
        if (!mounted || fetchId != _activeFetchId) return;
        setState(() {
          _lastPhotoCount = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meerdere adressen gevonden. Kies het juiste adres.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted || fetchId != _activeFetchId) return;
      _bagDebugInfo = 'Fout bij ophalen adres: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fout bij ophalen adres')),
      );
    } finally {
      if (!mounted || fetchId != _activeFetchId) return;
      setState(() => _isLoading = false);
    }
  }

  /// Navigate to photo selection screen with the fetched address.
  Future<void> _proceedToPhotos() async {
    if (_bagData == null) return;
    final currentAddress = _bagData!.getFolderName();

    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => PhotoSelectionScreen(
          bagData: _bagData!,
          initialPhotoCount: _lastPhotoCount,
        ),
      ),
    );

    if (!mounted || result == null) return;
    setState(() {
      _lastPhotoCount = result;
    });
    await _savePhotoCountForAddress(
      addressFolderName: currentAddress,
      count: result,
    );
  }

  Future<void> _openOpnameAfsluiten() async {
    if (_bagData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Haal eerst een adres op voor het dossier.')),
      );
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OpnameAfsluitenScreen(
          bagData: _bagData!,
          dossierName: _bagData!.getFolderName(),
        ),
      ),
    );
    if (!mounted || saved != true) return;
    await _saveDossierAddress(_bagData!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Adres opgeslagen voor later: ${_bagData!.getFolderName()}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PM Realestate Data & Visuals')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/icon.png',
                      height: 88,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'PM Realestate Data & Visuals',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
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
                      // Bouwjaar en gebruiksdoel worden niet getoond bij handmatige invoer
                      if (_bagDebugInfo.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _bagDebugInfo,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                )
              else
                Text(
                  'Haal eerst je adres op',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: _manualAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Voer adres handmatig in',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualPostcodeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Postcode',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _manualHuisnummerController,
                        decoration: const InputDecoration(
                          labelText: 'Huisnummer',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('Zoek op postcode + huisnummer'),
                onPressed: _isLoading ? null : _searchBagByManualPair,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.gps_fixed),
                label: const Text('Ophalen Adres'),
                onPressed: _isLoading ? null : _fetchAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_location_alt),
                label: const Text('Gebruik handmatig adres'),
                onPressed: _useManualAddress,
              ),
              if (_bagCandidates.isNotEmpty)
                const SizedBox(height: 16),
              if (_bagCandidates.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Text(
                        _bagCandidates.length > 1
                            ? 'Mogelijke adressen (${_bagCandidates.length})'
                            : 'Gevonden adres (1)',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: Card(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _bagCandidates.length,
                            itemBuilder: (context, index) {
                              final candidate = _bagCandidates[index];
                              final isSelected =
                                  _bagData?.getFolderName() == candidate.getFolderName();
                              return ListTile(
                                dense: true,
                                title: Text(_formatBagCandidate(candidate)),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle,
                                        color: Theme.of(context).colorScheme.primary,
                                      )
                                    : null,
                                onTap: _isLoading
                                    ? null
                                    : () => _selectBagCandidate(candidate),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Foto\'s gemaakt: $_lastPhotoCount',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading) ...[
                const SizedBox(
                  width: 220,
                  child: LinearProgressIndicator(),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Annuleer ophalen'),
                  onPressed: _cancelFetch,
                ),
                const SizedBox(height: 8),
              ],
              ElevatedButton.icon(
                icon: const Icon(Icons.assignment_turned_in),
                label: const Text('Opname afsluiten'),
                onPressed: _isLoading ? null : _openOpnameAfsluiten,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Adres opslaan in projecten'),
                onPressed: _isLoading ? null : _saveCurrentAddressForLater,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      'Opgeslagen projecten (${_savedDossiers.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (_savedDossiers.isEmpty)
                      Text(
                        'Nog geen opgeslagen projecten. Kies een adres en tik op "Adres opslaan in projecten".',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: Card(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _savedDossiers.length,
                            itemBuilder: (context, index) {
                              final item = _savedDossiers[index];
                              final selected = _bagData != null &&
                                  _candidateIdentityKey(_bagData!) ==
                                      _candidateIdentityKey(item);
                              return ListTile(
                                dense: true,
                                title: Text(_formatBagCandidate(item)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (selected)
                                      Icon(
                                        Icons.check_circle,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    IconButton(
                                      tooltip: 'Verwijder adres',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed:
                                          _isLoading ? null : () => _removeSavedDossier(item),
                                    ),
                                  ],
                                ),
                                onTap: _isLoading ? null : () => _selectSavedDossier(item),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_bagData != null) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Naar camera'),
                  onPressed: _proceedToPhotos,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _manualAddressController.dispose();
    _manualPostcodeController.dispose();
    _manualHuisnummerController.dispose();
    super.dispose();
  }
}

