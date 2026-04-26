import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

import '../services/bag_service.dart';
import '../services/photo_library_service.dart';
import '../services/stability_logger_service.dart';

enum CameraControlsLayout {
  bottom,
  right,
}

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
  const textScale = 1.15;
  final textWidth = math.max(1, _stringWidth(font, text));
  final textHeight = math.max(1, img.findStringHeight(font, text));
  final textLayer = img.Image(textWidth, textHeight);
  img.fill(textLayer, img.getColor(0, 0, 0, 0));

  img.drawString(
    textLayer,
    font,
    0,
    0,
    text,
    color: img.getColor(255, 255, 255),
  );

  final scaledTextLayer = img.copyResize(
    textLayer,
    width: math.max(1, (textWidth * textScale).round()),
    height: math.max(1, (textHeight * textScale).round()),
    interpolation: img.Interpolation.linear,
  );

  final textX = 20;
  final int textY = barTop + math.max(8, (barHeight - scaledTextLayer.height) ~/ 2);
  img.copyInto(decoded, scaledTextLayer, dstX: textX, dstY: textY, blend: true);

  final encoded = img.encodeJpg(decoded, quality: 92);
  file.writeAsBytesSync(encoded, flush: true);
  return true;
}

int _stringWidth(img.BitmapFont font, String value) {
  var width = 0;
  for (final codePoint in value.codeUnits) {
    final character = font.characters[codePoint];
    if (character == null) {
      width += font.base ~/ 2;
      continue;
    }
    width += character.xadvance;
  }
  return width;
}

class TaggedCameraCaptureView extends StatefulWidget {
  final BagData bagData;
  final List<String> labels;
  final Color accentColor;
  final String albumName;
  final int initialPhotoNumber;
  final VoidCallback? onPhotoSaved;
  final CameraControlsLayout controlsLayout;
  final double controlsOpacity;
  final bool transparentLabelButtons;
  final bool compactLabelButtons;
  final double labelButtonBlueOpacity;
  final bool showCustomLabelCaptureButton;
  final String customLabelButtonText;

