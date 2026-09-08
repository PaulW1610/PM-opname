import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final String emailRecipient;
  final String adviseurVoorletters;
  final String adviseurTussenvoegsel;
  final String adviseurAchternaam;
  final String examenNummerWonen;
  final String examenNummerUtiliteit;
  final String eigenaarId;
  final String eigenaarNaam;
  final String photoStorageLocation;
  final double gpsBagRadiusMeters;

  const AppSettings({
    required this.emailRecipient,
    required this.adviseurVoorletters,
    required this.adviseurTussenvoegsel,
    required this.adviseurAchternaam,
    required this.examenNummerWonen,
    required this.examenNummerUtiliteit,
    required this.eigenaarId,
    required this.eigenaarNaam,
    required this.photoStorageLocation,
    required this.gpsBagRadiusMeters,
  });

  AppSettings copyWith({
    String? emailRecipient,
    String? adviseurVoorletters,
    String? adviseurTussenvoegsel,
    String? adviseurAchternaam,
    String? examenNummerWonen,
    String? examenNummerUtiliteit,
    String? eigenaarId,
    String? eigenaarNaam,
    String? photoStorageLocation,
    double? gpsBagRadiusMeters,
  }) {
    return AppSettings(
      emailRecipient: emailRecipient ?? this.emailRecipient,
      adviseurVoorletters: adviseurVoorletters ?? this.adviseurVoorletters,
      adviseurTussenvoegsel:
          adviseurTussenvoegsel ?? this.adviseurTussenvoegsel,
      adviseurAchternaam: adviseurAchternaam ?? this.adviseurAchternaam,
      examenNummerWonen: examenNummerWonen ?? this.examenNummerWonen,
      examenNummerUtiliteit: examenNummerUtiliteit ?? this.examenNummerUtiliteit,
      eigenaarId: eigenaarId ?? this.eigenaarId,
      eigenaarNaam: eigenaarNaam ?? this.eigenaarNaam,
      photoStorageLocation: photoStorageLocation ?? this.photoStorageLocation,
      gpsBagRadiusMeters: gpsBagRadiusMeters ?? this.gpsBagRadiusMeters,
    );
  }
}

class AppSettingsService {
  static const String _emailRecipientKey = 'settings_email_recipient_v1';
  static const String _adviseurVoorlettersKey = 'settings_adviseur_voorletters_v1';
  static const String _adviseurTussenvoegselKey =
      'settings_adviseur_tussenvoegsel_v1';
  static const String _adviseurAchternaamKey = 'settings_adviseur_achternaam_v1';
  static const String _examenWonenKey = 'settings_examen_wonen_v1';
  static const String _examenUtiliteitKey = 'settings_examen_utiliteit_v1';
  static const String _eigenaarIdKey = 'settings_eigenaar_id_v1';
  static const String _eigenaarNaamKey = 'settings_eigenaar_naam_v1';
  static const String _photoStorageKey = 'settings_photo_storage_v1';
  static const String _gpsBagRadiusMetersKey = 'settings_gps_bag_radius_meters_v1';
  static const String defaultEmailRecipient = 'info@pmlabels.nl';
  static const double defaultGpsBagRadiusMeters = 50.0;
  static const double minGpsBagRadiusMeters = 10.0;
  static const double maxGpsBagRadiusMeters = 500.0;

  static double sanitizeGpsBagRadiusMeters(double value) {
    if (value.isNaN || value.isInfinite) {
      return defaultGpsBagRadiusMeters;
    }
    final clamped = value.clamp(minGpsBagRadiusMeters, maxGpsBagRadiusMeters);
    return clamped.toDouble();
  }

  static Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final storedRadius = prefs.getDouble(_gpsBagRadiusMetersKey);
    final gpsBagRadiusMeters = sanitizeGpsBagRadiusMeters(
      storedRadius ?? defaultGpsBagRadiusMeters,
    );
    return AppSettings(
      emailRecipient: (prefs.getString(_emailRecipientKey) ?? defaultEmailRecipient).trim(),
      adviseurVoorletters: (prefs.getString(_adviseurVoorlettersKey) ?? '').trim(),
      adviseurTussenvoegsel:
          (prefs.getString(_adviseurTussenvoegselKey) ?? '').trim(),
      adviseurAchternaam: (prefs.getString(_adviseurAchternaamKey) ?? '').trim(),
      examenNummerWonen: (prefs.getString(_examenWonenKey) ?? '').trim(),
      examenNummerUtiliteit: (prefs.getString(_examenUtiliteitKey) ?? '').trim(),
      eigenaarId: (prefs.getString(_eigenaarIdKey) ?? '').trim(),
      eigenaarNaam: (prefs.getString(_eigenaarNaamKey) ?? '').trim(),
      photoStorageLocation: (prefs.getString(_photoStorageKey) ?? '').trim(),
      gpsBagRadiusMeters: gpsBagRadiusMeters,
    );
  }

  static Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailRecipientKey, settings.emailRecipient.trim());
    await prefs.setString(
        _adviseurVoorlettersKey, settings.adviseurVoorletters.trim());
    await prefs.setString(
        _adviseurTussenvoegselKey, settings.adviseurTussenvoegsel.trim());
    await prefs.setString(
        _adviseurAchternaamKey, settings.adviseurAchternaam.trim());
    await prefs.setString(_examenWonenKey, settings.examenNummerWonen.trim());
    await prefs.setString(_examenUtiliteitKey, settings.examenNummerUtiliteit.trim());
    await prefs.setString(_eigenaarIdKey, settings.eigenaarId.trim());
    await prefs.setString(_eigenaarNaamKey, settings.eigenaarNaam.trim());
    await prefs.setString(_photoStorageKey, settings.photoStorageLocation.trim());
    await prefs.setDouble(
      _gpsBagRadiusMetersKey,
      sanitizeGpsBagRadiusMeters(settings.gpsBagRadiusMeters),
    );
  }

  static Future<String> loadEmailRecipient() async {
    final settings = await loadSettings();
    if (settings.emailRecipient.isNotEmpty) {
      return settings.emailRecipient;
    }
    return defaultEmailRecipient;
  }

  static Future<double> loadGpsBagRadiusMeters() async {
    final settings = await loadSettings();
    return settings.gpsBagRadiusMeters;
  }
}