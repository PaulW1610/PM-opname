// Genereert een vierkant app-icoon (1024x1024) uit de blueprint collective-
// huisstijl: de merk-gradient als achtergrond + het woordmerk gecentreerd in wit.
//
// Bronnen (uit map logos/):
//   - logos/_extract/op_verloop.png   -> kleuren van de gradient (hoeken)
//   - logos/_extract/Logo_blueprintcollective_dia.png -> woordmerk (transparant)
//
// Uitvoer: assets/icon.png
//
// Draaien:  dart run tool/make_icon.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  final gradientSrc =
      img.decodeImage(File('logos/_extract/op_verloop.png').readAsBytesSync())!;
  final wordmarkSrc = img.decodeImage(
      File('logos/_extract/Logo_blueprintcollective_dia.png')
          .readAsBytesSync())!;

  // Gradient-eindkleuren samplen uit de hoeken van het huisstijlbeeld.
  final c0 = gradientSrc.getPixel(0, 0); // licht blauw (linksboven)
  final c1 = gradientSrc.getPixel(
      gradientSrc.width - 1, gradientSrc.height - 1); // donker navy (rechtsonder)
  final r0 = img.getRed(c0), g0 = img.getGreen(c0), b0 = img.getBlue(c0);
  final r1 = img.getRed(c1), g1 = img.getGreen(c1), b1 = img.getBlue(c1);

  // 1) Diagonale gradient tekenen.
  final icon = img.Image(size, size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final t = (x + y) / (2 * (size - 1));
      final r = (r0 + (r1 - r0) * t).round();
      final g = (g0 + (g1 - g0) * t).round();
      final b = (b0 + (b1 - b0) * t).round();
      icon.setPixel(x, y, img.getColor(r, g, b));
    }
  }

  // 2) Woordmerk omkleuren naar wit (alpha behouden voor scherpe randen).
  final whiteMark = img.Image(wordmarkSrc.width, wordmarkSrc.height);
  for (var y = 0; y < wordmarkSrc.height; y++) {
    for (var x = 0; x < wordmarkSrc.width; x++) {
      final a = img.getAlpha(wordmarkSrc.getPixel(x, y));
      whiteMark.setPixel(x, y, img.getColor(255, 255, 255, a));
    }
  }

  // 3) Schalen naar ~78% breedte met marge en centreren.
  final targetW = (size * 0.78).round();
  final targetH =
      (whiteMark.height * targetW / whiteMark.width).round();
  final scaled = img.copyResize(
    whiteMark,
    width: targetW,
    height: math.max(1, targetH),
    interpolation: img.Interpolation.cubic,
  );
  final dstX = ((size - scaled.width) / 2).round();
  final dstY = ((size - scaled.height) / 2).round();
  img.copyInto(icon, scaled, dstX: dstX, dstY: dstY, blend: true);

  File('assets/icon.png').writeAsBytesSync(img.encodePng(icon));
  stdout.writeln('assets/icon.png geschreven (${size}x$size).');
}
