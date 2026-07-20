/// Data-model voor de volledige WWS-opname-invoer (POST /bd/v1/wws body).
class WwsBinnenruimte {
  final String type;
  final double m2;
  final bool verwarmd;
  final bool verkoeld;

  const WwsBinnenruimte({
    required this.type,
    required this.m2,
    this.verwarmd = true,
    this.verkoeld = false,
  });

  WwsBinnenruimte copyWith({
    String? type,
    double? m2,
    bool? verwarmd,
    bool? verkoeld,
  }) =>
      WwsBinnenruimte(
        type: type ?? this.type,
        m2: m2 ?? this.m2,
        verwarmd: verwarmd ?? this.verwarmd,
        verkoeld: verkoeld ?? this.verkoeld,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'm2': m2,
        'verwarmd': verwarmd,
        'verkoeld': verkoeld,
      };

  factory WwsBinnenruimte.fromJson(Map<String, dynamic> json) =>
      WwsBinnenruimte(
        type: json['type'] as String? ?? '',
        m2: (json['m2'] as num?)?.toDouble() ?? 0.0,
        verwarmd: json['verwarmd'] as bool? ?? true,
        verkoeld: json['verkoeld'] as bool? ?? false,
      );
}

class WwsBuitenruimte {
  final String type;
  final double m2;

  const WwsBuitenruimte({required this.type, required this.m2});

  WwsBuitenruimte copyWith({String? type, double? m2}) =>
      WwsBuitenruimte(type: type ?? this.type, m2: m2 ?? this.m2);

  Map<String, dynamic> toJson() => {'type': type, 'm2': m2};

  factory WwsBuitenruimte.fromJson(Map<String, dynamic> json) =>
      WwsBuitenruimte(
        type: json['type'] as String? ?? '',
        m2: (json['m2'] as num?)?.toDouble() ?? 0.0,
      );
}

class WwsKenmerk {
  final String kenmerk;
  final int aantal;

  const WwsKenmerk({required this.kenmerk, this.aantal = 1});

  WwsKenmerk copyWith({String? kenmerk, int? aantal}) =>
      WwsKenmerk(
        kenmerk: kenmerk ?? this.kenmerk,
        aantal: aantal ?? this.aantal,
      );

  Map<String, dynamic> toJson() => {'kenmerk': kenmerk, 'aantal': aantal};

  factory WwsKenmerk.fromJson(Map<String, dynamic> json) => WwsKenmerk(
        kenmerk: json['kenmerk'] as String? ?? '',
        aantal: json['aantal'] as int? ?? 1,
      );
}

class WwsOpnameData {
  final List<WwsBinnenruimte> binnenruimtes;
  final List<WwsBuitenruimte> buitenruimtes;
  final List<WwsKenmerk> keukenKenmerken;
  final List<WwsKenmerk> sanitairBasis;
  final List<WwsKenmerk> sanitairExtra;
  final String aanrechtlengte;
  final String energieLabel;
  final String woningtype;
  final int bouwjaar;
  final double wozWaarde;
  final String wozJaar;
  final String wozBron;

  const WwsOpnameData({
    this.binnenruimtes = const [],
    this.buitenruimtes = const [],
    this.keukenKenmerken = const [],
    this.sanitairBasis = const [],
    this.sanitairExtra = const [],
    this.aanrechtlengte = '2 meter of langer',
    this.energieLabel = '',
    this.woningtype = 'Meergezinswoning',
    this.bouwjaar = 0,
    this.wozWaarde = 0.0,
    this.wozJaar = '2026',
    this.wozBron = 'WOZ-beschikking',
  });

  WwsOpnameData copyWith({
    List<WwsBinnenruimte>? binnenruimtes,
    List<WwsBuitenruimte>? buitenruimtes,
    List<WwsKenmerk>? keukenKenmerken,
    List<WwsKenmerk>? sanitairBasis,
    List<WwsKenmerk>? sanitairExtra,
    String? aanrechtlengte,
    String? energieLabel,
    String? woningtype,
    int? bouwjaar,
    double? wozWaarde,
    String? wozJaar,
    String? wozBron,
  }) =>
      WwsOpnameData(
        binnenruimtes: binnenruimtes ?? this.binnenruimtes,
        buitenruimtes: buitenruimtes ?? this.buitenruimtes,
        keukenKenmerken: keukenKenmerken ?? this.keukenKenmerken,
        sanitairBasis: sanitairBasis ?? this.sanitairBasis,
        sanitairExtra: sanitairExtra ?? this.sanitairExtra,
        aanrechtlengte: aanrechtlengte ?? this.aanrechtlengte,
        energieLabel: energieLabel ?? this.energieLabel,
        woningtype: woningtype ?? this.woningtype,
        bouwjaar: bouwjaar ?? this.bouwjaar,
        wozWaarde: wozWaarde ?? this.wozWaarde,
        wozJaar: wozJaar ?? this.wozJaar,
        wozBron: wozBron ?? this.wozBron,
      );

