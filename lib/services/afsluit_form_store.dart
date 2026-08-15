import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Bewaart de ingevulde staat van het opname-afsluitformulier PER DOSSIER,
/// zodat het scherm niet meer "op nul springt" als je het opnieuw opent.
/// Wordt gewist zodra de opname is afgesloten (verstuurd/opgeslagen).
class AfsluitFormStore {
  static String _key(String dossier) => 'afsluit_form_v1_${dossier.trim()}';

  static Future<Map<String, dynamic>> laad(String dossier) async {
    if (dossier.trim().isEmpty) return const <String, dynamic>{};
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(dossier));
    if (raw == null || raw.isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  static Future<void> bewaar(String dossier, Map<String, dynamic> data) async {
    if (dossier.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(dossier), jsonEncode(data));
  }

  static Future<void> wis(String dossier) async {
    if (dossier.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(dossier));
  }
}
