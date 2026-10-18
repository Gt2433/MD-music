import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Global persistent app background layer that supports:
/// 1. Default theme mode (Light / Dark / AMOLED)
/// 2. Custom arbitrary background color
/// 3. Custom gallery background image with blur, opacity, and base color bleed-through
class GlobalAppBackground extends StatelessWidget {
  const GlobalAppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        AppTheme.bgTypeNotifier,
        AppTheme.customBgColorNotifier,
        AppTheme.customBgImageNotifier,
        AppTheme.customBgBlurNotifier,
        AppTheme.customBgOpacityNotifier,
        AppTheme.themeModeNotifier,
        AppTheme.amoledBlackNotifier,
      ]),
      builder: (context, _) {
        final bgType = AppTheme.bgTypeNotifier.value;
        final customColor = AppTheme.customBgColorNotifier.value;
        final imagePath = AppTheme.customBgImageNotifier.value;
        final blur = AppTheme.customBgBlurNotifier.value;
        final opacity = AppTheme.customBgOpacityNotifier.value;
        final isDark = AppTheme.isDark;
        final isAmoled = AppTheme.amoledBlackNotifier.value;

        // Base underlying color
        final Color baseColor;
        if (bgType == 'color') {
          baseColor = customColor;
        } else if (isDark) {
          baseColor = isAmoled ? Colors.black : AppTheme.darkBackground;
        } else {
          baseColor = AppTheme.lightBackground;
        }

        // 1. If not image or image file does not exist, show base solid color
        if (bgType != 'image' || imagePath == null || imagePath.isEmpty) {
          return Container(
            color: baseColor,
          );
        }

        final file = File(imagePath);
        if (!file.existsSync()) {
          return Container(
            color: baseColor,
          );
        }

        // 2. Custom Image Background with Blur, Opacity & Base Color Bleed-Through
        return Container(
          color: baseColor,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The Image Layer with Opacity
              Opacity(
                opacity: opacity.clamp(0.05, 1.0),
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: baseColor),
                ),
              ),

              // The Hardware-Accelerated Blur Filter
              if (blur > 0.05)
                BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blur,
                    sigmaY: blur,
                  ),
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),

              // Subtle Protective Contrast Scrim for absolute legibility
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.35),
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.35),
                      Colors.black.withOpacity(0.60),
                    ],
                    stops: const [0.0, 0.25, 0.70, 1.0],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
