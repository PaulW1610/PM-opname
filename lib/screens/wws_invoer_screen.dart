import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/wws_invoer_data.dart';
import '../models/wws_opname_data.dart';
import '../services/blueprint_api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Hoofd-scherm: WWS tegel-overzicht
// ─────────────────────────────────────────────────────────────────────────────

class WwsInvoerScreen extends StatefulWidget {
  final String dossierNaam;
  final WwsInvoerData initialData;
  /// Pre-gevulde WOZ-waarde vanuit de WOZ-lookup op het startscherm.
  final int? wozVoorgevuld;
  /// Pre-gevuld bouwjaar vanuit de BAG-lookup op het startscherm.
  final int? bouwjaarVoorgevuld;

  const WwsInvoerScreen({
    Key? key,
    required this.dossierNaam,
    required this.initialData,
    this.wozVoorgevuld,
    this.bouwjaarVoorgevuld,
  }) : super(key: key);

  @override
  State<WwsInvoerScreen> createState() => _WwsInvoerScreenState();
}

class _WwsInvoerScreenState extends State<WwsInvoerScreen> {
  late bool _toepassen;
  late WwsOpnameData _opname;

  Map<String, dynamic>? _berekening;
  bool _berekenenBusy = false;
  String? _berekenFout;

  @override
  void initState() {
    super.initState();
    _toepassen = widget.initialData.toepassen;

    var opname = widget.initialData.opnameData ?? const WwsOpnameData();
    final wozVoor = widget.wozVoorgevuld;
    if (wozVoor != null && wozVoor > 0 && opname.wozWaarde == 0.0) {
      opname = opname.copyWith(wozWaarde: wozVoor.toDouble());
    }
    final bouwjaarVoor = widget.bouwjaarVoorgevuld;
    if (bouwjaarVoor != null && bouwjaarVoor > 0 && opname.bouwjaar == 0) {
      opname = opname.copyWith(bouwjaar: bouwjaarVoor);
    }
    _opname = opname;

    final punten = widget.initialData.punten.trim();
    final maxHuur = widget.initialData.maxHuur.trim();
    if (punten.isNotEmpty) {
      _berekening = {
        'totaal_met_cap': num.tryParse(punten) ?? punten,
        'max_huur': num.tryParse(maxHuur),
        'vrije_sector': maxHuur.isEmpty,
      };
    }
  }

  Future<void> _bereken() async {
    setState(() {
      _berekenenBusy = true;
      _berekenFout = null;
    });
    try {
      final result = await BlueprintApiService.calculateWws(_opname.toApiJson());
      if (!mounted) return;
      setState(() {
        _berekening = result;
        _berekenenBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _berekenenBusy = false;
        _berekenFout = e.toString();
      });
    }
  }

  /// Bouwt de huidige WWS-invoer (gebruikt bij Opslaan én bij terug-navigeren).
  WwsInvoerData _huidigeData() {
    final ber = _berekening;
    final punten = ber != null
        ? (ber['totaal_met_cap'] as num?)?.toString() ?? ''
        : widget.initialData.punten;
    final maxHuurRaw = ber != null ? ber['max_huur'] as num? : null;
    final maxHuur = maxHuurRaw != null
        ? maxHuurRaw.toDouble().toStringAsFixed(2)
        : (ber != null ? '' : widget.initialData.maxHuur);

    return WwsInvoerData(
      toepassen: _toepassen,
      punten: punten,
      maxHuur: maxHuur,
      wozWaarde: _opname.wozWaarde > 0
          ? _opname.wozWaarde.toStringAsFixed(0)
          : widget.initialData.wozWaarde,
      wozJaar: _opname.wozJaar,
      opnameData: _opname,
    );
  }

  void _opslaan() {
    Navigator.of(context).pop(_huidigeData());
  }

  Future<void> _openBinnenruimtes() async {
    final result = await Navigator.of(context).push<List<WwsBinnenruimte>>(
      MaterialPageRoute(
        builder: (_) => _BinnenruimtesScreen(initial: _opname.binnenruimtes),
      ),
    );
    if (result != null) setState(() => _opname = _opname.copyWith(binnenruimtes: result));
  }

  Future<void> _openBuitenruimtes() async {
    final result = await Navigator.of(context).push<List<WwsBuitenruimte>>(
      MaterialPageRoute(
        builder: (_) => _BuitenruimtesScreen(initial: _opname.buitenruimtes),
      ),
    );
    if (result != null) setState(() => _opname = _opname.copyWith(buitenruimtes: result));
  }