  const TaggedCameraCaptureView({
    Key? key,
    required this.bagData,
    required this.labels,
    required this.accentColor,
    required this.albumName,
    required this.initialPhotoNumber,
    this.onPhotoSaved,
    this.controlsLayout = CameraControlsLayout.bottom,
    this.controlsOpacity = 1.0,
    this.transparentLabelButtons = false,
    this.compactLabelButtons = false,
    this.labelButtonBlueOpacity = 0.0,
    this.showCustomLabelCaptureButton = false,
    this.customLabelButtonText = 'Eigen label',
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
  bool _torchEnabled = false;
  double _pinchStartZoom = 1.0;
  List<int> _backCameraIndices = const [];
  late int _nextPhotoNumber;
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

  String _lensTypeForName(String rawName) {
    final name = rawName.toLowerCase();
    if (name.contains('ultra_wide') ||
        name.contains('ultra-wide') ||
        name.contains('ultra wide') ||
        name.contains('0.5x') ||
        name.contains('0,5x') ||
        name.contains('0.5') ||
        name.contains('0,5') ||
        name.contains('built_in_ultra_wide')) {
      return 'ultra';
    }
    if (name.contains('telephoto') ||
        name.contains('tele_photo') ||
        name.contains('built_in_telephoto') ||
        name.contains(' tele')) {
      return 'tele';
    }
    if (name.contains('wide_angle') ||
        name.contains('wide-angle') ||
        name.contains('wide angle') ||
        name.contains('built_in_wide_angle')) {
      return 'wide';
    }
    return 'other';
  }

  int _lensTypePriority(String lensType) {
    switch (lensType) {
      case 'ultra':
        return 0;
      case 'wide':
        return 1;
      case 'tele':
        return 2;
      default:
        return 9;
    }
  }

  void _resolveLensIndices(List<CameraDescription> cameras) {
    int? standardIndex;
    int? ultraIndex;
    final backIndices = <int>[];

    for (var i = 0; i < cameras.length; i++) {
      final camera = cameras[i];
      if (camera.lensDirection != CameraLensDirection.back) {
        continue;
      }
      backIndices.add(i);
      final lensType = _lensTypeForName(camera.name);

      if (lensType == 'ultra') {
        ultraIndex ??= i;
      } else if (lensType == 'wide') {
        standardIndex ??= i;
      }

      standardIndex ??= i;
    }

    backIndices.sort((left, right) {
      final leftType = _lensTypeForName(cameras[left].name);
      final rightType = _lensTypeForName(cameras[right].name);
      final byType =
          _lensTypePriority(leftType).compareTo(_lensTypePriority(rightType));
      if (byType != 0) {
        return byType;
      }
      return left.compareTo(right);
    });

    _backCameraIndices = backIndices;
    _standardBackCameraIndex = standardIndex ?? ultraIndex;
    _ultraWideCameraIndex = ultraIndex ?? (backIndices.length >= 2 ? backIndices.first : null);
  }

  String _cameraLabel(int index) {
    if (index < 0 || index >= _cameras.length) {
      return 'Lens';
    }
    if (index == 3) {
      return '0.5';
    }
    if (index == 2) {
      return '1.0';
    }
    if (index == 0) {
      return '1.5';
    }
    final camera = _cameras[index];
    final name = camera.name.toLowerCase();
    if (name.contains('ultra') || name.contains('0.5')) {
      return '0.5x';
    }
    if (name.contains('tele') || name.contains('2x') || name.contains('3x')) {
      return 'Tele';
    }
    if (name.contains('wide')) {
      return '1x';
    }
    return 'Lens ${index + 1}';
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
    _nextPhotoNumber = widget.initialPhotoNumber < 1 ? 1 : widget.initialPhotoNumber;
    WidgetsBinding.instance.addObserver(this);
    StabilityLoggerService.addBreadcrumb('camera_view_init');
    _initializeCamera();
  }

  @override
  void dispose() {
    final controller = _controller;
    _cameraSession++;
    _controller = null;
    WidgetsBinding.instance.removeObserver(this);
    StabilityLoggerService.addBreadcrumb('camera_view_dispose');
    controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    StabilityLoggerService.addBreadcrumb('app_lifecycle:$state');
    final controller = _controller;
    if (state == AppLifecycleState.inactive) {
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (controller != null) {
        _cameraSession++;
        controller.dispose();
        _controller = null;
      }
      if (mounted) {
        setState(() {
          _isInitializing = true;
        });
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final current = _controller;
      if (current != null && current.value.isInitialized) {
        return;
      }
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
      await StabilityLoggerService.recordEvent(
        'camera_initialize_start',
        data: {'preferredIndex': preferredIndex},
      );
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
          (_ultraWideCameraIndex ??
              _standardBackCameraIndex ??
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
      });
      await StabilityLoggerService.recordEvent(
        'camera_initialize_success',
        data: {
          'resolvedIndex': resolvedIndex,
          'cameraCount': cameras.length,
          'minZoom': minZoom,
          'maxZoom': maxZoom,
        },
      );
    } catch (error) {
      await StabilityLoggerService.recordException(
        error,
        StackTrace.current,
        context: 'camera_initialize',
      );
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
    });
  }

  List<int> _orderedLensIndices() {
    if (_backCameraIndices.isEmpty) {
      return const [];
    }
    const preferred = [3, 2, 0];
    final ordered = <int>[];
    for (final index in preferred) {
      if (_backCameraIndices.contains(index)) {
        ordered.add(index);
      }
    }
    for (final index in _backCameraIndices) {
      if (!ordered.contains(index)) {
        ordered.add(index);
      }
    }
    return ordered;
  }


  void _onScaleStart(ScaleStartDetails details) {
    _pinchStartZoom = _zoomLevel;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) {
      return;
    }
    final scale = details.scale;
    if (scale <= 0) {
      return;
    }
    final candidate = _pinchStartZoom * scale;
    _setZoom(candidate);
  }

