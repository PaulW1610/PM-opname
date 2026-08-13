/// Gebouwtype-keuze voor het opnameformulier (twee getrapte keuzelijsten:
/// eerst de categorie, dan het type). De codes komen uit Pauls Excel
/// "Variabelen vabi template" (kolom BuildingCategory + sub).
///
/// LET OP — twee verschillende nummersystemen:
/// * [buildingCategory] (+ [sub]) is de **EP-Online BuildingCategory** uit de
///   Excel (1=vrijstaand, 2=kop/hoek, 3=tussen, 4=twee-onder-1-kap,
///   7=appartement met een supplement). Die zit in de EP-Online-exportlaag.
/// * [objectClassificatie] = de **VABI-interne** vier codes
///   `[Gebouwtype, Subtype, Ligging, Daktype]` in het `ObjectClassificatie`-blok
///   van het VABI-projectbestand (= onze import_template.xml). Dít is wat de
///   app in de XML zet. Deze codes zijn NIET gelijk aan de BuildingCategory en
///   moeten per type uit VABI worden afgelezen (dummy-export → aflezen). Zolang
///   ze onbekend zijn is [objectClassificatie] `null` en laat de app het
///   `ObjectClassificatie`-blok ongemoeid (blijft -1, adviseur kiest in VABI).
class GebouwtypeOptie {
  final String categorie;
  final String type;
  final int buildingCategory;
  final int? sub;

  /// `[Gebouwtype, Subtype, Ligging, Daktype]` of `null` als nog niet
  /// geverifieerd uit VABI.
  final List<int>? objectClassificatie;

  const GebouwtypeOptie({
    required this.categorie,
    required this.type,
    required this.buildingCategory,
    this.sub,
    this.objectClassificatie,
  });

  /// Unieke sleutel om de keuze te bewaren/terug te vinden.
  String get id => sub == null
      ? '$categorie|$type'
      : '$categorie|$type|$sub';

  /// Leesbare regel voor JSON/PDF-bijlage.
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

  /// Alle keuzes. ObjectClassificatie alleen ingevuld waar geverifieerd:
  /// * Tussenligging eengezins → 0/2/-1/0 (uit een echt monitorbestand).
  /// De overige zijn nog te oogsten uit VABI.
  static const List<GebouwtypeOptie> opties = <GebouwtypeOptie>[
    // --- Eengezinswoning ---
    GebouwtypeOptie(
      categorie: eengezins,
      type: 'Vrijstaand',
      buildingCategory: 1,
    ),
    GebouwtypeOptie(
      categorie: eengezins,
      type: 'Kop eind of Hoek',
      buildingCategory: 2,
    ),
    GebouwtypeOptie(
      categorie: eengezins,
      type: 'Tussenligging',
      buildingCategory: 3,
      objectClassificatie: <int>[0, 2, -1, 0],
    ),
    GebouwtypeOptie(
      categorie: eengezins,
      type: 'Twee onder 1 kap',
      buildingCategory: 4,
    ),
    // --- Woning in een appartementencomplex (allemaal BuildingCategory 7) ---
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Kop eind of Hoek — onderste verdieping',
      buildingCategory: 7,
      sub: 3,
    ),
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Kop eind of Hoek — tussen verdieping',
      buildingCategory: 7,
      sub: 2,
    ),
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Kop eind of Hoek — bovenste',
      buildingCategory: 7,
      sub: 1,
    ),
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Tussenligging — tussenligging',
      buildingCategory: 7,
      sub: 5,
    ),
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Tussenligging — bovenste',
      buildingCategory: 7,
      sub: 4,
    ),
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Tussenligging — onderste verdieping',
      buildingCategory: 7,
      sub: 6,
    ),
    GebouwtypeOptie(
      categorie: appartement,
      type: 'Tussenligging — onderste verdieping met dak',
      buildingCategory: 7,
      sub: 7,
    ),
  ];

  static List<GebouwtypeOptie> voorCategorie(String categorie) => opties
      .where((o) => o.categorie == categorie)
      .toList(growable: false);
}