  Future<void> _openKeuken() async {
    final result = await Navigator.of(context).push<_KeukenResult>(
      MaterialPageRoute(
        builder: (_) => _KeukenScreen(
          initialKenmerken: _opname.keukenKenmerken,
          initialAanrechtlengte: _opname.aanrechtlengte,
        ),
      ),
    );
    if (result != null) {
      setState(() => _opname = _opname.copyWith(
            keukenKenmerken: result.kenmerken,
            aanrechtlengte: result.aanrechtlengte,
          ));
    }
  }

  Future<void> _openSanitair() async {
    final result = await Navigator.of(context).push<_SanitairResult>(
      MaterialPageRoute(
        builder: (_) => _SanitairScreen(
          initialBasis: _opname.sanitairBasis,
          initialExtra: _opname.sanitairExtra,
        ),
      ),
    );
    if (result != null) {
      setState(() => _opname = _opname.copyWith(
            sanitairBasis: result.basis,
            sanitairExtra: result.extra,
          ));
    }
  }

  Future<void> _openEnergie() async {
    final result = await Navigator.of(context).push<_EnergieResult>(
      MaterialPageRoute(
        builder: (_) => _EnergieScreen(
          initialLabel: _opname.energieLabel,
          initialWoningtype: _opname.woningtype,
          initialBouwjaar: _opname.bouwjaar,
        ),
      ),
    );
    if (result != null) {
      setState(() => _opname = _opname.copyWith(
            energieLabel: result.energieLabel,
            woningtype: result.woningtype,
            bouwjaar: result.bouwjaar,
          ));
    }
  }

  Future<void> _openWoz() async {
    final result = await Navigator.of(context).push<_WozResult>(
      MaterialPageRoute(
        builder: (_) => _WozScreen(
          initialWaarde: _opname.wozWaarde,
          initialJaar: _opname.wozJaar,
          initialBron: _opname.wozBron,
        ),
      ),
    );
    if (result != null) {
      setState(() => _opname = _opname.copyWith(
            wozWaarde: result.waarde,
            wozJaar: result.jaar,
            wozBron: result.bron,
          ));
    }
  }

  String get _binnenSub {
    final n = _opname.binnenruimtes.length;
    return n == 0 ? 'Nog niet ingevuld' : '$n ruimte${n == 1 ? '' : 's'}';
  }

  String get _buitenSub {
    final n = _opname.buitenruimtes.length;
    if (n == 0) return 'Nog niet ingevuld';
    return _opname.buitenruimtes.map((r) => r.type).join(', ');
  }

  String get _keukenSub {
    final n = _opname.keukenKenmerken.fold<int>(0, (s, k) => s + k.aantal);
    return '${_opname.aanrechtlengte}'
        '${n > 0 ? ', $n kenmerk${n == 1 ? '' : 'en'}' : ''}';
  }

  String get _sanitairSub {
    final n = (_opname.sanitairBasis + _opname.sanitairExtra)
        .fold<int>(0, (s, k) => s + k.aantal);
    return n == 0 ? 'Nog niet ingevuld' : '$n voorziening${n == 1 ? '' : 'en'}';
  }

  String get _energieSub {
    final parts = <String>[];
    if (_opname.energieLabel.isNotEmpty) parts.add(_opname.energieLabel);
    if (_opname.bouwjaar > 0) parts.add('bouwjaar ${_opname.bouwjaar}');
    parts.add(_opname.woningtype);
    return parts.join(', ');
  }

  String get _wozSub {
    if (_opname.wozWaarde <= 0) return 'Nog niet ingevuld';
    final waarde = _opname.wozWaarde
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
    return '€ $waarde (${_opname.wozJaar})';
  }

