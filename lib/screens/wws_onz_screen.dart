import 'package:flutter/material.dart';

import '../models/wws_onz_data.dart';
import '../services/blueprint_api_service.dart';

/// Herbruikbare invoervelden + row-editors voor de WWS-onzelfstandig-schermen.
/// Elk scherm (hoofd + subschermen) mixt dit in en levert zijn eigen setState.
mixin _WwsOnzVelden<T extends StatefulWidget> on State<T> {
  Widget vNum(String label, double waarde, ValueChanged<double> onChanged,
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
        onChanged: (t) =>
            onChanged(double.tryParse(t.replaceAll(',', '.').trim()) ?? 0),
      ),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Widget vTekst(String label, String waarde, ValueChanged<String> onChanged) =>
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

  Widget vDropdown(String label, String waarde, List<String> opties,
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

  Widget vSwitch(String label, bool waarde, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label),
        value: waarde,
        onChanged: (v) => setState(() => onChanged(v)),
      );

  /// Voorziening-kiezer: aangevinkt = aantal 1.
  /// Voorzieningen met aantal-teller (net als de kenmerk-rijen bij de
  /// zelfstandige WWS): per optie een nette rij met −/aantal/+.
  Widget vVoorzieningen(
      String titel, List<String> opties, Map<String, int> map) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Text(titel, style: Theme.of(context).textTheme.labelMedium),
        ),
        ...opties.map((o) => _VoorzieningRij(
              label: o,
              aantal: map[o] ?? 0,
              onChanged: (n) => setState(() {
                if (n > 0) {
                  map[o] = n;
                } else {
                  map.remove(o);
                }
              }),
            )),
      ],
    );
  }

  /// Multiselect van vaste teksten → lijst van strings (aftrekpunten).
  /// Nette aanvinkvakjes, net als bij de zelfstandige WWS.
  Widget vTekstlijst(String titel, List<String> opties, List<String> gekozen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Text(titel, style: Theme.of(context).textTheme.labelMedium),
        ),
        ...opties.map((o) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(o),
              value: gekozen.contains(o),
              onChanged: (sel) => setState(() {
                if (sel == true) {
                  if (!gekozen.contains(o)) gekozen.add(o);
                } else {
                  gekozen.remove(o);
                }
              }),
            )),
      ],
    );
  }

  Widget vVerwijder(VoidCallback onDelete) => Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Verwijderen'),
          onPressed: () => setState(onDelete),
        ),
      );

  Widget vGedeeld(bool gedeeld, ValueChanged<bool> onG, int delenMet,
      ValueChanged<int> onN) {
    return Row(
      children: [
        Expanded(child: vSwitch('Gedeeld', gedeeld, onG)),
        if (gedeeld)
          SizedBox(
            width: 120,
            child: vNum('Delen met', delenMet.toDouble(),
                (v) => onN(v.round() < 1 ? 1 : v.round()),
                isInt: true),
          ),
      ],
    );
  }

  Widget vKaart(
      {required String titel,
      required List<Widget> children,
      bool open = false}) {
    return Card(
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.4),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        initiallyExpanded: open,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(titel, style: const TextStyle(fontSize: 14)),
        children: children,
      ),
    );
  }

  bool isKeukenType(String rt) =>
      rt == 'Keuken' || rt == 'Woonkamer met open keuken';
  bool isSanitairType(String rt) => rt == 'Badkamer' || rt == 'Toiletruimte';

  Widget ruimteEditor(WwsOnzRuimte r, int i, VoidCallback onDelete) {
    return vKaart(
      titel: r.naam.isEmpty ? 'Ruimte ${i + 1}' : r.naam,
      children: [
        vTekst('Naam', r.naam, (v) => r.naam = v),
        vDropdown('Soort', r.soort, WwsOnzKeuzes.soorten, (v) => r.soort = v),
        vNum('Oppervlakte (m²)', r.oppervlakte, (v) => r.oppervlakte = v),
        vGedeeld(r.gedeeld, (v) => r.gedeeld = v, r.delenMet,
            (v) => r.delenMet = v),
        vSwitch('Verwarmd', r.verwarmd, (v) => r.verwarmd = v),
        vSwitch('Verkoeld', r.verkoeld, (v) => r.verkoeld = v),
        vVerwijder(onDelete),
      ],
    );
  }

  Widget facilityEditor(WwsOnzFacilityRij r, int i, VoidCallback onDelete) {
    final keuken = isKeukenType(r.ruimtetype);
    final sanitair = isSanitairType(r.ruimtetype);
    return vKaart(
      titel: '${r.ruimtetype}${r.naam.isNotEmpty ? ' — ${r.naam}' : ''}',
      children: [
        vDropdown('Ruimtetype', r.ruimtetype, WwsOnzKeuzes.ruimtetypes,
            (v) => r.ruimtetype = v),
        vTekst('Naam', r.naam, (v) => r.naam = v),
        if (r.ruimtetype != 'Toiletruimte')
          vNum('Oppervlakte (m²)', r.oppervlakte, (v) => r.oppervlakte = v),
        vGedeeld(r.gedeeld, (v) => r.gedeeld = v, r.delenMet,
            (v) => r.delenMet = v),
        vSwitch('Verwarmd', r.verwarmd, (v) => r.verwarmd = v),
        vSwitch('Verkoeld', r.verkoeld, (v) => r.verkoeld = v),
        if (keuken) ...[
          vDropdown('Aanrechtlengte', r.aanrecht, WwsOnzKeuzes.aanrechtlengtes,
              (v) => r.aanrecht = v),
          vVoorzieningen('Keukenvoorzieningen', WwsOnzKeuzes.keukenKenmerken,
              r.keukenKenmerken),
        ],
        if (sanitair) ...[
          vVoorzieningen(
              'Sanitair (basis)', WwsOnzKeuzes.sanitairBasis, r.sanitairBasis),
          vVoorzieningen(
              'Sanitair (extra)', WwsOnzKeuzes.sanitairExtra, r.sanitairExtra),
        ],
        vVerwijder(onDelete),
      ],
    );
  }

  Widget buitenEditor(WwsOnzBuiten r, int i, VoidCallback onDelete) {
    return vKaart(
      titel: r.naam.isEmpty ? 'Buitenruimte ${i + 1}' : r.naam,
      children: [
        vTekst('Naam', r.naam, (v) => r.naam = v),
        vDropdown('Type', r.type, WwsOnzKeuzes.buitenTypes, (v) => r.type = v),
        vNum('Oppervlakte (m²)', r.oppervlakte, (v) => r.oppervlakte = v),
        vGedeeld(r.gedeeld, (v) => r.gedeeld = v, r.delenMet,
            (v) => r.delenMet = v),
        vVerwijder(onDelete),
      ],
    );
  }

  Widget kamerEditor(WwsOnzKamer u, int i, VoidCallback onDelete) {
    final eigenKeuken = u.kitchen == 'Eigen keuken';
    final eigenSanitair = u.sanitary == 'Eigen toilet, douche en wastafel';
    return vKaart(
      titel: u.naam.isEmpty ? 'Kamer ${i + 1}' : u.naam,
      open: i == 0,
      children: [
        vTekst('Naam kamer', u.naam, (v) => u.naam = v),
        Padding(
          padding: const EdgeInsets.only(top: 8),
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
          ruimteEditor(u.rooms[j], j, () => u.rooms.removeAt(j)),
        const Divider(),
        vDropdown('Keuken', u.kitchen, WwsOnzKeuzes.keukenSoort,
            (v) => u.kitchen = v),
        if (eigenKeuken) ...[
          vDropdown('Aanrechtlengte (eigen keuken)', u.privateCountertop,
              WwsOnzKeuzes.aanrechtlengtes, (v) => u.privateCountertop = v),
          vVoorzieningen('Keukenvoorzieningen (eigen)',
              WwsOnzKeuzes.keukenKenmerken, u.privateKitchenFeatures),
        ],
        vDropdown('Sanitair', u.sanitary, WwsOnzKeuzes.sanitairSoort,
            (v) => u.sanitary = v),
        if (eigenSanitair) ...[
          vVoorzieningen('Sanitair basis (eigen)', WwsOnzKeuzes.sanitairBasis,
              u.privateSanitairBasis),
          vVoorzieningen('Sanitair extra (eigen)', WwsOnzKeuzes.sanitairExtra,
              u.privateSanitairExtra),
        ],
        vSwitch('Eigen wastafel in de kamer', u.privateWashbasin,
            (v) => u.privateWashbasin = v),
        vDropdown('Eigen buitenruimte', u.privateOutdoorType,
            WwsOnzKeuzes.buitenTypes, (v) => u.privateOutdoorType = v),
        if (u.privateOutdoorType != 'Geen buitenruimte')
          vNum('Oppervlakte eigen buitenruimte (m²)', u.privateOutdoorM2,
              (v) => u.privateOutdoorM2 = v),
        vNum('Investering handicapvoorzieningen (€)', u.handicapCosts,
            (v) => u.handicapCosts = v),
        vTekstlijst('Aftrekpunten', WwsOnzKeuzes.aftrekposten, u.deductions),
        vSwitch('Zorgwoning', u.zorgwoning, (v) => u.zorgwoning = v),
        vVerwijder(onDelete),
      ],
    );
  }
}

