/// Gebouwtype-keuze voor het opnameformulier (twee getrapte keuzelijsten:
/// eerst de categorie, dan het type). De types + BuildingCategory-codes komen
/// uit Pauls Excel "Variabelen vabi template".
///
/// Twee verschillende nummersystemen:
/// * [buildingCategory] (+ [sub]) = de **EP-Online BuildingCategory** +
///   supplement uit de Excel. Die staat in de EP-Online-exportlaag van een
///   monitorbestand, NIET in het VABI-projectbestand dat de app maakt.
/// * [objectClassificatie] = de **VABI-interne** velden in het
///   `ObjectClassificatie`-blok van de import-template (tagnaam → waarde). Dit
///   is wat de app in de XML zet: `Gebouwtype`, `Subtype` en `Ligging`.
///   `Daktype` blijft op de template-standaard (-1): dat hangt van het dak van
///   de woning af, niet van het gebouwtype, en de adviseur bevestigt het in
///   VABI.
///
/// De codes zijn geoogst uit 148 echte monitorbestanden door
/// (BuildingCategory, BuildingCategorySupplement) ↔ ObjectClassificatie te
/// paren (13 aug 2026). Gebouwtype = 0 eengezins / 1 appartement;
/// Subtype = 0 vrijstaand / 1 kop-eind-hoek / 2 tussen; Ligging (appartement) =
/// 2 bovenste / 1 tussen / 0 onderste (eengezins: -1).
class GebouwtypeOptie {
  final String categorie;
  final String type;
  final int buildingCategory;
  final int? sub;

  /// Bekende, per-type vaste ObjectClassificatie-velden (tagnaam → waarde).
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

  static const List<GebouwtypeOptie> opties = <GebouwtypeOptie>[
    // --- Eengezinswoning (Gebouwtype 0, Ligging -1) ---
    GebouwtypeOptie(
      categorie: eengezins,
      type: 'Vrijstaand',
      buildingCategory: 1,
      objectClassificatie: <String, int>{'Gebouwtype': 0, 'Subtype': 0, 'Ligging': -1},
    ),
    GebouwtypeOptie(
      categorie: eengezins,
      type: 'Kop eind of Hoek',
      buildingCategory: 2,
      objectClassificatie: <String, int>{'Gebouwtype': 0, 'Subtype': 1, 'Ligging': -1},
    ),
    GebouwtypeOptie(
      categorie: eengezins,
      type: 'Tussenligging',
      buildingCategory: 3,
      objectClassificatie: <String, int>{'Gebouwtype': 0, 'Subtype': 2, 'Ligging': -1},
    ),
    GebouwtypeOptie(
      categorie: eengezins,
      type: 'Twee onder 1 kap',
      buildingCategory: 4,
      // Geen monitorbestand van dit type in de dataset; Subtype nog onbekend.
      // Gebouwtype is wel zeker grondgebonden (0).
      objectClassificatie: <String, int>{'Gebouwtype': 0, 'Ligging': -1},
    ),
    // --- Woning in een appartementencomplex (Gebouwtype 1) ---
    // Subtype: 1 = kop/hoek, 2 = tussen. Ligging: 0 onderste / 1 tussen / 2 bovenste.
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Kop eind of Hoek — onderste verdieping',
      buildingCategory: 7,
      sub: 3,
      // Sub 3 niet in de dataset; Ligging 0 volgt uit het patroon (onderste).
      objectClassificatie: <String, int>{'Gebouwtype': 1, 'Subtype': 1, 'Ligging': 0},
    ),
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Kop eind of Hoek — tussen verdieping',
      buildingCategory: 7,
      sub: 2,
      objectClassificatie: <String, int>{'Gebouwtype': 1, 'Subtype': 1, 'Ligging': 1},
    ),
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Kop eind of Hoek — bovenste',
      buildingCategory: 7,
      sub: 1,
      objectClassificatie: <String, int>{'Gebouwtype': 1, 'Subtype': 1, 'Ligging': 2},
    ),
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Tussenligging — tussenligging',
      buildingCategory: 7,
      sub: 5,
      objectClassificatie: <String, int>{'Gebouwtype': 1, 'Subtype': 2, 'Ligging': 1},
    ),
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Tussenligging — bovenste',
      buildingCategory: 7,
      sub: 4,
      objectClassificatie: <String, int>{'Gebouwtype': 1, 'Subtype': 2, 'Ligging': 2},
    ),
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Tussenligging — onderste verdieping',
      buildingCategory: 7,
      sub: 6,
      objectClassificatie: <String, int>{'Gebouwtype': 1, 'Subtype': 2, 'Ligging': 0},
    ),
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Tussenligging — onderste verdieping met dak',
      buildingCategory: 7,
      sub: 7,
      // Sub 7 niet in de dataset; zelfde als onderste (1/2/0). "Met dak" zet in
      // VABI vermoedelijk ook een Daktype — die laten we aan de adviseur.
      objectClassificatie: <String, int>{'Gebouwtype': 1, 'Subtype': 2, 'Ligging': 0},
    ),
  ];

  static List<GebouwtypeOptie> voorCategorie(String categorie) => opties
      .where((o) => o.categorie == categorie)
      .toList(growable: false);
}