  bool _gevuld(int i) {
    switch (i) {
      case 0: return _opname.binnenruimtes.isNotEmpty;
      case 1: return _opname.buitenruimtes.isNotEmpty;
      case 2: return _opname.keukenKenmerken.isNotEmpty;
      case 3: return (_opname.sanitairBasis + _opname.sanitairExtra).isNotEmpty;
      case 4: return _opname.energieLabel.isNotEmpty || _opname.bouwjaar > 0;
      case 5: return _opname.wozWaarde > 0;
      default: return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _TileData(label: 'Binnenruimtes', icon: Icons.meeting_room,
          subtitle: _binnenSub, onTap: _openBinnenruimtes, gevuld: _gevuld(0)),
      _TileData(label: 'Buitenruimtes', icon: Icons.deck,
          subtitle: _buitenSub, onTap: _openBuitenruimtes, gevuld: _gevuld(1)),
      _TileData(label: 'Keuken', icon: Icons.kitchen,
          subtitle: _keukenSub, onTap: _openKeuken, gevuld: _gevuld(2)),
      _TileData(label: 'Sanitair', icon: Icons.bathtub,
          subtitle: _sanitairSub, onTap: _openSanitair, gevuld: _gevuld(3)),
      _TileData(label: 'Energie & Type', icon: Icons.bolt,
          subtitle: _energieSub, onTap: _openEnergie, gevuld: _gevuld(4)),
      _TileData(label: 'WOZ-waarde', icon: Icons.euro,
          subtitle: _wozSub, onTap: _openWoz, gevuld: _gevuld(5)),
    ];

    return PopScope<WwsInvoerData>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Ook bij terug-navigeren de huidige invoer teruggeven, zodat
        // start_screen 'm opslaat (auto-bewaren zonder expliciet 'Opslaan').
        Navigator.of(context).pop(_huidigeData());
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('WWS opname'),
        actions: [
          TextButton.icon(
            onPressed: _opslaan,
            icon: const Icon(Icons.save),
            label: const Text('Opslaan'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.dossierNaam,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('WWS puntentelling koppelen aan object'),
              value: _toepassen,
              onChanged: (v) => setState(() {
                _toepassen = v;
                if (!v) _berekening = null;
              }),
            ),
            if (_toepassen) ...[
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tiles.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                ),
                itemBuilder: (context, i) => _WwsTegel(data: tiles[i]),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _berekenenBusy
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.calculate),
                  label: const Text('Bereken WWS punten'),
                  onPressed: _berekenenBusy ? null : _bereken,
                ),
              ),
              if (_berekenFout != null) ...[
                const SizedBox(height: 8),
                Text('Fout: $_berekenFout',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ],
              if (_berekening != null) ...[
                const SizedBox(height: 16),
                _BerekeningResultaat(berekening: _berekening!),
              ],
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Niet elk object krijgt WWS. Laat de schakelaar uit voor objecten zonder puntentelling.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('WWS opslaan'),
                onPressed: _opslaan,
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tegel-widget
// ─────────────────────────────────────────────────────────────────────────────

class _TileData {
  final String label;
  final IconData icon;
  final String subtitle;
  final VoidCallback onTap;
  final bool gevuld;
  const _TileData({
    required this.label, required this.icon, required this.subtitle,
    required this.onTap, required this.gevuld,
  });
}

class _WwsTegel extends StatelessWidget {
  final _TileData data;
  const _WwsTegel({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: data.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(data.icon, size: 26,
                      color: data.gevuld ? cs.primary : cs.onSurface.withOpacity(0.45)),
                  const Spacer(),
                  if (data.gevuld)
                    Icon(Icons.check_circle, size: 18, color: cs.primary),
                ],
              ),
              const SizedBox(height: 8),
              Text(data.label,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Expanded(
                child: Text(data.subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resultaat-kaart
// ─────────────────────────────────────────────────────────────────────────────

class _BerekeningResultaat extends StatelessWidget {
  final Map<String, dynamic> berekening;
  const _BerekeningResultaat({required this.berekening});

  @override
  Widget build(BuildContext context) {
    final punten = berekening['totaal_met_cap'];
    final maxHuurRaw = berekening['max_huur'] as num?;
    final vrijeSector = berekening['vrije_sector'] as bool? ?? maxHuurRaw == null;
    final huurTekst = vrijeSector
        ? 'Vrije sector'
        : '€ ${maxHuurRaw!.toDouble().toStringAsFixed(2)}';
    final verantwoording = berekening['verantwoording'] as Map<String, dynamic>?;
    final totaalRegels = verantwoording?['totaal'] as List<dynamic>?;

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Uitslag berekening',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatKaart(label: 'Punten', waarde: '$punten')),
                const SizedBox(width: 12),
                Expanded(child: _StatKaart(label: 'Max. huur', waarde: huurTekst)),
              ],
            ),
            if (totaalRegels != null && totaalRegels.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Toelichting', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              ...totaalRegels.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('• $r',
                        style: Theme.of(context).textTheme.bodySmall),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatKaart extends StatelessWidget {
  final String label;
  final String waarde;
  const _StatKaart({required this.label, required this.waarde});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(waarde,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-scherm: Binnenruimtes
// ─────────────────────────────────────────────────────────────────────────────

class _BinnenruimtesScreen extends StatefulWidget {
  final List<WwsBinnenruimte> initial;
  const _BinnenruimtesScreen({required this.initial});

  @override
  State<_BinnenruimtesScreen> createState() => _BinnenruimtesScreenState();
}

class _BinnenruimtesScreenState extends State<_BinnenruimtesScreen> {
  late List<WwsBinnenruimte> _ruimtes;

  @override
  void initState() {
    super.initState();
    _ruimtes = List.from(widget.initial);
  }

  Future<void> _voegToe() async {
    final r = await _RuimteDialog.show(context);
    if (r != null) setState(() => _ruimtes.add(r));
  }

  Future<void> _bewerk(int i) async {
    final r = await _RuimteDialog.show(context, _ruimtes[i]);
    if (r != null) setState(() => _ruimtes[i] = r);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_ruimtes);
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Binnenruimtes'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(_ruimtes),
              child: const Text('Klaar')),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _voegToe,
        icon: const Icon(Icons.add),
        label: const Text('Ruimte toevoegen'),
      ),
      body: _ruimtes.isEmpty
          ? const Center(
              child: Text('Nog geen ruimtes.\nTik + om er een toe te voegen.',
                  textAlign: TextAlign.center))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _ruimtes.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = _ruimtes[i];
                return ListTile(
                  leading: const Icon(Icons.meeting_room),
                  title: Text(r.type),
                  subtitle: Text(
                    '${r.m2.toStringAsFixed(1)} m²'
                    '${r.verwarmd ? '  ·  verwarmd' : ''}'
                    '${r.verkoeld ? '  ·  verkoeld' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _bewerk(i)),
                      IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              setState(() => _ruimtes.removeAt(i))),
                    ],
                  ),
                );
              },
            ),
    ));
  }
}