/// Gegevens voor één tegel op het hoofdscherm.
class _Tegel {
  final String label;
  final IconData icon;
  final String subtitle;
  final bool gevuld;
  final VoidCallback onTap;
  const _Tegel(this.label, this.icon, this.subtitle, this.gevuld, this.onTap);
}

/// Hoofdscherm WWS onzelfstandig: tegel-grid zoals de zelfstandige WWS.
class WwsOnzScreen extends StatefulWidget {
  final String dossierNaam;
  final String adres;
  final String postcode;
  final String plaats;
  final String huisnummer;
  final String toevoeging;
  final int? bouwjaar;
  final double? wozVoorgevuld;
  final String? energieLabelVoorgevuld;

  const WwsOnzScreen({
    super.key,
    required this.dossierNaam,
    this.adres = '',
    this.postcode = '',
    this.plaats = '',
    this.huisnummer = '',
    this.toevoeging = '',
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

  static const Color _gevuldBg = Color(0xFFEAF4EC);
  static const Color _gevuldRand = Color(0xFF9CCBA6);
  static const Color _gevuldGroen = Color(0xFF2F7D4F);

  @override
  void initState() {
    super.initState();
    _d = WwsOnzDossier(
      adres: widget.adres,
      postcode: widget.postcode,
      plaats: widget.plaats,
      bouwjaar: widget.bouwjaar,
      woz: widget.wozVoorgevuld ?? 0,
      label: _normLabel(widget.energieLabelVoorgevuld ?? ''),
    );
  }

  String _normLabel(String raw) {
    final s = raw.trim().toUpperCase();
    return WwsOnzKeuzes.energielabels.contains(s) ? s : 'Geen geldig label';
  }

  Future<void> _open(Widget scherm) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => scherm));
    if (mounted) setState(() {}); // tegels + samenvattingen verversen
  }

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
    final tegels = <_Tegel>[
      _Tegel(
        'Gebouw',
        Icons.apartment,
        '${_d.occupants} bewoners · ${_d.label}',
        _d.occupants > 0 && _d.woz > 0,
        () => _open(_GebouwScherm(_d,
            huisnummer: widget.huisnummer, toevoeging: widget.toevoeging)),
      ),
      _Tegel(
        'Gedeelde ruimtes',
        Icons.meeting_room_outlined,
        _d.facilityRows.isEmpty
            ? 'Nog geen'
            : '${_d.facilityRows.length} ruimte(s)',
        _d.facilityRows.isNotEmpty,
        () => _open(_GedeeldeRuimtesScherm(_d)),
      ),
      _Tegel(
        'Extra gedeeld',
        Icons.door_sliding_outlined,
        _d.sharedRooms.isEmpty ? 'Nog geen' : '${_d.sharedRooms.length}',
        _d.sharedRooms.isNotEmpty,
        () => _open(_ExtraRuimtesScherm(_d)),
      ),
      _Tegel(
        'Buitenruimtes',
        Icons.deck_outlined,
        _d.outdoor.isEmpty ? 'Nog geen' : '${_d.outdoor.length}',
        _d.outdoor.isNotEmpty,
        () => _open(_BuitenScherm(_d)),
      ),
      _Tegel(
        'Kamers',
        Icons.bed_outlined,
        '${_d.units.length} kamer(s)',
        _d.units.isNotEmpty,
        () => _open(_KamersScherm(_d)),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('WWS onzelfstandig')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          Text(widget.dossierNaam,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Kamerpuntenstelsel — tik een blok om in te vullen.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          if (_resultaat != null) _resultaatKaart(_resultaat!),
          if (_fout != null) _melding('Berekenen mislukt: $_fout'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.3,
            ),
            itemCount: tegels.length,
            itemBuilder: (_, i) => _tegelKaart(tegels[i]),
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

  Widget _tegelKaart(_Tegel t) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: t.gevuld ? 1 : 2,
      color: t.gevuld ? _gevuldBg : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: t.gevuld
            ? const BorderSide(color: _gevuldRand, width: 1.4)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: t.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(t.icon,
                      size: 26,
                      color: t.gevuld
                          ? _gevuldGroen
                          : cs.onSurface.withValues(alpha: 0.45)),
                  const Spacer(),
                  if (t.gevuld)
                    const Icon(Icons.check_circle,
                        size: 18, color: _gevuldGroen),
                ],
              ),
              const SizedBox(height: 8),
              Text(t.label,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Expanded(
                child: Text(t.subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultaatKaart(Map<String, dynamic> res) {
    final totaal = res['totaal'] is Map ? res['totaal'] as Map : const {};
    final units = res['units'] is List ? res['units'] as List : const [];
    String euro(dynamic v) => v is num ? '€ ${v.toStringAsFixed(2)}' : '—';
    return Card(
      color: const Color(0xFFE9F0F9),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Uitkomst', style: Theme.of(context).textTheme.titleSmall),
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

  Widget _melding(String tekst) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
        ),
        child: Text(tekst, style: const TextStyle(color: Colors.red)),
      );
}

// ---------------- Subschermen ----------------

class _GebouwScherm extends StatefulWidget {
  final WwsOnzDossier d;
  final String huisnummer;
  final String toevoeging;
  const _GebouwScherm(this.d, {this.huisnummer = '', this.toevoeging = ''});
  @override
  State<_GebouwScherm> createState() => _GebouwSchermState();
}

class _GebouwSchermState extends State<_GebouwScherm> with _WwsOnzVelden {
  bool _wozBezig = false;

  Future<void> _haalWoz() async {
    final d = widget.d;
    final postcode = d.postcode.replaceAll(' ', '').trim();
    if (postcode.isEmpty || widget.huisnummer.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Geen postcode + huisnummer bekend; haal eerst een '
            'adres op via het startscherm.'),
      ));
      return;
    }
    setState(() => _wozBezig = true);
    try {
      final res = await BlueprintApiService.lookupWoz(
        postcode: postcode,
        huisnummer: widget.huisnummer.trim(),
        toevoeging: widget.toevoeging.trim(),
      );
      if (!mounted) return;
      if (res.status == WozStatus.ok && (res.waarde ?? 0) > 0) {
        setState(() => d.woz = res.waarde!.toDouble());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('WOZ opgehaald: € ${res.waarde}'
              '${res.peildatum.isNotEmpty ? ' (peildatum ${res.peildatum})' : ''}'),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.melding.isNotEmpty
              ? res.melding
              : 'Geen WOZ-waarde gevonden voor dit adres.'),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('WOZ ophalen mislukt: $e'),
      ));
    } finally {
      if (mounted) setState(() => _wozBezig = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    return Scaffold(
      appBar: AppBar(title: const Text('Gebouw')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          vNum('Aantal bewoners', d.occupants.toDouble(),
              (v) => d.occupants = v.round(),
              isInt: true),
          vNum('GBO pand (m², uit WOZ)', d.gbo, (v) => d.gbo = v),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: vNum('WOZ-waarde pand (€)', d.woz, (v) => d.woz = v),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: FilledButton.tonalIcon(
                  onPressed: _wozBezig ? null : _haalWoz,
                  icon: _wozBezig
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download, size: 18),
                  label: const Text('Ophalen'),
                ),
              ),
            ],
          ),
          vDropdown('COROP-gebied', d.corop, WwsOnzKeuzes.coropGebieden,
              (v) => d.corop = v),
          vDropdown('Energielabel pand', d.label, WwsOnzKeuzes.energielabels,
              (v) => d.label = v),
          vNum('Punten parkeerruimten', d.parkingPoints,
              (v) => d.parkingPoints = v),
          vNum('Aantal verwarmde hallen/gangen', d.heatedHallCount.toDouble(),
              (v) => d.heatedHallCount = v.round(),
              isInt: true),
          vSwitch('Gedeelde deurbel met intercom', d.sharedDoorbellIntercom,
              (v) => d.sharedDoorbellIntercom = v),
        ],
      ),
    );
  }
}

