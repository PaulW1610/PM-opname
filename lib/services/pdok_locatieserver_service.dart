import 'dart:convert';

import 'package:http/http.dart' as http;

/// Eén adres zoals de PDOK Locatieserver het teruggeeft bij een coördinaat.
class PdokAdres {
  /// Volledige weergave, bijv. "Ruysdaelkade 79A-1, 1072AL Amsterdam".
  final String weergavenaam;
  final String postcode;
  final String? straat;
  final String? plaats;
  final String? huisnummer;
  final String? huisletter;
  final String? huisnummertoevoeging;

  /// BAG-nummeraanduiding van dit adres.
  final String? nummeraanduidingId;

  /// Afstand in meters tussen het opgegeven punt en dit adres.
  final double afstandMeters;

  const PdokAdres({
    required this.weergavenaam,
    required this.postcode,
    required this.afstandMeters,
    this.straat,
    this.plaats,
    this.huisnummer,
    this.huisletter,
    this.huisnummertoevoeging,
    this.nummeraanduidingId,
  });

  factory PdokAdres.fromJson(Map<String, dynamic> json) {
    String? tekst(String sleutel) {
      final waarde = (json[sleutel] ?? '').toString().trim();
      return waarde.isEmpty || waarde.toLowerCase() == 'null' ? null : waarde;
    }

    final afstand = json['afstand'];
    return PdokAdres(
      weergavenaam: tekst('weergavenaam') ?? '',
      postcode: (tekst('postcode') ?? '').toUpperCase(),
      straat: tekst('straatnaam'),
      plaats: tekst('woonplaatsnaam'),
      huisnummer: tekst('huisnummer'),
      huisletter: tekst('huisletter'),
      huisnummertoevoeging: tekst('huisnummertoevoeging'),
      nummeraanduidingId: tekst('nummeraanduiding_id'),
      afstandMeters: afstand is num
          ? afstand.toDouble()
          : double.tryParse((afstand ?? '').toString()) ?? double.infinity,
    );
  }

  /// Postcode + huisnummer, de sleutel waarmee BAG bevraagd wordt.
  String get postcodeHuisnummerSleutel =>
      '${postcode.replaceAll(' ', '').toUpperCase()}|${huisnummer ?? ''}';

  /// Huisletter en toevoeging aan elkaar ("A1"), leeg als beide ontbreken.
  String get toevoegingSleutel {
    final samen = [huisletter, huisnummertoevoeging]
        .whereType<String>()
        .join()
        .replaceAll(RegExp(r'[\s-]'), '')
        .toLowerCase();
    return samen;
  }
}

/// Adressen zoeken bij een GPS-punt via de PDOK Locatieserver.
///
/// Waarom naast BAG: de BAG-API van het Kadaster kan niet op coördinaten
/// zoeken. De app gebruikte daarvoor de reverse geocoding van het besturings-
/// systeem, en die is in Nederland op huisnummerniveau onbetrouwbaar — vandaar
/// dat er buurhuisnummers bijgezocht moesten worden. De Locatieserver is de
/// Nederlandse voorziening hiervoor: gratis, zonder sleutel, en hij geeft de
/// adressen op afstand gesorteerd terug, inclusief huisletter en toevoeging.
///
/// BAG blijft de bron voor de inhoudelijke gegevens (bouwjaar, oppervlakte,
/// pand-id); PDOK bepaalt alleen wélk adres je voor je hebt.
class PdokLocatieserverService {
  static const String _basisUrl =
      'https://api.pdok.nl/bzk/locatieserver/search/v3_1';

  /// De velden die we terugvragen; scheelt bandbreedte op een slechte lijn.
  static const String _velden =
      'weergavenaam,afstand,postcode,huisnummer,huisletter,'
      'huisnummertoevoeging,straatnaam,woonplaatsnaam,nummeraanduiding_id';

  /// Adressen rond [latitude]/[longitude], dichtstbijzijnde eerst.
  ///
  /// Geeft een lege lijst terug als PDOK niets weet of onbereikbaar is; de
  /// beller kan dan terugvallen op de oude route.
  static Future<List<PdokAdres>> adressenBijCoordinaten({
    required double latitude,
    required double longitude,
    int aantal = 10,
    Duration tijdslimiet = const Duration(seconds: 10),
  }) async {
    final uri = Uri.parse('$_basisUrl/reverse').replace(
      queryParameters: <String, String>{
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'type': 'adres',
        'rows': aantal.toString(),
        'fl': _velden,
      },
    );

    try {
      final resp = await http.get(uri).timeout(tijdslimiet);
      if (resp.statusCode != 200) {
        return const <PdokAdres>[];
      }

      final decoded = json.decode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        return const <PdokAdres>[];
      }
      final response = decoded['response'];
      if (response is! Map<String, dynamic>) {
        return const <PdokAdres>[];
      }
      final docs = response['docs'];
      if (docs is! List) {
        return const <PdokAdres>[];
      }

      final adressen = <PdokAdres>[];
      for (final doc in docs) {
        if (doc is Map<String, dynamic>) {
          final adres = PdokAdres.fromJson(doc);
          if (adres.postcode.isNotEmpty && (adres.huisnummer ?? '').isNotEmpty) {
            adressen.add(adres);
          }
        }
      }

      adressen.sort((a, b) => a.afstandMeters.compareTo(b.afstandMeters));
      return adressen;
    } catch (_) {
      return const <PdokAdres>[];
    }
  }
}
