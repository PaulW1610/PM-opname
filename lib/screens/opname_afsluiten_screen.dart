import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/app_secrets.dart';
import '../models/gebouwtype_optie.dart';
import '../models/wws_invoer_data.dart';
import '../services/afsluit_form_store.dart';
import '../services/app_settings_service.dart';
import '../services/bag_service.dart';
import '../services/blueprint_api_service.dart';
import '../services/nextcloud_service.dart';
import '../services/dossier_photo_store.dart';
import '../services/dossier_service.dart';
import '../services/json_export_service.dart';
import '../services/opmerkingen_formulier_service.dart';
import '../services/overige_ruimte_beslisschema_service.dart';
import '../services/three_d_bag_service.dart';
import '../services/xml_export_service.dart';
import '../theme/brand.dart';
import '../widgets/pm_branding_header.dart';

class OpnameAfsluitenScreen extends StatefulWidget {
  final BagData bagData;
  final String dossierName;
  final WwsInvoerData initialWwsData;

  const OpnameAfsluitenScreen({
    Key? key,
    required this.bagData,
    required this.dossierName,
    this.initialWwsData = const WwsInvoerData(),
  }) : super(key: key);

  @override
  State<OpnameAfsluitenScreen> createState() => _OpnameAfsluitenScreenState();
}

class _OpnameAfsluitenScreenState extends State<OpnameAfsluitenScreen> {
  static const String _bagPdfBuildVersion = '2026-02-27-v3';
  static const String _bagApiKey = AppSecrets.bagApiKey;
  static const List<String> _vloerOpties = ['Hout', 'Beton'];
  static const List<String> _ventilatieOpties = [
    'A - Natuurlijk (toevoer + afvoer)',
    'B - Mechanische toevoer, natuurlijke afvoer',
    'C - Natuurlijke toevoer, mechanische afvoer',
    'C - Vraaggestuurd (CO₂)',
    'C - Vraaggestuurd (RV)',
    'D - Balansventilatie',
    'D - Balansventilatie met WTW',
    'D - Vraaggestuurd (CO₂)',
  ];
  static const List<String> _verwarmingOpties = [
    'Gasgestookte Ketel',
    'Lokaal Gasakachel',
    'Lokaal Olie Kachel',
    'Electrische Verwarming',
    'Moederhaard',
    'Gasgestookte Ketel',
    'WKK',
    'Warmtepomp Gasabsorptie',
    'Warmtepomp Gasmotor',
    'Warmtepomp Electrisch',
    'Biomassa kachel',
    'Biomassakachel handgestookt',
    'Biomassa Kachel automatisch gestookt',
  ];
  static const List<String> _tapwaterOpties = [
    'Tapwater zelfde als Verwarming',
    'Boiler',
    'Keukengeiser',
  ];
  static const List<String> _gegevensOpties = [
    'Zonnepanelen',
    'Fotos verbouwing',
    'Fotos isolatie',
    'Facturen aannemer',
  ];

  String _gebouwCategorie = GebouwtypeOptie.eengezins;
  GebouwtypeOptie _gebouwType =
      GebouwtypeOptie.voorCategorie(GebouwtypeOptie.eengezins).first;
  String _vloerType = _vloerOpties.first;
  String _ventilatieType = _ventilatieOpties.first;
  int _verwarmingType = 1;
  String _tapwaterType = _tapwaterOpties.first;
  bool? _koelingAanwezig;
  bool? _zonneEnergieAanwezig;
  bool? _renovatieVanToepassing;
  bool? _alleRamenHetzelfde;
  final Set<String> _aangeleverdeGegevens = <String>{};
  late final TextEditingController _bouwjaarController;
  late final TextEditingController _huurActueelController;
  late final TextEditingController _wwsPuntenController;
  late final TextEditingController _wwsMaxHuurController;
  late final TextEditingController _wwsWozWaardeController;
  BagData? _resolvedBagData;
  late WwsInvoerData _wwsData;
  bool _verhuurNaarObject = false;
  bool _isSaving = false;
  String _bagPdfStatus = 'Onbekend';
  String _gebouwhoogte = '';

  String get _verwarmingTypeLabel {
    final index = _verwarmingType - 1;
    if (index < 0 || index >= _verwarmingOpties.length) {
      return _verwarmingOpties.first;
    }
    return _verwarmingOpties[index];
  }

  @override
  void initState() {
    super.initState();
    _bouwjaarController = TextEditingController(
      text: (widget.bagData.oorspronkelijkBouwjaar ?? '').trim(),
    );
    _huurActueelController = TextEditingController();
    _wwsData = widget.initialWwsData;
    _wwsPuntenController = TextEditingController(text: _wwsData.punten);
    _wwsMaxHuurController = TextEditingController(text: _wwsData.maxHuur);
    _wwsWozWaardeController = TextEditingController(text: _wwsData.wozWaarde);
    _prefillInitialObjectData();
    _restoreForm();
  }

  Future<void> _prefillInitialObjectData() async {
    await _prefillBouwjaarFromBag();
    await _prefillGebouwhoogteFrom3dBag();
  }

  Timer? _formSaveTimer;

  /// Herstelt de eerder ingevulde formulierstaat voor dit dossier (indien er
  /// een bewaard concept is), zodat het scherm niet op nul begint.
  Future<void> _restoreForm() async {
    final data = await AfsluitFormStore.laad(widget.dossierName);
    if (data.isEmpty || !mounted) return;
    setState(() => _applyFormData(data));
  }

