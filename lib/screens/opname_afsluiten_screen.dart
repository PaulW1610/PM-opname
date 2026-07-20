import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/app_secrets.dart';
import '../models/wws_invoer_data.dart';
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
  }

  Future<void> _prefillInitialObjectData() async {
    await _prefillBouwjaarFromBag();
    await _prefillGebouwhoogteFrom3dBag();
  }

  @override
  void dispose() {
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

    final fields = <String, String>{
      'titel': widget.dossierName,
      if ((bagData.bagPandId ?? '').trim().isNotEmpty)
        'pand': (bagData.bagPandId ?? '').trim(),
      if (_wwsData.toepassen && _wwsData.wozWaarde.trim().isNotEmpty)
        'woz': _wwsWozWaardeController.text.trim(),
      'wws_actief': _wwsData.toepassen ? '1' : '0',
    };

    if (_wwsData.toepassen) {
      final opname = _wwsData.opnameData;
      if (opname != null) {
        // Contract §3.9: stuur het WWS als dossier in de INVOER-vorm (§3.2).
        // De server herrekent zelf wws_punten en huur_max uit dit dossier,
        // dus die sturen we NIET mee (server is de rekenmeester).
        fields['wws_dossier'] = jsonEncode(opname.toApiJson());
      } else {
        // Terugval als de volledige invoer ontbreekt: stuur de bekende
        // getallen mee zodat de eenheid toch punten/huur toont.
        if (_wwsData.punten.trim().isNotEmpty) {
          fields['wws_punten'] = _wwsPuntenController.text.trim();
        }
        if (_wwsData.maxHuur.trim().isNotEmpty) {
          fields['huur_max'] = _wwsMaxHuurController.text.trim();
        }
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

    final wwsInfo = _wwsData.toepassen
        ? 'WWS gekoppeld${_wwsData.punten.trim().isNotEmpty ? ' (${_wwsData.punten.trim()} pt)' : ''}'
        : 'WWS niet gekoppeld';
    final verhuurInfo = _verhuurNaarObject
        ? 'verhuur: ja'
        : 'verhuur: nee';
    return 'Object gekoppeld aan website. $wwsInfo, $verhuurInfo.';
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

  Future<void> _createAndMailXml() async {
    _dismissKeyboard();
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

      final jsonFile = await JsonExportService.createJsonForDossier(
        dossierName: widget.dossierName,
        data: <String, dynamic>{
          'schemaVersie': JsonExportService.schemaVersie,
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

      await FlutterEmailSender.send(email);

      // Auto-upload naar Nextcloud als geconfigureerd (export-bestanden -> EP/).
      String nextcloudInfo = '';
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
          nextcloudInfo =
              '\n${uploadResult.uploadedCount} bestand(en) geüpload naar Nextcloud ("$nextcloudRootFolder"/EP).';
        }
        if (!uploadResult.isSuccess && (uploadResult.message?.isNotEmpty ?? false)) {
          nextcloudInfo = '$nextcloudInfo\nNextcloud: ${uploadResult.message}';
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'XML + BAG PDF + Formulier PDF'
            '${beslisschemaPdfFile != null ? ' + Beslisschema PDF' : ''}'
            '${opmerkingenPdfFile != null ? ' + Opmerkingen PDF' : ''}'
            '${drieDbagImageFile != null ? ' + 3DBAG afbeelding' : ''} '
            'aangemaakt en e-mail geopend. Bouwjaar: $bouwjaar '
            '(bron: ${_resolveBouwjaarBron()})'
            '${_gebouwhoogte.isNotEmpty ? ', Gebouwhoogte: ${_gebouwhoogte} m (3DBAG)' : ''}$nextcloudInfo',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('XML/e-mail mislukt: $error')),
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

  /// Handmatige upload naar Nextcloud (export -> EP/) met een duidelijk
  /// resultaatvenster, los van de mail-stap.
  Future<void> _uploadToNextcloud() async {
    if (!await NextcloudService.isConfigured()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nextcloud is niet ingesteld. Vul je gegevens in via Instellingen.',
          ),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _prefillBouwjaarFromBag();
      await _prefillGebouwhoogteFrom3dBag();
      final bagData = _resolvedBagData ?? widget.bagData;
      final bouwjaar = _resolveBouwjaarForExport();
      if (bouwjaar.isEmpty || bouwjaar == '0') {
        throw Exception('Geen bouwjaar. Vul bouwjaar handmatig in.');
      }
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
      );
      final formulierPdfFile = await _createFormulierPdfForMail(
        bagData: bagData,
        bouwjaar: bouwjaar,
      );
      final rootFolder = _nextcloudRootFolderName(bagData);
      final fotoFiles = await DossierPhotoStore.photosForPrefix(
        bagData.getPhotoFilePrefix(),
      );
      final result = await NextcloudService.uploadDossier(
        rootFolderName: 'Lopend/$rootFolder',
        filesBySubfolder: {
          'EP': [xmlFile, formulierPdfFile],
          if (fotoFiles.isNotEmpty) 'foto\'s': fotoFiles,
        },
        ensureSubfolders: const [
          'foto\'s',
          'EP',
          'correspondentie',
          'onderbouwing',
        ],
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(result.isSuccess
              ? 'Nextcloud-upload geslaagd'
              : 'Nextcloud-upload (deels) mislukt'),
          content: SingleChildScrollView(
            child: SelectableText(
              'Map: "$rootFolder"/EP\n'
              'Geüpload: ${result.uploadedCount}/${result.totalCount}\n'
              '${result.failedFiles.isNotEmpty ? 'Mislukt: ${result.failedFiles.join(', ')}\n' : ''}'
              '${result.message ?? NextcloudService.lastError ?? ''}'
              '\n\nDoelpad (WebDAV):\n${result.targetUrl ?? '-'}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Nextcloud-upload mislukt'),
          content: Text('$error'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isSaving = false);
    }
  }

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

  Future<void> _save() async {
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
      final result = await DossierService.saveOpnameAfsluitingWithAlbumImage(
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

      final bagData = _resolvedBagData ?? widget.bagData;
      String websiteInfo;
      try {
        websiteInfo = await _syncNaarBlueprintObject(
          bagData,
          bewijsFoto: File(result.imageFilePath),
        );
      } on BlueprintApiException catch (error) {
        websiteInfo =
            'Websitekoppeling mislukt (${error.code}): ${error.message}';
      } catch (error) {
        websiteInfo = 'Websitekoppeling mislukt: $error';
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Opgeslagen'),
          content: SingleChildScrollView(
            child: Text(
              'Formulier opgeslagen in dossier en Foto\'s-album.\n\n'
              'Tekstbestand:\n${result.textFilePath}\n\n'
              'PNG-bestand:\n${result.imageFilePath}\n\n'
              '$websiteInfo',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final textToCopy =
                    'Tekstbestand: ${result.textFilePath}\nPNG-bestand: ${result.imageFilePath}';
                await Clipboard.setData(ClipboardData(text: textToCopy));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Paden gekopieerd naar klembord.')),
                );
              },
              child: const Text('Kopieer pad'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opslaan mislukt: $error')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
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
          onChanged: onChanged,
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
              value: _wwsData.toepassen,
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _wwsData = _wwsData.copyWith(toepassen: value);
                      });
                    },
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
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Opslaan...' : 'Opslaan in dossier'),
                onPressed: _isSaving ? null : _save,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.mail_outline),
                label: const Text('Afronden en mail'),
                onPressed: _isSaving ? null : _createAndMailXml,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Upload naar Nextcloud'),
                onPressed: _isSaving ? null : _uploadToNextcloud,
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