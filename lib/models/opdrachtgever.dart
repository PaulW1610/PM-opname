/// Een opdrachtgever (klant) die aan een opname gekoppeld kan worden.
///
/// Herbruikbaar: dezelfde opdrachtgever wordt voor meerdere opnames gebruikt.
/// Het opdrachtnummer hoort NIET hier maar per opname (bij het dossier), omdat
/// dat per opdracht verschilt.
///
/// [gewijzigdOp] en [verwijderd] zijn voor de Nextcloud-CSV-sync (last-write-wins
/// + soft-delete), zodat wijzigingen tussen pc en telefoon netjes samenkomen.
class Opdrachtgever {
  /// Stabiele sleutel; verandert niet als de naam wordt aangepast.
  final String id;

  /// Naam van de opdrachtgever (verplicht).
  final String naam;

  /// Contactpersoon (optioneel).
  final String contactpersoon;

  /// E-mailadres (optioneel).
  final String email;

  /// Telefoonnummer (optioneel).
  final String telefoon;

  /// Laatste wijzigingstijdstip (voor sync; bepaalt wie wint).
  final DateTime gewijzigdOp;

  /// Soft-delete: zo blijft een verwijdering bewaard tot de sync 'm verwerkt.
  final bool verwijderd;

  /// Maak een opdrachtgever.
  const Opdrachtgever({
    required this.id,
    required this.naam,
    this.contactpersoon = '',
    this.email = '',
    this.telefoon = '',
    required this.gewijzigdOp,
    this.verwijderd = false,
  });

  /// Een nette weergavenaam voor in de dropdown.
  String get displayLabel {
    final n = naam.trim();
    final c = contactpersoon.trim();
    if (n.isEmpty) return c.isEmpty ? 'Onbekende opdrachtgever' : c;
    return c.isEmpty ? n : '$n — $c';
  }

  /// Kopie met aangepaste velden.
  Opdrachtgever copyWith({
    String? id,
    String? naam,
    String? contactpersoon,
    String? email,
    String? telefoon,
    DateTime? gewijzigdOp,
    bool? verwijderd,
  }) {
    return Opdrachtgever(
      id: id ?? this.id,
      naam: naam ?? this.naam,
      contactpersoon: contactpersoon ?? this.contactpersoon,
      email: email ?? this.email,
      telefoon: telefoon ?? this.telefoon,
      gewijzigdOp: gewijzigdOp ?? this.gewijzigdOp,
      verwijderd: verwijderd ?? this.verwijderd,
    );
  }

  /// Naar JSON (voor lokale opslag in SharedPreferences).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'naam': naam,
        'contactpersoon': contactpersoon,
        'email': email,
        'telefoon': telefoon,
        'gewijzigdOp': gewijzigdOp.toUtc().toIso8601String(),
        'verwijderd': verwijderd,
      };

  /// Uit JSON (lokale opslag).
  factory Opdrachtgever.fromJson(Map<String, dynamic> json) {
    return Opdrachtgever(
      id: (json['id'] ?? '').toString(),
      naam: (json['naam'] ?? '').toString(),
      contactpersoon: (json['contactpersoon'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      telefoon: (json['telefoon'] ?? '').toString(),
      gewijzigdOp: _parseDate(json['gewijzigdOp']),
      verwijderd: json['verwijderd'] == true ||
          json['verwijderd']?.toString().toLowerCase() == 'true',
    );
  }

  /// Compacte momentopname voor in het dossier/JSON-export (zonder sync-velden).
  Map<String, dynamic> toSnapshotJson() => <String, dynamic>{
        'id': id,
        'naam': naam,
        'contactpersoon': contactpersoon,
        'email': email,
        'telefoon': telefoon,
      };

  /// Uit een dossier-momentopname (kan ontbrekende sync-velden hebben).
  factory Opdrachtgever.fromSnapshotJson(Map<String, dynamic> json) {
    return Opdrachtgever(
      id: (json['id'] ?? '').toString(),
      naam: (json['naam'] ?? '').toString(),
      contactpersoon: (json['contactpersoon'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      telefoon: (json['telefoon'] ?? '').toString(),
      gewijzigdOp: _parseDate(json['gewijzigdOp']),
      verwijderd: false,
    );
  }

  static DateTime _parseDate(dynamic raw) {
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return DateTime.tryParse(text)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