/// Gedeeld basis-scherm voor een lijst met "+ toevoegen" en editors.
abstract class _LijstSchermState<W extends StatefulWidget> extends State<W>
    with _WwsOnzVelden<W> {
  String get titel;
  int get aantal;
  void voegToe();
  List<Widget> bouwItems();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titel)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: bouwItems(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(voegToe),
        icon: const Icon(Icons.add),
        label: const Text('Toevoegen'),
      ),
    );
  }
}

class _GedeeldeRuimtesScherm extends StatefulWidget {
  final WwsOnzDossier d;
  const _GedeeldeRuimtesScherm(this.d);
  @override
  State<_GedeeldeRuimtesScherm> createState() => _GedeeldeRuimtesState();
}

class _GedeeldeRuimtesState
    extends _LijstSchermState<_GedeeldeRuimtesScherm> {
  @override
  String get titel => 'Gedeelde ruimtes';
  @override
  int get aantal => widget.d.facilityRows.length;
  @override
  void voegToe() => widget.d.facilityRows.add(WwsOnzFacilityRij());
  @override
  List<Widget> bouwItems() => [
        for (var i = 0; i < widget.d.facilityRows.length; i++)
          facilityEditor(widget.d.facilityRows[i], i,
              () => widget.d.facilityRows.removeAt(i)),
      ];
}

