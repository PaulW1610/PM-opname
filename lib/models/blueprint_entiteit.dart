/// Zet een JSON-waarde tolerant om naar int (accepteert int, num of tekst).
///
/// De website geeft sommige numerieke velden als tekst terug (bv. "1980");
/// een harde `as int`-cast zou daarop crashen.
int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}

/// Zet een JSON-waarde tolerant om naar double (accepteert num of tekst,
/// met komma of punt als decimaalteken).
double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().trim().replaceAll(',', '.'));
}

/// Eenheid in de Blueprint-portefeuille (minimaal voor de lijst).
class BlueprintEntiteit {
  final int id;
  final String titel;
  final String adres;
  final String plaats;
  final String postcode;
  final String? label;
  final String? ep2;
  final String? wwsPunten;
  final String? huurMax;
  final String? woz;
  final String? updatedAt;
  final String url;
  final bool heeftXml;

  const BlueprintEntiteit({
    required this.id,
    required this.titel,
    required this.adres,
    required this.plaats,
    required this.postcode,
    this.label,
    this.ep2,
    this.wwsPunten,
    this.huurMax,
    this.woz,
    this.updatedAt,
    required this.url,
    this.heeftXml = false,
  });

  factory BlueprintEntiteit.fromJson(Map<String, dynamic> json) =>
      BlueprintEntiteit(
        id: _toInt(json['id']) ?? 0,
        titel: json['titel'] as String? ?? '',
        adres: json['adres'] as String? ?? '',
        plaats: json['plaats'] as String? ?? '',
        postcode: json['postcode'] as String? ?? '',
        label: json['label'] as String?,
        ep2: json['ep2'] as String?,
        wwsPunten: json['wws_punten'] as String?,
        huurMax: json['huur_max'] as String?,
        woz: json['woz'] as String?,
        updatedAt: json['updated_at'] as String?,
        url: json['url'] as String? ?? '',
        heeftXml: json['heeft_xml'] as bool? ?? false,
      );
}

/// Volledig detail van een eenheid met geometrie.
class BlueprintEntiteitDetail extends BlueprintEntiteit {
  final int? bouwjaar;
  final double? ag;
  final double? qv10;
  final double? behoefte;
  final String? huurActueel;
  final String? ververst;
  final BlueprintGeometrie? geb;
  final BlueprintKosten? kosten;
  final BlueprintScenario? scenario;

  const BlueprintEntiteitDetail({
    required int id,
    required String titel,
    required String adres,
    required String plaats,
    required String postcode,
    String? label,
    String? ep2,
    String? wwsPunten,
    String? huurMax,
    String? woz,
    String? updatedAt,
    required String url,
    bool heeftXml = false,
    this.bouwjaar,
    this.ag,
    this.qv10,
    this.behoefte,
    this.huurActueel,
    this.ververst,
    this.geb,
    this.kosten,
    this.scenario,
  }) : super(
    id: id,
    titel: titel,
    adres: adres,
    plaats: plaats,
    postcode: postcode,
    label: label,
    ep2: ep2,
    wwsPunten: wwsPunten,
    huurMax: huurMax,
    woz: woz,
    updatedAt: updatedAt,
    url: url,
    heeftXml: heeftXml,
  );

  factory BlueprintEntiteitDetail.fromJson(Map<String, dynamic> json) =>
      BlueprintEntiteitDetail(
        id: _toInt(json['id']) ?? 0,
        titel: json['titel'] as String? ?? '',
        adres: json['adres'] as String? ?? '',
        plaats: json['plaats'] as String? ?? '',
        postcode: json['postcode'] as String? ?? '',
        label: json['label'] as String?,
        ep2: json['ep2'] as String?,
        wwsPunten: json['wws_punten'] as String?,
        huurMax: json['huur_max'] as String?,
        woz: json['woz'] as String?,
        updatedAt: json['updated_at'] as String?,
        url: json['url'] as String? ?? '',
        heeftXml: json['heeft_xml'] as bool? ?? false,
        bouwjaar: _toInt(json['bouwjaar']),
        ag: _toDouble(json['ag']),
        qv10: _toDouble(json['qv10']),
        behoefte: _toDouble(json['behoefte']),
        huurActueel: json['huur_actueel'] as String?,
        ververst: json['ververst'] as String?,
        geb: json['geb'] != null
            ? BlueprintGeometrie.fromJson(json['geb'] as Map<String, dynamic>)
            : null,
        kosten: json['kosten'] != null
            ? BlueprintKosten.fromJson(json['kosten'] as Map<String, dynamic>)
            : null,
        scenario: json['scenario'] != null
            ? BlueprintScenario.fromJson(
                json['scenario'] as Map<String, dynamic>)
            : null,
      );
}

/// Geometrie-object met vlakken en ramen.
class BlueprintGeometrie {
  final double ag;
  final List<BlueprintVlak> vlakken;
  final List<BlueprintRaam> ramen;

  const BlueprintGeometrie({
    required this.ag,
    this.vlakken = const [],
    this.ramen = const [],
  });

