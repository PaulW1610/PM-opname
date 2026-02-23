import 'dart:convert';
import 'package:http/http.dart' as http;

/// Model to hold BAG response data.
class BagData {
  /// Postcode from BAG response (e.g., "2101 HL").
  final String postcode;

  /// Place name from BAG response.
  final String plaatsnaam;

  /// Building year from BAG response.
  final String? oorspronkelijkBouwjaar;

  /// Use case from BAG response.
  final String? gebruiksdoel;

  /// Create BAG data model.
  BagData({
    required this.postcode,
    required this.plaatsnaam,
    this.oorspronkelijkBouwjaar,
    this.gebruiksdoel,
  });

  /// Create from JSON response.
  factory BagData.fromJson(Map<String, dynamic> json) {
    return BagData(
      postcode: json['postcode'] ?? 'Unknown',
      plaatsnaam: json['plaatsnaam'] ?? 'Unknown',
      oorspronkelijkBouwjaar:
          json['oorspronkelijkBouwjaar']?.toString(),
      gebruiksdoel: json['gebruiksdoel'],
    );
  }

  /// Get folder name as "Plaatsnaam_Postcode".
  String getFolderName() {
    final clean = '$plaatsnaam $postcode'
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return clean;
  }
}

/// Simple BAG client helpers.
///
/// Configure `baseUrl` to your BAG endpoint. Set `useQueryApiKey` to true
/// if your provider expects the API key in the query string.
class BagService {
  /// The BAG endpoint base URL (without query parameters).
  static String baseUrl = 'https://bag.example.api/lookup';

  /// If true, send the API key using the `api_key` query parameter.
  static bool useQueryApiKey = false;

  /// Lookup BAG data by [lat]/[lon] using [apiKey]. Returns [BagData].
  static Future<BagData> lookupByCoords(
    double lat,
    double lon,
    String apiKey,
  ) async {
    Uri uri;
    if (useQueryApiKey) {
      uri = Uri.parse(baseUrl).replace(
        queryParameters: {
          'lat': lat.toString(),
          'lon': lon.toString(),
          'api_key': apiKey,
        },
      );

      final resp = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      );
      if (resp.statusCode != 200) {
        throw Exception('BAG request failed: ${resp.statusCode}');
      }
      final decoded = json.decode(resp.body);
      return BagData.fromJson(decoded);
    }

    uri = Uri.parse(baseUrl).replace(
      queryParameters: {
        'lat': lat.toString(),
        'lon': lon.toString(),
      },
    );

    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Accept': 'application/json',
      },
    );
    if (resp.statusCode != 200) {
      throw Exception('BAG request failed: ${resp.statusCode}');
    }
    final decoded = json.decode(resp.body);
    return BagData.fromJson(decoded);
  }
}
