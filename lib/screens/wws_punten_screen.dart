import 'package:flutter/material.dart';

import '../services/bag_service.dart';
import '../widgets/pm_branding_header.dart';
import '../widgets/tagged_camera_capture_view.dart';

class WwsPuntenScreen extends StatelessWidget {
  final BagData bagData;
  final String albumName;
  final int initialPhotoNumber;
  final VoidCallback? onPhotoSaved;

  const WwsPuntenScreen({
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
                labels: const [
                  '',
                  'Achtergevel',
                  'Voorgevel',
                  'Ventilatie',
                  'CV',
                  'Badkamer',
                  'Keuken',
                  'Verwarmde Hal',
                  'Berging',
                  'Tuin',
                ],
                accentColor: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
