import 'package:shared_preferences/shared_preferences.dart';

/// Onthoudt welk website-`entiteitId` bij een dossier hoort.
///
/// Waarom: `POST /entiteit` maakt telkens een NIEUW object aan. Sloot een
/// opnemer een dossier twee keer af (of drukte hij op "Opnieuw naar website"
/// nadat de eerste poging serverzijdig tóch was gelukt), dan verscheen het
/// object dubbel op de site. Door het id te bewaren kan de afsluit-flow bij een
/// volgende verzending `POST /entiteit/{id}` (update) doen i.p.v. nieuw
/// aanmaken. De koppeling blijft ook ná een geslaagde afsluiting bewaard, zodat
/// een heropend dossier hetzelfde object bijwerkt.
class EntiteitLinkStore {
  static String _key(String dossier) => 'entiteit_id_v1_${dossier.trim()}';

  /// Het eerder aangemaakte entiteit-id voor dit dossier, of null.
  static Future<int?> laad(String dossier) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final waarde = prefs.getInt(_key(dossier));
      return (waarde != null && waarde > 0) ? waarde : null;
    } catch (_) {
      return null;
    }
  }

  /// Bewaar de koppeling dossier → entiteit-id.
  static Future<void> bewaar(String dossier, int entiteitId) async {
    if (entiteitId <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key(dossier), entiteitId);
    } catch (_) {}
  }

  /// Verwijder de koppeling (bijv. na definitief verwijderen van het object).
  static Future<void> wis(String dossier) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(dossier));
    } catch (_) {}
  }
}
