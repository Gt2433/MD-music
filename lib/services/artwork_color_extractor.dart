import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Service to extract the most vibrant and prominent color from song album artwork
/// for dynamic ambient glow halos matching the song's cover rather than the app theme.
class ArtworkColorExtractor {
  static final Map<int, Color> _cache = {};

  static Color? getCachedColor(int songId) => _cache[songId];

  static Future<Color?> extract(int songId, Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty) return null;
    if (_cache.containsKey(songId)) return _cache[songId];

    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 32,
        targetHeight: 32,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;
      final pixels = byteData.buffer.asUint8List();

      double bestScore = -1.0;
      Color? bestColor;
      int totalR = 0, totalG = 0, totalB = 0, count = 0;

      for (int i = 0; i < pixels.length; i += 4) {
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];
        final a = pixels[i + 3];
        if (a < 120) continue;

        totalR += r;
        totalG += g;
        totalB += b;
        count++;

        final hsv = HSVColor.fromColor(Color.fromARGB(255, r, g, b));
        // Skip near-black and near-white/desaturated
        if (hsv.value > 0.16 && hsv.value < 0.98 && hsv.saturation > 0.18) {
          // Weight towards rich saturation and balanced brightness
          final score =
              (hsv.saturation * 2.2) + (1.0 - (hsv.value - 0.58).abs());
          if (score > bestScore) {
            bestScore = score;
            bestColor = Color.fromARGB(255, r, g, b);
          }
        }
      }

      final result = bestColor ??
          (count > 0
              ? Color.fromARGB(
                  255, totalR ~/ count, totalG ~/ count, totalB ~/ count)
              : null);

      if (result != null) {
        _cache[songId] = result;
      }
      return result;
    } catch (e) {
      debugPrint('Error extracting artwork color: $e');
      return null;
    }
  }
}
