import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final iconFile = File('assets/icon.png');
  if (!iconFile.existsSync()) {
    stderr.writeln('assets/icon.png not found');
    exit(1);
  }

  final source = img.decodeImage(iconFile.readAsBytesSync());
  if (source == null) {
    stderr.writeln('Failed to decode assets/icon.png');
    exit(1);
  }

  const zoomFactor = 1.12;
  final cropWidth = (source.width / zoomFactor).round();
  final cropHeight = (source.height / zoomFactor).round();
  final cropX = ((source.width - cropWidth) / 2).round();
  final cropY = ((source.height - cropHeight) / 2).round();

  final cropped = img.copyCrop(source, cropX, cropY, cropWidth, cropHeight);
  final resized = img.copyResize(cropped, width: source.width, height: source.height);

  iconFile.writeAsBytesSync(img.encodePng(resized), flush: true);
  stdout.writeln('Icon scaled up by ${(zoomFactor * 100).round()}%');
}
