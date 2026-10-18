import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/volume_service.dart';
import '../theme/app_theme.dart';

class VolumeHud extends StatefulWidget {
  const VolumeHud({super.key});

  @override
  State<VolumeHud> createState() => _VolumeHudState();
}

class _VolumeHudState extends State<VolumeHud> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  double _dragOffsetY = 0.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );

    _slideAnimation = Tween<double>(begin: -1.2, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );

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

            final hudWidth = (screenWidth - 36).clamp(300.0, 420.0);
            final targetTop = (topPadding > 0 ? topPadding + 8 : 24.0);

            return IgnorePointer(
              ignoring: !isVisible,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  if (_animController.value == 0.0 && !isVisible) {
                    return const SizedBox.shrink();
                  }

                  // Slide down translation + interactive upward swipe drag translation
                  final baseSlideY = _slideAnimation.value * (targetTop + 100);
                  final effectiveTranslateY = baseSlideY + _dragOffsetY;

                  return Transform.translate(
                    offset: Offset(0, effectiveTranslateY),
                    child: Opacity(
                      opacity: (_fadeAnimation.value * (1.0 - (_dragOffsetY.abs() / 120.0).clamp(0.0, 0.95))).clamp(0.0, 1.0),
                      child: child,
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
                        // Swipe / Drag upwards to dismiss
                        onVerticalDragUpdate: (details) {
                          if (details.delta.dy < 0 || _dragOffsetY < 0) {
                            setState(() {
                              _dragOffsetY = (_dragOffsetY + details.delta.dy).clamp(-180.0, 0.0);
                            });
                            // If dragged up by more than 22 pixels, dismiss immediately
                            if (_dragOffsetY <= -22) {
                              _dismissUpwards();
                            }
                          }
                        },
                        onVerticalDragEnd: (details) {
                          if (details.primaryVelocity != null && details.primaryVelocity! < -80) {
                            _dismissUpwards();
                          } else if (_dragOffsetY <= -15) {
                            _dismissUpwards();
                          } else {
                            // Bounce back if user didn't pull up far enough
                            setState(() {
                              _dragOffsetY = 0.0;
                            });
                          }
                        },
                        child: Container(
                          width: hudWidth,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(AppTheme.isDark ? 0.60 : 0.18),
                                blurRadius: 32,
                                offset: const Offset(0, 14),
                              ),
                              BoxShadow(
                                color: accentColor.withOpacity(0.16),
                                blurRadius: 24,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                                decoration: BoxDecoration(
                                  // Luxury frosted glass blurry tint
                                  color: AppTheme.isDark
                                      ? const Color(0xFF0C1712).withOpacity(0.82)
                                      : Colors.white.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(
                                    color: (AppTheme.isDark ? Colors.white : Colors.black).withOpacity(0.14),
                                    width: 1.2,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Top Swipe-Up Dismiss Handle Indicator
                                    InkWell(
                                      onTap: _dismissUpwards,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 20),
                                        child: Container(
                                          width: 38,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: (AppTheme.isDark ? Colors.white : Colors.black).withOpacity(0.24),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    // Content Row: Speaker Icon, Interactive Track, Percentage Text
                                    Row(
                                      children: [
                                        // Speaker Icon Button (Tap to toggle mute)
                                        InkWell(
                                          onTap: () => volumeService.toggleMute(),
                                          borderRadius: BorderRadius.circular(14),
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: accentColor.withOpacity(0.14),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: accentColor.withOpacity(0.28),
                                                width: 1,
                                              ),
                                            ),
                                            child: Center(
                                              child: Icon(
                                                volumeIcon,
                                                color: accentColor,
                                                size: 22,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Wide Interactive Volume Bar (Snap to steps on drag)
                                        Expanded(
                                          child: LayoutBuilder(
                                            builder: (context, trackConstraints) {
                                              return GestureDetector(
                                                behavior: HitTestBehavior.opaque,
                                                onHorizontalDragUpdate: (details) {
                                                  final trackWidth = trackConstraints.maxWidth;
                                                  if (trackWidth > 0) {
                                                    final deltaFraction = details.delta.dx / trackWidth;
                                                    final rawNext = (volume + deltaFraction).clamp(0.0, 1.0);
                                                    volumeService.setVolume(rawNext);
                                                  }
                                                },
                                                onTapDown: (details) {
                                                  final trackWidth = trackConstraints.maxWidth;
                                                  if (trackWidth > 0) {
                                                    final fraction = (details.localPosition.dx / trackWidth).clamp(0.0, 1.0);
                                                    volumeService.setVolume(fraction);
                                                  }
                                                },
                                                child: Container(
                                                  height: 36,
                                                  alignment: Alignment.center,
                                                  child: Container(
                                                    height: 10,
                                                    decoration: BoxDecoration(
                                                      color: (AppTheme.isDark ? const Color(0xFF1E2C24) : Colors.black.withOpacity(0.08)),
                                                      borderRadius: BorderRadius.circular(10),
                                                      border: Border.all(
                                                        color: (AppTheme.isDark ? Colors.white : Colors.black).withOpacity(0.08),
                                                        width: 0.8,
                                                      ),
                                                    ),
                                                    child: Stack(
                                                      children: [
                                                        // Active progress fill
                                                        FractionallySizedBox(
                                                          widthFactor: volume.clamp(0.0, 1.0),
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              gradient: LinearGradient(
                                                                colors: [
                                                                  accentColor,
                                                                  accentColor.withOpacity(0.85),
                                                                ],
                                                              ),
                                                              borderRadius: BorderRadius.circular(10),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: accentColor.withOpacity(0.45),
                                                                  blurRadius: 8,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),

                                        const SizedBox(width: 12),

                                        // Large, Bold, Clear Percentage Text
                                        SizedBox(
                                          width: 48,
                                          child: Text(
                                            '$percentage%',
                                            textAlign: TextAlign.end,
                                            style: TextStyle(
                                              color: accentColor,
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                        ),
                                      ],
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
