import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../config/app_secrets.dart';
import '../models/opdrachtgever.dart';
import '../models/wws_invoer_data.dart';
import '../services/app_settings_service.dart';
import '../services/bag_service.dart';
import '../services/blueprint_api_service.dart';
import '../services/location_service.dart';
import '../services/opdrachtgever_service.dart';
import '../services/pdok_locatieserver_service.dart';
import '../theme/brand.dart';
import 'beslisschemas_screen.dart';
import 'instellingen_screen.dart';
import 'opname_afsluiten_screen.dart';
import 'photo_selection_screen.dart';
import 'portefeuille_scherm.dart';
import 'wws_invoer_screen.dart';

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
  static const String _bagApiKey = AppSecrets.bagApiKey;
  static const String _savedDossiersKey = 'saved_dossiers_v1';
  static const double _defaultGpsBagRadiusMeters = 50.0;
  static const int _targetBagCandidateCount = 6;

  BagData? _bagData;
  List<BagData> _bagCandidates = const <BagData>[];
  bool _isLoading = false;
  int _lastPhotoCount = 0;
  double _gpsBagRadiusMeters = _defaultGpsBagRadiusMeters;
  int _activeFetchId = 0;
  final TextEditingController _manualAddressController = TextEditingController();
  final TextEditingController _manualPostcodeController = TextEditingController();
  final TextEditingController _manualHuisnummerController = TextEditingController();
  List<BagData> _savedDossiers = const <BagData>[];

  List<Opdrachtgever> _opdrachtgevers = const <Opdrachtgever>[];
  Opdrachtgever? _selectedOpdrachtgever;
  final TextEditingController _opdrachtnummerController =
      TextEditingController();
  bool _syncingOpdrachtgevers = false;
  final Map<String, WwsInvoerData> _wwsPerAdres = <String, WwsInvoerData>{};
  bool _wozBusy = false;
  String _wozStatus = 'WOZ nog niet opgehaald';
  int? _wozWaarde;
  String? _energieLabel;
  EpLabelResult? _epLabel;
  String _wozPeildatum = '';

  @override
  void initState() {
    super.initState();
    _loadSavedDossiers();
    _loadLookupSettings();
    _loadOpdrachtgevers();
    _loadWwsPerAdres();
    _syncOpdrachtgevers(silent: true);
  }

  static const String _kWwsPerAdres = 'wws_per_adres_v1';

  /// Laadt de per-adres bewaarde WWS-invoer van schijf (overleeft app-herstart).
  Future<void> _loadWwsPerAdres() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kWwsPerAdres);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final loaded = <String, WwsInvoerData>{};
      decoded.forEach((key, value) {
        loaded[key] =
            WwsInvoerData.fromJson(Map<String, dynamic>.from(value as Map));
      });
      if (!mounted) return;
      setState(() {
        _wwsPerAdres
          ..clear()
          ..addAll(loaded);
      });
    } catch (_) {
      // Corrupte opslag negeren; niet crashen op opstart.
    }
  }

  /// Bewaart de per-adres WWS-invoer op schijf.
  Future<void> _saveWwsPerAdres() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = _wwsPerAdres
          .map((key, value) => MapEntry(key, value.toJson()));
      await prefs.setString(_kWwsPerAdres, jsonEncode(map));
    } catch (_) {
      // Opslagfout stil negeren.
    }
  }

  Future<void> _loadOpdrachtgevers() async {
    final lijst = await OpdrachtgeverService.loadActive();
    if (!mounted) return;
    setState(() {
      _opdrachtgevers = lijst;
      // Houd de selectie geldig; val terug op de bijgewerkte versie indien aanwezig.
      final sel = _selectedOpdrachtgever;
      if (sel != null) {
        final match =
            lijst.where((o) => o.id == sel.id).cast<Opdrachtgever?>();
        _selectedOpdrachtgever = match.isNotEmpty ? match.first : sel;
      }
    });
  }

  Future<void> _syncOpdrachtgevers({bool silent = false}) async {
    if (_syncingOpdrachtgevers) return;
    setState(() => _syncingOpdrachtgevers = true);
    final result = await OpdrachtgeverService.syncWithNextcloud();
    if (!mounted) {
      _syncingOpdrachtgevers = false;
      return;
    }
    setState(() => _syncingOpdrachtgevers = false);
    await _loadOpdrachtgevers();
    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  /// Past de gekozen opdrachtgever + opdrachtnummer toe op een dossier.
  BagData _withOpdrachtgever(BagData data) {
    final nummer = _opdrachtnummerController.text.trim();
    return data.copyWith(
      opdrachtgever: _selectedOpdrachtgever,
      opdrachtnummer: nummer.isEmpty ? null : nummer,
    );
  }

  void _onSelectOpdrachtgever(String? id) {
    setState(() {
      if (id == null) {
        _selectedOpdrachtgever = null;
        return;
      }
      final match =
          _opdrachtgevers.where((o) => o.id == id).cast<Opdrachtgever?>();
      _selectedOpdrachtgever = match.isNotEmpty ? match.first : null;
    });
  }

  Future<void> _nieuweOpdrachtgever() async {
    final result = await showDialog<_OpdrachtgeverDialogResult>(
      context: context,
      builder: (_) => const _OpdrachtgeverDialog(),
    );
    if (result == null || result.opdrachtgever == null) return;
    final saved = await OpdrachtgeverService.addOrUpdate(
      result.opdrachtgever!.copyWith(id: OpdrachtgeverService.generateId()),
    );
    await _loadOpdrachtgevers();
    if (!mounted) return;
    setState(() => _selectedOpdrachtgever = saved);
    _syncOpdrachtgevers(silent: true);
  }

  Future<void> _bewerkOpdrachtgever() async {
    final huidig = _selectedOpdrachtgever;
    if (huidig == null) return;
    final result = await showDialog<_OpdrachtgeverDialogResult>(
      context: context,
      builder: (_) => _OpdrachtgeverDialog(bestaande: huidig),
    );
    if (result == null) return;
    if (result.verwijderen) {
      await OpdrachtgeverService.softDelete(huidig.id);
      await _loadOpdrachtgevers();
      if (!mounted) return;
      setState(() => _selectedOpdrachtgever = null);
    } else if (result.opdrachtgever != null) {
      final saved = await OpdrachtgeverService.addOrUpdate(result.opdrachtgever!);
      await _loadOpdrachtgevers();
      if (!mounted) return;
      setState(() => _selectedOpdrachtgever = saved);
    }
    _syncOpdrachtgevers(silent: true);
  }

  Future<void> _loadLookupSettings() async {
    final radius = await AppSettingsService.loadGpsBagRadiusMeters();
    if (!mounted) {
      _gpsBagRadiusMeters = radius;
      return;
    }
    setState(() {
      _gpsBagRadiusMeters = radius;
    });
  }

  Future<void> _openInstellingen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const InstellingenScreen(),
      ),
    );
    await _loadLookupSettings();
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
              // Los bewaren, anders zijn "79-1" en "79 A1" na herladen weer
              // niet uit elkaar te houden.
              'huisletter': item.huisletter,
              'huisnummertoevoeging': item.huisnummertoevoeging,
              'oppervlakte': item.oppervlakte,
              'postcode': item.postcode,
              'plaatsnaam': item.plaatsnaam,
              'identificatie': item.bagAdresId,
              'bagIdentificatie': item.bagIdentificatie,
              'bagPandId': item.bagPandId,
              'oorspronkelijkBouwjaar': item.oorspronkelijkBouwjaar,
              if (item.opdrachtgever != null)
                'opdrachtgever': item.opdrachtgever!.toSnapshotJson(),
              'opdrachtnummer': item.opdrachtnummer,
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

  /// Herstelt de eerder gekozen opdrachtgever + opdrachtnummer voor dit adres.
  ///
  /// Gebruikt eerst de opdrachtgever die het dossier zelf draagt (bv. een
  /// opgeslagen project); valt anders terug op een opgeslagen project met
  /// hetzelfde adres. Wist nooit een al gekozen opdrachtgever/nummer.
  void _restoreOpdrachtgeverForAddress(BagData data) {
    Opdrachtgever? og = data.opdrachtgever;
    String? nummer = data.opdrachtnummer;
    if (og == null) {
      final key = _candidateIdentityKey(data);
      for (final d in _savedDossiers) {
        if (_candidateIdentityKey(d) == key && d.opdrachtgever != null) {
          og = d.opdrachtgever;
          nummer = d.opdrachtnummer;
          break;
        }
      }
    }
    if (og != null) {
      final ogId = og.id;
      final match =
          _opdrachtgevers.where((o) => o.id == ogId).cast<Opdrachtgever?>();
      _selectedOpdrachtgever = match.isNotEmpty ? match.first : og;
    }
    if ((nummer ?? '').trim().isNotEmpty) {
      _opdrachtnummerController.text = nummer!.trim();
    }
  }

  Future<void> _selectSavedDossier(BagData bagData) async {
    final savedCount = await _loadPhotoCountForAddress(bagData);
    if (!mounted) return;
    _restoreOpdrachtgeverForAddress(bagData);
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
    await _lookupWozForAddress(bagData);
    await _lookupEpLabelForAddress(bagData);
  }

  Future<void> _saveCurrentAddressForLater() async {
    if (_bagData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Haal of kies eerst een adres.')),
      );
      return;
    }
    await _saveDossierAddress(_withOpdrachtgever(_bagData!));
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
              // Los bewaren, anders zijn "79-1" en "79 A1" na herladen weer
              // niet uit elkaar te houden.
              'huisletter': item.huisletter,
              'huisnummertoevoeging': item.huisnummertoevoeging,
              'oppervlakte': item.oppervlakte,
              'postcode': item.postcode,
              'plaatsnaam': item.plaatsnaam,
              'identificatie': item.bagAdresId,
              'bagIdentificatie': item.bagIdentificatie,
              'bagPandId': item.bagPandId,
              'oorspronkelijkBouwjaar': item.oorspronkelijkBouwjaar,
              if (item.opdrachtgever != null)
                'opdrachtgever': item.opdrachtgever!.toSnapshotJson(),
              'opdrachtnummer': item.opdrachtnummer,
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
    });
  }

  String _counterKeyForAddress(BagData bagData) {
    final encoded = Uri.encodeComponent(bagData.getPhotoCounterScope());
    return 'photo_count_$encoded';
  }

  Future<int> _loadPhotoCountForAddress(BagData bagData) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_counterKeyForAddress(bagData)) ?? 0;
  }

  Future<void> _savePhotoCountForAddress({
    required BagData bagData,
    required int count,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_counterKeyForAddress(bagData), count);
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
    final savedCount = await _loadPhotoCountForAddress(bagData);
    if (!mounted) return;
    setState(() {
      _bagData = bagData;
      _bagCandidates = <BagData>[bagData];
      _lastPhotoCount = savedCount;
      _wozStatus = 'WOZ niet beschikbaar zonder postcode + huisnummer.';
      _wozWaarde = null;
      _wozPeildatum = '';
    });
    await _proceedToPhotos();
  }

  /// Kleur per energielabel (groen = zuinig … rood = onzuinig).
  Color _labelKleur(String label) {
    final l = label.toUpperCase();
    if (l.startsWith('A')) return const Color(0xFF2E7D32);
    if (l == 'B') return const Color(0xFF66BB6A);
    if (l == 'C') return const Color(0xFF9CCC65);
    if (l == 'D') return const Color(0xFFF9A825);
    if (l == 'E') return const Color(0xFFF57C00);
    if (l == 'F') return const Color(0xFFEF6C00);
    return const Color(0xFFD32F2F);
  }

  /// Formatteert een datum als dd-MM-yyyy (of '—' bij null).
  String _datumNl(DateTime? d) {
    if (d == null) return '—';
    String tw(int n) => n.toString().padLeft(2, '0');
    return '${tw(d.day)}-${tw(d.month)}-${d.year}';
  }

  /// Toont alle geregistreerde EP-Online-gegevens in een detail-sheet, met een
  /// waarschuwing bij een label van vóór 2021 of een (bijna) verlopen label.
  void _toonLabelDetails(EpLabelResult ep) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kop: grote labelletter + soort registratie.
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _labelKleur(ep.label),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        ep.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Geregistreerd energielabel',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (ep.soort.trim().isNotEmpty)
                            Text(
                              ep.soort,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          const Text(
                            'Bron: EP-Online (RVO)',
                            style: TextStyle(
                                color: Colors.black45, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Waarschuwing vóór 2021 (oude bepalingsmethode).
                if (ep.isVoor2021)
                  _labelWaarschuwing(
                    kleur: const Color(0xFFEF6C00),
                    icoon: Icons.warning_amber_rounded,
                    titel: 'Label van vóór 2021',
                    tekst:
                        'Dit label is vastgelegd met de oude bepalingsmethode '
                        '(Energie-Index). Het kan sterk afwijken van de '
                        'werkelijke energieprestatie — een nieuwe opname is '
                        'aan te raden.',
                  ),

                // Waarschuwing verlopen / bijna verlopen.
                if (ep.isVerlopen)
                  _labelWaarschuwing(
                    kleur: const Color(0xFFD32F2F),
                    icoon: Icons.error_outline,
                    titel: 'Label verlopen',
                    tekst:
                        'De geldigheid is verstreken (${_datumNl(ep.geldigTotDatum)}). '
                        'Er is een nieuwe opname nodig.',
                  )
                else if (ep.verlooptBinnenkort)
                  _labelWaarschuwing(
                    kleur: const Color(0xFFF9A825),
                    icoon: Icons.schedule,
                    titel: 'Verloopt binnenkort',
                    tekst:
                        'Dit label verloopt op ${_datumNl(ep.geldigTotDatum)}. '
                        'Plan tijdig een nieuwe opname in.',
                  ),

                const SizedBox(height: 16),

                // Feitenlijst.
                _labelRegel('Label', ep.label),
                _labelRegel('Registratiedatum', _datumNl(ep.registratieOp)),
                if (ep.opnameOp != null)
                  _labelRegel('Opnamedatum', _datumNl(ep.opnameOp)),
                _labelRegel('Geldig tot', _datumNl(ep.geldigTotDatum)),
                if (ep.bouwjaar != null)
                  _labelRegel('Bouwjaar', ep.bouwjaar.toString()),
                if (ep.ag != null)
                  _labelRegel('Gebruiksoppervlak', '${ep.ag} m²'),
                if (ep.ep2 != null)
                  _labelRegel('Primair fossiel (EP2)', '${ep.ep2} kWh/m²·jr'),
                if (ep.warmtebehoefte != null)
                  _labelRegel(
                      'Warmtebehoefte', '${ep.warmtebehoefte} kWh/m²·jr'),
                if (ep.bagId.trim().isNotEmpty)
                  _labelRegel('BAG-id', ep.bagId),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Sluiten'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _labelWaarschuwing({
    required Color kleur,
    required IconData icoon,
    required String titel,
    required String tekst,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kleur.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kleur.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icoon, color: kleur, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titel,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: kleur)),
                const SizedBox(height: 2),
                Text(tekst, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelRegel(String label, String waarde) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(waarde,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// Haalt het geregistreerde energielabel op via het publieke `eplabel`-
  /// endpoint (§3.1b); de server gebruikt de EP-Online-key. Stil falen: bij een
  /// fout of geen label blijft `_energieLabel` gewoon null.
  Future<void> _lookupEpLabelForAddress(BagData bagData) async {
    final postcode =
        bagData.postcode.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final huisnummer = (bagData.huisnummer ?? '').trim();
    final toevoeging = (bagData.huisletterHuisnummertoevoeging ?? '').trim();
    if (postcode.isEmpty || postcode == '-' || huisnummer.isEmpty) return;
    try {
      final result = await BlueprintApiService.lookupEpLabel(
        postcode: postcode,
        huisnummer: huisnummer,
        toevoeging: toevoeging,
      );
      if (!mounted) return;
      setState(() {
        _energieLabel = result.isOk ? result.label : null;
        _epLabel = result.isOk ? result : null;
      });
    } catch (_) {
      // Stil negeren; label vooraf invullen is een extraatje.
    }
  }

  Future<void> _lookupWozForAddress(BagData bagData) async {
    final postcode = bagData.postcode.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final huisnummer = (bagData.huisnummer ?? '').trim();
    final toevoeging = (bagData.huisletterHuisnummertoevoeging ?? '').trim();

    if (postcode.isEmpty || postcode == '-' || huisnummer.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _wozBusy = false;
        _wozStatus = 'WOZ niet beschikbaar: postcode/huisnummer ontbreekt.';
        _wozWaarde = null;
        _wozPeildatum = '';
      });
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _wozBusy = true;
      _wozStatus = 'WOZ ophalen...';
    });

    try {
      final result = await BlueprintApiService.lookupWoz(
        postcode: postcode,
        huisnummer: huisnummer,
        toevoeging: toevoeging,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _wozBusy = false;
        _wozWaarde = result.waarde;
        _wozPeildatum = result.peildatum;
        switch (result.status) {
          case WozStatus.ok:
            _wozStatus = 'WOZ gevonden';
            break;
          case WozStatus.nietGevonden:
            _wozStatus = result.melding.isEmpty
                ? 'WOZ niet gevonden voor dit adres.'
                : result.melding;
            break;
          case WozStatus.geenWoz:
            _wozStatus = 'Geen openbare WOZ beschikbaar.';
            break;
          case WozStatus.fout:
            _wozStatus = result.melding.isEmpty
                ? 'WOZ lookup gaf een foutstatus.'
                : result.melding;
            break;
          case WozStatus.onbekend:
            _wozStatus = 'Onbekende WOZ-status ontvangen.';
            break;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _wozBusy = false;
        _wozStatus = 'WOZ ophalen mislukt: $error';
        _wozWaarde = null;
        _wozPeildatum = '';
      });
    }
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

  bool _isSelectedBagCandidate(BagData candidate) {
    final selected = _bagData;
    if (selected == null) {
      return false;
    }
    return _candidateIdentityKey(selected) == _candidateIdentityKey(candidate);
  }

  Color _lookupStatusColor(String level) {
    switch (level) {
      case 'error':
        return Colors.red.shade700;
      case 'fallback':
        return Colors.orange.shade800;
      case 'ok':
      default:
        return Colors.green.shade700;
    }
  }

  String _candidateStatusLevel(BagData candidate) {
    final isSelected = _isSelectedBagCandidate(candidate);
    final matchesCurrentInput = _matchesCurrentInput(candidate);

    if (isSelected || matchesCurrentInput) {
      return 'ok';
    }

    final hasAdresId = (candidate.bagAdresId ?? '').trim().isNotEmpty;
    final hasPandId = (candidate.bagPandId ?? '').trim().isNotEmpty;
    final hasObjectId = (candidate.adresseerbaarObjectId ?? '').trim().isNotEmpty;

    if (hasAdresId || hasPandId || hasObjectId) {
      return 'fallback';
    }

    final postcode = candidate.postcode.trim();
    if (postcode.isEmpty || postcode.contains(',')) {
      return 'error';
    }

    return 'fallback';
  }

  String _candidateStatusText(BagData candidate) {
    final isSelected = _isSelectedBagCandidate(candidate);
    final matchesCurrentInput = _matchesCurrentInput(candidate);

    final String status;
    if (isSelected) {
      status = 'Geselecteerd adres';
    } else if (matchesCurrentInput) {
      status = 'Huidige locatie match';
    } else {
      switch (_candidateStatusLevel(candidate)) {
        case 'ok':
          status = 'Waarschijnlijke match';
          break;
        case 'fallback':
          status = 'Alternatief BAG-adres';
          break;
        case 'error':
        default:
          status = 'Onzekere match';
      }
    }

    // Oppervlakte en bouwjaar erbij: in een portiek met acht woningen op
    // hetzelfde huisnummer is de m² het snelste onderscheid.
    final kenmerken = <String>[
      if (candidate.oppervlakte != null && candidate.oppervlakte! > 0)
        '${candidate.oppervlakte} m²',
      if ((candidate.oorspronkelijkBouwjaar ?? '').trim().isNotEmpty)
        candidate.oorspronkelijkBouwjaar!.trim(),
    ];

    return kenmerken.isEmpty ? status : '${kenmerken.join(' · ')} · $status';
  }

  String _normalizePostcode(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  String _normalizeHuisnummer(String value) {
    return value.trim().toLowerCase();
  }

  String _extractHuisnummerNumeric(String value) {
    return RegExp(r'^\d+').stringMatch(value.trim()) ?? '';
  }

  bool _matchesCurrentInput(BagData candidate) {
    final inputPostcode = _normalizePostcode(_manualPostcodeController.text);
    final inputHuisnummer = _normalizeHuisnummer(_manualHuisnummerController.text);
    if (inputPostcode.isEmpty || inputHuisnummer.isEmpty) {
      return false;
    }

    final candidatePostcode = _normalizePostcode(candidate.postcode);
    if (candidatePostcode != inputPostcode) {
      return false;
    }

    final candidateHuisnummer = _normalizeHuisnummer(candidate.huisnummer ?? '');
    if (candidateHuisnummer.isEmpty) {
      return false;
    }

    if (candidateHuisnummer == inputHuisnummer) {
      return true;
    }

    final inputNumeric = _extractHuisnummerNumeric(inputHuisnummer);
    final candidateNumeric = _extractHuisnummerNumeric(candidateHuisnummer);
    if (inputNumeric.isNotEmpty && candidateNumeric.isNotEmpty) {
      return inputNumeric == candidateNumeric;
    }

    return false;
  }

  double? _distanceToCandidateMeters({
    required BagData candidate,
    required double latitude,
    required double longitude,
  }) {
    final candidateLat = candidate.latitude;
    final candidateLon = candidate.longitude;
    if (candidateLat == null || candidateLon == null) {
      return null;
    }

    return Geolocator.distanceBetween(
      latitude,
      longitude,
      candidateLat,
      candidateLon,
    );
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

  Future<List<MapEntry<int, List<Placemark>>>> _sampleNearbyPlacemarkBatches({
    required double latitude,
    required double longitude,
    int maxRequests = 18,
  }) async {
    final batches = <MapEntry<int, List<Placemark>>>[];
    if (maxRequests <= 0) {
      return batches;
    }

    const radiiInMeters = <double>[30, 70, 140, 240, 360];
    const directionsPerRing = <int>[8, 8, 6, 4, 4];
    var requestCount = 0;

    for (var ring = 0; ring < radiiInMeters.length; ring++) {
      final radius = radiiInMeters[ring];
      final steps = directionsPerRing[ring];

      for (var step = 0; step < steps; step++) {
        if (requestCount >= maxRequests) {
          return batches;
        }

        final radians = (step * (360.0 / steps)) * math.pi / 180.0;
        final eastMeters = math.sin(radians) * radius;
        final northMeters = math.cos(radians) * radius;
        final latDelta = northMeters / 111320.0;
        final metersPerLonDegree =
            111320.0 * math.cos(latitude * math.pi / 180.0);
        final lonDelta = metersPerLonDegree.abs() < 0.000001
            ? 0.0
            : eastMeters / metersPerLonDegree;

        final sampleLat = latitude + latDelta;
        final sampleLon = longitude + lonDelta;

        try {
          final sampledPlacemarks = await placemarkFromCoordinates(
            sampleLat,
            sampleLon,
          ).timeout(const Duration(seconds: 6));
          batches.add(MapEntry(requestCount + 1, sampledPlacemarks));
        } catch (_) {}

        requestCount++;
      }
    }

    return batches;
  }

  Future<List<MapEntry<String, String>>> _collectLookupPairsAroundPosition({
    required List<Placemark> seedPlacemarks,
    required List<MapEntry<int, List<Placemark>>> sampledPlacemarkBatches,
  }) async {
    final pairs = <MapEntry<String, String>>[];
    final seen = <String>{};

    void addPairs(Iterable<MapEntry<String, String>> inputPairs) {
      for (final pair in inputPairs) {
        final key = '${pair.key.toUpperCase()}|${pair.value.toLowerCase()}';
        if (seen.add(key)) {
          pairs.add(pair);
        }
      }
    }

    addPairs(_collectLookupPairs(seedPlacemarks));

    for (final batch in sampledPlacemarkBatches) {
      if (pairs.length >= 40) {
        break;
      }

      addPairs(_collectLookupPairs(batch.value));
    }

    return pairs;
  }

  Future<List<MapEntry<BagData, int>>> _collectNearbyPlacemarkCandidates({
    required List<Placemark> seedPlacemarks,
    required List<MapEntry<int, List<Placemark>>> sampledPlacemarkBatches,
  }) async {
    final collected = <MapEntry<BagData, int>>[];
    final seen = <String>{};

    void addPlacemarkCandidates(List<Placemark> placemarks, int rank) {
      for (final placemark in placemarks.take(2)) {
        final straat = (placemark.thoroughfare ?? placemark.street ?? '').trim();
        final huisnummer = _extractHouseNumberFallback(placemark);
        final postcode = _extractPostcode(placemark);
        final plaats = (placemark.locality ??
                placemark.subAdministrativeArea ??
                placemark.administrativeArea ??
                '')
            .trim();

        if (straat.isEmpty || huisnummer.isEmpty || postcode.isEmpty || plaats.isEmpty) {
          continue;
        }

        final candidate = BagData(
          adres: straat,
          huisnummer: huisnummer,
          postcode: postcode,
          plaatsnaam: plaats,
        );

        final key = _candidateIdentityKey(candidate);
        if (seen.add(key)) {
          collected.add(MapEntry(candidate, rank));
        }
      }
    }

    addPlacemarkCandidates(seedPlacemarks, 0);

    for (final batch in sampledPlacemarkBatches) {
      if (collected.length >= 16) {
        break;
      }

      addPlacemarkCandidates(batch.value, batch.key);
    }

    return collected;
  }

  /// Hoeveel verschillende huisnummers we maximaal bij BAG navragen na een
  /// PDOK-treffer. Eén verzoek per huisnummer levert al alle appartementen.
  static const int _maxBagGroepenViaPdok = 3;

  /// Huisletter + toevoeging als vergelijkbare sleutel ("a1", "h", "").
  String _toevoegingSleutel(String? huisletter, String? toevoeging) {
    return [huisletter, toevoeging]
        .whereType<String>()
        .join()
        .replaceAll(RegExp(r'[\s-]'), '')
        .toLowerCase();
  }

  /// Adres bepalen bij een GPS-punt via de PDOK Locatieserver.
  ///
  /// PDOK zegt wélk adres je voor je hebt (op afstand gesorteerd, met
  /// huisletter en toevoeging); BAG levert daarna de inhoud (bouwjaar,
  /// oppervlakte, pand-id). Lege lijst = PDOK wist niets, dan valt de
  /// aanroeper terug op de oude route via het besturingssysteem.
  Future<List<BagData>> _bagKandidatenViaPdok({
    required double latitude,
    required double longitude,
  }) async {
    final pdokAdressen = await PdokLocatieserverService.adressenBijCoordinaten(
      latitude: latitude,
      longitude: longitude,
      aantal: 12,
    );
    if (pdokAdressen.isEmpty) {
      return const <BagData>[];
    }

    // Per postcode+huisnummer één BAG-verzoek.
    final bagPerHuisnummer = <String, List<BagData>>{};
    for (final adres in pdokAdressen) {
      final sleutel = adres.postcodeHuisnummerSleutel;
      if (bagPerHuisnummer.containsKey(sleutel)) {
        continue;
      }
      if (bagPerHuisnummer.length >= _maxBagGroepenViaPdok) {
        break;
      }
      try {
        bagPerHuisnummer[sleutel] =
            await BagService.lookupCandidatesByAddressExact(
          adres.postcode,
          adres.huisnummer ?? '',
          _bagApiKey,
        ).timeout(const Duration(seconds: 12));
      } catch (_) {
        bagPerHuisnummer[sleutel] = const <BagData>[];
      }
    }

    // In PDOK-volgorde teruggeven: dichtstbijzijnde adres bovenaan.
    final resultaat = <BagData>[];
    final gezien = <String>{};
    for (final adres in pdokAdressen) {
      final woningen = bagPerHuisnummer[adres.postcodeHuisnummerSleutel];
      if (woningen == null) {
        continue;
      }

      BagData? treffer;
      for (final woning in woningen) {
        final woningSleutel = _toevoegingSleutel(
          woning.huisletter,
          woning.huisnummertoevoeging,
        );
        if (woningSleutel == adres.toevoegingSleutel) {
          treffer = woning;
          break;
        }
      }

      // Geen BAG-treffer (bijv. adres net buiten de BAG-selectie): dan tonen
      // we wat PDOK weet, zodat de woning niet uit de lijst verdwijnt.
      final kandidaat = treffer ??
          BagData(
            adres: adres.straat,
            huisnummer: adres.huisnummer,
            huisletter: adres.huisletter,
            huisnummertoevoeging: adres.huisnummertoevoeging,
            huisletterHuisnummertoevoeging: [
              adres.huisletter,
              adres.huisnummertoevoeging,
            ].whereType<String>().join(),
            postcode: adres.postcode,
            plaatsnaam: adres.plaats ?? '',
            bagAdresId: adres.nummeraanduidingId,
          );

      if (gezien.add(_candidateIdentityKey(kandidaat))) {
        resultaat.add(kandidaat);
      }
    }

    return resultaat;
  }

  /// Meldt het als de BAG-sleutel ontbreekt (build zonder dart-defines).
  ///
  /// Zonder deze melding zou het adres ophalen stil niets opleveren en ga je
  /// op locatie een fout zoeken die er niet is.
  bool _bagSleutelOntbreekt() {
    if (AppSecrets.hasBagApiKey) {
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Geen BAG-sleutel in deze build. Bouw via tool/run_ios.sh of '
          'tool/build_testflight.sh — die geven tool/dart_defines.json mee.',
        ),
        duration: Duration(seconds: 6),
      ),
    );
    return true;
  }

  Future<void> _searchBagByManualPair() async {
    if (_isLoading) return;
    if (_bagSleutelOntbreekt()) return;

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
        photoCount = await _loadPhotoCountForAddress(selected);
        if (!mounted || fetchId != _activeFetchId) return;
      }

      setState(() {
        _bagCandidates = candidates;
        _bagData = selected;
        _lastPhotoCount = photoCount;
      });
      if (selected != null) {
        await _lookupWozForAddress(selected);
        await _lookupEpLabelForAddress(selected);
      }

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
    final savedCount = await _loadPhotoCountForAddress(candidate);
    if (!mounted) return;
    _restoreOpdrachtgeverForAddress(candidate);
    setState(() {
      _bagData = candidate;
      _lastPhotoCount = savedCount;
    });
    await _lookupWozForAddress(candidate);
    await _lookupEpLabelForAddress(candidate);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Adres gekozen: ${candidate.getFolderName()}')),
    );
  }

  /// Fetch GPS location and lookup BAG address data.
  Future<void> _fetchAddress() async {
    if (_isLoading) return;
    if (!kIsWeb && _bagSleutelOntbreekt()) return;
    final fetchId = ++_activeFetchId;

    final latestRadius = await AppSettingsService.loadGpsBagRadiusMeters();
    if (!mounted || fetchId != _activeFetchId) return;
    _gpsBagRadiusMeters = latestRadius;

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
      final candidateNearestRank = <String, int>{};

      // Eerst de Nederlandse route: PDOK weet welk adres bij dit punt hoort,
      // inclusief appartementen op hetzelfde huisnummer. Lukt dat, dan is de
      // hele omweg hieronder (reverse geocoding van het besturingssysteem plus
      // het bijzoeken van buurhuisnummers) niet nodig.
      try {
        final pdokKandidaten = await _bagKandidatenViaPdok(
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
        if (fetchId != _activeFetchId || !mounted) return;
        if (pdokKandidaten.isNotEmpty) {
          candidateBagData = List<BagData>.from(pdokKandidaten);
          selectedBagData = pdokKandidaten.first;
          for (var index = 0; index < pdokKandidaten.length; index++) {
            candidateNearestRank[_candidateIdentityKey(pdokKandidaten[index])] =
                index;
          }
        }
      } catch (_) {
        // PDOK onbereikbaar: stilletjes doorvallen naar de oude route.
      }

      List<Placemark> placemarks = const <Placemark>[];
      if (candidateBagData.isEmpty) {
        try {
          placemarks = await placemarkFromCoordinates(
            pos.latitude,
            pos.longitude,
          ).timeout(const Duration(seconds: 12));
        } catch (_) {
          placemarks = const <Placemark>[];
        }
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
            // Geen placeholder: een lege plaats wordt bij de export via de
            // BAG-lookup op postcode+huisnummer aangevuld (voorheen lekte hier
            // de tekst "Locatie" het adresveld in).
            '',
      );
      // Invulvelden vullen: kwam het adres van PDOK, dan is dat de betere bron.
      final pdokTreffer = selectedBagData;
      final pdokGelukt = candidateBagData.isNotEmpty && pdokTreffer != null;
      final invulBron = pdokGelukt ? pdokTreffer : gpsAddressCandidate;
      if (_manualAddressController.text.trim().isEmpty) {
        _manualAddressController.text = _formatBagCandidate(invulBron);
      }

      final postcode = pdokGelukt
          ? invulBron.postcode.trim()
          : _extractPostcode(placemark);
      final huisnummer = pdokGelukt
          ? (invulBron.huisnummer ?? '').trim()
          : _extractHouseNumberFallback(placemark);
      if (_manualPostcodeController.text.trim().isEmpty && postcode.isNotEmpty) {
        _manualPostcodeController.text = postcode;
      }
      if (_manualHuisnummerController.text.trim().isEmpty && huisnummer.isNotEmpty) {
        _manualHuisnummerController.text = huisnummer;
      }

      // De oude omweg — buurhuisnummers bijzoeken via reverse geocoding van het
      // besturingssysteem — draait alleen nog als PDOK niets opleverde.
      var sampledPlacemarkBatches = const <MapEntry<int, List<Placemark>>>[];
      var lookupPairs = const <MapEntry<String, String>>[];
      if (candidateBagData.isEmpty) {
        sampledPlacemarkBatches = await _sampleNearbyPlacemarkBatches(
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
        lookupPairs = await _collectLookupPairsAroundPosition(
          seedPlacemarks: placemarks,
          sampledPlacemarkBatches: sampledPlacemarkBatches,
        );
      }

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
              final existingRank = candidateNearestRank[key];
              if (existingRank == null || index < existingRank) {
                candidateNearestRank[key] = index;
              }
              if (seenCandidateKeys.add(key)) {
                candidateBagData.add(candidate);
              }
            }

            if (selectedBagData == null && index == 0 && pairCandidates.isNotEmpty) {
              selectedBagData = pairCandidates.first;
            }
          }

          if (fetchId != _activeFetchId || !mounted) return;
          if (candidateBagData.length == 1) {
            selectedBagData = candidateBagData.first;
          }
        } catch (error) {
          selectedBagData = BagData(
            adres: placemark?.thoroughfare,
            huisnummer: huisnummer,
            postcode: postcode,
            plaatsnaam: placemark?.locality ??
                placemark?.subAdministrativeArea ??
                placemark?.administrativeArea ??
                'Unknown',
          );
          candidateBagData = <BagData>[selectedBagData];
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
        candidateBagData = <BagData>[selectedBagData];
      }

      if (candidateBagData.length < _targetBagCandidateCount) {
        final straat = (placemark?.thoroughfare ?? placemark?.street ?? '').trim();
        final plaats = (placemark?.locality ??
                placemark?.subAdministrativeArea ??
                placemark?.administrativeArea ??
                '')
            .trim();
        final queryCandidates = <String>{
          [straat, plaats].where((part) => part.isNotEmpty).join(' ').trim(),
          [postcode, huisnummer].where((part) => part.isNotEmpty).join(' ').trim(),
          [postcode, plaats].where((part) => part.isNotEmpty).join(' ').trim(),
          _manualAddressController.text.trim(),
        }.where((item) => item.isNotEmpty).toSet();

        final seenKeys = candidateBagData
            .map(_candidateIdentityKey)
            .toSet();
        var qAdded = 0;

        for (var index = 0; index < queryCandidates.length; index++) {
          final query = queryCandidates.elementAt(index);
          List<BagData> qResults = const <BagData>[];
          try {
            qResults = await BagService.lookupCandidatesByQuery(
              query,
              _bagApiKey,
            ).timeout(const Duration(seconds: 10));
          } catch (_) {
            qResults = const <BagData>[];
          }

          for (final candidate in qResults) {
            final key = _candidateIdentityKey(candidate);
            if (!seenKeys.add(key)) {
              continue;
            }
            candidateBagData.add(candidate);
            candidateNearestRank[key] = candidateNearestRank[key] ?? (200 + index);
            qAdded++;
          }

          if (candidateBagData.length >= 8) {
            break;
          }
        }

        if (qAdded > 0) {
        }
      }

      if (candidateBagData.length < _targetBagCandidateCount) {
        final nearbyPlacemarkCandidates = await _collectNearbyPlacemarkCandidates(
          seedPlacemarks: placemarks,
          sampledPlacemarkBatches: sampledPlacemarkBatches,
        );
        if (fetchId != _activeFetchId || !mounted) return;

        final seenKeys = candidateBagData.map(_candidateIdentityKey).toSet();

        for (final nearbyEntry in nearbyPlacemarkCandidates) {
          final candidate = nearbyEntry.key;
          final key = _candidateIdentityKey(candidate);
          if (!seenKeys.add(key)) {
            continue;
          }

          candidateBagData.add(candidate);
          candidateNearestRank[key] = candidateNearestRank[key] ?? (1000 + nearbyEntry.value);
        }


        if (selectedBagData == null && candidateBagData.isNotEmpty) {
          selectedBagData = candidateBagData.first;
        }
      }

      final inputMatchedCandidates = candidateBagData
          .where(_matchesCurrentInput)
          .toList(growable: false);
      final inputMatchedKeys = inputMatchedCandidates
          .map(_candidateIdentityKey)
          .toSet();
      if (inputMatchedCandidates.isNotEmpty) {
        if (selectedBagData == null ||
            !inputMatchedKeys.contains(_candidateIdentityKey(selectedBagData))) {
          selectedBagData = inputMatchedCandidates.first;
        }
      }

      final distanceByKey = <String, double>{};
      final withDistance = <BagData>[];
      final withoutDistance = <BagData>[];
      for (final candidate in candidateBagData) {
        final distance = _distanceToCandidateMeters(
          candidate: candidate,
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
        if (distance == null) {
          withoutDistance.add(candidate);
          continue;
        }
        withDistance.add(candidate);
        distanceByKey[_candidateIdentityKey(candidate)] = distance;
      }

      final withinRadius = withDistance
          .where((candidate) {
            final key = _candidateIdentityKey(candidate);
            final distance = distanceByKey[key];
            return distance != null && distance <= _gpsBagRadiusMeters;
          })
          .toList(growable: false);

      List<BagData> sortByDistance(List<BagData> items) {
        final sorted = List<BagData>.from(items);
        sorted.sort((left, right) {
          final leftDistance = distanceByKey[_candidateIdentityKey(left)] ?? double.infinity;
          final rightDistance = distanceByKey[_candidateIdentityKey(right)] ?? double.infinity;
          return leftDistance.compareTo(rightDistance);
        });
        return sorted;
      }

      if (withDistance.isNotEmpty) {
        if (withinRadius.isNotEmpty) {
          final sortedWithinRadius = sortByDistance(withinRadius);
          final sortedAll = sortByDistance(withDistance);
          final selectedKeys =
              sortedWithinRadius.map(_candidateIdentityKey).toSet();
          final supplementalNearby = sortedAll
              .where((candidate) =>
                  !selectedKeys.contains(_candidateIdentityKey(candidate)))
              .take(5)
              .toList(growable: false);

          final supplementalUnknownDistance = withoutDistance
            .where((candidate) =>
              !selectedKeys.contains(_candidateIdentityKey(candidate)))
            .take(8)
            .toList(growable: false);

          candidateBagData = <BagData>[
            ...sortedWithinRadius,
            ...supplementalNearby,
          ...supplementalUnknownDistance,
          ];
          if (selectedBagData == null ||
            !candidateBagData
              .map(_candidateIdentityKey)
              .contains(_candidateIdentityKey(selectedBagData))) {
          selectedBagData = sortedWithinRadius.first;
          }
        } else {
          final nearestCandidates = sortByDistance(withDistance)
              .take(5)
              .toList(growable: false);

          final supplementalUnknownDistance = withoutDistance
            .take(8)
            .toList(growable: false);

          candidateBagData = <BagData>[
          ...nearestCandidates,
          ...supplementalUnknownDistance,
          ];
          if (selectedBagData == null ||
            !candidateBagData
              .map(_candidateIdentityKey)
              .contains(_candidateIdentityKey(selectedBagData))) {
          selectedBagData = nearestCandidates.isNotEmpty
            ? nearestCandidates.first
            : (supplementalUnknownDistance.isNotEmpty
              ? supplementalUnknownDistance.first
              : null);
          }
        }
      } else {
      }

      setState(() {
        candidateBagData.sort(
          (left, right) {
            final leftIsInputMatch =
                inputMatchedKeys.contains(_candidateIdentityKey(left));
            final rightIsInputMatch =
                inputMatchedKeys.contains(_candidateIdentityKey(right));
            if (leftIsInputMatch != rightIsInputMatch) {
              return leftIsInputMatch ? -1 : 1;
            }

            final leftDistance = distanceByKey[_candidateIdentityKey(left)] ?? double.infinity;
            final rightDistance = distanceByKey[_candidateIdentityKey(right)] ?? double.infinity;
            if (leftDistance != rightDistance) {
              return leftDistance.compareTo(rightDistance);
            }

            final leftKey = _candidateIdentityKey(left);
            final rightKey = _candidateIdentityKey(right);
            final leftRank = candidateNearestRank[leftKey] ?? 1 << 20;
            final rightRank = candidateNearestRank[rightKey] ?? 1 << 20;
            if (leftRank != rightRank) {
              return leftRank.compareTo(rightRank);
            }
            return _candidateSortKey(left).compareTo(_candidateSortKey(right));
          },
        );
        final gpsKey = _formatBagCandidate(gpsAddressCandidate).toLowerCase();
        final containsGpsCandidate = candidateBagData.any(
          (item) => _formatBagCandidate(item).toLowerCase() == gpsKey,
        );
        final radiusFilterApplied = withDistance.isNotEmpty;
        if (!radiusFilterApplied && !containsGpsCandidate) {
          candidateBagData = <BagData>[gpsAddressCandidate, ...candidateBagData];
        }
        _bagCandidates = candidateBagData;
        _bagData = selectedBagData;
      });

      if (selectedBagData != null) {
        await _lookupWozForAddress(selectedBagData);
        await _lookupEpLabelForAddress(selectedBagData);
        final savedCount = await _loadPhotoCountForAddress(selectedBagData);
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
    final currentAddress = _bagData!;

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
      bagData: currentAddress,
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

    final effectief = _withOpdrachtgever(_bagData!);
    final wwsData =
        _wwsPerAdres[_candidateIdentityKey(_bagData!)] ?? const WwsInvoerData();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OpnameAfsluitenScreen(
          bagData: effectief,
          dossierName: effectief.getFolderName(),
          initialWwsData: wwsData,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    await _saveDossierAddress(effectief);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Adres opgeslagen voor later: ${_bagData!.getFolderName()}')),
    );
  }

  Future<void> _openWwsInvoer() async {
    if (_bagData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Haal eerst een adres op voor het dossier.')),
      );
      return;
    }
    final key = _candidateIdentityKey(_bagData!);
    final initial = _wwsPerAdres[key] ?? const WwsInvoerData();
    final result = await Navigator.of(context).push<WwsInvoerData>(
      MaterialPageRoute(
        builder: (_) => WwsInvoerScreen(
          dossierNaam: _bagData!.getFolderName(),
          initialData: initial,
          wozVoorgevuld: _wozWaarde,
          bouwjaarVoorgevuld: int.tryParse(
            (_bagData!.oorspronkelijkBouwjaar ?? '').trim(),
          ),
          energieLabelVoorgevuld: _energieLabel,
        ),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _wwsPerAdres[key] = result;
    });
    await _saveWwsPerAdres();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('WWS bijgewerkt: ${result.korteStatus}')),
    );
  }

  Future<void> _openPortefeuille() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const PortefeuilleScherm(),
      ),
    );
  }

  Future<void> _openBeslisschemas() async {
    if (_bagData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Haal eerst een adres op voor het dossier.')),
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BeslisschemasScreen(
          bagData: _bagData!,
          dossierName: _bagData!.getFolderName(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('blueprint collective'),
        actions: [
          IconButton(
            tooltip: 'Instellingen',
            icon: const Icon(Icons.settings),
            onPressed: _openInstellingen,
          ),
        ],
      ),
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
                      'blueprint collective',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_bagData != null)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 48, color: BrandColors.navy),
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
                      if (_wozBusy)
                        const SizedBox(
                          width: 160,
                          child: LinearProgressIndicator(),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        _wozWaarde != null
                            ? 'WOZ: EUR ${_wozWaarde.toString()} ${_wozPeildatum.isNotEmpty ? '(peildatum $_wozPeildatum)' : ''}'
                            : _wozStatus,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_energieLabel != null) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _epLabel != null
                              ? () => _toonLabelDetails(_epLabel!)
                              : null,
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _labelKleur(_energieLabel!),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.energy_savings_leaf,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Energielabel  ${_energieLabel!}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (_epLabel != null) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    (_epLabel!.isVoor2021 ||
                                            _epLabel!.isVerlopen)
                                        ? Icons.warning_amber_rounded
                                        : Icons.info_outline,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _epLabel != null
                              ? 'Tik voor details (datum, geldigheid)'
                              : 'Er is al een geregistreerd label',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54),
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
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildOpdrachtgeverSection(),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildActionGrid(),
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
                              final isSelected = _isSelectedBagCandidate(candidate);
                              final candidateLevel =
                                  _candidateStatusLevel(candidate);
                              final candidateColor =
                                  _lookupStatusColor(candidateLevel);
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.circle,
                                  size: 12,
                                  color: candidateColor,
                                ),
                                title: Text(_formatBagCandidate(candidate)),
                                subtitle: Text(
                                  _candidateStatusText(candidate),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: candidateColor),
                                ),
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
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Blok om de opdrachtgever te kiezen/beheren + het opdrachtnummer in te
  /// voeren. De keuze reist mee met het dossier (JSON/XML/PDF).
  Widget _buildOpdrachtgeverSection() {
    final items = <Opdrachtgever>[..._opdrachtgevers];
    final sel = _selectedOpdrachtgever;
    // Toon een gekozen (bv. uit een opgeslagen dossier) ook als die niet meer
    // in de actieve lijst staat.
    if (sel != null && !items.any((o) => o.id == sel.id)) {
      items.insert(0, sel);
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.business, size: 20, color: BrandColors.navy),
                const SizedBox(width: 8),
                Text(
                  'Opdrachtgever',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                _syncingOpdrachtgevers
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Synchroniseer met Nextcloud',
                        icon: const Icon(Icons.sync),
                        onPressed: () => _syncOpdrachtgevers(),
                      ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: sel?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Kies opdrachtgever',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('— Geen —'),
                      ),
                      for (final o in items)
                        DropdownMenuItem<String>(
                          value: o.id,
                          child: Text(
                            o.displayLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _onSelectOpdrachtgever,
                  ),
                ),
                IconButton(
                  tooltip: 'Nieuwe opdrachtgever',
                  icon: const Icon(Icons.add_circle_outline),
                  color: BrandColors.navy,
                  onPressed: _nieuweOpdrachtgever,
                ),
                IconButton(
                  tooltip: 'Bewerk/verwijder',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: sel == null ? null : _bewerkOpdrachtgever,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextField(
                controller: _opdrachtnummerController,
                decoration: const InputDecoration(
                  labelText: 'Opdrachtnummer (deze opname)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Uniform rooster van vierkante huisstijl-knoppen voor de hoofdacties.
  ///
  /// Oranje = belangrijkste acties (adres ophalen, naar camera); marineblauw =
  /// de overige acties. Knoppen die een adres vereisen zijn uitgeschakeld tot
  /// er een adres gekozen is, zodat de lay-out stabiel blijft.
  Widget _buildActionGrid() {
    final bool hasAddress = _bagData != null;
    final bool busy = _isLoading;

    final tiles = <Widget>[
      BrandTileButton(
        icon: Icons.gps_fixed,
        label: 'Adres ophalen',
        color: BrandColors.orange,
        onPressed: busy ? null : _fetchAddress,
      ),
      BrandTileButton(
        icon: Icons.photo_camera,
        label: 'Naar camera',
        color: BrandColors.orange,
        onPressed: (busy || !hasAddress) ? null : _proceedToPhotos,
      ),
      BrandTileButton(
        icon: Icons.search,
        label: 'Zoek op postcode',
        onPressed: busy ? null : _searchBagByManualPair,
      ),
      BrandTileButton(
        icon: Icons.edit_location_alt,
        label: 'Handmatig adres',
        onPressed: busy ? null : _useManualAddress,
      ),
      BrandTileButton(
        icon: Icons.assignment_turned_in,
        label: 'Opname afsluiten',
        onPressed: (busy || !hasAddress) ? null : _openOpnameAfsluiten,
      ),
      BrandTileButton(
        icon: Icons.calculate_outlined,
        label: 'WWS',
        onPressed: (busy || !hasAddress) ? null : _openWwsInvoer,
      ),
      BrandTileButton(
        icon: Icons.account_tree_outlined,
        label: 'Beslisschemas',
        onPressed: (busy || !hasAddress) ? null : _openBeslisschemas,
      ),
      BrandTileButton(
        icon: Icons.bookmark_add_outlined,
        label: 'Adres opslaan',
        onPressed: (busy || !hasAddress) ? null : _saveCurrentAddressForLater,
      ),
      BrandTileButton(
        icon: Icons.business,
        label: 'Mijn eenheden',
        onPressed: busy ? null : _openPortefeuille,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1,
      children: tiles,
    );
  }

  @override
  void dispose() {
    _manualAddressController.dispose();
    _manualPostcodeController.dispose();
    _manualHuisnummerController.dispose();
    _opdrachtnummerController.dispose();
    super.dispose();
  }
}

/// Resultaat van de opdrachtgever-dialoog: een (gewijzigde) opdrachtgever, of
/// een verzoek tot verwijderen.
class _OpdrachtgeverDialogResult {
  /// De ingevoerde/gewijzigde opdrachtgever (null bij verwijderen).
  final Opdrachtgever? opdrachtgever;

  /// True als de gebruiker op verwijderen tikte.
  final bool verwijderen;

  const _OpdrachtgeverDialogResult({this.opdrachtgever, this.verwijderen = false});
}

/// Dialoog om een opdrachtgever toe te voegen of te bewerken.
class _OpdrachtgeverDialog extends StatefulWidget {
  const _OpdrachtgeverDialog({this.bestaande});

  /// Bestaande opdrachtgever (bewerken) of null (nieuw).
  final Opdrachtgever? bestaande;

  @override
  State<_OpdrachtgeverDialog> createState() => _OpdrachtgeverDialogState();
}

class _OpdrachtgeverDialogState extends State<_OpdrachtgeverDialog> {
  late final TextEditingController _naam;
  late final TextEditingController _contact;
  late final TextEditingController _email;
  late final TextEditingController _tel;

  @override
  void initState() {
    super.initState();
    final b = widget.bestaande;
    _naam = TextEditingController(text: b?.naam ?? '');
    _contact = TextEditingController(text: b?.contactpersoon ?? '');
    _email = TextEditingController(text: b?.email ?? '');
    _tel = TextEditingController(text: b?.telefoon ?? '');
  }

  @override
  void dispose() {
    _naam.dispose();
    _contact.dispose();
    _email.dispose();
    _tel.dispose();
    super.dispose();
  }

  void _opslaan() {
    final naam = _naam.text.trim();
    if (naam.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Naam is verplicht.')),
      );
      return;
    }
    final b = widget.bestaande;
    final result = Opdrachtgever(
      id: b?.id ?? '',
      naam: naam,
      contactpersoon: _contact.text.trim(),
      email: _email.text.trim(),
      telefoon: _tel.text.trim(),
      gewijzigdOp: DateTime.now().toUtc(),
    );
    Navigator.of(context)
        .pop(_OpdrachtgeverDialogResult(opdrachtgever: result));
  }

  @override
  Widget build(BuildContext context) {
    final bewerken = widget.bestaande != null;
    return AlertDialog(
      title: Text(bewerken ? 'Opdrachtgever bewerken' : 'Nieuwe opdrachtgever'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _naam,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Naam *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contact,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Contactpersoon',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefoon',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (bewerken)
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              const _OpdrachtgeverDialogResult(verwijderen: true),
            ),
            child: const Text('Verwijderen',
                style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuleren'),
        ),
        FilledButton(
          onPressed: _opslaan,
          child: const Text('Opslaan'),
        ),
      ],
    );
  }
}

