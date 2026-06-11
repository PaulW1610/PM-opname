import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/bag_service.dart';
import '../services/photo_library_service.dart';
import '../services/stability_logger_service.dart';
import '../services/volume_button_service.dart';

/// One choice in the camera label menu. When [subLabels] is non-empty, tapping
/// the button opens a submenu and the chosen sub-label becomes the photo label;
/// otherwise [label] itself is used directly.
class CameraLabelOption {
  /// The button text, and (when there is no submenu) the label burned onto the photo.
  final String label;

  /// Optional sub-options shown in a submenu (e.g. glass types).
  final List<String> subLabels;

  const CameraLabelOption(this.label, {this.subLabels = const []});

  bool get hasSubmenu => subLabels.isNotEmpty;
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
  // 50% larger than the previous scale of 1.3225.
  const textScale = 1.98;
  final textWidth = math.max(1, _stringWidth(font, text));
  final textHeight = math.max(1, img.findStringHeight(font, text));
  // Extra padding so the faux-bold offset copies are not clipped.
  final textLayer = img.Image(textWidth + 2, textHeight + 2);
  img.fill(textLayer, img.getColor(0, 0, 0, 0));

  // Draw the text several times with 1px offsets to thicken the strokes
  // (faux-bold), since the bundled bitmap font has no bold variant.
  const boldOffsets = <List<int>>[
    [0, 0],
    [1, 0],
    [0, 1],
    [1, 1],
  ];
  for (final offset in boldOffsets) {
    img.drawString(
      textLayer,
      font,
      offset[0],
      offset[1],
      text,
      color: img.getColor(255, 255, 255),
    );
  }

