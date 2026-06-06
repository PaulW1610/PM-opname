import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/app_secrets.dart';
import '../services/app_settings_service.dart';
import '../services/bag_service.dart';
import '../services/dropbox_service.dart';
import '../services/dossier_service.dart';
import '../services/opmerkingen_formulier_service.dart';
import '../services/overige_ruimte_beslisschema_service.dart';
import '../services/three_d_bag_service.dart';
import '../services/xml_export_service.dart';
import '../widgets/pm_branding_header.dart';

class OpnameAfsluitenScreen extends StatefulWidget {
  final BagData bagData;
  final String dossierName;

  const OpnameAfsluitenScreen({
    Key? key,
    required this.bagData,
    required this.dossierName,
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
  BagData? _resolvedBagData;
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
    _prefillInitialObjectData();
  }

  Future<void> _prefillInitialObjectData() async {
    await _prefillBouwjaarFromBag();
    await _prefillGebouwhoogteFrom3dBag();
  }

  @override
  void dispose() {
    _bouwjaarController.dispose();
    super.dispose();
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

      final attachmentPaths = <String>[
        xmlFile.path,
        bagPdfFile.path,
        formulierPdfFile.path,
        if (beslisschemaPdfFile != null) beslisschemaPdfFile.path,
        if (opmerkingenPdfFile != null) opmerkingenPdfFile.path,
        if (drieDbagImageFile != null) drieDbagImageFile.path,
      ];
      final dropboxAddressFolderName = bagData.getFolderName();
      final recipientEmail = await AppSettingsService.loadEmailRecipient();

      if (mounted) {
        setState(() {
          _bagPdfStatus = 'Gegenereerd';
        });
      }

      final email = Email(
        body:
          'Bijgevoegd: XML export + BAG PDF + Formulier PDF'
          '${beslisschemaPdfFile != null ? ' + Beslisschema PDF' : ''}'
          '${opmerkingenPdfFile != null ? ' + Opmerkingen PDF' : ''}'
          '${drieDbagImageFile != null ? ' + 3DBAG afbeelding' : ''} voor ${widget.dossierName}.',
        subject: 'XML export ${widget.dossierName}',
        recipients: [recipientEmail],
        attachmentPaths: attachmentPaths,
        isHTML: false,
      );

      await FlutterEmailSender.send(email);

      // Auto-upload naar Dropbox als verbonden
      String dropboxInfo = '';
      if (await DropboxService.isConnected()) {
        final uploadFiles = attachmentPaths.map((p) => File(p)).toList();
        final uploadResult = await DropboxService.uploadDossierFiles(
          addressFolderName: dropboxAddressFolderName,
          files: uploadFiles,
        );
        if (uploadResult.uploadedCount > 0) {
          dropboxInfo =
              '\n${uploadResult.uploadedCount} bestand${uploadResult.uploadedCount == 1 ? '' : 'en'} geüpload naar Dropbox.';
        }
        if (!uploadResult.isSuccess && (uploadResult.message?.isNotEmpty ?? false)) {
          dropboxInfo = '$dropboxInfo\nDropbox: ${uploadResult.message}';
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
            '${_gebouwhoogte.isNotEmpty ? ', Gebouwhoogte: ${_gebouwhoogte} m (3DBAG)' : ''}$dropboxInfo',
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

  Future<void> _uploadToDropbox() async {
    if (!await DropboxService.isConnected()) {
      if (!mounted) return;
      final reason = DropboxService.lastError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reason != null && reason.isNotEmpty
                ? 'Dropbox is niet klaar voor uploaden: $reason'
                : 'Dropbox is niet verbonden. Verbind via Instellingen.',
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
      final dropboxAddressFolderName = bagData.getFolderName();
      final uploadResult = await DropboxService.uploadDossierFiles(
        addressFolderName: dropboxAddressFolderName,
        files: [
          xmlFile,
          bagPdfFile,
          formulierPdfFile,
          if (beslisschemaPdfFile != null) beslisschemaPdfFile,
          if (opmerkingenPdfFile != null) opmerkingenPdfFile,
        ],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uploadResult.isSuccess
                ? '${uploadResult.uploadedCount} bestand${uploadResult.uploadedCount == 1 ? '' : 'en'} geüpload naar de Dropbox app-map met adresprefix $dropboxAddressFolderName.'
                : 'Dropbox upload deels/helemaal mislukt: ${uploadResult.message ?? 'onbekende fout'}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dropbox upload mislukt: $error')),
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

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Opgeslagen'),
          content: SingleChildScrollView(
            child: Text(
              'Formulier opgeslagen in dossier en Foto\'s-album.\n\n'
              'Tekstbestand:\n${result.textFilePath}\n\n'
              'PNG-bestand:\n${result.imageFilePath}',
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
                label: const Text('Upload naar Dropbox'),
                onPressed: _isSaving ? null : _uploadToDropbox,
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