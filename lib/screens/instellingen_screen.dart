import 'package:flutter/material.dart';

import '../services/app_settings_service.dart';
import '../services/nextcloud_service.dart';

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

  final TextEditingController _ncUrlController = TextEditingController();
  final TextEditingController _ncUserController = TextEditingController();
  final TextEditingController _ncPassController = TextEditingController();
  final TextEditingController _ncBaseController = TextEditingController();
  final TextEditingController _ncLinkController = TextEditingController();
  final TextEditingController _ncLinkPassController = TextEditingController();

  NextcloudMode _ncMode = NextcloudMode.link;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _nextcloudConfigured = false;
  bool _ncBusy = false;
  String? _ncStatus;
  bool _ncStatusOk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await AppSettingsService.loadSettings();
    final ncConfig = await NextcloudService.loadConfig();
    if (!mounted) {
      return;
    }
    setState(() {
      _emailController.text = settings.emailRecipient;
      _examenWonenController.text = settings.examenNummerWonen;
      _examenUtiliteitController.text = settings.examenNummerUtiliteit;
      _photoStorageController.text = settings.photoStorageLocation;
      _gpsRadiusController.text = settings.gpsBagRadiusMeters.toStringAsFixed(0);
      if (ncConfig != null) {
        _ncMode = ncConfig.mode;
        _ncUrlController.text = ncConfig.baseUrl;
        _ncUserController.text = ncConfig.username;
        _ncPassController.text = ncConfig.appPassword;
        _ncLinkController.text = ncConfig.linkUrl;
        _ncLinkPassController.text = ncConfig.linkPassword;
        _ncBaseController.text = ncConfig.basePath;
        _nextcloudConfigured = true;
      }
      _isLoading = false;
    });
  }

  Future<void> _saveAndTestNextcloud() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_ncMode == NextcloudMode.link) {
      final link = _ncLinkController.text.trim();
      if (link.isEmpty || !link.contains('/s/')) {
        setState(() {
          _ncStatus =
              'Vul een geldige deellink in (bijv. https://cloud.domein.nl/s/AbC123).';
          _ncStatusOk = false;
        });
        return;
      }
      setState(() {
        _ncBusy = true;
        _ncStatus = null;
      });
      await NextcloudService.saveLinkConfig(
        linkUrl: link,
        linkPassword: _ncLinkPassController.text,
        basePath: _ncBaseController.text,
      );
    } else {
      final url = _ncUrlController.text.trim();
      final user = _ncUserController.text.trim();
      final pass = _ncPassController.text.trim();
      if (url.isEmpty || user.isEmpty || pass.isEmpty) {
        setState(() {
          _ncStatus = 'Vul server-URL, gebruiker én app-wachtwoord in.';
          _ncStatusOk = false;
        });
        return;
      }
      setState(() {
        _ncBusy = true;
        _ncStatus = null;
      });
      await NextcloudService.saveAccountConfig(
        baseUrl: url,
        username: user,
        appPassword: pass,
        basePath: _ncBaseController.text,
      );
    }
    final ok = await NextcloudService.testConnection();
    if (!mounted) return;
    setState(() {
      _ncBusy = false;
      _nextcloudConfigured = ok;
      _ncStatusOk = ok;
      _ncStatus = ok
          ? 'Verbonden! Bestanden worden automatisch geüpload bij afronden.'
          : (NextcloudService.lastError ?? 'Verbinding mislukt.');
    });
  }

  Future<void> _disconnectNextcloud() async {
    await NextcloudService.clearConfig();
    if (!mounted) return;
    setState(() {
      _ncUrlController.clear();
      _ncUserController.clear();
      _ncPassController.clear();
      _ncLinkController.clear();
      _ncLinkPassController.clear();
      _ncBaseController.clear();
      _nextcloudConfigured = false;
      _ncStatus = 'Nextcloud-verbinding verbroken.';
      _ncStatusOk = false;
    });
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
    _emailController.dispose();
    _examenWonenController.dispose();
    _examenUtiliteitController.dispose();
    _photoStorageController.dispose();
    _gpsRadiusController.dispose();
    _ncUrlController.dispose();
    _ncUserController.dispose();
    _ncPassController.dispose();
    _ncLinkController.dispose();
    _ncLinkPassController.dispose();
    _ncBaseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instellingen'),
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home_outlined),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
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
                      labelText: 'Foto-opslag locatie (optioneel)',
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
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Instellingen opslaan'),
                      onPressed: _isSaving ? null : _save,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Nextcloud (automatische upload)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _nextcloudConfigured ? Icons.check_circle : Icons.cloud_off,
                        color: _nextcloudConfigured ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(_nextcloudConfigured ? 'Verbonden' : 'Niet verbonden'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<NextcloudMode>(
                    segments: const [
                      ButtonSegment(
                        value: NextcloudMode.link,
                        label: Text('Publieke link'),
                        icon: Icon(Icons.link),
                      ),
                      ButtonSegment(
                        value: NextcloudMode.account,
                        label: Text('Account'),
                        icon: Icon(Icons.person),
                      ),
                    ],
                    selected: {_ncMode},
                    onSelectionChanged: (s) =>
                        setState(() => _ncMode = s.first),
                  ),
                  const SizedBox(height: 12),
                  if (_ncMode == NextcloudMode.link) ...[
                    const Text(
                      'Maak in Nextcloud een deellink met "Uploaden en bewerken '
                      'toestaan" en plak die hier. Optioneel een link-wachtwoord.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ncLinkController,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Deellink',
                        hintText: 'https://cloud.jouwdomein.nl/s/AbC123',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ncLinkPassController,
                      obscureText: true,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Link-wachtwoord (optioneel)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Gebruik een app-wachtwoord uit Nextcloud > Instellingen > '
                      'Beveiliging. Server-URL bijv. https://cloud.jouwdomein.nl',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ncUrlController,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Server-URL',
                        hintText: 'https://cloud.jouwdomein.nl',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ncUserController,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Gebruikersnaam',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ncPassController,
                      obscureText: true,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'App-wachtwoord',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ncBaseController,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Submap in de gedeelde map (optioneel)',
                      hintText: 'bijv. Opnames',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_ncStatus != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _ncStatus!,
                      style: TextStyle(
                        color: _ncStatusOk
                            ? Colors.green.shade800
                            : Colors.orange.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _ncBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_done),
                      label: Text(_ncBusy ? 'Testen…' : 'Verbinden & testen'),
                      onPressed: _ncBusy ? null : _saveAndTestNextcloud,
                    ),
                  ),
                  if (_nextcloudConfigured) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.link_off),
                        label: const Text('Nextcloud verbreken'),
                        onPressed: _ncBusy ? null : _disconnectNextcloud,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
