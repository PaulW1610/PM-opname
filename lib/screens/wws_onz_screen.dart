import 'package:flutter/material.dart';

import '../models/wws_onz_data.dart';
import '../services/blueprint_api_service.dart';

/// Invoerscherm WWS onzelfstandige woonruimte (kamerverhuur). De server rekent
/// (`POST /bd/v1/wws-onz`); dit scherm verzamelt het dossier en toont de
/// uitkomst per kamer + totaal.
class WwsOnzScreen extends StatefulWidget {
  final String dossierNaam;
  final String adres;
  final String postcode;
  final String plaats;
  final int? bouwjaar;
  final double? wozVoorgevuld;
  final String? energieLabelVoorgevuld;

  const WwsOnzScreen({
    super.key,
    required this.dossierNaam,
    this.adres = '',
    this.postcode = '',
    this.plaats = '',
    this.bouwjaar,
    this.wozVoorgevuld,
    this.energieLabelVoorgevuld,
  });

  @override
  State<WwsOnzScreen> createState() => _WwsOnzScreenState();
}

class _WwsOnzScreenState extends State<WwsOnzScreen> {
  late final WwsOnzDossier _d;
  bool _bezig = false;
  String? _fout;
  Map<String, dynamic>? _resultaat;

  @override
  void initState() {
    super.initState();
    _d = WwsOnzDossier(
      adres: widget.adres,
      postcode: widget.postcode,
      plaats: widget.plaats,
      bouwjaar: widget.bouwjaar,
      woz: widget.wozVoorgevuld ?? 0,
      label: (widget.energieLabelVoorgevuld ?? '').trim().isNotEmpty
          ? _normLabel(widget.energieLabelVoorgevuld!)
          : 'Geen geldig label',
    );
  }

  String _normLabel(String raw) {
    final s = raw.trim().toUpperCase();
    return WwsOnzKeuzes.energielabels.contains(s) ? s : 'Geen geldig label';
  }

  bool _isKeukenType(String rt) =>
      rt == 'Keuken' || rt == 'Woonkamer met open keuken';
  bool _isSanitairType(String rt) => rt == 'Badkamer' || rt == 'Toiletruimte';