class _ExtraRuimtesScherm extends StatefulWidget {
  final WwsOnzDossier d;
  const _ExtraRuimtesScherm(this.d);
  @override
  State<_ExtraRuimtesScherm> createState() => _ExtraRuimtesState();
}

class _ExtraRuimtesState extends _LijstSchermState<_ExtraRuimtesScherm> {
  @override
  String get titel => 'Extra gedeelde ruimtes';
  @override
  int get aantal => widget.d.sharedRooms.length;
  @override
  void voegToe() => widget.d.sharedRooms.add(WwsOnzRuimte(gedeeld: true));
  @override
  List<Widget> bouwItems() => [
        for (var i = 0; i < widget.d.sharedRooms.length; i++)
          ruimteEditor(widget.d.sharedRooms[i], i,
              () => widget.d.sharedRooms.removeAt(i)),
      ];
}

class _BuitenScherm extends StatefulWidget {
  final WwsOnzDossier d;
  const _BuitenScherm(this.d);
  @override
  State<_BuitenScherm> createState() => _BuitenState();
}

class _BuitenState extends _LijstSchermState<_BuitenScherm> {
  @override
  String get titel => 'Buitenruimtes';
  @override
  int get aantal => widget.d.outdoor.length;
  @override
  void voegToe() => widget.d.outdoor.add(WwsOnzBuiten());
  @override
  List<Widget> bouwItems() => [
        for (var i = 0; i < widget.d.outdoor.length; i++)
          buitenEditor(widget.d.outdoor[i], i,
              () => widget.d.outdoor.removeAt(i)),
      ];
}