class _RuimteDialog extends StatefulWidget {
  final WwsBinnenruimte? existing;
  const _RuimteDialog({this.existing});

  static Future<WwsBinnenruimte?> show(BuildContext context,
      [WwsBinnenruimte? existing]) {
    return showDialog<WwsBinnenruimte>(
      context: context,
      builder: (_) => _RuimteDialog(existing: existing),
    );
  }

  @override
  State<_RuimteDialog> createState() => _RuimteDialogState();
}

class _RuimteDialogState extends State<_RuimteDialog> {
  static const _alleTypen = [
    ...BlueprintWwsContract.verblijfsruimteTypen,
    ...BlueprintWwsContract.overigeRuimteTypen,
  ];

  late String _type;
  final _m2Controller = TextEditingController();
  late bool _verwarmd;
  late bool _verkoeld;

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.type ?? _alleTypen.first;
    _m2Controller.text = widget.existing != null
        ? widget.existing!.m2.toStringAsFixed(1)
        : '';
    _verwarmd = widget.existing?.verwarmd ?? true;
    _verkoeld = widget.existing?.verkoeld ?? false;
  }

  @override
  void dispose() {
    _m2Controller.dispose();
    super.dispose();
  }

  void _opslaan() {
    final m2 = double.tryParse(_m2Controller.text.replaceAll(',', '.'));
    if (m2 == null || m2 <= 0) return;
    Navigator.of(context).pop(WwsBinnenruimte(
        type: _type, m2: m2, verwarmd: _verwarmd, verkoeld: _verkoeld));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Ruimte toevoegen' : 'Ruimte bewerken'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Type ruimte', border: OutlineInputBorder()),
              items: _alleTypen
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _m2Controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              decoration: const InputDecoration(
                  labelText: 'Oppervlakte (m²)',
                  hintText: 'Bijv. 20.5',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Verwarmd'),
              value: _verwarmd,
              onChanged: (v) => setState(() => _verwarmd = v!),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Verkoeld'),
              value: _verkoeld,
              onChanged: (v) => setState(() => _verkoeld = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuleren')),
        ElevatedButton(onPressed: _opslaan, child: const Text('Opslaan')),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-scherm: Buitenruimtes
// ─────────────────────────────────────────────────────────────────────────────

class _BuitenruimtesScreen extends StatefulWidget {
  final List<WwsBuitenruimte> initial;
  const _BuitenruimtesScreen({required this.initial});

  @override
  State<_BuitenruimtesScreen> createState() => _BuitenruimtesScreenState();
}

class _BuitenruimtesScreenState extends State<_BuitenruimtesScreen> {
  late List<WwsBuitenruimte> _ruimtes;

  @override
  void initState() {
    super.initState();
    _ruimtes = List.from(widget.initial);
  }

  Future<void> _voegToe() async {
    final r = await _BuitenruimteDialog.show(context);
    if (r != null) setState(() => _ruimtes.add(r));
  }

  Future<void> _bewerk(int i) async {
    final r = await _BuitenruimteDialog.show(context, _ruimtes[i]);
    if (r != null) setState(() => _ruimtes[i] = r);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_ruimtes);
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Buitenruimtes'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(_ruimtes),
              child: const Text('Klaar')),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _voegToe,
        icon: const Icon(Icons.add),
        label: const Text('Buitenruimte toevoegen'),
      ),
      body: _ruimtes.isEmpty
          ? const Center(
              child: Text(
                  'Nog geen buitenruimtes.\nTip: voeg "Geen buitenruimte" toe voor de -5 puntenaftrek.',
                  textAlign: TextAlign.center))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _ruimtes.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = _ruimtes[i];
                return ListTile(
                  leading: const Icon(Icons.deck),
                  title: Text(r.type),
                  subtitle: r.m2 > 0 ? Text('${r.m2.toStringAsFixed(1)} m²') : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _bewerk(i)),
                      IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              setState(() => _ruimtes.removeAt(i))),
                    ],
                  ),
                );
              },
            ),
    ));
  }
}

