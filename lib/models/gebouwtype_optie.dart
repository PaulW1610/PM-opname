/// Gebouwtype-keuze voor het opnameformulier (twee getrapte keuzelijsten:
/// eerst de categorie, dan het type). De types + BuildingCategory-codes komen
/// uit Pauls Excel "Variabelen vabi template".
///
/// Twee verschillende nummersystemen:
/// * [buildingCategory] (+ [sub]) = de **EP-Online BuildingCategory** uit de
///   Excel. Die staat in de EP-Online-exportlaag van een monitorbestand, NIET
///   in het VABI-projectbestand dat de app maakt.
/// * [objectClassificatie] = de **VABI-interne** velden in het
///   `ObjectClassificatie`-blok van de import-template. De app schrijft alleen
///   de velden die per gebouwtype VAST zijn: `Gebouwtype` en `Subtype`.
///   `Ligging` en `Daktype` variëren per woning (verdieping, daktype) en worden
///   NIET hier gezet — die blijven op de template-standaard (-1), de adviseur
///   bevestigt ze in VABI.
///
/// De Gebouwtype/Subtype-codes zijn geoogst uit 147 echte monitorbestanden
/// (BuildingCategory ↔ ObjectClassificatie), 13 aug 2026:
///   BC1 vrijstaand → 0/0 · BC2 kop-eind/hoek → 0/1 · BC3 tussen → 0/2 ·
///   BC7 appartement → 1/1 (hoek) of 1/2 (tussen).
class GebouwtypeOptie {
  final String categorie;
  final String type;
  final int buildingCategory;
  final int? sub;

  /// Bekende, per-type vaste ObjectClassificatie-velden (tagnaam → waarde).
  /// Bevat `Gebouwtype` en `Subtype`; leeg als (nog) onbekend.
  final Map<String, int> objectClassificatie;

  const GebouwtypeOptie({
    required this.categorie,
    required this.type,
    required this.buildingCategory,
    this.sub,
    this.objectClassificatie = const <String, int>{},
  });

  String get id =>
      sub == null ? '$categorie|$type' : '$categorie|$type|$sub';

  String get weergave {
    final buffer = StringBuffer('$categorie — $type');
    buffer.write(' (BuildingCategory $buildingCategory');
    if (sub != null) {
      buffer.write(', sub $sub');
    }
    buffer.write(')');
    return buffer.toString();
  }

  static const String eengezins = 'Eengezinswoning';
  static const String appartement = 'Woning in een appartementencomplex';

  static const List<String> categorieen = <String>[eengezins, appartement];

  static const Map<String, int> _grondgebonden0 = <String, int>{
    'Gebouwtype': 0,
    'Subtype': 0,
  };
  static const Map<String, int> _grondgebonden1 = <String, int>{
    'Gebouwtype': 0,
    'Subtype': 1,
  };
  static const Map<String, int> _grondgebonden2 = <String, int>{
    'Gebouwtype': 0,
    'Subtype': 2,
  };
  static const Map<String, int> _appHoek = <String, int>{
    'Gebouwtype': 1,
    'Subtype': 1,
  };
  static const Map<String, int> _appTussen = <String, int>{
    'Gebouwtype': 1,
    'Subtype': 2,
  };

  static const List<GebouwtypeOptie> opties = <GebouwtypeOptie>[
    // --- Eengezinswoning ---
    GebouwtypeOptie(
      categorie: eengezins,
      type: 'Vrijstaand',
      buildingCategory: 1,
      objectClassificatie: _grondgebonden0,
    ),
    GebouwtypeOptie(
      categorie: eengezins,
      type: 'Kop eind of Hoek',
      buildingCategory: 2,
      objectClassificatie: _grondgebonden1,
    ),
    GebouwtypeOptie(
      categorie: eengezins,
      type: 'Tussenligging',
      buildingCategory: 3,
      objectClassificatie: _grondgebonden2,
    ),
    GebouwtypeOptie(
      categorie: eengezins,
      type: 'Twee onder 1 kap',
      buildingCategory: 4,
      // Geen monitorbestand van dit type in de dataset; Subtype nog onbekend.
      // Gebouwtype is wel zeker grondgebonden (0).
      objectClassificatie: <String, int>{'Gebouwtype': 0},
    ),
    // --- Woning in een appartementencomplex (BuildingCategory 7) ---
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Kop eind of Hoek — onderste verdieping',
      buildingCategory: 7,
      sub: 3,
      objectClassificatie: _appHoek,
    ),
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Kop eind of Hoek — tussen verdieping',
      buildingCategory: 7,
      sub: 2,
      objectClassificatie: _appHoek,
    ),
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Kop eind of Hoek — bovenste',
      buildingCategory: 7,
      sub: 1,
      objectClassificatie: _appHoek,
    ),
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Tussenligging — tussenligging',
      buildingCategory: 7,
      sub: 5,
      objectClassificatie: _appTussen,
    ),
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Tussenligging — bovenste',
      buildingCategory: 7,
      sub: 4,
      objectClassificatie: _appTussen,
    ),
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Tussenligging — onderste verdieping',
      buildingCategory: 7,
      sub: 6,
      objectClassificatie: _appTussen,
    ),
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Tussenligging — onderste verdieping met dak',
      buildingCategory: 7,
      sub: 7,
      objectClassificatie: _appTussen,
    ),
  ];

  static List<GebouwtypeOptie> voorCategorie(String categorie) => opties
      .where((o) => o.categorie == categorie)
      .toList(growable: false);
}
