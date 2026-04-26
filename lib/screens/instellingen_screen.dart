import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_settings_service.dart';
import '../services/dropbox_service.dart';

class InstellingenScreen extends StatefulWidget {
  const InstellingenScreen({Key? key}) : super(key: key);

  @override
  State<InstellingenScreen> createState() => _InstellingenScreenState();
}

class _InstellingenScreenState extends State<InstellingenScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _examenWonenController = TextEditingController();
  final TextEditingController _examenUtiliteitController = TextEditingController();
  final TextEditingController _photoStorageController = TextEditingController();
  final TextEditingController _gpsRadiusController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _dropboxConnected = false;
  StreamSubscription<Uri>? _appLinksSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _setupAppLinks();
  }

  Future<void> _load() async {
    final settings = await AppSettingsService.loadSettings();
    final dropboxConnected = await DropboxService.validateConnection();
    if (!mounted) {
      return;
    }
    setState(() {
      _emailController.text = settings.emailRecipient;
      _examenWonenController.text = settings.examenNummerWonen;
      _examenUtiliteitController.text = settings.examenNummerUtiliteit;
      _photoStorageController.text = settings.photoStorageLocation;
      _gpsRadiusController.text = settings.gpsBagRadiusMeters.toStringAsFixed(0);
      _isLoading = false;
      _dropboxConnected = dropboxConnected;
    });
  }

  void _setupAppLinks() {
    _appLinksSubscription = AppLinks().uriLinkStream.listen((uri) {
      if (uri.scheme == 'nl.paulweijers.photoorganizerapp' &&
          uri.host == 'dropbox-auth') {
        _handleDropboxCallback(uri);
      }
    });
  }

  Future<void> _handleDropboxCallback(Uri uri) async {
    final success = await DropboxService.handleAuthCallback(uri);
    if (!mounted) return;
    setState(() => _dropboxConnected = success);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Dropbox verbonden! Bestanden worden automatisch geüpload.'
              : 'Dropbox verbinding mislukt: ${DropboxService.lastError ?? 'onbekende fout'}',
        ),
      ),
    );
  }

  Future<void> _connectDropbox() async {
    final url = await DropboxService.buildAuthUrl();
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kan Dropbox niet openen.')),
      );
    }
  }

  Future<void> _disconnectDropbox() async {
    await DropboxService.disconnect();
    if (!mounted) return;
    setState(() => _dropboxConnected = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dropbox verbinding verbroken.')),
    );
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final parsedRadius = double.tryParse(
      _gpsRadiusController.text.replaceAll(',', '.').trim(),
    );
    final sanitizedRadius = AppSettingsService.sanitizeGpsBagRadiusMeters(
      parsedRadius ?? AppSettingsService.defaultGpsBagRadiusMeters,
    );

    setState(() {
      _isSaving = true;
    });
    await AppSettingsService.saveSettings(
      AppSettings(
        emailRecipient: _emailController.text,
        examenNummerWonen: _examenWonenController.text,
        examenNummerUtiliteit: _examenUtiliteitController.text,
        photoStorageLocation: _photoStorageController.text,
        gpsBagRadiusMeters: sanitizedRadius,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _gpsRadiusController.text = sanitizedRadius.toStringAsFixed(0);
      _isSaving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Instellingen opgeslagen.')),
    );
  }

  @override
  void dispose() {
    _appLinksSubscription?.cancel();
    _emailController.dispose();
    _examenWonenController.dispose();
    _examenUtiliteitController.dispose();
    _photoStorageController.dispose();
    _gpsRadiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instellingen'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail ontvanger voor afsluiten opname',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _examenWonenController,
                    decoration: const InputDecoration(
                      labelText: 'Examen nummer adviseur (Wonen)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _examenUtiliteitController,
                    decoration: const InputDecoration(
                      labelText: 'Examen nummer adviseur (Utiliteit)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _photoStorageController,
                    decoration: const InputDecoration(
                      labelText: 'Foto-opslag locatie (later OneDrive/Dropbox)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _gpsRadiusController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText:
                          'BAG GPS radius (meter, ${AppSettingsService.minGpsBagRadiusMeters.toInt()}-${AppSettingsService.maxGpsBagRadiusMeters.toInt()})',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Dropbox',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _dropboxConnected ? Icons.check_circle : Icons.cloud_off,
                        color: _dropboxConnected ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(_dropboxConnected ? 'Verbonden' : 'Niet verbonden'),
                    ],
                  ),
                  if (!_dropboxConnected && (DropboxService.lastError?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 8),
                    Text(
                      DropboxService.lastError!,
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: _dropboxConnected
                        ? OutlinedButton.icon(
                            icon: const Icon(Icons.link_off),
                            label: const Text('Dropbox verbreken'),
                            onPressed: _disconnectDropbox,
                          )
                        : ElevatedButton.icon(
                            icon: const Icon(Icons.cloud_upload),
                            label: const Text('Verbinden met Dropbox'),
                            onPressed: _connectDropbox,
                          ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Opslaan'),
                      onPressed: _isSaving ? null : _save,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}