class _BuitenruimteDialog extends StatefulWidget {
  final WwsBuitenruimte? existing;
  const _BuitenruimteDialog({this.existing});

  static Future<WwsBuitenruimte?> show(BuildContext context,
      [WwsBuitenruimte? existing]) {
    return showDialog<WwsBuitenruimte>(
      context: context,
      builder: (_) => _BuitenruimteDialog(existing: existing),
    );
  }

  @override
  State<_BuitenruimteDialog> createState() => _BuitenruimteDialogState();
}

class _BuitenruimteDialogState extends State<_BuitenruimteDialog> {
  late String _type;
  final _m2Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.type ?? BlueprintWwsContract.buitenruimteTypen.first;
    _m2Controller.text = widget.existing != null && widget.existing!.m2 > 0
        ? widget.existing!.m2.toStringAsFixed(1)
        : '';
  }

  @override
  void dispose() {
    _m2Controller.dispose();
    super.dispose();
  }

  void _opslaan() {
    final geenBuiten = _type == 'Geen buitenruimte';
    final m2 = geenBuiten
        ? 0.0
        : double.tryParse(_m2Controller.text.replaceAll(',', '.'));
    if (!geenBuiten && (m2 == null || m2 <= 0)) return;
    Navigator.of(context).pop(WwsBuitenruimte(type: _type, m2: m2 ?? 0.0));
  }

  @override
  Widget build(BuildContext context) {
    final geenBuiten = _type == 'Geen buitenruimte';
    return AlertDialog(
      title: Text(widget.existing == null
          ? 'Buitenruimte toevoegen'
          : 'Buitenruimte bewerken'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _type,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Type', border: OutlineInputBorder()),
            items: BlueprintWwsContract.buitenruimteTypen
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _type = v!),
          ),
          if (!geenBuiten) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _m2Controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              decoration: const InputDecoration(
                  labelText: 'Oppervlakte (m²)', border: OutlineInputBorder()),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuleren')),
        ElevatedButton(onPressed: _opslaan, child: const Text('Opslaan')),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-scherm: Keuken
// ─────────────────────────────────────────────────────────────────────────────

class _KeukenResult {
  final List<WwsKenmerk> kenmerken;
  final String aanrechtlengte;
  const _KeukenResult(this.kenmerken, this.aanrechtlengte);
}

class _KeukenScreen extends StatefulWidget {
  final List<WwsKenmerk> initialKenmerken;
  final String initialAanrechtlengte;
  const _KeukenScreen(
      {required this.initialKenmerken, required this.initialAanrechtlengte});

  @override
  State<_KeukenScreen> createState() => _KeukenScreenState();
}

class _KeukenScreenState extends State<_KeukenScreen> {
  late String _aanrechtlengte;
  late Map<String, int> _aantallen;

  @override
  void initState() {
    super.initState();
    _aanrechtlengte = widget.initialAanrechtlengte;
    _aantallen = {for (final k in widget.initialKenmerken) k.kenmerk: k.aantal};
  }

  void _klaar() {
    final kenmerken = _aantallen.entries
        .where((e) => e.value > 0)
        .map((e) => WwsKenmerk(kenmerk: e.key, aantal: e.value))
        .toList();
    Navigator.of(context).pop(_KeukenResult(kenmerken, _aanrechtlengte));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _klaar();
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Keuken'),
        actions: [TextButton(onPressed: _klaar, child: const Text('Klaar'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _aanrechtlengte,
            decoration: const InputDecoration(
                labelText: 'Aanrechtlengte', border: OutlineInputBorder()),
            items: BlueprintWwsContract.aanrechtLengtes
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) => setState(() => _aanrechtlengte = v!),
          ),
          const SizedBox(height: 20),
          Text('Kenmerken', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...BlueprintWwsContract.keukenKenmerken.map((k) => _KenmerkRij(
                label: k,
                aantal: _aantallen[k] ?? 0,
                onChanged: (n) => setState(() => _aantallen[k] = n),
              )),
        ],
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-scherm: Sanitair
// ─────────────────────────────────────────────────────────────────────────────

class _SanitairResult {
  final List<WwsKenmerk> basis;
  final List<WwsKenmerk> extra;
  const _SanitairResult(this.basis, this.extra);
}

class _SanitairScreen extends StatefulWidget {
  final List<WwsKenmerk> initialBasis;
  final List<WwsKenmerk> initialExtra;
  const _SanitairScreen(
      {required this.initialBasis, required this.initialExtra});

  @override
  State<_SanitairScreen> createState() => _SanitairScreenState();
}

class _SanitairScreenState extends State<_SanitairScreen> {
  late Map<String, int> _basis;
  late Map<String, int> _extra;

  @override
  void initState() {
    super.initState();
    _basis = {for (final k in widget.initialBasis) k.kenmerk: k.aantal};
    _extra = {for (final k in widget.initialExtra) k.kenmerk: k.aantal};
  }

  void _klaar() {
    Navigator.of(context).pop(_SanitairResult(
      _basis.entries.where((e) => e.value > 0)
          .map((e) => WwsKenmerk(kenmerk: e.key, aantal: e.value)).toList(),
      _extra.entries.where((e) => e.value > 0)
          .map((e) => WwsKenmerk(kenmerk: e.key, aantal: e.value)).toList(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _klaar();
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Sanitair'),
        actions: [TextButton(onPressed: _klaar, child: const Text('Klaar'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Basis sanitair', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...BlueprintWwsContract.sanitairBasisKenmerken.map((k) => _KenmerkRij(
                label: k,
                aantal: _basis[k] ?? 0,
                onChanged: (n) => setState(() => _basis[k] = n),
              )),
          const SizedBox(height: 20),
          Text('Extra sanitair', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...BlueprintWwsContract.sanitairExtraKenmerken.map((k) => _KenmerkRij(
                label: k,
                aantal: _extra[k] ?? 0,
                onChanged: (n) => setState(() => _extra[k] = n),
              )),
        ],
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-scherm: Energie & Type
// ─────────────────────────────────────────────────────────────────────────────

class _EnergieResult {
  final String energieLabel;
  final String woningtype;
  final int bouwjaar;
  const _EnergieResult(this.energieLabel, this.woningtype, this.bouwjaar);
}

class _EnergieScreen extends StatefulWidget {
  final String initialLabel;
  final String initialWoningtype;
  final int initialBouwjaar;
  const _EnergieScreen({
    required this.initialLabel,
    required this.initialWoningtype,
    required this.initialBouwjaar,
  });

  @override
  State<_EnergieScreen> createState() => _EnergieScreenState();
}

class _EnergieScreenState extends State<_EnergieScreen> {
  static const _labels = [
    '', 'A++++', 'A+++', 'A++', 'A+', 'A', 'B', 'C', 'D', 'E', 'F', 'G'
  ];

  late String _label;
  late String _woningtype;
  late TextEditingController _bouwjaarController;

  @override
  void initState() {
    super.initState();
    _label = _labels.contains(widget.initialLabel) ? widget.initialLabel : '';
    _woningtype = widget.initialWoningtype;
    _bouwjaarController = TextEditingController(
      text: widget.initialBouwjaar > 0 ? widget.initialBouwjaar.toString() : '',
    );
  }

  @override
  void dispose() {
    _bouwjaarController.dispose();
    super.dispose();
  }

  void _klaar() {
    final bouwjaar = int.tryParse(_bouwjaarController.text.trim()) ?? 0;
    Navigator.of(context).pop(_EnergieResult(_label, _woningtype, bouwjaar));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _klaar();
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Energie & Type'),
        actions: [TextButton(onPressed: _klaar, child: const Text('Klaar'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _label,
            decoration: const InputDecoration(
              labelText: 'Energielabel',
              helperText: 'Leeg = terugval op bouwjaartabel',
              border: OutlineInputBorder(),
            ),
            items: _labels
                .map((l) => DropdownMenuItem(
                    value: l, child: Text(l.isEmpty ? '— onbekend —' : l)))
                .toList(),
            onChanged: (v) => setState(() => _label = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _woningtype,
            decoration: const InputDecoration(
                labelText: 'Woningtype', border: OutlineInputBorder()),
            items: BlueprintWwsContract.woningTypen
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _woningtype = v!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bouwjaarController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Bouwjaar',
              helperText: 'Voor energie-terugval als label onbekend is',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-scherm: WOZ-waarde
// ─────────────────────────────────────────────────────────────────────────────

class _WozResult {
  final double waarde;
  final String jaar;
  final String bron;
  const _WozResult(this.waarde, this.jaar, this.bron);
}

class _WozScreen extends StatefulWidget {
  final double initialWaarde;
  final String initialJaar;
  final String initialBron;
  const _WozScreen({
    required this.initialWaarde,
    required this.initialJaar,
    required this.initialBron,
  });

  @override
  State<_WozScreen> createState() => _WozScreenState();
}

class _WozScreenState extends State<_WozScreen> {
  late TextEditingController _waardeController;
  late String _jaar;
  late String _bron;

  @override
  void initState() {
    super.initState();
    _waardeController = TextEditingController(
      text: widget.initialWaarde > 0
          ? widget.initialWaarde.toStringAsFixed(0)
          : '',
    );
    _jaar = widget.initialJaar;
    _bron = widget.initialBron;
  }

  @override
  void dispose() {
    _waardeController.dispose();
    super.dispose();
  }

  void _klaar() {
    final raw = _waardeController.text
        .replaceAll('.', '')
        .replaceAll(',', '')
        .trim();
    final waarde = double.tryParse(raw) ?? 0.0;
    Navigator.of(context).pop(_WozResult(waarde, _jaar, _bron));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _klaar();
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('WOZ-waarde'),
        actions: [TextButton(onPressed: _klaar, child: const Text('Klaar'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _waardeController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'WOZ-waarde (EUR)',
              prefixText: '€ ',
              helperText: 'Wordt voorgevuld vanuit de WOZ-lookup',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _jaar,
            decoration: const InputDecoration(
                labelText: 'WOZ-jaar', border: OutlineInputBorder()),
            items: BlueprintWwsContract.wozJaren
                .map((j) => DropdownMenuItem(value: j, child: Text(j)))
                .toList(),
            onChanged: (v) => setState(() => _jaar = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _bron,
            decoration: const InputDecoration(
                labelText: 'WOZ-bron', border: OutlineInputBorder()),
            items: BlueprintWwsContract.wozBronnen
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) => setState(() => _bron = v!),
          ),
        ],
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Herbruikbare widget: kenmerk met +/- teller
// ─────────────────────────────────────────────────────────────────────────────

class _KenmerkRij extends StatelessWidget {
  final String label;
  final int aantal;
  final ValueChanged<int> onChanged;

  const _KenmerkRij({
    required this.label,
    required this.aantal,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: aantal > 0 ? null : Colors.black54)),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: aantal > 0 ? () => onChanged(aantal - 1) : null,
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 28,
            child: Text('$aantal',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight:
                        aantal > 0 ? FontWeight.bold : FontWeight.normal)),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => onChanged(aantal + 1),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

