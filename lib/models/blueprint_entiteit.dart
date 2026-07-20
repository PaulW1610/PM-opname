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
        id: json['id'] as int,
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
        id: json['id'] as int,
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
        bouwjaar: json['bouwjaar'] as int?,
        ag: (json['ag'] as num?)?.toDouble(),
        qv10: (json['qv10'] as num?)?.toDouble(),
        behoefte: (json['behoefte'] as num?)?.toDouble(),
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

    return BlueprintGeometrie(
      ag: (json['ag'] as num? ?? 0).toDouble(),
      vlakken: vlakkenRaw
          .whereType<Map<String, dynamic>>()
          .map(BlueprintVlak.fromJson)
          .toList(),
      ramen: ramenRaw
          .whereType<Map<String, dynamic>>()
          .map(BlueprintRaam.fromJson)
          .toList(),
    );
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
    a: (json['A'] as num? ?? 0).toDouble(),
    rcVan: (json['rc'] as num? ?? json['rc_van'] as num? ?? 0).toDouble(),
    rcNaar: (json['rc_naar'] as num?)?.toDouble(),
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
  final double a;
  final double uVan;
  final double? uNaar;
  final double? gNaar;

  const BlueprintRaam({
    required this.a,
    required this.uVan,
    this.uNaar,
    this.gNaar,
  });

  factory BlueprintRaam.fromJson(Map<String, dynamic> json) => BlueprintRaam(
    a: (json['A'] as num? ?? 0).toDouble(),
    uVan: (json['u'] as num? ?? json['u_van'] as num? ?? 0).toDouble(),
    uNaar: (json['u_naar'] as num?)?.toDouble(),
    gNaar: (json['g_naar'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
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
        ongematcht: json['ongematcht'] as int? ?? 0,
        vabi: json['vabi'] as Map<String, dynamic>?,
      );
}