  factory BlueprintGeometrie.fromJson(Map<String, dynamic> json) {
    final vlakkenRaw = json['vlakken'] as List<dynamic>? ?? [];
    final ramenRaw = json['ramen'] as List<dynamic>? ?? [];

    final vlakken = <BlueprintVlak>[];
    final ramen = <BlueprintRaam>[];

    // Ramen kunnen als aparte `ramen`-lijst komen, óf (contract §3.7) gemengd
    // in `vlakken` staan als {naam:"raam", A, U}. Splits ze eruit zodat de
    // glastype-bundeling werkt en ramen niet als losse vlakken verschijnen.
    for (final e in ramenRaw.whereType<Map<String, dynamic>>()) {
      ramen.add(BlueprintRaam.fromJson(e));
    }
    for (final e in vlakkenRaw.whereType<Map<String, dynamic>>()) {
      if (_isRaam(e)) {
        ramen.add(BlueprintRaam.fromJson(e));
      } else {
        vlakken.add(BlueprintVlak.fromJson(e));
      }
    }

    return BlueprintGeometrie(
      ag: _toDouble(json['ag']) ?? 0,
      vlakken: vlakken,
      ramen: ramen,
    );
  }

  /// Herkent of een geometrie-item een raam is: naam "raam"/"glas", of een
  /// U-waarde zonder Rc-waarde.
  static bool _isRaam(Map<String, dynamic> e) {
    final naam = (e['naam'] as String? ?? '').toLowerCase();
    if (naam.contains('raam') ||
        naam.contains('glas') ||
        naam.contains('beglazing')) {
      return true;
    }
    final hasU = e.containsKey('U') || e.containsKey('u') || e.containsKey('u_van');
    final hasRc = e.containsKey('rc') || e.containsKey('rc_van');
    return hasU && !hasRc;
  }

  Map<String, dynamic> toJson() => {
    'ag': ag,
    'vlakken': vlakken.map((v) => v.toJson()).toList(),
    'ramen': ramen.map((r) => r.toJson()).toList(),
  };
}

/// Vlak (muur, dak, vloer) met oppervlakte en warmtedoorgangscoëfficiënt.
class BlueprintVlak {
  final String naam;
  final double a;
  final double rcVan;
  final double? rcNaar;

  const BlueprintVlak({
    required this.naam,
    required this.a,
    required this.rcVan,
    this.rcNaar,
  });

  factory BlueprintVlak.fromJson(Map<String, dynamic> json) => BlueprintVlak(
    naam: json['naam'] as String? ?? '',
    a: _toDouble(json['A']) ?? 0,
    rcVan: _toDouble(json['rc']) ?? _toDouble(json['rc_van']) ?? 0,
    rcNaar: _toDouble(json['rc_naar']),
  );

  Map<String, dynamic> toJson() => {
    'naam': naam,
    'A': a,
    'rc_van': rcVan,
    if (rcNaar != null) 'rc_naar': rcNaar,
  };
}

/// Raam met oppervlakte en U-waarde.
class BlueprintRaam {
  final String naam;
  final double a;
  final double uVan;
  final double? uNaar;
  final double? gNaar;

  const BlueprintRaam({
    this.naam = 'raam',
    required this.a,
    required this.uVan,
    this.uNaar,
    this.gNaar,
  });

  factory BlueprintRaam.fromJson(Map<String, dynamic> json) => BlueprintRaam(
    naam: json['naam'] as String? ?? 'raam',
    a: _toDouble(json['A']) ?? _toDouble(json['a']) ?? 0,
    uVan: _toDouble(json['U']) ??
        _toDouble(json['u']) ??
        _toDouble(json['u_van']) ??
        0,
    uNaar: _toDouble(json['u_naar']),
    gNaar: _toDouble(json['g_naar']),
  );

  Map<String, dynamic> toJson() => {
    'naam': naam,
    'A': a,
    'u_van': uVan,
    if (uNaar != null) 'u_naar': uNaar,
    if (gNaar != null) 'g_naar': gNaar,
  };
}

/// Kostenkengetallen per maatregel.
class BlueprintKosten {
  final Map<String, dynamic> data;

  const BlueprintKosten({required this.data});

  factory BlueprintKosten.fromJson(Map<String, dynamic> json) =>
      BlueprintKosten(data: json);
}

/// Scenario met schuifjes + berekende resultaten.
class BlueprintScenario {
  final Map<String, dynamic> scenario;
  final Map<String, dynamic>? resultaat;
  final String? notitie;
  final String? tijdstip;
  final String? door;

  const BlueprintScenario({
    required this.scenario,
    this.resultaat,
    this.notitie,
    this.tijdstip,
    this.door,
  });

  factory BlueprintScenario.fromJson(Map<String, dynamic> json) =>
      BlueprintScenario(
        scenario: json['scenario'] as Map<String, dynamic>? ?? {},
        resultaat: json['resultaat'] as Map<String, dynamic>?,
        notitie: json['notitie'] as String?,
        tijdstip: json['tijdstip'] as String?,
        door: json['door'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'scenario': scenario,
    if (resultaat != null) 'resultaat': resultaat,
    if (notitie != null) 'notitie': notitie,
  };
}

/// Rekenresultaat (nulmeting vs. scenario).
class BlueprintRekenResultaat {
  final Map<String, dynamic> nul;
  final Map<String, dynamic> scenario;
  final Map<String, dynamic> ep2;
  final int ongematcht;
  final Map<String, dynamic>? vabi;

  const BlueprintRekenResultaat({
    required this.nul,
    required this.scenario,
    required this.ep2,
    this.ongematcht = 0,
    this.vabi,
  });

  factory BlueprintRekenResultaat.fromJson(Map<String, dynamic> json) =>
      BlueprintRekenResultaat(
        nul: json['nul'] as Map<String, dynamic>? ?? {},
        scenario: json['scenario'] as Map<String, dynamic>? ?? {},
        ep2: json['ep2'] as Map<String, dynamic>? ?? {},
        ongematcht: _toInt(json['ongematcht']) ?? 0,
        vabi: json['vabi'] as Map<String, dynamic>?,
      );
}