  /// Zet de bewaarde waarden terug op de invoervelden.
  void _applyFormData(Map<String, dynamic> d) {
    String? s(String k) => d[k] is String ? d[k] as String : null;
    bool? b(String k) => d[k] is bool ? d[k] as bool : null;

    final cat = s('gebouwCategorie');
    if (cat != null && GebouwtypeOptie.categorieen.contains(cat)) {
      _gebouwCategorie = cat;
    }
    final typeId = s('gebouwTypeId');
    if (typeId != null) {
      final match = GebouwtypeOptie.opties
          .where((o) => o.id == typeId)
          .toList(growable: false);
      if (match.isNotEmpty) _gebouwType = match.first;
    }
    if (s('vloerType') != null) _vloerType = s('vloerType')!;
    if (s('ventilatieType') != null) _ventilatieType = s('ventilatieType')!;
    if (d['verwarmingType'] is int) _verwarmingType = d['verwarmingType'] as int;
    if (s('tapwaterType') != null) _tapwaterType = s('tapwaterType')!;
    _koelingAanwezig = b('koelingAanwezig') ?? _koelingAanwezig;
    _zonneEnergieAanwezig = b('zonneEnergieAanwezig') ?? _zonneEnergieAanwezig;
    _renovatieVanToepassing =
        b('renovatieVanToepassing') ?? _renovatieVanToepassing;
    _alleRamenHetzelfde = b('alleRamenHetzelfde') ?? _alleRamenHetzelfde;
    if (d['aangeleverdeGegevens'] is List) {
      _aangeleverdeGegevens
        ..clear()
        ..addAll((d['aangeleverdeGegevens'] as List).whereType<String>());
    }
    if (s('bouwjaar') != null) _bouwjaarController.text = s('bouwjaar')!;
    if (s('huurActueel') != null) _huurActueelController.text = s('huurActueel')!;
    _verhuurNaarObject = b('verhuurNaarObject') ?? _verhuurNaarObject;
    // WWS-invoer (waarden + schakelaar) terugzetten.
    final wws = d['wws'];
    if (wws is Map) {
      _wwsData = _wwsData.copyWith(
        punten: wws['punten'] is String ? wws['punten'] as String : null,
        maxHuur: wws['maxHuur'] is String ? wws['maxHuur'] as String : null,
        wozWaarde: wws['woz'] is String ? wws['woz'] as String : null,
        toepassen: wws['toepassen'] is bool ? wws['toepassen'] as bool : null,
      );
      _wwsPuntenController.text = _wwsData.punten;
      _wwsMaxHuurController.text = _wwsData.maxHuur;
      _wwsWozWaardeController.text = _wwsData.wozWaarde;
    }
  }

  /// De huidige formulierstaat als bewaarbaar mapje.
  Map<String, dynamic> _currentFormData() => <String, dynamic>{
        'gebouwCategorie': _gebouwCategorie,
        'gebouwTypeId': _gebouwType.id,
        'vloerType': _vloerType,
        'ventilatieType': _ventilatieType,
        'verwarmingType': _verwarmingType,
        'tapwaterType': _tapwaterType,
        'koelingAanwezig': _koelingAanwezig,
        'zonneEnergieAanwezig': _zonneEnergieAanwezig,
        'renovatieVanToepassing': _renovatieVanToepassing,
        'alleRamenHetzelfde': _alleRamenHetzelfde,
        'aangeleverdeGegevens': _aangeleverdeGegevens.toList(),
        'bouwjaar': _bouwjaarController.text,
        'huurActueel': _huurActueelController.text,
        'verhuurNaarObject': _verhuurNaarObject,
        'wws': <String, dynamic>{
          'punten': _wwsPuntenController.text,
          'maxHuur': _wwsMaxHuurController.text,
          'woz': _wwsWozWaardeController.text,
          'toepassen': _wwsData.toepassen,
        },
      };

  /// Stille automatische opslag van de formulierstaat (kort na een wijziging),
  /// zodat er nooit iets verloren gaat.
  void _scheduleFormSave() {
    _formSaveTimer?.cancel();
    _formSaveTimer = Timer(const Duration(milliseconds: 500), () {
      AfsluitFormStore.bewaar(widget.dossierName, _currentFormData());
    });
  }

  @override
  void dispose() {
    _formSaveTimer?.cancel();
    // Laatste stand bewaren vóór de controllers weg zijn (vangnet naast de
    // autosave), zodat het scherm bij terugkomen niet op nul staat.
    AfsluitFormStore.bewaar(widget.dossierName, _currentFormData());
    _bouwjaarController.dispose();
    _huurActueelController.dispose();
    _wwsPuntenController.dispose();
    _wwsMaxHuurController.dispose();
    _wwsWozWaardeController.dispose();
    super.dispose();
  }

