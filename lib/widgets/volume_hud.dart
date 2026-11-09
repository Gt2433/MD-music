import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/volume_service.dart';
import '../theme/app_theme.dart';

/// Ultra-smooth, minimalist floating capsule volume indicator (HUD)
/// Displays on hardware/software volume adjustment with refined glassmorphism,
/// smooth appearance/disappearance animations, and animated progress interpolation.
class VolumeHud extends StatefulWidget {
  const VolumeHud({super.key});

  @override
  State<VolumeHud> createState() => _VolumeHudState();
}

class _VolumeHudState extends State<VolumeHud> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  double _dragOffsetY = 0.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );

    // Smooth subtle slide from top (-28px to 0)
    _slideAnimation = Tween<double>(begin: -28.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    // Subtle scale expansion for a natural, tactile pop (0.86 to 1.0)
    _scaleAnimation = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    // Soft opacity fade
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    final volumeService = VolumeService();
    volumeService.isVisible.addListener(_handleVisibilityChange);
    if (volumeService.isVisible.value) {
      _animController.value = 1.0;
    }
  }

  void _handleVisibilityChange() {
    final visible = VolumeService().isVisible.value;
    if (visible) {
      setState(() {
        _dragOffsetY = 0.0;
      });
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  void dispose() {
    VolumeService().isVisible.removeListener(_handleVisibilityChange);
    _animController.dispose();
    super.dispose();
  }

  void _dismissUpwards() {
    VolumeService().dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final volumeService = VolumeService();
    final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;

    return ValueListenableBuilder<bool>(
      valueListenable: volumeService.isVisible,
      builder: (context, isVisible, _) {
        return ValueListenableBuilder<double>(
          valueListenable: volumeService.volume,
          builder: (context, volume, _) {
            final percentage = (volume * 100).round();

            Color accentColor;
            IconData volumeIcon;

            if (percentage == 0) {
              accentColor = const Color(0xFFFF5252);
              volumeIcon = Icons.volume_off_rounded;
            } else if (percentage <= 5) {
              accentColor = const Color(0xFF00E5FF);
              volumeIcon = Icons.volume_mute_rounded;
            } else if (percentage <= 35) {
              accentColor = const Color(0xFF26E07F);
              volumeIcon = Icons.volume_down_rounded;
            } else {
              accentColor = AppTheme.accentColor;
              volumeIcon = Icons.volume_up_rounded;
            }

            // Compact, elegant capsule width
            final capsuleWidth = (screenWidth * 0.60).clamp(215.0, 255.0);
            final targetTop = (topPadding > 0 ? topPadding + 10.0 : 22.0);

            return IgnorePointer(
              ignoring: !isVisible,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  if (_animController.value == 0.0 && !isVisible) {
                    return const SizedBox.shrink();
                  }

                  final effectiveTranslateY = _slideAnimation.value + _dragOffsetY;
                  final scale = _scaleAnimation.value;
                  final opacity = (_fadeAnimation.value *
                          (1.0 - (_dragOffsetY.abs() / 80.0).clamp(0.0, 0.95)))
                      .clamp(0.0, 1.0);

                  return Transform.translate(
                    offset: Offset(0, effectiveTranslateY),
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: targetTop),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Material(
                        color: Colors.transparent,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          // Swipe up to dismiss instantly
                          onVerticalDragUpdate: (details) {
                            if (details.delta.dy < 0 || _dragOffsetY < 0) {
                              setState(() {
                                _dragOffsetY =
                                    (_dragOffsetY + details.delta.dy).clamp(-100.0, 0.0);
                              });
                              if (_dragOffsetY <= -18) {
                                _dismissUpwards();
                              }
                            }
                          },
                          onVerticalDragEnd: (details) {
                            if (details.primaryVelocity != null &&
                                details.primaryVelocity! < -60) {
                              _dismissUpwards();
                            } else if (_dragOffsetY <= -14) {
                              _dismissUpwards();
                            } else {
                              setState(() {
                                _dragOffsetY = 0.0;
                              });
                            }
                          },
                          child: Container(
                            width: capsuleWidth,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(AppTheme.isDark ? 0.42 : 0.12),
                                  blurRadius: 18,
                                  offset: const Offset(0, 7),
                                ),
                                BoxShadow(
                                  color: accentColor.withOpacity(0.16),
                                  blurRadius: 14,
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 13),
                                  decoration: BoxDecoration(
                                    color: AppTheme.isDark
                                        ? const Color(0xDF0D1612)
                                        : Colors.white.withOpacity(0.92),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: (AppTheme.isDark ? Colors.white : Colors.black)
                                          .withOpacity(0.12),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // 1. Interactive Speaker Icon with Micro-animation
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          volumeService.toggleMute();
                                        },
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Center(
                                            child: AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 180),
                                              transitionBuilder: (child, anim) =>
                                                  ScaleTransition(scale: anim, child: child),
                                              child: Icon(
                                                volumeIcon,
                                                key: ValueKey<IconData>(volumeIcon),
                                                color: accentColor,
                                                size: 19,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      // 2. Smooth Gliding Interactive Volume Bar
                                      Expanded(
                                        child: LayoutBuilder(
                                          builder: (context, trackConstraints) {
                                            return GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onHorizontalDragUpdate: (details) {
                                                final trackWidth = trackConstraints.maxWidth;
                                                if (trackWidth > 0) {
                                                  final deltaFraction =
                                                      details.delta.dx / trackWidth;
                                                  final rawNext =
                                                      (volume + deltaFraction).clamp(0.0, 1.0);
                                                  volumeService.setVolume(rawNext);
                                                }
                                              },
                                              onTapDown: (details) {
                                                final trackWidth = trackConstraints.maxWidth;
                                                if (trackWidth > 0) {
                                                  final fraction = (details.localPosition.dx /
                                                          trackWidth)
                                                      .clamp(0.0, 1.0);
                                                  volumeService.setVolume(fraction);
                                                }
                                              },
                                              child: Container(
                                                height: 34,
                                                alignment: Alignment.center,
                                                child: Container(
                                                  height: 6.0,
                                                  decoration: BoxDecoration(
                                                    color: (AppTheme.isDark
                                                        ? Colors.white.withOpacity(0.12)
                                                        : Colors.black.withOpacity(0.08)),
                                                    borderRadius: BorderRadius.circular(3),
                                                  ),
                                                  child: TweenAnimationBuilder<double>(
                                                    tween: Tween<double>(
                                                      begin: 0.0,
                                                      end: volume.clamp(0.0, 1.0),
                                                    ),
                                                    duration: const Duration(milliseconds: 160),
                                                    curve: Curves.easeOutCubic,
                                                    builder: (context, animVolume, _) {
                                                      return Stack(
                                                        children: [
                                                          FractionallySizedBox(
                                                            widthFactor: animVolume,
                                                            child: Container(
                                                              decoration: BoxDecoration(
                                                                gradient: LinearGradient(
                                                                  colors: [
                                                                    accentColor,
                                                                    accentColor.withOpacity(0.85),
                                                                  ],
                                                                ),
                                                                borderRadius:
                                                                    BorderRadius.circular(3),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: accentColor
                                                                        .withOpacity(0.40),
                                                                    blurRadius: 6,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // 3. Crisp Percentage Text
                                      SizedBox(
                                        width: 36,
                                        child: Text(
                                          '$percentage%',
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: accentColor,
                                            fontSize: 13.0,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