  Future<void> _bereken() async {
    setState(() {
      _bezig = true;
      _fout = null;
    });
    try {
      final res = await BlueprintApiService.rekenWwsOnz(_d.toJson());
      if (!mounted) return;
      setState(() => _resultaat = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _fout = e.toString());
    } finally {
      if (mounted) setState(() => _bezig = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WWS onzelfstandig')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          Text(widget.dossierNaam,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Kamerpuntenstelsel — de server rekent na het versturen.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),

          if (_resultaat != null) _resultaatKaart(_resultaat!),
          if (_fout != null)
            _melding('Berekenen mislukt: $_fout', Colors.red),

          _sectie('Gebouw', [
            _numField('Aantal bewoners', _d.occupants.toDouble(),
                (v) => _d.occupants = v.round(),
                isInt: true),
            _numField('GBO pand (m², uit WOZ)', _d.gbo, (v) => _d.gbo = v),
            _numField('WOZ-waarde pand (€)', _d.woz, (v) => _d.woz = v),
            _dropdown('COROP-gebied', _d.corop, WwsOnzKeuzes.coropGebieden,
                (v) => _d.corop = v),
            _dropdown('Energielabel pand', _d.label,
                WwsOnzKeuzes.energielabels, (v) => _d.label = v),
            _numField('Punten parkeerruimten', _d.parkingPoints,
                (v) => _d.parkingPoints = v),
            _numField('Aantal verwarmde hallen/gangen',
                _d.heatedHallCount.toDouble(),
                (v) => _d.heatedHallCount = v.round(),
                isInt: true),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Gedeelde deurbel met intercom'),
              value: _d.sharedDoorbellIntercom,
              onChanged: (v) => setState(() => _d.sharedDoorbellIntercom = v),
            ),
          ]),

          _lijstSectie<WwsOnzFacilityRij>(
            'Gedeelde ruimtes',
            _d.facilityRows,
            () => _d.facilityRows.add(WwsOnzFacilityRij()),
            (r, i) => _facilityEditor(r, i),
          ),

          _lijstSectie<WwsOnzRuimte>(
            'Extra gedeelde ruimtes',
            _d.sharedRooms,
            () => _d.sharedRooms.add(WwsOnzRuimte(gedeeld: true)),
            (r, i) => _ruimteEditor(r, i, gedeeldVast: true),
          ),

          _lijstSectie<WwsOnzBuiten>(
            'Buitenruimtes (pand)',
            _d.outdoor,
            () => _d.outdoor.add(WwsOnzBuiten()),
            (r, i) => _buitenEditor(r, i),
          ),

          _lijstSectie<WwsOnzKamer>(
            'Kamers',
            _d.units,
            () => _d.units.add(WwsOnzKamer(naam: 'Kamer ${_d.units.length + 1}')),
            (u, i) => _kamerEditor(u, i),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            icon: _bezig
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.calculate_outlined),
            label: Text(_bezig ? 'Berekenen…' : 'Bereken punten'),
            onPressed: _bezig ? null : _bereken,
          ),
        ),
      ),
    );
  }

  // ---- Resultaat ----

  Widget _resultaatKaart(Map<String, dynamic> res) {
    final totaal = res['totaal'] is Map ? res['totaal'] as Map : const {};
    final units = res['units'] is List ? res['units'] as List : const [];
    String euro(dynamic v) =>
        v is num ? '€ ${v.toStringAsFixed(2)}' : '—';
    return Card(
      color: const Color(0xFFE9F0F9),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Uitkomst',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text('Totaal: ${totaal['punten'] ?? '—'} punten · '
                'max. huur ${euro(totaal['max_huur_maand'])}/mnd'),
            const Divider(),
            for (final u in units.whereType<Map>())
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• ${u['naam'] ?? 'Kamer'}: '
                    '${u['punten'] ?? '—'} pt · '
                    '${euro(u['max_huur_maand'])}/mnd'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _melding(String tekst, Color kleur) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: kleur.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kleur.withValues(alpha: 0.4)),
        ),
        child: Text(tekst, style: TextStyle(color: kleur)),
      );

  // ---- Secties + herbruikbare velden ----

  Widget _sectie(String titel, List<Widget> kinderen) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titel, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              ...kinderen,
            ],
          ),
        ),
      );

  Widget _lijstSectie<T>(
    String titel,
    List<T> lijst,
    VoidCallback opToevoegen,
    Widget Function(T item, int index) editor,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('$titel (${lijst.length})',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Toevoegen'),
                  onPressed: () => setState(opToevoegen),
                ),
              ],
            ),
            for (var i = 0; i < lijst.length; i++) editor(lijst[i], i),
          ],
        ),
      ),
    );
  }

  Widget _numField(String label, double waarde, ValueChanged<double> onChanged,
      {bool isInt = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        initialValue: isInt
            ? waarde.round().toString()
            : (waarde == 0 ? '' : _fmt(waarde)),
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: false),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (t) {
          final v = double.tryParse(t.replaceAll(',', '.').trim()) ?? 0;
          onChanged(v);
        },
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Widget _dropdown(String label, String waarde, List<String> opties,
      ValueChanged<String> onChanged) {
    final huidig = opties.contains(waarde) ? waarde : opties.first;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        initialValue: huidig,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: opties
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => onChanged(v));
        },
      ),
    );
  }

  Widget _switch(String label, bool waarde, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label),
        value: waarde,
        onChanged: (v) => setState(() => onChanged(v)),
      );

  /// Voorziening-kiezer: aangevinkte voorziening = aantal 1 (v1).
  Widget _voorzieningen(
      String titel, List<String> opties, Map<String, int> map) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(titel, style: Theme.of(context).textTheme.labelMedium),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          children: opties.map((o) {
            final aan = (map[o] ?? 0) > 0;
            return FilterChip(
              label: Text(o, style: const TextStyle(fontSize: 12)),
              selected: aan,
              onSelected: (sel) => setState(() {
                if (sel) {
                  map[o] = 1;
                } else {
                  map.remove(o);
                }
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _verwijderKnop(VoidCallback onDelete) => Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Verwijderen'),
          onPressed: () => setState(onDelete),
        ),
      );

  Widget _gedeeldRegel(bool gedeeld, ValueChanged<bool> onG, int delenMet,
      ValueChanged<int> onN) {
    return Row(
      children: [
        Expanded(child: _switch('Gedeeld', gedeeld, onG)),
        if (gedeeld)
          SizedBox(
            width: 120,
            child: _numField('Delen met', delenMet.toDouble(),
                (v) => onN(v.round() < 1 ? 1 : v.round()),
                isInt: true),
          ),
      ],
    );
  }

  // ---- Row-editors ----

  Widget _ruimteEditor(WwsOnzRuimte r, int i,
      {bool gedeeldVast = false, VoidCallback? onDelete}) {
    return _rijKaart(
      titel: r.naam.isEmpty ? 'Ruimte ${i + 1}' : r.naam,
      children: [
        _tekst('Naam', r.naam, (v) => r.naam = v),
        _dropdown('Soort', r.soort, WwsOnzKeuzes.soorten, (v) => r.soort = v),
        _numField('Oppervlakte (m²)', r.oppervlakte, (v) => r.oppervlakte = v),
        _gedeeldRegel(r.gedeeld, (v) => r.gedeeld = v, r.delenMet,
            (v) => r.delenMet = v),
        _switch('Verwarmd', r.verwarmd, (v) => r.verwarmd = v),
        _switch('Verkoeld', r.verkoeld, (v) => r.verkoeld = v),
        if (onDelete != null) _verwijderKnop(onDelete),
      ],
    );
  }

  Widget _facilityEditor(WwsOnzFacilityRij r, int i) {
    final keuken = _isKeukenType(r.ruimtetype);
    final sanitair = _isSanitairType(r.ruimtetype);
    return _rijKaart(
      titel: '${r.ruimtetype}${r.naam.isNotEmpty ? ' — ${r.naam}' : ''}',
      children: [
        _dropdown('Ruimtetype', r.ruimtetype, WwsOnzKeuzes.ruimtetypes,
            (v) => r.ruimtetype = v),
        _tekst('Naam', r.naam, (v) => r.naam = v),
        if (r.ruimtetype != 'Toiletruimte')
          _numField('Oppervlakte (m²)', r.oppervlakte,
              (v) => r.oppervlakte = v),
        _gedeeldRegel(r.gedeeld, (v) => r.gedeeld = v, r.delenMet,
            (v) => r.delenMet = v),
        _switch('Verwarmd', r.verwarmd, (v) => r.verwarmd = v),
        _switch('Verkoeld', r.verkoeld, (v) => r.verkoeld = v),
        if (keuken) ...[
          _dropdown('Aanrechtlengte', r.aanrecht,
              WwsOnzKeuzes.aanrechtlengtes, (v) => r.aanrecht = v),
          _voorzieningen('Keukenvoorzieningen',
              WwsOnzKeuzes.keukenKenmerken, r.keukenKenmerken),
        ],
        if (sanitair) ...[
          _voorzieningen('Sanitair (basis)', WwsOnzKeuzes.sanitairBasis,
              r.sanitairBasis),
          _voorzieningen('Sanitair (extra)', WwsOnzKeuzes.sanitairExtra,
              r.sanitairExtra),
        ],
        _verwijderKnop(() => _d.facilityRows.remove(r)),
      ],
    );
  }

  Widget _buitenEditor(WwsOnzBuiten r, int i) {
    return _rijKaart(
      titel: r.naam.isEmpty ? 'Buitenruimte ${i + 1}' : r.naam,
      children: [
        _tekst('Naam', r.naam, (v) => r.naam = v),
        _dropdown('Type', r.type, WwsOnzKeuzes.buitenTypes, (v) => r.type = v),
        _numField('Oppervlakte (m²)', r.oppervlakte, (v) => r.oppervlakte = v),
        _gedeeldRegel(r.gedeeld, (v) => r.gedeeld = v, r.delenMet,
            (v) => r.delenMet = v),
        _verwijderKnop(() => _d.outdoor.remove(r)),
      ],
    );
  }

  Widget _kamerEditor(WwsOnzKamer u, int i) {
    final eigenKeuken = u.kitchen == 'Eigen keuken';
    final eigenSanitair = u.sanitary == 'Eigen toilet, douche en wastafel';
    return _rijKaart(
      titel: u.naam.isEmpty ? 'Kamer ${i + 1}' : u.naam,
      initieelOpen: i == 0,
      children: [
        _tekst('Naam kamer', u.naam, (v) => u.naam = v),
        // Privéruimten van de kamer.
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Expanded(
                child: Text('Ruimten van de kamer (${u.rooms.length})',
                    style: Theme.of(context).textTheme.labelMedium),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ruimte'),
                onPressed: () =>
                    setState(() => u.rooms.add(WwsOnzRuimte(naam: 'Ruimte'))),
              ),
            ],
          ),
        ),
        for (var j = 0; j < u.rooms.length; j++)
          _ruimteEditor(u.rooms[j], j,
              onDelete: () => u.rooms.removeAt(j)),
        const Divider(),
        _dropdown('Keuken', u.kitchen, WwsOnzKeuzes.keukenSoort,
            (v) => u.kitchen = v),
        if (eigenKeuken) ...[
          _dropdown('Aanrechtlengte (eigen keuken)', u.privateCountertop,
              WwsOnzKeuzes.aanrechtlengtes, (v) => u.privateCountertop = v),
          _voorzieningen('Keukenvoorzieningen (eigen)',
              WwsOnzKeuzes.keukenKenmerken, u.privateKitchenFeatures),
        ],
        _dropdown('Sanitair', u.sanitary, WwsOnzKeuzes.sanitairSoort,
            (v) => u.sanitary = v),
        if (eigenSanitair) ...[
          _voorzieningen('Sanitair basis (eigen)',
              WwsOnzKeuzes.sanitairBasis, u.privateSanitairBasis),
          _voorzieningen('Sanitair extra (eigen)',
              WwsOnzKeuzes.sanitairExtra, u.privateSanitairExtra),
        ],
        _switch('Eigen wastafel in de kamer', u.privateWashbasin,
            (v) => u.privateWashbasin = v),
        _dropdown('Eigen buitenruimte', u.privateOutdoorType,
            WwsOnzKeuzes.buitenTypes, (v) => u.privateOutdoorType = v),
        if (u.privateOutdoorType != 'Geen buitenruimte')
          _numField('Oppervlakte eigen buitenruimte (m²)', u.privateOutdoorM2,
              (v) => u.privateOutdoorM2 = v),
        _numField('Investering handicapvoorzieningen (€)', u.handicapCosts,
            (v) => u.handicapCosts = v),
        _voorzieningenLijst('Aftrekpunten', WwsOnzKeuzes.aftrekposten,
            u.deductions),
        _switch('Zorgwoning', u.zorgwoning, (v) => u.zorgwoning = v),
        _verwijderKnop(() => _d.units.remove(u)),
      ],
    );
  }

  /// Multiselect van vaste teksten (aftrekpunten) → lijst van strings.
  Widget _voorzieningenLijst(
      String titel, List<String> opties, List<String> gekozen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(titel, style: Theme.of(context).textTheme.labelMedium),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          children: opties.map((o) {
            final aan = gekozen.contains(o);
            return FilterChip(
              label: Text(o, style: const TextStyle(fontSize: 12)),
              selected: aan,
              onSelected: (sel) => setState(() {
                if (sel) {
                  gekozen.add(o);
                } else {
                  gekozen.remove(o);
                }
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _tekst(String label, String waarde, ValueChanged<String> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextFormField(
          initialValue: waarde,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: onChanged,
        ),
      );

  Widget _rijKaart({
    required String titel,
    required List<Widget> children,
    bool initieelOpen = false,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.4),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        initiallyExpanded: initieelOpen,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(titel, style: const TextStyle(fontSize: 14)),
        children: children,
      ),
    );
  }
}