class _KamersScherm extends StatefulWidget {
  final WwsOnzDossier d;
  const _KamersScherm(this.d);
  @override
  State<_KamersScherm> createState() => _KamersState();
}

class _KamersState extends _LijstSchermState<_KamersScherm> {
  @override
  String get titel => 'Kamers';
  @override
  int get aantal => widget.d.units.length;
  @override
  void voegToe() =>
      widget.d.units.add(WwsOnzKamer(naam: 'Kamer ${widget.d.units.length + 1}'));
  @override
  List<Widget> bouwItems() => [
        for (var i = 0; i < widget.d.units.length; i++)
          kamerEditor(widget.d.units[i], i, () => widget.d.units.removeAt(i)),
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Voorziening-rij met aantal-teller (zelfde stijl als de zelfstandige WWS)
// ─────────────────────────────────────────────────────────────────────────────

class _VoorzieningRij extends StatelessWidget {
  final String label;
  final int aantal;
  final ValueChanged<int> onChanged;

  const _VoorzieningRij({
    required this.label,
    required this.aantal,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final actief = aantal > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: actief ? const Color(0xFFE7F6EC) : const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: actief ? const Color(0xFFA5D6A7) : const Color(0xFFE4E6EA),
          width: actief ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: actief ? FontWeight.w600 : FontWeight.normal,
                    color: actief ? const Color(0xFF1B5E20) : Colors.black87,
                  ),
            ),
          ),
          _RondeVoorzKnop(
            icon: Icons.remove,
            onTap: actief ? () => onChanged(aantal - 1) : null,
          ),
          Container(
            width: 34,
            alignment: Alignment.center,
            child: Text(
              '$aantal',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: actief ? const Color(0xFF2E7D32) : Colors.black38,
              ),
            ),
          ),
          _RondeVoorzKnop(
            icon: Icons.add,
            onTap: () => onChanged(aantal + 1),
            primair: true,
          ),
        ],
      ),
    );
  }
}

/// Ronde +/- knop voor de voorziening-teller.
class _RondeVoorzKnop extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool primair;

  const _RondeVoorzKnop({
    required this.icon,
    required this.onTap,
    this.primair = false,
  });

  @override
  Widget build(BuildContext context) {
    final actief = onTap != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: !actief
            ? const Color(0xFFECEDEF)
            : primair
                ? const Color(0xFF2E7D32)
                : const Color(0xFFFFFFFF),
        shape: const CircleBorder(),
        elevation: actief ? 1 : 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              icon,
              size: 20,
              color: !actief
                  ? Colors.black26
                  : primair
                      ? Colors.white
                      : const Color(0xFF2E7D32),
            ),
          ),
        ),
      ),
    );
  }
}