  final scaledTextLayer = img.copyResize(
    textLayer,
    width: math.max(1, (textLayer.width * textScale).round()),
    height: math.max(1, (textLayer.height * textScale).round()),
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
  final List<CameraLabelOption> labelOptions;
  final Color accentColor;
  final String albumName;
  final int initialPhotoNumber;
  final VoidCallback? onPhotoSaved;
  final bool showCustomLabelCaptureButton;
  final String customLabelButtonText;

  const TaggedCameraCaptureView({
    Key? key,
    required this.bagData,
    required this.labelOptions,
    required this.accentColor,
    required this.albumName,
    required this.initialPhotoNumber,
    this.onPhotoSaved,
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
  /// The label the user picked; non-null means we are in the full-screen
  /// capture step (one shutter button). Null means the label-selection step.
  String? _armedLabel;
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
    _loadRecentCustomLabels();
    _startVolumeButtonListener();
    _initializeCamera();
  }

  /// Luistert naar fysieke volumeknop-drukken om de sluiter te bedienen.
  StreamSubscription<void>? _volumeButtonSub;

  void _startVolumeButtonListener() {
    try {
      _volumeButtonSub = VolumeButtonService.presses
          .listen((_) => _onVolumeButtonPressed(), onError: (_) {});
    } catch (_) {}
  }

  void _onVolumeButtonPressed() {
    if (!mounted) return;
    // Volumeknop = sluiter, alleen op het opnamescherm (label gekozen) en
    // als de camera klaar is en er niet al een opname loopt.
    if (_armedLabel == null || _isSaving || _isInitializing) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _captureAndSave(_armedLabel!);
  }

  /// Recently used custom labels, most recent first. Persisted so the same
  /// text can be reused on the next photo (and after restarting the app).
  static const String _recentCustomLabelsKey = 'recent_custom_labels_v1';
  static const int _maxRecentCustomLabels = 12;
  List<String> _recentCustomLabels = const [];

  Future<void> _loadRecentCustomLabels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_recentCustomLabelsKey) ?? const [];
      if (!mounted) return;
      setState(() {
        _recentCustomLabels = stored;
      });
    } catch (_) {}
  }

  Future<void> _rememberCustomLabel(String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    final updated = <String>[trimmed];
    for (final existing in _recentCustomLabels) {
      if (existing.toLowerCase() == trimmed.toLowerCase()) continue;
      if (updated.length >= _maxRecentCustomLabels) break;
      updated.add(existing);
    }
    if (mounted) {
      setState(() {
        _recentCustomLabels = updated;
      });
    } else {
      _recentCustomLabels = updated;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentCustomLabelsKey, updated);
    } catch (_) {}
  }

  /// Remove one saved custom label so the list can be pruned to a good set.
  Future<void> _removeRecentCustomLabel(String label) async {
    final updated = _recentCustomLabels
        .where((l) => l.toLowerCase() != label.toLowerCase())
        .toList(growable: false);
    if (mounted) {
      setState(() {
        _recentCustomLabels = updated;
      });
    } else {
      _recentCustomLabels = updated;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentCustomLabelsKey, updated);
    } catch (_) {}
  }

  @override
  void dispose() {
    final controller = _controller;
    _cameraSession++;
    _controller = null;
    _volumeButtonSub?.cancel();
    _volumeButtonSub = null;
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

      // Lege label = foto zonder tekstbalk; sla de overlay dan over.
      if (label.trim().isNotEmpty) {
        await _drawLabelOnImage(image.path, label);
      }

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

  /// Ask for a free-text label and arm it (go to the capture step), instead of
  /// taking the photo immediately. Prefilled with the most recently used label.
  Future<void> _promptCustomLabelAndArm() async {
    if (_isSaving || _isInitializing) {
      return;
    }

    final lastLabel =
        _recentCustomLabels.isNotEmpty ? _recentCustomLabels.first : '';

    final enteredLabel = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _CustomLabelDialog(
        initialText: lastLabel,
        recentLabels: _recentCustomLabels,
        onDelete: _removeRecentCustomLabel,
      ),
    );

    final label = enteredLabel?.trim() ?? '';
    if (label.isEmpty) {
      return;
    }
    await _rememberCustomLabel(label);
    _armLabel(label);
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final hasPreview = controller != null && controller.value.isInitialized;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        // In the capture step, "back" returns to the label-selection step.
        if (_armedLabel != null) {
          setState(() => _armedLabel = null);
          return;
        }
        final shouldPop = await _handleBackNavigation();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCameraPreview(hasPreview),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _armedLabel == null
                    ? _buildSelectionOverlay(hasPreview)
                    : _buildCaptureOverlay(hasPreview),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Step 1: choose a label. The camera fills the screen so you can already frame.
  Widget _buildSelectionOverlay(bool hasPreview) {
    final enabled = hasPreview && !_isSaving && !_isInitializing;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.72)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: _requiredFacadeLabels
                .map((label) => _buildCheckPill(label, _hasSavedLabel(label)))
                .toList(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final option in widget.labelOptions)
                _buildOptionButton(option, enabled),
              if (widget.showCustomLabelCaptureButton)
                _buildCustomLabelButton(enabled),
              _buildNoLabelButton(enabled),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoLabelButton(bool enabled) {
    return OutlinedButton.icon(
      onPressed: enabled ? () => _armLabel('') : null,
      icon: const Icon(Icons.photo_camera),
      label: const Text('Foto zonder label'),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.45),
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white70),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildOptionButton(CameraLabelOption option, bool enabled) {
    final done = !option.hasSubmenu && _hasSavedLabel(option.label);
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.accentColor.withValues(alpha: 0.92),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      onPressed: enabled
          ? () =>
              option.hasSubmenu ? _openSubmenu(option) : _armLabel(option.label)
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done) ...[
            const Icon(Icons.check, size: 18),
            const SizedBox(width: 4),
          ],
          Text(option.label),
          if (option.hasSubmenu) ...[
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 18),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomLabelButton(bool enabled) {
    return OutlinedButton.icon(
      onPressed: enabled ? _promptCustomLabelAndArm : null,
      icon: const Icon(Icons.edit),
      label: Text(widget.customLabelButtonText),
      style: OutlinedButton.styleFrom(
        backgroundColor: const Color(0xFF006FAF),
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF005A90)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _openSubmenu(CameraLabelOption option) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1B1B1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Kies ${option.label.toLowerCase()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final sub in option.subLabels)
              ListTile(
                title: Text(
                  sub,
                  style: const TextStyle(color: Colors.white, fontSize: 17),
                ),
                trailing: _hasSavedLabel(sub)
                    ? const Icon(Icons.check, color: Colors.greenAccent)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(sub),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null && chosen.isNotEmpty) {
      _armLabel(chosen);
    }
  }

  void _armLabel(String label) {
    if (!mounted) return;
    setState(() => _armedLabel = label);
  }

  /// Step 2: full-screen camera with one shutter button for the chosen label.
  Widget _buildCaptureOverlay(bool hasPreview) {
    final canShoot = hasPreview && !_isSaving && !_isInitializing;
    final lensIndices = _orderedLensIndices();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.72)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _armedLabel!.isEmpty
                  ? 'FOTO (GEEN LABEL)'
                  : _armedLabel!.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (lensIndices.isNotEmpty)
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final lensIndex in lensIndices)
                  OutlinedButton(
                    onPressed:
                        canShoot ? () => _switchToLensIndex(lensIndex) : null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _cameraIndex == lensIndex
                          ? Colors.white.withValues(alpha: 0.20)
                          : Colors.black.withValues(alpha: 0.30),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                      padding:
                          const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    ),
                    child: Text(_cameraLabel(lensIndex)),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 92,
                child: TextButton.icon(
                  onPressed: () => setState(() => _armedLabel = null),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: const Text('Terug',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: canShoot ? () => _captureAndSave(_armedLabel!) : null,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white
                            .withValues(alpha: canShoot ? 1.0 : 0.4),
                        border: Border.all(color: widget.accentColor, width: 5),
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 34,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 92,
                child: Text(
                  'foto #$_nextPhotoNumber',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tip: de volumeknop maakt ook een foto',
            style: TextStyle(color: Colors.white70, fontSize: 12),
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

/// Dialog for entering a custom photo label, with quick-pick chips for
/// previously used labels. Owns its own [TextEditingController] so its
/// lifecycle is managed correctly (disposed only after the dialog is gone).
class _CustomLabelDialog extends StatefulWidget {
  final String initialText;
  final List<String> recentLabels;

  /// Called when the user removes a saved label (to prune the list).
  final void Function(String label)? onDelete;

  const _CustomLabelDialog({
    required this.initialText,
    required this.recentLabels,
    this.onDelete,
  });

  @override
  State<_CustomLabelDialog> createState() => _CustomLabelDialogState();
}

class _CustomLabelDialogState extends State<_CustomLabelDialog> {
  late final TextEditingController _controller;
  late List<String> _recent;

  @override
  void initState() {
    super.initState();
    _recent = List<String>.from(widget.recentLabels);
    _controller = TextEditingController(text: widget.initialText);
    // Select the prefilled text so it is easy to overwrite by typing.
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialText.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _useRecent(String recent) {
    _controller.text = recent;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: recent.length),
    );
  }

  void _deleteRecent(String recent) {
    setState(() => _recent.remove(recent));
    widget.onDelete?.call(recent);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Label invoeren'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Bijv. Meterkast',
              ),
              onSubmitted: (_) =>
                  Navigator.of(context).pop(_controller.text),
            ),
            if (_recent.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Eerder gebruikt (tik = kiezen, ✕ = verwijderen):'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _recent
                    .map(
                      (recent) => InputChip(
                        label: Text(recent),
                        onPressed: () => _useRecent(recent),
                        onDeleted: widget.onDelete == null
                            ? null
                            : () => _deleteRecent(recent),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuleren'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