  Future<String> _syncNaarBlueprintObject(
    BagData bagData, {
    required File bewijsFoto,
  }) async {
    final config = await BlueprintApiService.loadConfig();
    if (!config.hasCredentials) {
      return 'Websitekoppeling overgeslagen: geen Blueprint credentials in Instellingen.';
    }

    // Losse adresvelden zijn VERPLICHT bij een app-intake (contract §3.3,
    // v0.62.1): het portaal draait hierop voor de weergavenaam, pand-
    // groepering, WOZ-verversen en de EP-Online-labelbewaking. Alleen een
    // samengeplakte `titel` is niet genoeg — de eenheid komt dan zonder naam
    // in het dashboard.
    final straat = _adresVeld(bagData.adres);
    final huisnr = _adresVeld(bagData.huisnummer);
    final toev = _adresVeld(bagData.huisletterHuisnummertoevoeging);
    final postcode = _adresVeld(bagData.postcode);
    final plaats = _adresVeld(bagData.plaatsnaam);

    // Contract §3.3: sturen we straat + huisnummer mee, dan MAG `titel` weg en
    // maakt de site de naam zelf ("straat huisnr toev"). We laten `titel` dan
    // bewust weg, zodat een meegestuurde titel de automatische naamgeving niet
    // kan overrulen. Alleen als het adres onbekend is valt de app terug op een
    // titel, anders heet de eenheid op de site "Nieuwe eenheid".
    final heeftAdres = straat != null && huisnr != null;
    final adresTitel = bagData.getFolderName().trim();

    final fields = <String, String>{
      if (!heeftAdres)
        'titel': adresTitel.isNotEmpty ? adresTitel : widget.dossierName,
      if (straat != null) 'straat': straat,
      if (huisnr != null) 'huisnr': huisnr,
      if (toev != null) 'toev': toev,
      if (postcode != null) 'postcode': postcode,
      if (plaats != null) 'plaats': plaats,
      if ((bagData.bagPandId ?? '').trim().isNotEmpty)
        'pand': (bagData.bagPandId ?? '').trim(),
      if (_wwsData.toepassen && _wwsData.wozWaarde.trim().isNotEmpty)
        'woz': _wwsWozWaardeController.text.trim(),
      'wws_actief': _wwsData.toepassen ? '1' : '0',
    };

    // Wat er van het WWS meegaat, zodat we het achteraf kunnen terugzien.
    var wwsVerstuurd = 'niet gekoppeld';
    if (_wwsData.toepassen) {
      final opname = _wwsData.opnameData;
      if (opname != null) {
        // Contract §3.9: stuur het WWS als dossier in de INVOER-vorm (§3.2).
        // De server herrekent zelf wws_punten en huur_max uit dit dossier,
        // dus die sturen we NIET mee (server is de rekenmeester).
        final dossier = opname.toApiJson();
        fields['wws_dossier'] = jsonEncode(dossier);
        final aantalRuimtes = opname.binnenruimtes.length;
        wwsVerstuurd = 'dossier verstuurd ($aantalRuimtes ruimtes)';
      } else {
        // Terugval als de volledige invoer ontbreekt: stuur de bekende
        // getallen mee zodat de eenheid toch punten/huur toont.
        if (_wwsData.punten.trim().isNotEmpty) {
          fields['wws_punten'] = _wwsPuntenController.text.trim();
        }
        if (_wwsData.maxHuur.trim().isNotEmpty) {
          fields['huur_max'] = _wwsMaxHuurController.text.trim();
        }
        wwsVerstuurd = _wwsData.punten.trim().isNotEmpty
            ? 'alleen punten (${_wwsData.punten.trim()}), geen dossier'
            : 'LEEG — geen invoer gevonden, website kan niets rekenen';
      }
    }

    final created = await BlueprintApiService.createEntiteit(fields: fields);
    final entiteitId = int.tryParse((created['id'] ?? '').toString());

    if (entiteitId != null && await bewijsFoto.exists()) {
      await BlueprintApiService.uploadDocument(
        entiteitId: entiteitId,
        bestand: bewijsFoto,
        categorie: 'foto',
      );
    }

    if (_verhuurNaarObject && entiteitId != null) {
      final verhuurFields = <String, dynamic>{
        if (_huurActueelController.text.trim().isNotEmpty)
          'huur_actueel': _huurActueelController.text.trim(),
        if (_wwsData.wozWaarde.trim().isNotEmpty)
          'woz': _wwsWozWaardeController.text.trim(),
      };
      await BlueprintApiService.saveVerhuur(
        entiteitId: entiteitId,
        fields: verhuurFields,
      );
    }

    // Antwoord van de website erbij: zo zie je meteen of daar een naam en een
    // puntentelling uit gerold zijn, in plaats van het pas op de site te
    // ontdekken.
    var serverAdres = (created['adres'] ?? '').toString().trim();
    final serverWws = (created['wws'] ?? '').toString().trim();
    final verhuurInfo = _verhuurNaarObject ? 'ja' : 'nee';
    var reparatie = '';

    // De site noemde eenheden tot nu toe naar de 16-cijferige BAG-pandcode die
    // wij als `pand` meesturen, in plaats van naar het adres. Zolang dat aan de
    // websitekant niet is opgelost repareren we het zelf: is de naam leeg of
    // puur numeriek, dan sturen we in één extra bewerking (§3.3, POST op
    // /entiteit/{id}) de adresvelden nogmaals mee mét een expliciete `titel`.
    if (entiteitId != null && _naamOnbruikbaar(serverAdres)) {
      final herstelTitel =
          adresTitel.isNotEmpty ? adresTitel : widget.dossierName;
      try {
        final hersteld = await BlueprintApiService.updateEntiteit(
          id: entiteitId,
          fields: <String, String>{
            'titel': herstelTitel,
            if (straat != null) 'straat': straat,
            if (huisnr != null) 'huisnr': huisnr,
            if (toev != null) 'toev': toev,
            if (postcode != null) 'postcode': postcode,
            if (plaats != null) 'plaats': plaats,
          },
        );
        final naNaam = (hersteld['adres'] ?? '').toString().trim();
        if (!_naamOnbruikbaar(naNaam)) {
          serverAdres = naNaam;
          reparatie = 'Naam stond eerst verkeerd (nummer) en is door de app '
              'hersteld naar "$naNaam".';
        } else {
          reparatie =
              'LET OP: de site blijft de eenheid een nummer noemen, ook na '
              'een herstelpoging met adres "$herstelTitel". Dit moet aan de '
              'websitekant opgelost worden — meld het even.';
        }
      } on Exception catch (e) {
        reparatie = 'Naam herstellen mislukte: $e';
      }
    }

    final serverUrl = (created['url'] ?? '').toString().trim();

    return <String>[
      'Object gekoppeld aan website.',
      'Naam op site: ${serverAdres.isNotEmpty ? serverAdres : '(leeg!)'}',
      if (reparatie.isNotEmpty) reparatie,
      if (serverUrl.isNotEmpty) 'Link: $serverUrl',
      'WWS verstuurd: $wwsVerstuurd',
      'WWS-punten volgens site: '
          '${serverWws.isNotEmpty && serverWws != '0' ? serverWws : '(leeg!)'}',
      'Verhuurgegevens meegestuurd: $verhuurInfo',
    ].join('\n');
  }

