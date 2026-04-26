import 'package:flutter/material.dart';

import '../services/bag_service.dart';
import '../widgets/pm_branding_header.dart';
import '../widgets/tagged_camera_capture_view.dart';

class UtiiteitScreen extends StatelessWidget {
  final BagData bagData;
  final String albumName;
  final int initialPhotoNumber;
  final VoidCallback? onPhotoSaved;

  const UtiiteitScreen({
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
                  'Gezondheid',
                  'Hotel',
                  'Kantoor',
                  'Winkel',
                  'Hulpfunctie',
                ],
                accentColor: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
