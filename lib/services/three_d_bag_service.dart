import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ThreeDBagService {
  static String baseUrl = 'https://api.3dbag.nl';

  static Future<File?> createGebouwOverzichtImageForDossier({
    required String bagPandId,
    required String dossierName,
  }) async {
    final decoded = await _fetchPandData(bagPandId: bagPandId);
    if (decoded == null) {
      return null;
    }

    final vertices = _extractVertices(decoded);
    if (vertices.isEmpty) {
      return null;
    }

    final rings = _extractRings(decoded);
    if (rings.isEmpty) {
      return null;
    }

    final image = img.Image(1200, 1200);
    img.fill(image, img.getColor(255, 255, 255));

    final allPoints = <math.Point<double>>[];
    final drawableRings = <List<math.Point<double>>>[];
    for (final ring in rings) {
      final points = <math.Point<double>>[];
      for (final index in ring) {
        if (index < 0 || index >= vertices.length) {
          continue;
        }
        final p = vertices[index];
        points.add(math.Point<double>(p.x, p.y));
      }
      if (points.length >= 2) {
        drawableRings.add(points);
        allPoints.addAll(points);
      }
    }

    if (allPoints.isEmpty) {
      return null;
    }

    var minX = allPoints.first.x;
    var maxX = allPoints.first.x;
    var minY = allPoints.first.y;
    var maxY = allPoints.first.y;
    for (final p in allPoints.skip(1)) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    final dx = (maxX - minX).abs();
    final dy = (maxY - minY).abs();
    if (dx <= 0 && dy <= 0) {
      return null;
    }

    const margin = 80.0;
    final drawWidth = image.width - (margin * 2);
    final drawHeight = image.height - (margin * 2);
    final scaleX = dx > 0 ? drawWidth / dx : 1.0;
    final scaleY = dy > 0 ? drawHeight / dy : 1.0;
    final scale = math.min(scaleX, scaleY);

    int toPixelX(double x) => (margin + (x - minX) * scale).round();
    int toPixelY(double y) => (image.height - margin - (y - minY) * scale).round();

    final lineColor = img.getColor(33, 78, 128);
    for (final ring in drawableRings) {
      if (ring.length < 2) {
        continue;
      }
      for (var i = 0; i < ring.length; i++) {
        final current = ring[i];
        final next = ring[(i + 1) % ring.length];
        img.drawLine(
          image,
          toPixelX(current.x),
          toPixelY(current.y),
          toPixelX(next.x),
          toPixelY(next.y),
          lineColor,
          thickness: 2,
        );
      }
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    final safeDossierName = _sanitizeName(dossierName);
    final file = File(
      '${documentsDir.path}/dossiers/$safeDossierName/3dbag_overzicht.png',
    );
    await file.parent.create(recursive: true);
    final pngBytes = img.encodePng(image, level: 3);
    await file.writeAsBytes(pngBytes, flush: true);
    return file;
  }

  static Future<double?> fetchGebouwhoogteMeters({
    required String bagPandId,
  }) async {
    final decoded = await _fetchPandData(bagPandId: bagPandId);
    if (decoded == null) {
      return null;
    }
    return _extractGebouwhoogteMeters(decoded);
  }

  static Future<Map<String, dynamic>?> _fetchPandData({
    required String bagPandId,
  }) async {
    final normalized = bagPandId.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final candidateIds = <String>{
      normalized,
      _toFullPandId(normalized),
      _toShortPandId(normalized),
    }..removeWhere((value) => value.trim().isEmpty);

    for (final candidateId in candidateIds) {
      final url = Uri.parse(
        '$baseUrl/collections/pand/items/${Uri.encodeComponent(candidateId)}',
      );

      final response = await http.get(
        url,
        headers: const {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        continue;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    }

    return null;
  }

  static List<_Vertex2D> _extractVertices(Map<String, dynamic> data) {
    final feature = data['feature'];
    if (feature is! Map<String, dynamic>) {
      return const [];
    }

    final rawVertices = feature['vertices'];
    if (rawVertices is! List) {
      return const [];
    }

    final vertices = <_Vertex2D>[];
    for (final item in rawVertices) {
      if (item is! List || item.length < 2) {
        continue;
      }
      final x = _toDouble(item[0]);
      final y = _toDouble(item[1]);
      if (x == null || y == null) {
        continue;
      }
      vertices.add(_Vertex2D(x: x, y: y));
    }
    return vertices;
  }

  static List<List<int>> _extractRings(Map<String, dynamic> data) {
    final feature = data['feature'];
    if (feature is! Map<String, dynamic>) {
      return const [];
    }

    final cityObjects = feature['CityObjects'];
    if (cityObjects is! Map<String, dynamic>) {
      return const [];
    }

    final rings = <List<int>>[];

    for (final cityObject in cityObjects.values) {
      if (cityObject is! Map<String, dynamic>) {
        continue;
      }
      final geometry = cityObject['geometry'];
      if (geometry is! List) {
        continue;
      }

      for (final geo in geometry) {
        if (geo is! Map<String, dynamic>) {
          continue;
        }
        final boundaries = geo['boundaries'];
        _collectIndexRings(boundaries, rings);
      }
    }

    return rings;
  }

  static void _collectIndexRings(dynamic node, List<List<int>> out) {
    if (node is! List || node.isEmpty) {
      return;
    }

    if (node.every((item) => item is int)) {
      out.add(node.cast<int>());
      return;
    }

    for (final child in node) {
      _collectIndexRings(child, out);
    }
  }

  static double? _extractGebouwhoogteMeters(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final feature = data['feature'];
    if (feature is! Map<String, dynamic>) {
      return null;
    }

    final cityObjects = feature['CityObjects'];
    if (cityObjects is! Map<String, dynamic>) {
      return null;
    }

    final relativeHeights = <double>[];
    final absoluteDakHeights = <double>[];
    final maaiveldHeights = <double>[];

    for (final cityObject in cityObjects.values) {
      if (cityObject is! Map<String, dynamic>) {
        continue;
      }

      final objectType = (cityObject['type'] ?? '').toString().toLowerCase();
      if (objectType.isNotEmpty &&
          !objectType.contains('building') &&
          !objectType.contains('pand')) {
        continue;
      }

      final attributes = cityObject['attributes'];
      if (attributes is! Map<String, dynamic>) {
        continue;
      }

      final maaiveld = _toDouble(attributes['b3_h_maaiveld']);
      final dakMax = _toDouble(attributes['b3_h_dak_max']);
      final dak70 = _toDouble(attributes['b3_h_dak_70p']);
      final nok = _toDouble(attributes['b3_h_nok']);

      final absoluteDak = dakMax ?? dak70 ?? nok;
      if (absoluteDak != null && absoluteDak > 0) {
        absoluteDakHeights.add(absoluteDak);
      }

      if (maaiveld != null) {
        maaiveldHeights.add(maaiveld);
      }

      if (absoluteDak != null && maaiveld != null) {
        final relativeHeight = absoluteDak - maaiveld;
        if (relativeHeight > 0) {
          relativeHeights.add(relativeHeight);
        }
      }
    }

    if (relativeHeights.isNotEmpty) {
      final maxRelative = relativeHeights.reduce(math.max);
      if (maxRelative > 0 && maxRelative < 400) {
        return maxRelative;
      }
    }

    if (absoluteDakHeights.isNotEmpty && maaiveldHeights.isNotEmpty) {
      final maxDak = absoluteDakHeights.reduce(math.max);
      final minMaaiveld = maaiveldHeights.reduce(math.min);
      final derived = maxDak - minMaaiveld;
      if (derived > 0 && derived < 400) {
        return derived;
      }
    }

    if (absoluteDakHeights.isNotEmpty) {
      final absolute = absoluteDakHeights.reduce(math.max);
      if (absolute > 0 && absolute < 400) {
        return absolute;
      }
    }

    return null;
  }

  static double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value == null) {
      return null;
    }
    return double.tryParse(value.toString());
  }

  static String _toFullPandId(String id) {
    final trimmed = id.trim();
    if (trimmed.startsWith('NL.IMBAG.Pand.')) {
      return trimmed;
    }
    return 'NL.IMBAG.Pand.$trimmed';
  }

  static String _toShortPandId(String id) {
    const prefix = 'NL.IMBAG.Pand.';
    final trimmed = id.trim();
    if (!trimmed.startsWith(prefix)) {
      return trimmed;
    }
    return trimmed.substring(prefix.length);
  }

  static String _sanitizeName(String raw) {
    final sanitized = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (sanitized.isEmpty) {
      return 'Onbekend_dossier';
    }
    return sanitized;
  }
}

class _Vertex2D {
  final double x;
  final double y;

  const _Vertex2D({
    required this.x,
    required this.y,
  });
}