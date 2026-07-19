import 'package:flutter/material.dart';

import '../models/wws_invoer_data.dart';
import '../services/blueprint_api_service.dart';

class WwsInvoerScreen extends StatefulWidget {
  final String dossierNaam;
  final WwsInvoerData initialData;

  const WwsInvoerScreen({
    Key? key,
    required this.dossierNaam,
    required this.initialData,
  }) : super(key: key);

  @override
  State<WwsInvoerScreen> createState() => _WwsInvoerScreenState();
}

class _WwsInvoerScreenState extends State<WwsInvoerScreen> {
  late bool _toepassen;
  late String _wozJaar;
  late final TextEditingController _puntenController;
  late final TextEditingController _maxHuurController;
  late final TextEditingController _wozWaardeController;

  @override
  void initState() {
    super.initState();
    _toepassen = widget.initialData.toepassen;
    _wozJaar = widget.initialData.wozJaar;
    _puntenController = TextEditingController(text: widget.initialData.punten);
    _maxHuurController =
        TextEditingController(text: widget.initialData.maxHuur);
    _wozWaardeController =
        TextEditingController(text: widget.initialData.wozWaarde);
  }

  @override
  void dispose() {
    _puntenController.dispose();
    _maxHuurController.dispose();
    _wozWaardeController.dispose();
    super.dispose();
  }

  void _opslaan() {
    final result = WwsInvoerData(
      toepassen: _toepassen,
      punten: _puntenController.text.trim(),
      maxHuur: _maxHuurController.text.trim(),
      wozWaarde: _wozWaardeController.text.trim(),
      wozJaar: _wozJaar,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WWS')), 
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dossier: ${widget.dossierNaam}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('WWS puntentelling koppelen aan object'),
              value: _toepassen,
              onChanged: (value) => setState(() => _toepassen = value),
            ),
            const SizedBox(height: 8),
            if (_toepassen) ...[
              TextField(
                controller: _puntenController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'WWS punten',
                  hintText: 'Bijv. 148',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _maxHuurController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Max huur (EUR)',
                  hintText: 'Bijv. 1025.50',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _wozWaardeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'WOZ waarde (EUR, optioneel)',
                  hintText: 'Bijv. 325000',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _wozJaar,
                items: BlueprintWwsContract.wozJaren
                    .map(
                      (jaar) => DropdownMenuItem<String>(
                        value: jaar,
                        child: Text(jaar),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _wozJaar = value);
                },
                decoration: const InputDecoration(
                  labelText: 'WOZ jaar',
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...[
              Text(
                'Niet elk object krijgt WWS. Laat de schakelaar uit voor objecten zonder puntentelling.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('WWS opslaan'),
                onPressed: _opslaan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