  Future<void> _captureAndSave(String label) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isSaving) {
      return;
    }

    try {
      await StabilityLoggerService.recordEvent(
        'camera_capture_start',
        data: {'label': label},
      );
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
      final photoNumber = _nextPhotoNumber;
      await PhotoLibraryService.saveImageToAddressAlbum(
        imagePath: image.path,
        addressAlbumName: albumName,
        photoFilePrefix: widget.bagData.getPhotoFilePrefix(),
        photoSequenceNumber: photoNumber,
      );

      if (!mounted) return;
      setState(() {
        _lastSavedLabel = label;
        _savedLabels.add(_normalizeLabel(label));
        _nextPhotoNumber = photoNumber + 1;
      });
      await StabilityLoggerService.recordEvent(
        'camera_capture_saved',
        data: {'label': label},
      );
      widget.onPhotoSaved?.call();
    } catch (error) {
      await StabilityLoggerService.recordException(
        error,
        StackTrace.current,
        context: 'camera_capture_save',
      );
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

  Future<void> _captureWithCustomLabel() async {
    if (_isSaving || _isInitializing) {
      return;
    }

    final textController = TextEditingController();
    final enteredLabel = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Label invoeren'),
        content: TextField(
          controller: textController,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'Bijv. Meterkast',
          ),
          onSubmitted: (_) => Navigator.of(dialogContext).pop(textController.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(textController.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    final label = enteredLabel?.trim() ?? '';
    if (label.isEmpty) {
      return;
    }
    await _captureAndSave(label);
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
      await StabilityLoggerService.recordEvent(
        'camera_torch_toggle',
        data: {'enabled': nextState},
      );
    } catch (_) {
      await StabilityLoggerService.recordEvent('camera_torch_unavailable');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zaklamp niet beschikbaar op deze camera')),
      );
    }
  }

  Widget _buildLabelButton(String label) {
    final isSelected = _lastSavedLabel == label;
    final isEmptyLabel = label.trim().isEmpty;
    final opacity = widget.controlsOpacity.clamp(0.0, 1.0).toDouble();
    final compact = widget.compactLabelButtons;
    final transparent = widget.transparentLabelButtons;
    final blueOpacity = widget.labelButtonBlueOpacity.clamp(0.0, 1.0).toDouble();
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: transparent
        ? Colors.blue.withValues(alpha: blueOpacity)
            : (isSelected
                ? Colors.blue.shade700.withValues(alpha: opacity)
                : Colors.blue.shade500.withValues(alpha: opacity)),
        foregroundColor: Colors.white,
        padding: compact
          ? const EdgeInsets.symmetric(vertical: 6, horizontal: 8)
            : const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        minimumSize: compact ? const Size(0, 36) : null,
        tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
        visualDensity: compact ? VisualDensity.compact : null,
        elevation: 0,
        shadowColor: Colors.transparent,
        side: BorderSide(
          color: (isSelected ? widget.accentColor : Colors.white).withValues(
            alpha: transparent ? opacity : (isEmptyLabel ? 0.6 : 0.0),
          ),
          width: transparent || isEmptyLabel ? 1 : 0,
        ),
      ),
      onPressed: (_isSaving || _isInitializing) ? null : () => _captureAndSave(label),
      child: isEmptyLabel
          ? SizedBox(width: compact ? 33 : 48, height: compact ? 17 : 20)
          : Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: compact ? 14 : null),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final hasPreview = controller != null && controller.value.isInitialized;
    final controlsHeight = math.min(170.0, MediaQuery.of(context).size.height * 0.24);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldPop = await _handleBackNavigation();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: widget.controlsLayout == CameraControlsLayout.right
            ? _buildRightControlsLayout(hasPreview)
            : _buildBottomControlsLayout(hasPreview, controlsHeight),
      ),
    );
  }

  Widget _buildBottomControlsLayout(bool hasPreview, double controlsHeight) {
    return Column(
      children: [
        Expanded(child: _buildCameraPreview(hasPreview)),
        const SizedBox(height: 6),
        SizedBox(
          height: controlsHeight,
          child: SingleChildScrollView(
            child: _buildControlsContent(hasPreview, stackedButtons: false),
          ),
        ),
      ],
    );
  }

  Widget _buildRightControlsLayout(bool hasPreview) {
    final maxWidth = MediaQuery.of(context).size.width;
    final panelWidth = (maxWidth * 0.42).clamp(210.0, 320.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraPreview(hasPreview),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: panelWidth,
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(10),
              child: SingleChildScrollView(
                child: _buildControlsContent(hasPreview, stackedButtons: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview(bool hasPreview) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasPreview)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                child: CameraPreview(_controller!),
              )
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
                            : (_cameraErrorMessage ?? 'Camera niet beschikbaar'),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
  }

  Widget _buildControlsContent(bool hasPreview, {required bool stackedButtons}) {
    final orderedLensIndices = _orderedLensIndices();
    return Column(
      crossAxisAlignment:
          stackedButtons ? CrossAxisAlignment.end : CrossAxisAlignment.center,
      children: [
        if (orderedLensIndices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: stackedButtons
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: orderedLensIndices
                        .map(
                          (lensIndex) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: OutlinedButton(
                              onPressed: (hasPreview && !_isSaving)
                                  ? () => _switchToLensIndex(lensIndex)
                                  : null,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: (_cameraIndex == lensIndex)
                                    ? Colors.white.withValues(alpha: 0.18)
                                    : Colors.transparent,
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(_cameraLabel(lensIndex)),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  )
                : Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: orderedLensIndices.map((lensIndex) {
                      return OutlinedButton(
                        onPressed: (hasPreview && !_isSaving)
                            ? () => _switchToLensIndex(lensIndex)
                            : null,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: (_cameraIndex == lensIndex)
                              ? Colors.white.withValues(alpha: 0.18)
                              : Colors.transparent,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                        ),
                        child: Text(_cameraLabel(lensIndex)),
                      );
                    }).toList(growable: false),
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
        const SizedBox(height: 2),
        if (stackedButtons)
          Column(
            children: widget.labels
                .map(
                  (label) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildLabelButton(label),
                  ),
                )
                .toList(),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: widget.labels.map(_buildLabelButton).toList(),
          ),
        if (widget.showCustomLabelCaptureButton)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: (hasPreview && !_isSaving)
                  ? _captureWithCustomLabel
                  : null,
              icon: const Icon(Icons.edit),
              label: Text(widget.customLabelButtonText),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFF006FAF),
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: const Color(0xFF005A90),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCheckPill(String label, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ok
            ? Colors.green.shade600.withValues(alpha: 0.72)
            : Colors.grey.shade700.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: ${ok ? '✅' : '❌'}',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}
