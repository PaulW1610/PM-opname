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
  /// Deze key is publiek (read-only adresbevragingen) en staat bewust als
  /// werkende default zodat de app in ELKE build-route werkt (ook een directe
  /// Xcode-build die geen --dart-define meegeeft). Te overschrijven via
  /// --dart-define=BAG_API_KEY=... of tool/dart_defines.json.
  static const String bagApiKey = String.fromEnvironment(
    'BAG_API_KEY',
    defaultValue: 'l79175a82fbd564ef8b7ac64e4b7857001',
  );

  /// Dropbox App key (public client id) voor de OAuth2 PKCE-flow.
  static const String dropboxAppKey =
      String.fromEnvironment('DROPBOX_APP_KEY', defaultValue: '');

  /// True wanneer er een BAG-key is meegegeven bij de build/run.
  static bool get hasBagApiKey => bagApiKey.isNotEmpty;

  /// True wanneer er een Dropbox-key is meegegeven bij de build/run.
  static bool get hasDropboxAppKey => dropboxAppKey.isNotEmpty;
}
