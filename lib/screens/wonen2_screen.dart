import 'package:flutter/material.dart';

import '../services/bag_service.dart';
import '../widgets/pm_branding_header.dart';
import '../widgets/tagged_camera_capture_view.dart';

class Wonen2Screen extends StatelessWidget {
  final BagData bagData;
  final String albumName;
  final int initialPhotoNumber;
  final VoidCallback? onPhotoSaved;

  const Wonen2Screen({
    Key? key,
    required this.bagData,
    required this.albumName,
    required this.initialPhotoNumber,
    this.onPhotoSaved,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PmBrandingHeader(showBackButton: true),
            Expanded(
              child: TaggedCameraCaptureView(
                bagData: bagData,
                albumName: albumName,
                initialPhotoNumber: initialPhotoNumber,
                onPhotoSaved: onPhotoSaved,
                controlsLayout: CameraControlsLayout.right,
                controlsOpacity: 0.60,
                transparentLabelButtons: true,
                compactLabelButtons: true,
                labelButtonBlueOpacity: 0.25,
                showCustomLabelCaptureButton: true,
                customLabelButtonText: 'Eigen label foto',
                labels: const [
                  '',
                  'Achtergevel',
                  'Voorgevel',
                  'Ventilatie',
                  'CV',
                  'Enkel Glas',
                  'Dubbel Glas',
                  'HR Glas',
                  'HR+ Glas',
                  'HR++ Glas',
                ],
                accentColor: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
