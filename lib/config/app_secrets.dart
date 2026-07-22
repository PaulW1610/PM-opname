/// Centrale plek voor API-keys en andere geheimen.
///
/// Geheimen worden NIET in de broncode opgenomen. Ze worden bij build/run
/// meegegeven via `--dart-define` of `--dart-define-from-file`.
///
/// Lokaal: vul `tool/dart_defines.json` (gitignored) op basis van
/// `tool/dart_defines.example.json` en start via `./tool/run_ios.sh` of
/// `./tool/build_testflight.sh` (die geven het bestand automatisch mee).
///
/// Voorbeeld handmatig:
/// ```
/// flutter run --dart-define-from-file=tool/dart_defines.json
/// ```
class AppSecrets {
  const AppSecrets._();

  /// BAG (Kadaster) API-key voor adres-/pandbevragingen.
  ///
  /// GEEN ingebakken standaardwaarde: de sleutel staat op naam van Paul bij
  /// het Kadaster (met een dagelijkse bevragingslimiet) en de repo is
  /// openbaar. Hij komt uitsluitend uit `tool/dart_defines.json` (gitignored);
  /// `tool/run_ios.sh` en `tool/build_testflight.sh` geven dat bestand mee.
  ///
  /// Bouw je rechtstreeks vanuit Xcode zonder dart-defines, dan is deze leeg
  /// en meldt het startscherm dat de sleutel ontbreekt — zie [hasBagApiKey].
  static const String bagApiKey = String.fromEnvironment('BAG_API_KEY');

  /// Dropbox App key (public client id) voor de OAuth2 PKCE-flow.
  static const String dropboxAppKey =
      String.fromEnvironment('DROPBOX_APP_KEY', defaultValue: '');

  /// True wanneer er een BAG-key is meegegeven bij de build/run.
  static bool get hasBagApiKey => bagApiKey.isNotEmpty;

  /// True wanneer er een Dropbox-key is meegegeven bij de build/run.
  static bool get hasDropboxAppKey => dropboxAppKey.isNotEmpty;
}