  /// Korte melding onder de WWS-schakelaar: staat er invoer klaar die de
  /// website kan doorrekenen, of gaat er straks niets mee?
  String _wwsDossierStatus() {
    final opname = _wwsData.opnameData;
    if (opname == null) {
      return 'Geen WWS-invoer gevonden voor dit adres';
    }
    final ruimtes = opname.binnenruimtes.length;
    final punten = _wwsData.punten.trim();
    return 'WWS-invoer klaar: $ruimtes ruimtes'
        '${punten.isNotEmpty ? ', $punten punten in de app' : ''}';
  }

  /// Adresveld schoonmaken; geeft null terug als er niets bruikbaars staat
  /// (leeg, "-" of het BAG-antwoord "unknown").
  /// Een naam die leeg is of alleen uit cijfers bestaat (zoals de 16-cijferige
  /// BAG-pandcode) is geen adres — die willen we op de site niet zien staan.
  bool _naamOnbruikbaar(String naam) {
    final schoon = naam.trim();
    return schoon.isEmpty || RegExp(r'^[0-9]+$').hasMatch(schoon);
  }

  String? _adresVeld(String? waarde) {
    final schoon = (waarde ?? '').trim();
    if (schoon.isEmpty || schoon == '-' || schoon.toLowerCase() == 'unknown') {
      return null;
    }
    return schoon;
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  String _resolveBouwjaarForExport() {
    final manualValue = _bouwjaarController.text.trim();
    if (manualValue.isNotEmpty && manualValue != '0') {
      return manualValue;
    }
    final bagValue = ((_resolvedBagData ?? widget.bagData).oorspronkelijkBouwjaar ?? '').trim();
    return bagValue;
  }

  String _resolveBouwjaarBron() {
    final manualValue = _bouwjaarController.text.trim();
    if (manualValue.isNotEmpty && manualValue != '0') {
      return 'Handmatig';
    }
    final bagValue = ((_resolvedBagData ?? widget.bagData).oorspronkelijkBouwjaar ?? '').trim();
    if (bagValue.isNotEmpty && bagValue != '0') {
      return 'BAG';
    }
    return 'Geen';
  }

  Future<void> _prefillBouwjaarFromBag() async {
    try {
      final resolved = await BagService.resolveBagDataForExport(
        bagData: widget.bagData,
        apiKey: _bagApiKey,
      );
      _resolvedBagData = resolved;

      final resolvedBouwjaar = (resolved.oorspronkelijkBouwjaar ?? '').trim();
      final currentValue = _bouwjaarController.text.trim();
      final shouldAutofill = currentValue.isEmpty || currentValue == '0';

      if (shouldAutofill && resolvedBouwjaar.isNotEmpty && resolvedBouwjaar != '0') {
        _bouwjaarController.text = resolvedBouwjaar;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _prefillGebouwhoogteFrom3dBag() async {
    final bagData = _resolvedBagData ?? widget.bagData;
    final pandId = (bagData.bagPandId ?? '').trim();
    if (pandId.isEmpty) {
      return;
    }

    try {
      final heightMeters = await ThreeDBagService.fetchGebouwhoogteMeters(
        bagPandId: pandId,
      );
      if (heightMeters == null || heightMeters <= 0) {
        return;
      }

      final formatted = heightMeters.toStringAsFixed(2);
      if (!mounted) {
        _gebouwhoogte = formatted;
        return;
      }

      setState(() {
        _gebouwhoogte = formatted;
      });
    } catch (_) {}
  }

  /// Eén knop sluit de opname af: XML + PDF's + JSON maken, mailen, naar
  /// Nextcloud zetten (voor de zekerheid), de formulier-samenvatting opslaan en
  /// de eenheid op de website (blueprint-data.nl) aanmaken. Elke stap is
  /// best-effort: als Nextcloud of de website hapert, gaat de rest gewoon door
  /// en zie je per onderdeel wat er lukte.
  Future<void> _afsluiten() async {
    _dismissKeyboard();
    if (_renovatieVanToepassing == null || _alleRamenHetzelfde == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vul alle verplichte velden in.')),
      );
      return;
    }
    setState(() {
      _isSaving = true;
    });

    try {
      await _prefillBouwjaarFromBag();
      await _prefillGebouwhoogteFrom3dBag();
      final bagData = _resolvedBagData ?? widget.bagData;
      final bouwjaar = _resolveBouwjaarForExport();
      if (bouwjaar.isEmpty || bouwjaar == '0') {
        throw Exception(
          'Geen bouwjaar beschikbaar. Vul bouwjaar handmatig in.',
        );
      }

      final settings = await AppSettingsService.loadSettings();
      final xmlFile = await XmlExportService.createXmlForDossier(
        dossierName: widget.dossierName,
        straat: (bagData.adres ?? '').trim(),
        huisnummer: (bagData.huisnummer ?? '').trim(),
        huisletterToevoeging:
            (bagData.huisletterHuisnummertoevoeging ?? '').trim(),
        postcode: bagData.postcode.trim(),
        plaatsnaam: bagData.plaatsnaam.trim(),
        bouwjaar: bouwjaar,
        gebouwhoogte: _gebouwhoogte,
        bagId: (bagData.bagIdentificatie ?? '').trim(),
        bagPandId: (bagData.bagPandId ?? '').trim(),
        vakbekwaamheidsnummer: settings.examenNummerWonen,
        adviseurVoorletters: settings.adviseurVoorletters,
        adviseurTussenvoegsel: settings.adviseurTussenvoegsel,
        adviseurAchternaam: settings.adviseurAchternaam,
        objectClassificatie: _gebouwType.objectClassificatie,
      );

      final bagPdfFile = await BagService.downloadBagPdfForDossier(
        apiKey: _bagApiKey,
        dossierName: widget.dossierName,
        bagData: bagData,
      );

      final formulierPdfFile = await _createFormulierPdfForMail(
        bagData: bagData,
        bouwjaar: bouwjaar,
      );
      final beslisschemaPdfFile =
          await OverigeRuimteBeslisschemaService.generatePdfFromSavedIfComplete(
        dossierName: widget.dossierName,
        bagData: bagData,
      );
      final opmerkingenPdfFile =
          await OpmerkingenFormulierService.generatePdfFromSavedIfAny(
        dossierName: widget.dossierName,
        bagData: bagData,
      );

      final bagPandId = (bagData.bagPandId ?? '').trim();
      final drieDbagImageFile = bagPandId.isEmpty
          ? null
          : await ThreeDBagService.createGebouwOverzichtImageForDossier(
              bagPandId: bagPandId,
              dossierName: widget.dossierName,
            );

      // Fotolijst met machineleesbaar label per foto (uit de bestandsnaam),
      // zodat de pc-keten het toestel/onderdeel niet uit de foto hoeft te
      // herkennen. Label ontbreekt bij oude/ongelabelde foto's.
      final fotoLijstVoorJson =
          (await DossierPhotoStore.photosForPrefix(bagData.getPhotoFilePrefix()))
              .map((f) {
        final label = DossierPhotoStore.labelFromFilename(f.path);
        return <String, dynamic>{
          'bestand': f.path.split('/').last,
          if (label != null) 'label': label,
        };
      }).toList();

      final jsonFile = await JsonExportService.createJsonForDossier(
        dossierName: widget.dossierName,
        data: <String, dynamic>{
          'schemaVersie': JsonExportService.schemaVersie,
          'fotos': fotoLijstVoorJson,
          'dossierNaam': widget.dossierName,
          'geexporteerdOp': DateTime.now().toIso8601String(),
          'adres': {
            'straat': (bagData.adres ?? '').trim(),
            'huisnummer': (bagData.huisnummer ?? '').trim(),
            'huisletterToevoeging':
                (bagData.huisletterHuisnummertoevoeging ?? '').trim(),
            'postcode': bagData.postcode.trim(),
            'plaats': bagData.plaatsnaam.trim(),
          },
          'bag': {
            'identificatie': (bagData.bagIdentificatie ?? '').trim(),
            'pandId': (bagData.bagPandId ?? '').trim(),
          },
          'opdrachtgever': bagData.opdrachtgever?.toSnapshotJson(),
          'opdrachtnummer': (bagData.opdrachtnummer ?? '').trim(),
          'bouwjaar': bouwjaar,
          'bouwjaarBron': _resolveBouwjaarBron(),
          'gebouwhoogteMeter': _gebouwhoogte,
          'formulier': {
            'gebouwCategorie': _gebouwCategorie,
            'gebouwType': _gebouwType.type,
            'gebouwBuildingCategory': _gebouwType.buildingCategory,
            if (_gebouwType.sub != null) 'gebouwSub': _gebouwType.sub,
            'vloer': _vloerType,
            'ventilatie': _ventilatieType,
            'verwarming': _verwarmingTypeLabel,
            'tapwater': _tapwaterType,
            'koelingAanwezig': _koelingAanwezig,
            'zonneEnergieAanwezig': _zonneEnergieAanwezig,
            'renovatieVanToepassing': _renovatieVanToepassing,
            'alleRamenHetzelfde': _alleRamenHetzelfde,
            'aangeleverdeGegevens': _aangeleverdeGegevens.toList(),
          },
        },
      );

      final attachmentPaths = <String>[
        xmlFile.path,
        jsonFile.path,
        bagPdfFile.path,
        formulierPdfFile.path,
        if (beslisschemaPdfFile != null) beslisschemaPdfFile.path,
        if (opmerkingenPdfFile != null) opmerkingenPdfFile.path,
        if (drieDbagImageFile != null) drieDbagImageFile.path,
      ];
      final nextcloudRootFolder = _nextcloudRootFolderName(bagData);
      final recipientEmail = await AppSettingsService.loadEmailRecipient();

      if (mounted) {
        setState(() {
          _bagPdfStatus = 'Gegenereerd';
        });
      }

      final email = Email(
        body:
          'Bijgevoegd: XML export + JSON export + BAG PDF + Formulier PDF'
          '${beslisschemaPdfFile != null ? ' + Beslisschema PDF' : ''}'
          '${opmerkingenPdfFile != null ? ' + Opmerkingen PDF' : ''}'
          '${drieDbagImageFile != null ? ' + 3DBAG afbeelding' : ''} voor ${widget.dossierName}.',
        subject: 'XML export ${widget.dossierName}',
        recipients: [recipientEmail],
        attachmentPaths: attachmentPaths,
        isHTML: false,
      );

      final meldingen = <String>[];

      // 1. E-mail met alle bijlagen.
      await FlutterEmailSender.send(email);
      meldingen.add('E-mail geopend met de bijlagen.');

      // 2. Naar Nextcloud (voor de zekerheid) — export-bestanden -> EP/.
      if (await NextcloudService.isConfigured()) {
        final epFiles = attachmentPaths.map((p) => File(p)).toList();
        final fotoFiles = await DossierPhotoStore.photosForPrefix(
          bagData.getPhotoFilePrefix(),
        );
        final uploadResult = await NextcloudService.uploadDossier(
          rootFolderName: 'Lopend/$nextcloudRootFolder',
          filesBySubfolder: {
            'EP': epFiles,
            if (fotoFiles.isNotEmpty) 'foto\'s': fotoFiles,
          },
          ensureSubfolders: const [
            'foto\'s',
            'EP',
            'correspondentie',
            'onderbouwing',
          ],
        );
        if (uploadResult.uploadedCount > 0) {
          meldingen.add(
            '${uploadResult.uploadedCount} bestand(en) naar Nextcloud '
            '("$nextcloudRootFolder"/EP).',
          );
        }
        if (!uploadResult.isSuccess &&
            (uploadResult.message?.isNotEmpty ?? false)) {
          meldingen.add('Nextcloud-let op: ${uploadResult.message}');
        }
      } else {
        meldingen.add('Nextcloud niet ingesteld — overgeslagen.');
      }

      // 3. Formulier-samenvatting opslaan (tekst + PNG + Foto's-album). De PNG
      // dient meteen als bewijsfoto voor de website.
      final formResult =
          await DossierService.saveOpnameAfsluitingWithAlbumImage(
        dossierName: widget.dossierName,
        vloerType: _vloerType,
        ventilatieType: _ventilatieType,
        verwarmingType: _verwarmingTypeLabel,
        tapwaterType: _tapwaterType,
        koelingAanwezig: _koelingAanwezig,
        zonneEnergieAanwezig: _zonneEnergieAanwezig,
        renovatieVanToepassing: _renovatieVanToepassing!,
        alleRamenHetzelfde: _alleRamenHetzelfde!,
        aangeleverdeGegevens: _aangeleverdeGegevens.toList(growable: false),
      );

      // 4. Eenheid op de website (blueprint-data.nl) — best-effort.
      try {
        final websiteInfo = await _syncNaarBlueprintObject(
          bagData,
          bewijsFoto: File(formResult.imageFilePath),
        );
        meldingen.add(websiteInfo);
      } on BlueprintApiException catch (error) {
        meldingen.add('Websitekoppeling mislukt (${error.code}): ${error.message}');
      } catch (error) {
        meldingen.add('Websitekoppeling mislukt: $error');
      }

      if (mounted) {
        setState(() {
          _bagPdfStatus = 'Gegenereerd';
        });
      }
      // Formulierstaat is verstuurd/opgeslagen; het bewaarde concept mag weg.
      await AfsluitFormStore.wis(widget.dossierName);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Opname afgesloten'),
          content: SingleChildScrollView(
            child: Text(
              'Bouwjaar: $bouwjaar (bron: ${_resolveBouwjaarBron()})'
              '${_gebouwhoogte.isNotEmpty ? '\nGebouwhoogte: $_gebouwhoogte m (3DBAG)' : ''}'
              '\n\n${meldingen.join('\n')}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Afsluiten mislukt: $error')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  /// Root-mapnaam op Nextcloud: "postcode straat huisnummer(toevoeging)".
  String _nextcloudRootFolderName(BagData bagData) =>
      bagData.getNextcloudDossierName();

  Future<File> _createFormulierPdfForMail({
    required BagData bagData,
    required String bouwjaar,
  }) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final safeDossierName = widget.dossierName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    final file = File(
      '${documentsDir.path}/dossiers/$safeDossierName/formulier_export_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.parent.create(recursive: true);

    final doc = pw.Document();
    final opnameDatum = DateTime.now();
    final formulierNaam =
        'Opname - ${(bagData.adres ?? '').trim()} ${(bagData.huisnummer ?? '').trim()} ${bagData.postcode.trim()}';

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, text: formulierNaam.trim()),
          pw.Text(
            'Opname Datum: '
            '${opnameDatum.day.toString().padLeft(2, '0')}-'
            '${opnameDatum.month.toString().padLeft(2, '0')}-'
            '${opnameDatum.year} '
            '${opnameDatum.hour.toString().padLeft(2, '0')}:'
            '${opnameDatum.minute.toString().padLeft(2, '0')}',
          ),
          pw.Text('Dossier: ${widget.dossierName}'),
          pw.SizedBox(height: 8),
          pw.Text('Adres: ${bagData.adres ?? '-'} ${bagData.huisnummer ?? ''}'.trim()),
          pw.Text('Postcode: ${bagData.postcode}'),
          pw.Text('Plaats: ${bagData.plaatsnaam}'),
          pw.Text('Bouwjaar: $bouwjaar'),
          if (bagData.opdrachtgever != null ||
              (bagData.opdrachtnummer ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: 8),
            if (bagData.opdrachtgever != null)
              pw.Text('Opdrachtgever: ${bagData.opdrachtgever!.naam}'),
            if ((bagData.opdrachtgever?.contactpersoon ?? '').trim().isNotEmpty)
              pw.Text(
                  'Contactpersoon: ${bagData.opdrachtgever!.contactpersoon}'),
            if ((bagData.opdrachtgever?.email ?? '').trim().isNotEmpty)
              pw.Text('E-mail: ${bagData.opdrachtgever!.email}'),
            if ((bagData.opdrachtgever?.telefoon ?? '').trim().isNotEmpty)
              pw.Text('Telefoon: ${bagData.opdrachtgever!.telefoon}'),
            if ((bagData.opdrachtnummer ?? '').trim().isNotEmpty)
              pw.Text('Opdrachtnummer: ${bagData.opdrachtnummer!.trim()}'),
          ],
          pw.SizedBox(height: 12),
          pw.Text('Vloer: $_vloerType'),
          pw.Text('Ventilatie: $_ventilatieType'),
          pw.Text('Verwarming: $_verwarmingTypeLabel'),
          pw.Text('Tapwater: $_tapwaterType'),
          pw.Text('Koeling: ${_koelingAanwezig == null ? '-' : (_koelingAanwezig! ? 'Ja' : 'Nee')}'),
          pw.Text('Zonne energie: ${_zonneEnergieAanwezig == null ? '-' : (_zonneEnergieAanwezig! ? 'Ja' : 'Nee')}'),
          pw.Text('Renovatie van toepassing: ${_renovatieVanToepassing == null ? '-' : (_renovatieVanToepassing! ? 'Ja' : 'Nee')}'),
          pw.Text('Alle ramen hetzelfde: ${_alleRamenHetzelfde == null ? '-' : (_alleRamenHetzelfde! ? 'Ja' : 'Nee')}'),
          pw.SizedBox(height: 12),
          pw.Text('Door opdrachtgever ter beschikking gestelde documenten:'),
          pw.SizedBox(height: 4),
          ..._gegevensOpties.map(
            (optie) => pw.Text(
              '- $optie: ${_aangeleverdeGegevens.contains(optie) ? 'Ja' : 'Nee'}',
            ),
          ),
        ],
      ),
    );

    await file.writeAsBytes(await doc.save(), flush: true);
    return file;
  }

  Widget _buildYesNoGroup({
    required String title,
    required bool? value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        RadioGroup<bool>(
          groupValue: value,
          onChanged: (v) {
            onChanged(v);
            _scheduleFormSave();
          },
          child: Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ja'),
                  value: true,
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Nee'),
                  value: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Alleen-lezen kaart met de gekoppelde opdrachtgever + opdrachtnummer.
  Widget _buildOpdrachtgeverInfo() {
    final og = widget.bagData.opdrachtgever;
    final nummer = (widget.bagData.opdrachtnummer ?? '').trim();
    if (og == null && nummer.isEmpty) {
      return const SizedBox.shrink();
    }

    final regels = <Widget>[];
    void regel(String label, String? waarde) {
      final v = (waarde ?? '').trim();
      if (v.isEmpty) return;
      regels.add(Padding(
        padding: const EdgeInsets.only(top: 2),
        child: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: v),
            ],
          ),
        ),
      ));
    }

    if (og != null) {
      regel('Naam', og.naam);
      regel('Contactpersoon', og.contactpersoon);
      regel('E-mail', og.email);
      regel('Telefoon', og.telefoon);
    }
    regel('Opdrachtnummer', nummer);

    return Card(
      elevation: 0,
      color: const Color(0xFFEFF2F8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.business, size: 18, color: BrandColors.navy),
                const SizedBox(width: 6),
                Text(
                  'Opdrachtgever',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...regels,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PmBrandingHeader(showBackButton: true),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dossier: ${widget.dossierName}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _buildOpdrachtgeverInfo(),
                    const SizedBox(height: 8),
                    Text(
                      'BAG PDF status v$_bagPdfBuildVersion: $_bagPdfStatus',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
            const SizedBox(height: 16),
            Text('Bouwjaar', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _bouwjaarController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onTapOutside: (_) => _dismissKeyboard(),
              onSubmitted: (_) => _dismissKeyboard(),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Bijv. 1998',
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _bouwjaarController,
              builder: (_, __, ___) {
                final previewBouwjaar = _resolveBouwjaarForExport();
                final bron = _resolveBouwjaarBron();
                final bagAdresId = (widget.bagData.bagAdresId ?? '-').trim().isEmpty
                    ? '-'
                    : (widget.bagData.bagAdresId ?? '-').trim();
                final bagObjectId =
                    (widget.bagData.adresseerbaarObjectId ?? '-').trim().isEmpty
                        ? '-'
                        : (widget.bagData.adresseerbaarObjectId ?? '-').trim();
                final bagPandId = (widget.bagData.bagPandId ?? '-').trim().isEmpty
                    ? '-'
                    : (widget.bagData.bagPandId ?? '-').trim();
                final gebouwhoogteDebug =
                    _gebouwhoogte.isEmpty ? '-' : '$_gebouwhoogte m';
                return Text(
                  'Debug bouwjaar export: ${previewBouwjaar.isEmpty ? '-': previewBouwjaar} (bron: $bron)\n'
                  'BAG ids: adres=$bagAdresId | object=$bagObjectId | pand=$bagPandId\n'
                  '3DBAG gebouwhoogte: $gebouwhoogteDebug',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '3DBAG gebouwhoogte (m)',
                border: OutlineInputBorder(),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _gebouwhoogte.isEmpty ? '-' : _gebouwhoogte,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            await _prefillGebouwhoogteFrom3dBag();
                          },
                    child: const Text('Ververs'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(thickness: 1.5),
            const SizedBox(height: 8),
            Text(
              'Websitekoppeling object',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('WWS koppelen aan object'),
              subtitle: Text(_wwsDossierStatus()),
              value: _wwsData.toepassen,
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _wwsData = _wwsData.copyWith(toepassen: value);
                      });
                    },
            ),
            if (_wwsData.toepassen && _wwsData.opnameData == null)
              Card(
                color: Colors.orange.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Let op: er is geen WWS-invoer gevonden voor dit adres. '
                    'De website krijgt dan geen dossier en kan geen punten '
                    'berekenen. Ga terug naar het startscherm, vul het WWS in '
                    'via de tegel "WWS", en sluit de opname daarna opnieuw af.',
                  ),
                ),
              ),
            if (_wwsData.toepassen) ...[
              TextField(
                controller: _wwsPuntenController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  _wwsData = _wwsData.copyWith(punten: value.trim());
                },
                decoration: const InputDecoration(
                  labelText: 'WWS punten',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _wwsMaxHuurController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  _wwsData = _wwsData.copyWith(maxHuur: value.trim());
                },
                decoration: const InputDecoration(
                  labelText: 'Max huur (EUR)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _wwsWozWaardeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  _wwsData = _wwsData.copyWith(wozWaarde: value.trim());
                },
                decoration: const InputDecoration(
                  labelText: 'WOZ waarde (EUR, optioneel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _wwsData.wozJaar,
                items: BlueprintWwsContract.wozJaren
                    .map(
                      (jaar) => DropdownMenuItem<String>(
                        value: jaar,
                        child: Text(jaar),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _wwsData = _wwsData.copyWith(wozJaar: value);
                        });
                      },
                decoration: const InputDecoration(
                  labelText: 'WOZ jaar',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Verhuurgegevens koppelen (ja/nee)'),
              value: _verhuurNaarObject,
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _verhuurNaarObject = value ?? false;
                      });
                    },
            ),
            if (_verhuurNaarObject)
              TextField(
                controller: _huurActueelController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Huur actueel (optioneel)',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 16),
            const Divider(thickness: 1.5),
            const SizedBox(height: 8),
            Text(
              'Gebouwtype',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text('Categorie', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _gebouwCategorie,
              items: GebouwtypeOptie.categorieen
                  .map(
                    (categorie) => DropdownMenuItem<String>(
                      value: categorie,
                      child: Text(categorie),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _gebouwCategorie = value;
                        // Tweede lijst hangt af van de categorie: reset naar de
                        // eerste optie binnen de nieuwe categorie.
                        _gebouwType =
                            GebouwtypeOptie.voorCategorie(value).first;
                      });
                    },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _gebouwType.id,
              isExpanded: true,
              items: GebouwtypeOptie.voorCategorie(_gebouwCategorie)
                  .map(
                    (optie) => DropdownMenuItem<String>(
                      value: optie.id,
                      child: Text(optie.type),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _gebouwType = GebouwtypeOptie.voorCategorie(
                          _gebouwCategorie,
                        ).firstWhere((o) => o.id == value);
                      });
                    },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(thickness: 1.5),
            const SizedBox(height: 8),
            Text('1. Vloer', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _vloerType,
              items: _vloerOpties
                  .map(
                    (optie) => DropdownMenuItem<String>(
                      value: optie,
                      child: Text(optie),
                    ),
                  )
                  .toList(),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _vloerType = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            const Divider(thickness: 1.5),
            const SizedBox(height: 8),
            Text(
              'Onderdeel installatie',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text('1. Ventilatie', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _ventilatieType,
              items: _ventilatieOpties
                  .map(
                    (optie) => DropdownMenuItem<String>(
                      value: optie,
                      child: Text(optie),
                    ),
                  )
                  .toList(),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _ventilatieType = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            Text('2. Verwarming', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _verwarmingType,
              items: List<int>.generate(_verwarmingOpties.length, (index) => index + 1)
                  .map(
                    (optie) => DropdownMenuItem<int>(
                      value: optie,
                      child: Text(_verwarmingOpties[optie - 1]),
                    ),
                  )
                  .toList(),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _verwarmingType = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            Text('3. Tapwater', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _tapwaterType,
              items: _tapwaterOpties
                  .map(
                    (optie) => DropdownMenuItem<String>(
                      value: optie,
                      child: Text(optie),
                    ),
                  )
                  .toList(),
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _tapwaterType = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            _buildYesNoGroup(
              title: '4. Koeling',
              value: _koelingAanwezig,
              onChanged: _isSaving
                  ? (_) {}
                  : (value) {
                      setState(() {
                        _koelingAanwezig = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            _buildYesNoGroup(
              title: '5. Zonne energie',
              value: _zonneEnergieAanwezig,
              onChanged: _isSaving
                  ? (_) {}
                  : (value) {
                      setState(() {
                        _zonneEnergieAanwezig = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            _buildYesNoGroup(
              title: 'Renovatie jaar van toepassing',
              value: _renovatieVanToepassing,
              onChanged: _isSaving
                  ? (_) {}
                  : (value) {
                      setState(() {
                        _renovatieVanToepassing = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            _buildYesNoGroup(
              title: 'Alle ramen het zelfde?',
              value: _alleRamenHetzelfde,
              onChanged: _isSaving
                  ? (_) {}
                  : (value) {
                      setState(() {
                        _alleRamenHetzelfde = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            Text(
              'Door opdrachtgever ter beschikking gestelde documenten',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ..._gegevensOpties.map(
              (optie) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(optie),
                value: _aangeleverdeGegevens.contains(optie),
                onChanged: _isSaving
                    ? null
                    : (checked) {
                        setState(() {
                          if (checked == true) {
                            _aangeleverdeGegevens.add(optie);
                          } else {
                            _aangeleverdeGegevens.remove(optie);
                          }
                        });
                      },
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isSaving
                      ? 'Bezig met afsluiten...'
                      : 'Opname afsluiten (Nextcloud + mail + website)',
                ),
                onPressed: _isSaving ? null : _afsluiten,
              ),
            ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}