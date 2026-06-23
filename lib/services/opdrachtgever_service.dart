import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/opdrachtgever.dart';
import 'nextcloud_service.dart';

/// Resultaat van een Nextcloud-sync van de opdrachtgeverslijst.
class OpdrachtgeverSyncResult {
  /// Is de sync gelukt (download + upload)?
  final bool ok;

  /// Korte melding voor de gebruiker.
  final String message;

  /// Aantal actieve opdrachtgevers na de sync.
  final int aantal;

  /// Maak een syncresultaat.
  const OpdrachtgeverSyncResult({
    required this.ok,
    required this.message,
    required this.aantal,
  });
}

/// Beheert de lijst opdrachtgevers: lokaal (SharedPreferences) + tweerichtings-
/// sync met een CSV-bestand in Nextcloud (`Opdrachtgevers.csv` bovenin de map).
///
/// Sync = ophalen -> samenvoegen per id (nieuwste `gewijzigdOp` wint, soft-delete
/// via `verwijderd`) -> terugschrijven. Zo blijven pc en telefoon gelijk.
class OpdrachtgeverService {
  OpdrachtgeverService._();

  static const String _kStore = 'opdrachtgevers_v1';

  /// Bestandsnaam in de Nextcloud-doelmap.
  static const String csvFileName = 'Opdrachtgevers.csv';

  static const String _csvHeader =
      'id;naam;contactpersoon;email;telefoon;gewijzigdOp;verwijderd';

  static int _idCounter = 0;

  /// Genereer een redelijk unieke, stabiele id.
  static String generateId() {
    _idCounter = (_idCounter + 1) % 100000;
    final ms = DateTime.now().microsecondsSinceEpoch;
    return 'og_${ms}_$_idCounter';
  }

