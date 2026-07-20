import 'package:flutter/material.dart';

import '../models/blueprint_entiteit.dart';
import '../services/blueprint_api_service.dart';
import 'instellingen_screen.dart';

/// Eenhedenlijst uit de Blueprint-portefeuille.
class PortefeuilleScherm extends StatefulWidget {
  const PortefeuilleScherm({Key? key}) : super(key: key);

  @override
  State<PortefeuilleScherm> createState() => _PortefeuilleSchermState();
}

class _PortefeuilleSchermState extends State<PortefeuilleScherm> {
  late Future<List<BlueprintEntiteit>> _eenheden;
  String _searchTerm = '';
  bool _isConfigured = false;
  bool _checkingConfig = true;

  @override
  void initState() {
    super.initState();
    _eenheden = Future.value([]);
    _checkCredentialsAndLoad();
  }

  Future<void> _checkCredentialsAndLoad() async {
    try {
      final config = await BlueprintApiService.loadConfig();
      if (!mounted) return;
      setState(() {
        _isConfigured = config.hasCredentials;
        _checkingConfig = false;
      });
      if (config.hasCredentials) {
        _loadEenheden();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isConfigured = false;
        _checkingConfig = false;
      });
    }
  }

  void _loadEenheden() {
    setState(() {
      _eenheden = BlueprintApiService.getEntiteiten(
        search: _searchTerm.isEmpty ? null : _searchTerm,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mijn eenheden'),
        elevation: 0,
      ),
      body: _checkingConfig
          ? const Center(child: CircularProgressIndicator())
          : !_isConfigured
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Blueprint Data niet ingesteld',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Configureer je Blueprint Data credentials in Instellingen.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const InstellingenScreen(),
                              ),
                            ).then((_) {
                              _checkCredentialsAndLoad();
                            });
                          },
                          icon: const Icon(Icons.settings),
                          label: const Text('Open Instellingen'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Zoekbalk
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Zoek op adres...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixIcon: _searchTerm.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() => _searchTerm = '');
                                    _loadEenheden();
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          setState(() => _searchTerm = val);
                          _loadEenheden();
                        },
                      ),
                    ),
                    // Lijst
                    Expanded(
                      child: FutureBuilder<List<BlueprintEntiteit>>(
                        future: _eenheden,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            final err = snapshot.error;
                            if (err is BlueprintApiException && err.status == 401) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    const Text('Niet ingelogd'),
                                    const SizedBox(height: 8),
                                    Text(
                                      err.message,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return Center(
                              child: Text('Fout: ${snapshot.error}'),
                            );
                          }

                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      _searchTerm.isEmpty
                          ? 'Geen eenheden gevonden'
                          : 'Geen resultaten',
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final e = items[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text(e.titel),
                        subtitle: Text('${e.adres}, ${e.plaats}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (e.label != null)
                              _LabelBadge(label: e.label!),
                            if (e.wwsPunten != null)
                              Text(
                                '${e.wwsPunten} ptn',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                        onTap: () => _openDetail(context, e.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, int id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerbeterScherm(entiteitId: id),
      ),
    );
  }
}

/// Energielabel-badge.
class _LabelBadge extends StatelessWidget {
  final String label;

  const _LabelBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = _labelColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }

  Color _labelColor(String l) {
    const mapping = {
      'A++++': Color(0xFF2E7D32),
      'A+++': Color(0xFF388E3C),
      'A++': Color(0xFF4CAF50),
      'A+': Color(0xFF7CB342),
      'A': Color(0xFFC0CA33),
      'B': Color(0xFFFDD835),
      'C': Color(0xFFFF9800),
      'D': Color(0xFFFF6F00),
      'E': Color(0xFFE65100),
      'F': Color(0xFFD84315),
      'G': Color(0xFFC62828),
    };
    return mapping[l] ?? Colors.grey;
  }
}

/// Verbeterscherm met schuifjes.
class VerbeterScherm extends StatefulWidget {
  final int entiteitId;

  const VerbeterScherm({Key? key, required this.entiteitId}) : super(key: key);

  @override
  State<VerbeterScherm> createState() => _VerbeterSchermState();
}

class _VerbeterSchermState extends State<VerbeterScherm> {
  late Future<BlueprintEntiteitDetail> _detail;
  BlueprintEntiteitDetail? _currentDetail;
  BlueprintRekenResultaat? _resultaat;
  bool _calculating = false;
  Map<String, double> _schuifjes = {};
  String? _notitie;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  void _loadDetail() {
    setState(() {
      _detail = BlueprintApiService.getEntiteit(widget.entiteitId).then((d) {
        _currentDetail = d;
        return d;
      });
    });
  }

  Map<String, dynamic> _buildScenario() {
    if (_currentDetail?.geb == null) {
      return {
        'vlakken': [],
        'ramen': [],
        'vloeren': [],
        'qv10': 0.7,
      };
    }

    final geb = _currentDetail!.geb!;
    final vlakkenList = <Map<String, dynamic>>[];
    final ramenList = <Map<String, dynamic>>[];
    final vloeren = <Map<String, dynamic>>[];

    // Vlakken (muren, daken, vloeren)
    for (var i = 0; i < geb.vlakken.length; i++) {
      final vlak = geb.vlakken[i];
      final rcNaar = _schuifjes['vlak_$i'] ?? vlak.rcNaar ?? vlak.rcVan;
      vlakkenList.add({
        'A': vlak.a,
        'rc_van': vlak.rcVan,
        'rc_naar': rcNaar,
      });
    }

    // Ramen
    for (var i = 0; i < geb.ramen.length; i++) {
      final raam = geb.ramen[i];
      final uNaar = _schuifjes['raam_$i'] ?? raam.uNaar ?? raam.uVan;
      final gNaar = _schuifjes['raam_g_$i'] ?? raam.gNaar;
      ramenList.add({
        'A': raam.a,
        'u_van': raam.uVan,
        'u_naar': uNaar,
        if (gNaar != null) 'g_naar': gNaar,
      });
    }

    return {
      'vlakken': vlakkenList,
      'ramen': ramenList,
      'vloeren': vloeren,
      'qv10': _schuifjes['qv10'] ?? 0.7,
    };
  }

  Future<void> _calculateScenario() async {
    setState(() => _calculating = true);
    try {
      final scenario = _buildScenario();
      final result = await BlueprintApiService.calculateReken(
        entiteitId: widget.entiteitId,
        scenario: scenario,
      );
      setState(() => _resultaat = result);

      if (mounted && _resultaat!.ongematcht > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_resultaat!.ongematcht} schuif(jes) konden niet matchen'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij rekenen: $e')),
      );
    } finally {
      setState(() => _calculating = false);
    }
  }

  Future<void> _saveScenario() async {
    try {
      final scenario = _buildScenario();
      Map<String, dynamic>? resultaat;
      if (_resultaat != null) {
        final epData = _resultaat!.ep2['scenario'] as Map<String, dynamic>?;
        if (epData != null) {
          resultaat = {
            'label_na': _labelFromEp2(epData['ep2'] as num? ?? 0),
            'ep2_na': epData['ep2'],
          };
        }
      }

      await BlueprintApiService.saveScenario(
        entiteitId: widget.entiteitId,
        scenario: scenario,
        resultaat: resultaat,
        notitie: _notitie,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Advies opgeslagen!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij opslaan: $e')),
      );
    }
  }

  String _labelFromEp2(num ep2Val) {
    if (ep2Val <= 50) return 'A++++';
    if (ep2Val <= 75) return 'A+++';
    if (ep2Val <= 100) return 'A++';
    if (ep2Val <= 130) return 'A+';
    if (ep2Val <= 150) return 'A';
    if (ep2Val <= 180) return 'B';
    if (ep2Val <= 220) return 'C';
    if (ep2Val <= 270) return 'D';
    if (ep2Val <= 330) return 'E';
    if (ep2Val <= 430) return 'F';
    return 'G';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verbeteren'),
      ),
      body: FutureBuilder<BlueprintEntiteitDetail>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final err = snapshot.error;
            final isBlueprintError = err is BlueprintApiException;
            final isAuthError = isBlueprintError && err.status == 401;
            final is404 = isBlueprintError && err.status == 404;
            
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isAuthError ? Icons.lock_outline : Icons.error_outline,
                      size: 64,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isAuthError
                          ? 'Niet ingelogd'
                          : is404
                              ? 'Eenheid niet gevonden'
                              : 'Kan details niet laden',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isBlueprintError ? err.message : err.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    if (isAuthError)
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Instellingen openen'),
                      )
                    else
                      ElevatedButton(
                        onPressed: _loadDetail,
                        child: const Text('Opnieuw proberen'),
                      ),
                  ],
                ),
              ),
            );
          }

          final detail = snapshot.data;
          if (detail == null) return const SizedBox();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.titel,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${detail.adres}, ${detail.plaats}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      // Huidge stats
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (detail.label != null)
                            _StatKaart(label: 'Label', waarde: detail.label!),
                          if (detail.ep2 != null)
                            _StatKaart(label: 'EP2', waarde: detail.ep2!),
                          if (detail.wwsPunten != null)
                            _StatKaart(label: 'WWS', waarde: detail.wwsPunten!),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Geometrie-info
              if (detail.geb != null) ...[
                _SectionHeader('Gebouw'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow('Oppervlakte', '${detail.geb!.ag.toStringAsFixed(1)} m²'),
                        _InfoRow('Vlakken', '${detail.geb!.vlakken.length}'),
                        _InfoRow('Ramen', '${detail.geb!.ramen.length}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Schuifjes (vlakken)
              if (detail.geb != null && detail.geb!.vlakken.isNotEmpty) ...[
                _SectionHeader('Verbeteringen per vlak'),
                ...detail.geb!.vlakken.asMap().entries.map((e) {
                  final i = e.key;
                  final v = e.value;
                  return _VlakSchuif(
                    vlak: v,
                    index: i,
                    onChanged: (rcNaar) {
                      setState(() {
                        _schuifjes['vlak_$i'] = rcNaar;
                      });
                    },
                  );
                }),
                const SizedBox(height: 16),
              ],

              // Schuifjes (ramen)
              if (detail.geb != null && detail.geb!.ramen.isNotEmpty) ...[
                _SectionHeader('Ramen verbeteren'),
                ...detail.geb!.ramen.asMap().entries.map((e) {
                  final i = e.key;
                  final r = e.value;
                  return _RaamSchuif(
                    raam: r,
                    index: i,
                    onUChanged: (uNaar) {
                      setState(() {
                        _schuifjes['raam_$i'] = uNaar;
                      });
                    },
                    onGChanged: (gNaar) {
                      setState(() {
                        _schuifjes['raam_g_$i'] = gNaar;
                      });
                    },
                  );
                }),
                const SizedBox(height: 16),
              ],

              // Bereken-knop
              ElevatedButton.icon(
                onPressed: _calculating ? null : _calculateScenario,
                icon: _calculating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.calculate),
                label: const Text('Doorrekenen'),
              ),
              const SizedBox(height: 16),

              // QV10-invoer (ventilatie)
              if (detail.qv10 != null) ...[
                _SectionHeader('Ventilatie (QV10)'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Huidos: ${detail.qv10!.toStringAsFixed(2)} m³/(h·m²)',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Nieuwe QV10 (m³/h·m²)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (val) {
                            final qv = double.tryParse(val);
                            if (qv != null) {
                              setState(() => _schuifjes['qv10'] = qv);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Resultaat
              if (_resultaat != null) ...[
                _SectionHeader('Resultaat'),
                _ResultaatCard(result: _resultaat!),
                const SizedBox(height: 16),

                // Notitie
                TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Notitie (optioneel): bijv. "Spouw + HR++ ramen + vloerisolatie"',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (val) => _notitie = val,
                ),
                const SizedBox(height: 16),

                // Opslaan-knop
                ElevatedButton.icon(
                  onPressed: _saveScenario,
                  icon: const Icon(Icons.save),
                  label: const Text('Advies opslaan & verzenden'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Schuif voor één vlak (muur/dak/vloer).
class _VlakSchuif extends StatefulWidget {
  final BlueprintVlak vlak;
  final int index;
  final Function(double) onChanged;

  const _VlakSchuif({
    required this.vlak,
    required this.index,
    required this.onChanged,
  });

  @override
  State<_VlakSchuif> createState() => _VlakSchuifState();
}

class _VlakSchuifState extends State<_VlakSchuif> {
  late double _rcNaar;

  @override
  void initState() {
    super.initState();
    _rcNaar = widget.vlak.rcNaar ?? widget.vlak.rcVan;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.vlak.naam} (${widget.vlak.a.toStringAsFixed(1)} m²)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'U-waarde (W/m²K)',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Van: ${widget.vlak.rcVan.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Naar: ${_rcNaar.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Slider(
              value: _rcNaar,
              min: 0.1,
              max: 5.0,
              divisions: 49,
              onChanged: (val) {
                setState(() => _rcNaar = val);
                widget.onChanged(val);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Schuif voor ramen.
class _RaamSchuif extends StatefulWidget {
  final BlueprintRaam raam;
  final int index;
  final Function(double) onUChanged;
  final Function(double) onGChanged;

  const _RaamSchuif({
    required this.raam,
    required this.index,
    required this.onUChanged,
    required this.onGChanged,
  });

  @override
  State<_RaamSchuif> createState() => _RaamSchuifState();
}

class _RaamSchuifState extends State<_RaamSchuif> {
  late double _uNaar;
  late double _gNaar;

  @override
  void initState() {
    super.initState();
    _uNaar = widget.raam.uNaar ?? widget.raam.uVan;
    _gNaar = widget.raam.gNaar ?? 0.5;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Raam ${widget.index + 1} (${widget.raam.a.toStringAsFixed(1)} m²)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            // U-waarde schuif
            Text(
              'U-waarde glas (W/m²K)',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Van: ${widget.raam.uVan.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
                const Spacer(),
                Text('Naar: ${_uNaar.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
              ],
            ),
            Slider(
              value: _uNaar,
              min: 0.5,
              max: 6.0,
              divisions: 55,
              onChanged: (val) {
                setState(() => _uNaar = val);
                widget.onUChanged(val);
              },
            ),
            const SizedBox(height: 12),
            // G-factor (zonnefactor)
            Text(
              'G-factor (zonnewarmte)',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('0.0 (weinig zon)', style: TextStyle(fontSize: 11)),
                const Spacer(),
                Text(_gNaar.toStringAsFixed(2), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                const Spacer(),
                const Text('1.0 (veel zon)', style: TextStyle(fontSize: 11)),
              ],
            ),
            Slider(
              value: _gNaar,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              onChanged: (val) {
                setState(() => _gNaar = val);
                widget.onGChanged(val);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Resultaatkaart.
class _ResultaatCard extends StatelessWidget {
  final BlueprintRekenResultaat result;

  const _ResultaatCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Berekend resultaat:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (result.ongematcht > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Waarschuwing: ${'${result.ongematcht} schuif(jes)'} konden niet worden gematched',
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            _InfoRow('Nulmeting EP2', result.nul['ep2']?.toString() ?? '-'),
            _InfoRow('Scenario EP2', result.scenario['ep2']?.toString() ?? '-'),
            if (result.ep2['scenario'] != null)
              _InfoRow(
                'Nieuw label',
                result.ep2['scenario']['label']?.toString() ?? '-',
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
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
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          waarde,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String waarde;

  const _InfoRow(this.label, this.waarde);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            waarde,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
