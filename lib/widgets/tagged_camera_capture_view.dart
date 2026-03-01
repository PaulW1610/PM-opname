import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

import '../services/bag_service.dart';
import '../services/photo_library_service.dart';

bool _renderLabelOverlay(Map<String, String> payload) {
  final imagePath = payload['path'];
  final rawLabel = payload['label'];
  if (imagePath == null || rawLabel == null) {
    return false;
  }

  final file = File(imagePath);
  final bytes = file.readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return false;
  }

  final int barHeight = math.max(72, (decoded.height * 0.14).round());
  final int barTop = decoded.height - barHeight;

  img.fillRect(
    decoded,
    0,
    barTop,
    decoded.width - 1,
    decoded.height - 1,
    img.getColor(0, 0, 0, 200),
  );

  final text = rawLabel.toUpperCase();
  final font = img.arial_24;
  final textX = 20;
  final int textY = barTop + math.max(8, (barHeight - font.lineHeight) ~/ 2);

  img.drawString(
    decoded,
    font,
    textX,
    textY,
    text,
    color: img.getColor(255, 255, 255),
  );

  final encoded = img.encodeJpg(decoded, quality: 92);
  file.writeAsBytesSync(encoded, flush: true);
  return true;
}

class TaggedCameraCaptureView extends StatefulWidget {
  final BagData bagData;
  final List<String> labels;
  final Color accentColor;
  final String albumName;
  final VoidCallback? onPhotoSaved;

  const TaggedCameraCaptureView({
    Key? key,
    required this.bagData,
    required this.labels,
    required this.accentColor,
    required this.albumName,
    this.onPhotoSaved,
  }) : super(key: key);

  @override
  State<TaggedCameraCaptureView> createState() => _TaggedCameraCaptureViewState();
}