  /// Alle opgeslagen opdrachtgevers (inclusief verwijderde tombstones).
  static Future<List<Opdrachtgever>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStore);
    if (raw == null || raw.trim().isEmpty) return <Opdrachtgever>[];
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return <Opdrachtgever>[];
      final result = <Opdrachtgever>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          result.add(Opdrachtgever.fromJson(item));
        } else if (item is Map) {
          result.add(Opdrachtgever.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      return result;
    } catch (_) {
      return <Opdrachtgever>[];
    }
  }

  /// Actieve opdrachtgevers (niet verwijderd), gesorteerd op naam.
  static Future<List<Opdrachtgever>> loadActive() async {
    final all = await loadAll();
    final active = all.where((o) => !o.verwijderd).toList();
    active.sort(
      (a, b) => a.naam.toLowerCase().compareTo(b.naam.toLowerCase()),
    );
    return active;
  }

  static Future<void> _saveAll(List<Opdrachtgever> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        json.encode(items.map((o) => o.toJson()).toList(growable: false));
    await prefs.setString(_kStore, encoded);
  }

  /// Voeg toe of werk bij (op id). Zet `gewijzigdOp` op nu.
  static Future<Opdrachtgever> addOrUpdate(Opdrachtgever input) async {
    final all = await loadAll();
    final stamped = input.copyWith(gewijzigdOp: DateTime.now().toUtc());
    final idx = all.indexWhere((o) => o.id == stamped.id);
    if (idx >= 0) {
      all[idx] = stamped;
    } else {
      all.add(stamped);
    }
    await _saveAll(all);
    return stamped;
  }

  /// Verwijder (soft-delete) op id, zodat de verwijdering ook synct.
  static Future<void> softDelete(String id) async {
    final all = await loadAll();
    final idx = all.indexWhere((o) => o.id == id);
    if (idx < 0) return;
    all[idx] = all[idx].copyWith(
      verwijderd: true,
      gewijzigdOp: DateTime.now().toUtc(),
    );
    await _saveAll(all);
  }

  // ----- Nextcloud CSV sync ------------------------------------------------

  /// Synchroniseer met `Opdrachtgevers.csv` in Nextcloud: ophalen, samenvoegen,
  /// terugschrijven. Best-effort; gooit nooit.
  static Future<OpdrachtgeverSyncResult> syncWithNextcloud() async {
    if (!await NextcloudService.isConfigured()) {
      return const OpdrachtgeverSyncResult(
        ok: false,
        message: 'Nextcloud is niet ingesteld.',
        aantal: 0,
      );
    }

    final local = await loadAll();

    // 1) Ophalen + parsen (ontbreken = lege remote, geen fout).
    List<Opdrachtgever> remote = <Opdrachtgever>[];
    final csv = await NextcloudService.downloadText(csvFileName);
    if (csv != null && csv.trim().isNotEmpty) {
      remote = _parseCsv(csv);
    }

    // 2) Samenvoegen per id (nieuwste gewijzigdOp wint).
    final merged = <String, Opdrachtgever>{};
    for (final o in local) {
      merged[o.id] = o;
    }
    for (final o in remote) {
      final existing = merged[o.id];
      if (existing == null || o.gewijzigdOp.isAfter(existing.gewijzigdOp)) {
        merged[o.id] = o;
      }
    }
    final mergedList = merged.values.toList();

    // 3) Lokaal opslaan.
    await _saveAll(mergedList);

    // 4) Terugschrijven naar Nextcloud.
    final upOk =
        await NextcloudService.uploadText(csvFileName, _toCsv(mergedList));

    final actief = mergedList.where((o) => !o.verwijderd).length;
    if (!upOk) {
      return OpdrachtgeverSyncResult(
        ok: false,
        message: 'Opgehaald, maar terugschrijven naar Nextcloud mislukte.',
        aantal: actief,
      );
    }
    return OpdrachtgeverSyncResult(
      ok: true,
      message: 'Opdrachtgevers gesynchroniseerd ($actief).',
      aantal: actief,
    );
  }

  // ----- CSV (de)serialisatie ----------------------------------------------

  static String _toCsv(List<Opdrachtgever> items) {
    final buffer = StringBuffer()..writeln(_csvHeader);
    for (final o in items) {
      buffer.writeln([
        o.id,
        o.naam,
        o.contactpersoon,
        o.email,
        o.telefoon,
        o.gewijzigdOp.toUtc().toIso8601String(),
        o.verwijderd ? 'true' : '',
      ].map(_csvEscape).join(';'));
    }
    return buffer.toString();
  }

  static String _csvEscape(String value) {
    if (value.contains(';') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static List<Opdrachtgever> _parseCsv(String csv) {
    final rows = _splitCsvRows(csv);
    if (rows.isEmpty) return <Opdrachtgever>[];

    // Kolomvolgorde uit de header bepalen (flexibel t.o.v. handmatige bewerking).
    final header = rows.first.map((h) => h.trim().toLowerCase()).toList();
    int col(String name) => header.indexOf(name);
    final iId = col('id');
    final iNaam = col('naam');
    final iContact = col('contactpersoon');
    final iEmail = col('email');
    final iTel = col('telefoon');
    final iGew = col('gewijzigdop');
    final iDel = col('verwijderd');

    String at(List<String> r, int i) =>
        (i >= 0 && i < r.length) ? r[i].trim() : '';

    final result = <Opdrachtgever>[];
    for (var rowIdx = 1; rowIdx < rows.length; rowIdx++) {
      final r = rows[rowIdx];
      if (r.every((c) => c.trim().isEmpty)) continue;
      final naam = at(r, iNaam);
      if (naam.isEmpty && at(r, iId).isEmpty) continue;

      var id = at(r, iId);
      if (id.isEmpty) id = generateId(); // door PC toegevoegde rij zonder id

      final gewRaw = at(r, iGew);
      final gew = gewRaw.isEmpty
          ? DateTime.now().toUtc()
          : (DateTime.tryParse(gewRaw)?.toUtc() ?? DateTime.now().toUtc());

      final delRaw = at(r, iDel).toLowerCase();
      final verwijderd =
          delRaw == 'true' || delRaw == '1' || delRaw == 'x' || delRaw == 'ja';

      result.add(Opdrachtgever(
        id: id,
        naam: naam,
        contactpersoon: at(r, iContact),
        email: at(r, iEmail),
        telefoon: at(r, iTel),
        gewijzigdOp: gew,
        verwijderd: verwijderd,
      ));
    }
    return result;
  }

  /// Splitst CSV in rijen van velden; ondersteunt `;`-scheiding, dubbele
  /// quotes en velden met regeleindes binnen quotes.
  static List<List<String>> _splitCsvRows(String csv) {
    final rows = <List<String>>[];
    var fields = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    void endField() {
      fields.add(field.toString());
      field.clear();
    }

    void endRow() {
      endField();
      rows.add(fields);
      fields = <String>[];
    }

    final text = csv.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == ';') {
          endField();
        } else if (ch == '\n') {
          endRow();
        } else {
          field.write(ch);
        }
      }
    }
    // Laatste veld/rij (als er geen afsluitende newline is).
    if (field.isNotEmpty || fields.isNotEmpty) {
      endRow();
    }
    return rows;
  }
}
