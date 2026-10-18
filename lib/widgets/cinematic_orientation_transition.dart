import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Cinematic Orientation Transition for MDmusic
/// Orchestrates a luxury movie-studio transition when switching to Landscape mode:
/// 1. Fade to pure pitch black (#000000)
/// 2. MDmusic emblem scales & fades into the void with soft light pulse
/// 3. "MDmusic" typography reveals with theatrical letter spacing
/// 4. 3D perspective flip and 90-degree rotation
/// 5. Precise orientation switch to Landscape
/// 6. Smooth fade-out of black screen to reveal MBD Vinyl Cinema player
class CinematicOrientationTransition extends StatefulWidget {
  final VoidCallback onOrientationChangeTrigger;
  final VoidCallback onFinished;

  const CinematicOrientationTransition({
    super.key,
    required this.onOrientationChangeTrigger,
    required this.onFinished,
  });

  @override
  State<CinematicOrientationTransition> createState() =>
      _CinematicOrientationTransitionState();
}

class _CinematicOrientationTransitionState
    extends State<CinematicOrientationTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _blackOverlayIn;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _rotation3D;
  late final Animation<double> _flipY;
  late final Animation<double> _elementsExitScale;
  late final Animation<double> _elementsExitOpacity;
  late final Animation<double> _blackOverlayOut;

  bool _orientationTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2050),
    );

    // 1. Fade to Black: 0% -> 18% (0ms - 370ms)
    _blackOverlayIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.18, curve: Curves.easeInOut),
      ),
    );

    // 2. Logo In (Scale + Fade): 16% -> 44% (330ms - 900ms)
    _logoScale = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.16, 0.44, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.16, 0.36, curve: Curves.easeOut),
      ),
    );

    // 3. Typography "MDmusic" In: 36% -> 58% (740ms - 1190ms)
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.36, 0.58, curve: Curves.easeOut),
      ),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.36, 0.58, curve: Curves.easeOutCubic),
      ),
    );

    // 4. 3D Perspective Rotation & Exit: 58% -> 82% (1190ms - 1680ms)
    // Rotates 90 degrees (pi / 2) with perspective depth
    _rotation3D = Tween<double>(begin: 0.0, end: math.pi / 2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.58, 0.82, curve: Curves.easeInOutCubic),
      ),
    );
    // Subtle 3D Y-axis flip sensation
    _flipY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.32)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.32, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.58, 0.82),
      ),
    );

    _elementsExitScale = Tween<double>(begin: 1.0, end: 0.72).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.64, 0.82, curve: Curves.easeInOut),
      ),
    );

    _elementsExitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.70, 0.82, curve: Curves.easeIn),
      ),
    );

    // 5. Fade from Black to Landscape: 82% -> 100% (1680ms - 2050ms)
    _blackOverlayOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.82, 1.0, curve: Curves.easeOut),
      ),
    );

    // Listen for orientation change timing at ~68% into animation
    _controller.addListener(() {
      if (!_orientationTriggered && _controller.value >= 0.70) {
        _orientationTriggered = true;
        widget.onOrientationChangeTrigger();
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished();
      }
    });

    // Start cinematic sequence
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Compute black background opacity: fades in at start, fades out at end
        double bgOpacity;
        if (_controller.value < 0.82) {
          bgOpacity = _blackOverlayIn.value;
        } else {
          bgOpacity = _blackOverlayOut.value;
        }

        final combinedOpacity = (_logoOpacity.value * _elementsExitOpacity.value)
            .clamp(0.0, 1.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Pure Pitch Black Background (#000000)
            Container(
              color: Colors.black.withOpacity(bgOpacity),
            ),

            // 2. Cinematic Center Stage
            if (combinedOpacity > 0.01)
              Center(
                child: Opacity(
                  opacity: combinedOpacity,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0016) // Perspective depth
                      ..rotateZ(_rotation3D.value) // 90-degree cinematic rotation
                      ..rotateY(_flipY.value) // 3D depth flip
                      ..scale(_logoScale.value * _elementsExitScale.value),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // MDmusic Emblem with Ambient Accent Pulse
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accent.withOpacity(0.42),
                                blurRadius: 36,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.85),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Cinematic "MDmusic" Typography
                        Opacity(
                          opacity: _textOpacity.value,
                          child: SlideTransition(
                            position: _textSlide,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      'MD',
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2.0,
                                        shadows: [
                                          Shadow(
                                            color: accent.withOpacity(0.85),
                                            blurRadius: 22,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'music',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 3.5,
                                        shadows: [
                                          Shadow(
                                            color: Colors.white.withOpacity(0.4),
                                            blurRadius: 18,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'VINYL CINEMA',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.45),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 5.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
