import 'package:flutter/material.dart';

import '../services/bag_service.dart';
import '../services/opmerkingen_formulier_service.dart';
import '../services/overige_ruimte_beslisschema_service.dart';
import '../widgets/pm_branding_header.dart';

class BeslisschemasScreen extends StatelessWidget {
  final BagData bagData;
  final String dossierName;

  const BeslisschemasScreen({
    Key? key,
    required this.bagData,
    required this.dossierName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const azureBlue = Color(0xFF006FAF);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PmBrandingHeader(showBackButton: true),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Beslisschemas',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dossier: $dossierName',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: azureBlue,
                    child: ListTile(
                      leading: const Icon(
                        Icons.picture_as_pdf_outlined,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Schema: Overige ruimte',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Vul beslisvragen in en exporteer een PDF-formulier.',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.white,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OverigeRuimteBeslisschemaScreen(
                              bagData: bagData,
                              dossierName: dossierName,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: azureBlue,
                    child: ListTile(
                      leading: const Icon(
                        Icons.description_outlined,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Formulier: Opmerkingen',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Typ opmerkingen en laat dit formulier als PDF meesturen bij afsluiten.',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.white,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OpmerkingenFormulierScreen(
                              bagData: bagData,
                              dossierName: dossierName,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: azureBlue,
                    child: const ListTile(
                      leading: Icon(Icons.lock_outline, color: Colors.white),
                      title: Text(
                        'Meer schemas volgen later',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Deze pagina is voorbereid op meerdere beslisschemas.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OpmerkingenFormulierScreen extends StatefulWidget {
  final BagData bagData;
  final String dossierName;

  const OpmerkingenFormulierScreen({
    Key? key,
    required this.bagData,
    required this.dossierName,
  }) : super(key: key);

  @override
  State<OpmerkingenFormulierScreen> createState() =>
      _OpmerkingenFormulierScreenState();
}

class _OpmerkingenFormulierScreenState extends State<OpmerkingenFormulierScreen> {
  final TextEditingController _opmerkingenController = TextEditingController();
  bool _isBusy = false;
  String _status = 'Nog geen PDF gegenereerd';

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _opmerkingenController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final saved = await OpmerkingenFormulierService.loadOpmerkingen(widget.dossierName);
    if (!mounted) {
      return;
    }
    setState(() {
      _opmerkingenController.text = saved;
      if (saved.isNotEmpty) {
        _status = 'Opmerkingen geladen';
      }
    });
  }

  Future<void> _saveDraft() async {
    await OpmerkingenFormulierService.saveOpmerkingen(
      dossierName: widget.dossierName,
      opmerkingen: _opmerkingenController.text,
    );
  }

  Future<void> _generatePdf() async {
    setState(() {
      _isBusy = true;
    });

    try {
      await _saveDraft();
      final file = await OpmerkingenFormulierService.generatePdf(
        dossierName: widget.dossierName,
        bagData: widget.bagData,
        opmerkingen: _opmerkingenController.text,
      );

      if (!mounted) return;
      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vul eerst opmerkingen in om een PDF te maken.')),
        );
        return;
      }

      setState(() {
        _status = 'Gegenereerd: ${file.path.split('/').last}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF opgeslagen: ${file.path}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Genereren van PDF mislukt: $error')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
      });
    }
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
                      'Formulier: Opmerkingen',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status PDF: $_status',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _opmerkingenController,
                      maxLines: 14,
                      onChanged: (_) {
                        _saveDraft();
                      },
                      decoration: const InputDecoration(
                        labelText: 'Opmerkingen',
                        border: OutlineInputBorder(),
                        hintText: 'Typ hier je opmerkingen voor dit dossier.',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF006FAF),
                          foregroundColor: Colors.white,
                        ),
                        icon: _isBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.picture_as_pdf),
                        label: Text(
                          _isBusy ? 'PDF genereren...' : 'Genereer PDF formulier',
                        ),
                        onPressed: _isBusy ? null : _generatePdf,
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

class OverigeRuimteBeslisschemaScreen extends StatefulWidget {
  final BagData bagData;
  final String dossierName;

  const OverigeRuimteBeslisschemaScreen({
    Key? key,
    required this.bagData,
    required this.dossierName,
  }) : super(key: key);

  @override
  State<OverigeRuimteBeslisschemaScreen> createState() =>
      _OverigeRuimteBeslisschemaScreenState();
}

class _OverigeRuimteBeslisschemaScreenState
    extends State<OverigeRuimteBeslisschemaScreen> {
  static const String _outcomeThermischeZone = 'thermische_zone';
  static const String _outcomeNietThermischeZone = 'niet_thermische_zone';
  static const String _outcomeNaarSchema2 = 'naar_schema_2';
  static const String _outcomeNaarSchema3 = 'naar_schema_3';
  static const String _outcomePending = 'pending';

  bool? _s1GrenstAanThermischeZone;
  bool? _s1VerwarmdOfGekoeldVoorVerblijf;
  bool? _s1OpenVerbindingMetThermischeZone;

  bool? _s2OmslotenDoorIsolatieSpouwOfAlleenGlas;
  bool? _s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas;
  bool? _s2ConstructieNaarRekenzoneMetSpouwOfIsolatie;
  bool? _s2WarmteweerstandConstructieKleinerDanRuimte;

  bool? _s3OmslotenDoorIsolatieOfSpouw;
  bool? _s3ConstructieNaarRekenzoneMetSpouwOfIsolatie;
  bool? _s3GebouwgebondenWarmteafgiftesysteemAanwezig;

  final TextEditingController _notitiesController = TextEditingController();
  bool _isSaving = false;
  String _status = 'Nog niet gegenereerd';

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  @override
  void dispose() {
    _notitiesController.dispose();
    super.dispose();
  }

  OverigeRuimteBeslisschemaData _currentData() {
    return OverigeRuimteBeslisschemaData(
      s1GrenstAanThermischeZone: _s1GrenstAanThermischeZone,
      s1VerwarmdOfGekoeldVoorVerblijf: _s1VerwarmdOfGekoeldVoorVerblijf,
      s1OpenVerbindingMetThermischeZone: _s1OpenVerbindingMetThermischeZone,
      s2OmslotenDoorIsolatieSpouwOfAlleenGlas: _s2OmslotenDoorIsolatieSpouwOfAlleenGlas,
      s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas:
          _s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas,
      s2ConstructieNaarRekenzoneMetSpouwOfIsolatie:
          _s2ConstructieNaarRekenzoneMetSpouwOfIsolatie,
      s2WarmteweerstandConstructieKleinerDanRuimte:
          _s2WarmteweerstandConstructieKleinerDanRuimte,
      s3OmslotenDoorIsolatieOfSpouw: _s3OmslotenDoorIsolatieOfSpouw,
      s3ConstructieNaarRekenzoneMetSpouwOfIsolatie:
          _s3ConstructieNaarRekenzoneMetSpouwOfIsolatie,
      s3GebouwgebondenWarmteafgiftesysteemAanwezig:
          _s3GebouwgebondenWarmteafgiftesysteemAanwezig,
      notities: _notitiesController.text,
    );
  }

  Future<void> _loadSavedData() async {
    final saved = await OverigeRuimteBeslisschemaService.loadData(widget.dossierName);
    if (!mounted || saved == null) {
      return;
    }
    setState(() {
      _s1GrenstAanThermischeZone = saved.s1GrenstAanThermischeZone;
      _s1VerwarmdOfGekoeldVoorVerblijf = saved.s1VerwarmdOfGekoeldVoorVerblijf;
      _s1OpenVerbindingMetThermischeZone = saved.s1OpenVerbindingMetThermischeZone;
      _s2OmslotenDoorIsolatieSpouwOfAlleenGlas = saved.s2OmslotenDoorIsolatieSpouwOfAlleenGlas;
      _s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas =
          saved.s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas;
      _s2ConstructieNaarRekenzoneMetSpouwOfIsolatie =
          saved.s2ConstructieNaarRekenzoneMetSpouwOfIsolatie;
      _s2WarmteweerstandConstructieKleinerDanRuimte =
          saved.s2WarmteweerstandConstructieKleinerDanRuimte;
      _s3OmslotenDoorIsolatieOfSpouw = saved.s3OmslotenDoorIsolatieOfSpouw;
      _s3ConstructieNaarRekenzoneMetSpouwOfIsolatie =
          saved.s3ConstructieNaarRekenzoneMetSpouwOfIsolatie;
      _s3GebouwgebondenWarmteafgiftesysteemAanwezig =
          saved.s3GebouwgebondenWarmteafgiftesysteemAanwezig;
      _notitiesController.text = saved.notities;
      _status = 'Antwoorden geladen';
    });
  }

  Future<void> _persistCurrentData() async {
    await OverigeRuimteBeslisschemaService.saveData(
      dossierName: widget.dossierName,
      data: _currentData(),
    );
  }

  bool get _schema1Vraag2Nodig => _s1GrenstAanThermischeZone == true;

  bool get _schema1Vraag3Nodig =>
      _s1GrenstAanThermischeZone == true &&
      _s1VerwarmdOfGekoeldVoorVerblijf == false;

  bool get _schema2Vraag2Nodig => _s2OmslotenDoorIsolatieSpouwOfAlleenGlas == true;

  bool get _schema2Vraag3Nodig =>
      _s2OmslotenDoorIsolatieSpouwOfAlleenGlas == true &&
      _s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas == false;

  bool get _schema2Vraag4Nodig =>
      _schema2Vraag3Nodig && _s2ConstructieNaarRekenzoneMetSpouwOfIsolatie == true;

  bool get _schema3Vraag2Nodig => _s3OmslotenDoorIsolatieOfSpouw == false;

  bool get _schema3Vraag3Nodig =>
      _schema3Vraag2Nodig && _s3ConstructieNaarRekenzoneMetSpouwOfIsolatie == false;

  bool get _schema2Actief => _schema1UitkomstCode == _outcomeNaarSchema2;

  bool get _schema3Actief => _schema2Actief && _schema2UitkomstCode == _outcomeNaarSchema3;

  bool get _isSchemaComplete =>
      _overallUitkomstCode == _outcomeThermischeZone ||
      _overallUitkomstCode == _outcomeNietThermischeZone;

  String get _schema1UitkomstCode {
    if (_s1GrenstAanThermischeZone == null) {
      return _outcomePending;
    }
    if (_s1GrenstAanThermischeZone == false) {
      return _outcomeNietThermischeZone;
    }
    if (_s1VerwarmdOfGekoeldVoorVerblijf == null) {
      return _outcomePending;
    }
    if (_s1VerwarmdOfGekoeldVoorVerblijf == true) {
      return _outcomeThermischeZone;
    }
    if (_s1OpenVerbindingMetThermischeZone == null) {
      return _outcomePending;
    }
    if (_s1OpenVerbindingMetThermischeZone == true) {
      return _outcomeThermischeZone;
    }
    return _outcomeNaarSchema2;
  }

  String get _schema2UitkomstCode {
    if (!_schema2Actief) {
      return _outcomePending;
    }

    if (_s2OmslotenDoorIsolatieSpouwOfAlleenGlas == null) {
      return _outcomePending;
    }
    if (_s2OmslotenDoorIsolatieSpouwOfAlleenGlas == false) {
      return _outcomeNaarSchema3;
    }
    if (_s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas == null) {
      return _outcomePending;
    }
    if (_s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas == true) {
      return _outcomeNaarSchema3;
    }
    if (_s2ConstructieNaarRekenzoneMetSpouwOfIsolatie == null) {
      return _outcomePending;
    }
    if (_s2ConstructieNaarRekenzoneMetSpouwOfIsolatie == false) {
      return _outcomeThermischeZone;
    }
    if (_s2WarmteweerstandConstructieKleinerDanRuimte == null) {
      return _outcomePending;
    }
    if (_s2WarmteweerstandConstructieKleinerDanRuimte == true) {
      return _outcomeThermischeZone;
    }
    return _outcomeNaarSchema3;
  }

  String get _schema3UitkomstCode {
    if (!_schema3Actief) {
      return _outcomePending;
    }

    if (_s3OmslotenDoorIsolatieOfSpouw == null) {
      return _outcomePending;
    }
    if (_s3OmslotenDoorIsolatieOfSpouw == true) {
      return _outcomeNietThermischeZone;
    }
    if (_s3ConstructieNaarRekenzoneMetSpouwOfIsolatie == null) {
      return _outcomePending;
    }
    if (_s3ConstructieNaarRekenzoneMetSpouwOfIsolatie == true) {
      return _outcomeNietThermischeZone;
    }
    if (_s3GebouwgebondenWarmteafgiftesysteemAanwezig == null) {
      return _outcomePending;
    }
    return _s3GebouwgebondenWarmteafgiftesysteemAanwezig == true
        ? _outcomeThermischeZone
        : _outcomeNietThermischeZone;
  }

  String get _overallUitkomstCode {
    if (_schema1UitkomstCode == _outcomeThermischeZone ||
        _schema1UitkomstCode == _outcomeNietThermischeZone) {
      return _schema1UitkomstCode;
    }

    if (_schema1UitkomstCode != _outcomeNaarSchema2) {
      return _outcomePending;
    }

    if (_schema2UitkomstCode == _outcomeThermischeZone ||
        _schema2UitkomstCode == _outcomeNietThermischeZone) {
      return _schema2UitkomstCode;
    }

    if (_schema2UitkomstCode == _outcomeNaarSchema3) {
      return _schema3UitkomstCode;
    }

    return _outcomePending;
  }

  String get _uitkomst {
    switch (_overallUitkomstCode) {
      case _outcomeThermischeZone:
        return 'Ruimte behoort tot thermische zone.';
      case _outcomeNietThermischeZone:
        return 'Ruimte behoort niet tot thermische zone.';
      default:
        if (_schema1UitkomstCode == _outcomePending) {
          return 'Nog geen uitkomst: vul Beslisschema 1 verder in.';
        }
        if (_schema1UitkomstCode == _outcomeNaarSchema2 &&
            _schema2UitkomstCode == _outcomePending) {
          return 'Ga door met Beslisschema 2 om de uitkomst te bepalen.';
        }
        if (_schema2UitkomstCode == _outcomeNaarSchema3 &&
            _schema3UitkomstCode == _outcomePending) {
          return 'Ga door met Beslisschema 3 om de uitkomst te bepalen.';
        }
        return 'Nog geen uitkomst beschikbaar.';
    }
  }

  void _resetSchema2() {
    _s2OmslotenDoorIsolatieSpouwOfAlleenGlas = null;
    _s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas = null;
    _s2ConstructieNaarRekenzoneMetSpouwOfIsolatie = null;
    _s2WarmteweerstandConstructieKleinerDanRuimte = null;
  }

  void _resetSchema3() {
    _s3OmslotenDoorIsolatieOfSpouw = null;
    _s3ConstructieNaarRekenzoneMetSpouwOfIsolatie = null;
    _s3GebouwgebondenWarmteafgiftesysteemAanwezig = null;
  }

  void _onSchema1Vraag1Changed(bool? value) {
    setState(() {
      _s1GrenstAanThermischeZone = value;
      _s1VerwarmdOfGekoeldVoorVerblijf = null;
      _s1OpenVerbindingMetThermischeZone = null;
      _resetSchema2();
      _resetSchema3();
    });
    _persistCurrentData();
  }

  void _onSchema1Vraag2Changed(bool? value) {
    setState(() {
      _s1VerwarmdOfGekoeldVoorVerblijf = value;
      _s1OpenVerbindingMetThermischeZone = null;
      _resetSchema2();
      _resetSchema3();
    });
    _persistCurrentData();
  }

  void _onSchema1Vraag3Changed(bool? value) {
    setState(() {
      _s1OpenVerbindingMetThermischeZone = value;
      _resetSchema2();
      _resetSchema3();
    });
    _persistCurrentData();
  }

  Future<void> _generatePdf() async {
    if (!_isSchemaComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Beantwoord eerst de benodigde vragen in het schema.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _persistCurrentData();
      final file = await OverigeRuimteBeslisschemaService.generatePdfIfComplete(
        dossierName: widget.dossierName,
        bagData: widget.bagData,
        data: _currentData(),
      );

      if (file == null) {
        throw Exception('Beantwoord eerst alle benodigde vragen om het PDF-formulier te maken.');
      }

      if (!mounted) return;
      setState(() {
        _status = 'Gegenereerd: ${file.path.split('/').last}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF opgeslagen: ${file.path}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Genereren van PDF mislukt: $error')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  Widget _buildJaNeeVraag({
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
          onChanged: _isSaving ? (_) {} : onChanged,
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
                      'Beslisschema 1: Thermische zone en overige ruimte',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status PDF: $_status',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _buildJaNeeVraag(
                      title:
                          '1. Grenst de ruimte aan een ruimte die hoort tot de thermische zone?',
                      value: _s1GrenstAanThermischeZone,
                      onChanged: _onSchema1Vraag1Changed,
                    ),
                    if (_schema1Vraag2Nodig) ...[
                      const SizedBox(height: 8),
                      _buildJaNeeVraag(
                        title:
                            '2. Wordt de ruimte verwarmd of gekoeld voor het verblijf van mensen?',
                        value: _s1VerwarmdOfGekoeldVoorVerblijf,
                        onChanged: _onSchema1Vraag2Changed,
                      ),
                    ],
                    if (_schema1Vraag3Nodig) ...[
                      const SizedBox(height: 8),
                      _buildJaNeeVraag(
                        title:
                            '3. Is er een open verbinding tussen de ruimte en een andere ruimte behorend bij de thermische zone?',
                        value: _s1OpenVerbindingMetThermischeZone,
                        onChanged: (value) {
                          _onSchema1Vraag3Changed(value);
                        },
                      ),
                    ],
                    if (_schema2Actief) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Beslisschema 2',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      _buildJaNeeVraag(
                        title:
                            '1. Wordt de ruimte omsloten door isolatie (3a) of een spouwmuur (3a) of alleen raam/glas (3b)?',
                        value: _s2OmslotenDoorIsolatieSpouwOfAlleenGlas,
                        onChanged: (value) {
                          setState(() {
                            _s2OmslotenDoorIsolatieSpouwOfAlleenGlas = value;
                            _s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas = null;
                            _s2ConstructieNaarRekenzoneMetSpouwOfIsolatie = null;
                            _s2WarmteweerstandConstructieKleinerDanRuimte = null;
                            _resetSchema3();
                          });
                          _persistCurrentData();
                        },
                      ),
                      if (_schema2Vraag2Nodig) ...[
                        const SizedBox(height: 8),
                        _buildJaNeeVraag(
                          title:
                              '2. Is in de ruimte in de gevel(s) of dak meer dan 10% raamoppervlak aanwezig en bestaat meer dan 30% van de oppervlakte van het raam uit enkel glas (4)?',
                          value: _s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas,
                          onChanged: (value) {
                            setState(() {
                              _s2MeerDan10ProcentRamenEnMeerDan30ProcentEnkelglas = value;
                              _s2ConstructieNaarRekenzoneMetSpouwOfIsolatie = null;
                              _s2WarmteweerstandConstructieKleinerDanRuimte = null;
                              _resetSchema3();
                            });
                            _persistCurrentData();
                          },
                        ),
                      ],
                      if (_schema2Vraag3Nodig) ...[
                        const SizedBox(height: 8),
                        _buildJaNeeVraag(
                          title:
                              '3. Is de constructie tussen de ruimte en andere ruimte behorend bij de rekenzone van een spouw en/of isolatie voorzien (3a)?',
                          value: _s2ConstructieNaarRekenzoneMetSpouwOfIsolatie,
                          onChanged: (value) {
                            setState(() {
                              _s2ConstructieNaarRekenzoneMetSpouwOfIsolatie = value;
                              _s2WarmteweerstandConstructieKleinerDanRuimte = null;
                              _resetSchema3();
                            });
                            _persistCurrentData();
                          },
                        ),
                      ],
                      if (_schema2Vraag4Nodig) ...[
                        const SizedBox(height: 8),
                        _buildJaNeeVraag(
                          title:
                              '4. Is de warmteweerstand van de constructie tussen de ruimte en andere ruimte behorend bij de thermische zone kleiner dan de warmteweerstand van de ruimte (5)?',
                          value: _s2WarmteweerstandConstructieKleinerDanRuimte,
                          onChanged: (value) {
                            setState(() {
                              _s2WarmteweerstandConstructieKleinerDanRuimte = value;
                              _resetSchema3();
                            });
                            _persistCurrentData();
                          },
                        ),
                      ],
                    ],
                    if (_schema3Actief) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Beslisschema 3',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      _buildJaNeeVraag(
                        title:
                            '1. Wordt de ruimte omsloten door isolatie (3a) of een spouwmuur (3a)?',
                        value: _s3OmslotenDoorIsolatieOfSpouw,
                        onChanged: (value) {
                          setState(() {
                            _s3OmslotenDoorIsolatieOfSpouw = value;
                            _s3ConstructieNaarRekenzoneMetSpouwOfIsolatie = null;
                            _s3GebouwgebondenWarmteafgiftesysteemAanwezig = null;
                          });
                          _persistCurrentData();
                        },
                      ),
                      if (_schema3Vraag2Nodig) ...[
                        const SizedBox(height: 8),
                        _buildJaNeeVraag(
                          title:
                              '2. Is de constructie tussen de ruimte en andere ruimte behorend bij de rekenzone van een spouw en/of isolatie voorzien (3a)?',
                          value: _s3ConstructieNaarRekenzoneMetSpouwOfIsolatie,
                          onChanged: (value) {
                            setState(() {
                              _s3ConstructieNaarRekenzoneMetSpouwOfIsolatie = value;
                              _s3GebouwgebondenWarmteafgiftesysteemAanwezig = null;
                            });
                            _persistCurrentData();
                          },
                        ),
                      ],
                      if (_schema3Vraag3Nodig) ...[
                        const SizedBox(height: 8),
                        _buildJaNeeVraag(
                          title:
                              '3. Is er in de ruimte een gebouwgebonden warmteafgiftesysteem (6) aanwezig?',
                          value: _s3GebouwgebondenWarmteafgiftesysteemAanwezig,
                          onChanged: (value) {
                            setState(() {
                              _s3GebouwgebondenWarmteafgiftesysteemAanwezig = value;
                            });
                            _persistCurrentData();
                          },
                        ),
                      ],
                    ],
                    const SizedBox(height: 8),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Einduitkomst beslisschemas',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_uitkomst),
                    ),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      title: const Text('Toelichting bij beslisschema 1 t/m 3'),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      children: const [
                        Text(
                          '1. Een ruimte wordt alleen verwarmd voor verblijf als er daadwerkelijk '
                          'mensen langdurig verblijven. Verkeersruimten worden in principe niet '
                          'als verblijf beschouwd.',
                        ),
                        SizedBox(height: 8),
                        Text(
                          '2. Een open verbinding is een opening die niet met vaste harde '
                          'elementen afsluitbaar is. Een deur geldt alleen als open verbinding '
                          'als die structureel open is volgens de toelichting.',
                        ),
                        SizedBox(height: 8),
                        Text(
                          '3a. Isolatie/spouw betekent dat meer dan 70% van de gesloten '
                          'uitwendige scheidingsconstructies minimaal 1 cm isolatie of spouw '
                          'bevat.',
                        ),
                        SizedBox(height: 8),
                        Text(
                          '3b. Alleen raam/glas geldt bijvoorbeeld bij een volledig beglaasde '
                          'loggia.',
                        ),
                        SizedBox(height: 8),
                        Text(
                          '4. Er is sprake van "meer dan 10% daglichtopeningen" en een '
                          'samengestelde U-waarde > 4.5 W/m2K (met enkel glas als grens).',
                        ),
                        SizedBox(height: 8),
                        Text(
                          '5. Warmteweerstand vergelijking: de oppervlaktegewogen gemiddelde '
                          'thermische weerstand van de overige ruimte wordt vergeleken met die '
                          'tussen overige ruimte en rekenzone.',
                        ),
                        SizedBox(height: 8),
                        Text(
                          '6. Radiatoren voor vorstbeveiliging en mobiele kachels tellen niet '
                          'als gebouwgebonden warmteafgiftesysteem.',
                        ),
                        SizedBox(height: 8),
                        Text(
                          '7. Een warmteopwekker op zichzelf geldt niet als '
                          'warmteafgiftesysteem.',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _notitiesController,
                      onChanged: (_) {
                        _persistCurrentData();
                      },
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Notities',
                        border: OutlineInputBorder(),
                        hintText: 'Vul hier aanvullende opmerkingen in.',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF006FAF),
                          foregroundColor: Colors.white,
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.picture_as_pdf),
                        label: Text(
                          _isSaving ? 'PDF genereren...' : 'Genereer PDF formulier',
                        ),
                        onPressed: _isSaving ? null : _generatePdf,
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