  /// Bouwt de JSON-body voor POST /bd/v1/wws.
  Map<String, dynamic> toApiJson() {
    final body = <String, dynamic>{};
    if (binnenruimtes.isNotEmpty) {
      body['binnenruimtes'] = binnenruimtes.map((r) => r.toJson()).toList();
    }
    if (buitenruimtes.isNotEmpty) {
      body['buitenruimtes'] = buitenruimtes.map((r) => r.toJson()).toList();
    }
    if (keukenKenmerken.isNotEmpty) {
      body['keuken_kenmerken'] =
          keukenKenmerken.map((k) => k.toJson()).toList();
    }
    if (sanitairBasis.isNotEmpty) {
      body['sanitair_basis'] = sanitairBasis.map((k) => k.toJson()).toList();
    }
    if (sanitairExtra.isNotEmpty) {
      body['sanitair_extra'] = sanitairExtra.map((k) => k.toJson()).toList();
    }
    body['aanrechtlengte'] = aanrechtlengte;
    if (energieLabel.isNotEmpty) body['energie_label'] = energieLabel;
    body['woningtype'] = woningtype;
    if (bouwjaar > 0) body['bouwjaar'] = bouwjaar;
    if (wozWaarde > 0) {
      body['woz_waarde'] = wozWaarde;
      body['woz_jaar'] = wozJaar;
      body['woz_bron'] = wozBron;
    }
    return body;
  }

  Map<String, dynamic> toJson() => {
        'binnenruimtes': binnenruimtes.map((r) => r.toJson()).toList(),
        'buitenruimtes': buitenruimtes.map((r) => r.toJson()).toList(),
        'keuken_kenmerken': keukenKenmerken.map((k) => k.toJson()).toList(),
        'sanitair_basis': sanitairBasis.map((k) => k.toJson()).toList(),
        'sanitair_extra': sanitairExtra.map((k) => k.toJson()).toList(),
        'aanrechtlengte': aanrechtlengte,
        'energie_label': energieLabel,
        'woningtype': woningtype,
        'bouwjaar': bouwjaar,
        'woz_waarde': wozWaarde,
        'woz_jaar': wozJaar,
        'woz_bron': wozBron,
      };

  factory WwsOpnameData.fromJson(Map<String, dynamic> json) => WwsOpnameData(
        binnenruimtes: (json['binnenruimtes'] as List<dynamic>? ?? [])
            .map((e) => WwsBinnenruimte.fromJson(e as Map<String, dynamic>))
            .toList(),
        buitenruimtes: (json['buitenruimtes'] as List<dynamic>? ?? [])
            .map((e) => WwsBuitenruimte.fromJson(e as Map<String, dynamic>))
            .toList(),
        keukenKenmerken: (json['keuken_kenmerken'] as List<dynamic>? ?? [])
            .map((e) => WwsKenmerk.fromJson(e as Map<String, dynamic>))
            .toList(),
        sanitairBasis: (json['sanitair_basis'] as List<dynamic>? ?? [])
            .map((e) => WwsKenmerk.fromJson(e as Map<String, dynamic>))
            .toList(),
        sanitairExtra: (json['sanitair_extra'] as List<dynamic>? ?? [])
            .map((e) => WwsKenmerk.fromJson(e as Map<String, dynamic>))
            .toList(),
        aanrechtlengte:
            json['aanrechtlengte'] as String? ?? '2 meter of langer',
        energieLabel: json['energie_label'] as String? ?? '',
        woningtype: json['woningtype'] as String? ?? 'Meergezinswoning',
        bouwjaar: json['bouwjaar'] as int? ?? 0,
        wozWaarde: (json['woz_waarde'] as num?)?.toDouble() ?? 0.0,
        wozJaar: json['woz_jaar'] as String? ?? '2026',
        wozBron: json['woz_bron'] as String? ?? 'WOZ-beschikking',
      );
}