class _TaggedCameraCaptureViewState extends State<TaggedCameraCaptureView>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  int _cameraSession = 0;
  bool _cameraTransitionInProgress = false;
  bool _isInitializing = true;
  bool _isSaving = false;
  String? _lastSavedLabel;
  String? _cameraErrorMessage;
  final Set<String> _savedLabels = <String>{};
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _zoomLevel = 1.0;
  double _zoomSliderValue = 0.0;
  bool _torchEnabled = false;
  int? _standardBackCameraIndex;
  int? _ultraWideCameraIndex;
  static const List<ResolutionPreset> _resolutionFallbacks = <ResolutionPreset>[
    ResolutionPreset.veryHigh,
    ResolutionPreset.high,
    ResolutionPreset.medium,
  ];
  static const List<String> _requiredFacadeLabels = [
    'Achtergevel',
    'Voorgevel',
  ];

  void _resolveLensIndices(List<CameraDescription> cameras) {
    int? standardIndex;
    int? ultraIndex;

    for (var i = 0; i < cameras.length; i++) {
      final camera = cameras[i];
      if (camera.lensDirection != CameraLensDirection.back) {
        continue;
      }
      final name = camera.name.toLowerCase();
      final isUltra =
          name.contains('ultra') || name.contains('0.5x') || name.contains('0.5');

      if (isUltra) {
        ultraIndex ??= i;
      } else {
        standardIndex ??= i;
      }
    }

    _standardBackCameraIndex = standardIndex ?? ultraIndex;
    _ultraWideCameraIndex = ultraIndex;
  }

  Future<CameraController> _createInitializedController(
    CameraDescription description,
  ) async {
    Object? lastError;
    for (final preset in _resolutionFallbacks) {
      final controller = CameraController(
        description,
        preset,
        enableAudio: false,
      );
      try {
        await controller.initialize();
        return controller;
      } catch (error) {
        lastError = error;
        await controller.dispose();
      }
    }
    throw Exception('Camera initialiseren mislukt op alle resoluties: $lastError');
  }

  String _normalizeLabel(String label) => label.trim().toLowerCase();

  bool _hasSavedLabel(String label) => _savedLabels.contains(_normalizeLabel(label));

  List<String> _missingRequiredLabels() {
    return _requiredFacadeLabels
        .where((label) => !_hasSavedLabel(label))
        .toList(growable: false);
  }

  Future<bool> _handleBackNavigation() async {
    final missingLabels = _missingRequiredLabels();
    if (missingLabels.isEmpty) {
      return true;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Controle ontbrekende foto\'s'),
        content: Text(
          'Nog niet vastgelegd: ${missingLabels.join(', ')}.\n'
          'Wil je toch teruggaan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Blijven'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Toch terug'),
          ),
        ],
      ),
    );

    return shouldLeave ?? false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    final controller = _controller;
    _cameraSession++;
    _controller = null;
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _cameraSession++;
      controller.dispose();
      _controller = null;
      if (mounted) {
        setState(() {
          _isInitializing = true;
        });
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _initializeCamera(preferredIndex: _cameraIndex);
    }
  }

  Future<void> _initializeCamera({int? preferredIndex}) async {
    if (_cameraTransitionInProgress) {
      return;
    }
    _cameraTransitionInProgress = true;

    final int session = ++_cameraSession;
    if (mounted) {
      setState(() {
        _isInitializing = true;
      });
    }

    try {
      final cameraPermission = await Permission.camera.request();
      if (!cameraPermission.isGranted) {
        if (!mounted || session != _cameraSession) return;
        setState(() {
          _isInitializing = false;
          _cameraErrorMessage =
              'Geen cameratoegang. Geef toestemming via Instellingen.';
        });
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted || session != _cameraSession) return;
        setState(() {
          _isInitializing = false;
          _cameraErrorMessage = 'Geen camera gevonden op dit toestel.';
        });
        return;
      }

      _resolveLensIndices(cameras);

      final selectedIndex = preferredIndex ??
          (_standardBackCameraIndex ??
              cameras.indexWhere(
                (camera) => camera.lensDirection == CameraLensDirection.back,
              ));
      final resolvedIndex = selectedIndex >= 0 ? selectedIndex : 0;

      await _controller?.dispose();
      _controller = null;

      final controller = await _createInitializedController(cameras[resolvedIndex]);
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      await controller.setZoomLevel(minZoom);
      try {
        await controller.setFlashMode(
          _torchEnabled ? FlashMode.torch : FlashMode.off,
        );
      } catch (_) {
        _torchEnabled = false;
      }

      if (!mounted || session != _cameraSession) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameras = cameras;
        _cameraIndex = resolvedIndex;
        _controller = controller;
        _isInitializing = false;
        _cameraErrorMessage = null;
        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _zoomLevel = minZoom;
        _zoomSliderValue = _zoomToSlider(minZoom);
      });
    } catch (error) {
      if (!mounted || session != _cameraSession) return;
      setState(() {
        _isInitializing = false;
        _cameraErrorMessage = 'Camera starten mislukt: $error';
      });
    } finally {
      _cameraTransitionInProgress = false;
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isInitializing || _isSaving) {
      return;
    }
    final nextIndex = (_cameraIndex + 1) % _cameras.length;
    await _initializeCamera(preferredIndex: nextIndex);
  }

  Future<void> _switchToLensIndex(int? index) async {
    if (index == null || _isInitializing || _isSaving) {
      return;
    }
    if (index == _cameraIndex) {
      return;
    }
    await _initializeCamera(preferredIndex: index);
  }

  Future<void> _setZoom(double value) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final clamped = value.clamp(_minZoom, _maxZoom);
    await controller.setZoomLevel(clamped);
    if (!mounted) return;
    setState(() {
      _zoomLevel = clamped;
      _zoomSliderValue = _zoomToSlider(clamped);
    });
  }

  double _sliderToZoom(double sliderValue) {
    if (_maxZoom <= _minZoom) {
      return _minZoom;
    }
    final normalized = sliderValue.clamp(0.0, 1.0);
    final curved = math.pow(normalized, 2.2).toDouble();
    final zoom = _minZoom + (_maxZoom - _minZoom) * curved;
    return zoom.clamp(_minZoom, _maxZoom);
  }

  double _zoomToSlider(double zoomValue) {
    if (_maxZoom <= _minZoom) {
      return 0.0;
    }
    final normalized =
        ((zoomValue - _minZoom) / (_maxZoom - _minZoom)).clamp(0.0, 1.0);
    return math.pow(normalized, 1 / 2.2).toDouble();
  }

  Future<void> _setZoomFromSlider(double sliderValue) async {
    if (!mounted) return;
    setState(() {
      _zoomSliderValue = sliderValue;
    });
    await _setZoom(_sliderToZoom(sliderValue));
  }

  Future<void> _captureAndSave(String label) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isSaving) {
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      try {
        await controller.setFlashMode(
          _torchEnabled ? FlashMode.torch : FlashMode.off,
        );
      } catch (_) {}

      final image = await controller.takePicture();

      if (_torchEnabled) {
        try {
          await controller.setFlashMode(FlashMode.torch);
        } catch (_) {}
      }

      await _drawLabelOnImage(image.path, label);

      final albumName = widget.albumName;
      await PhotoLibraryService.saveImageToAddressAlbum(
        imagePath: image.path,
        addressAlbumName: albumName,
      );

      if (!mounted) return;
      setState(() {
        _lastSavedLabel = label;
        _savedLabels.add(_normalizeLabel(label));
      });
      widget.onPhotoSaved?.call();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij opslaan: $error')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _drawLabelOnImage(String imagePath, String label) async {
    final ok = await compute(
      _renderLabelOverlay,
      {'path': imagePath, 'label': label},
    );

    if (!ok) {
      throw Exception('Kon foto niet bewerken voor label-overlay');
    }
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isSaving) {
      return;
    }

    final nextState = !_torchEnabled;
    try {
      await controller.setFlashMode(nextState ? FlashMode.torch : FlashMode.off);
      if (!mounted) return;
      setState(() {
        _torchEnabled = nextState;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zaklamp niet beschikbaar op deze camera')),
      );
    }
  }

  Widget _buildLabelButton(String label) {
    final isSelected = _lastSavedLabel == label;
    final isEmptyLabel = label.trim().isEmpty;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? Colors.blue.shade700.withOpacity(0.70)
            : Colors.blue.shade500.withOpacity(0.55),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        elevation: 0,
        shadowColor: Colors.transparent,
        side: isEmptyLabel
            ? BorderSide(color: Colors.white.withOpacity(0.6), width: 1)
            : null,
      ),
      onPressed: (_isSaving || _isInitializing) ? null : () => _captureAndSave(label),
      child: isEmptyLabel
          ? const SizedBox(width: 48, height: 20)
          : Text(label, textAlign: TextAlign.center),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final hasPreview = controller != null && controller.value.isInitialized;
    final controlsHeight = math.min(170.0, MediaQuery.of(context).size.height * 0.24);

    return WillPopScope(
      onWillPop: _handleBackNavigation,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasPreview)
                        CameraPreview(controller!)
                      else
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isInitializing
                                      ? 'Camera wordt gestart...'
                                      : (_cameraErrorMessage ??
                                          'Camera niet beschikbaar'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _isInitializing
                                      ? null
                                      : () => _initializeCamera(
                                            preferredIndex: _cameraIndex,
                                          ),
                                  child: const Text('Opnieuw proberen'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: IconButton(
                          onPressed: _toggleTorch,
                          icon: Icon(
                            _torchEnabled ? Icons.flash_on : Icons.flash_off,
                            color: _torchEnabled ? Colors.amber : Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          onPressed: _switchCamera,
                          icon: const Icon(Icons.cameraswitch, color: Colors.white),
                        ),
                      ),
                      if (_torchEnabled)
                        Positioned(
                          top: 12,
                          left: 56,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flash_on, color: Colors.amber, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Zaklamp AAN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_isSaving)
                        const Center(
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: controlsHeight,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_ultraWideCameraIndex != null && _standardBackCameraIndex != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            OutlinedButton(
                              onPressed: (hasPreview && !_isSaving)
                                  ? () => _switchToLensIndex(_ultraWideCameraIndex)
                                  : null,
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    (_cameraIndex == _ultraWideCameraIndex)
                                        ? Colors.white.withOpacity(0.18)
                                        : Colors.transparent,
                              ),
                              child: const Text('0.5x'),
                            ),
                            OutlinedButton(
                              onPressed: (hasPreview && !_isSaving)
                                  ? () => _switchToLensIndex(_standardBackCameraIndex)
                                  : null,
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    (_cameraIndex == _standardBackCameraIndex)
                                        ? Colors.white.withOpacity(0.18)
                                        : Colors.transparent,
                              ),
                              child: const Text('1x'),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        const Icon(Icons.zoom_out),
                        Expanded(
                          child: Slider(
                            value: _zoomSliderValue,
                            min: 0.0,
                            max: 1.0,
                            onChanged: (hasPreview && !_isSaving)
                                ? _setZoomFromSlider
                                : null,
                          ),
                        ),
                        const Icon(Icons.zoom_in),
                      ],
                    ),
                    if (_lastSavedLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Laatst opgeslagen: $_lastSavedLabel',
                          style: TextStyle(
                            color: widget.accentColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: _requiredFacadeLabels
                            .map((label) => _buildCheckPill(label, _hasSavedLabel(label)))
                            .toList(),
                      ),
                    ),
                    Text(
                      'Locatie: ${widget.albumName}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: widget.labels.map(_buildLabelButton).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckPill(String label, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ok
            ? Colors.green.shade600.withOpacity(0.72)
            : Colors.grey.shade700.withOpacity(0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: ${ok ? '✅' : '❌'}',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}
