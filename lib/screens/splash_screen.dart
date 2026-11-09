import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Luxury opening Splash Screen with Fade In, Scale, and an elegant musical light glow.
class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animController;
  late final AnimationController _glowPulseController;

  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _shimmerAnimation;
  late final Animation<double> _titleFadeAnimation;
  late final Animation<Offset> _titleSlideAnimation;

  Timer? _navigationTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    // Main entrance controller (1150ms total)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );

    // Continuous soft ambient musical pulse
    _glowPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // 1. Logo Fade
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );

    // 2. Logo Scale (soft spring out)
    _scaleAnimation = Tween<double>(begin: 0.76, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );

    // 3. Elegant Light Sweep across logo
    _shimmerAnimation = Tween<double>(begin: -1.2, end: 1.4).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.35, 0.95, curve: Curves.easeInOutCubic),
      ),
    );

    // 4. Title Text Fade & gentle upward slide
    _titleFadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.38, 0.9, curve: Curves.easeOut),
    );

    _titleSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.38, 0.9, curve: Curves.easeOutCubic),
    ));

    // Start entrance animation
    _animController.forward();

    // Auto-advance smoothly after the animation completes (1300ms)
    _navigationTimer = Timer(const Duration(milliseconds: 1350), () {
      _navigateToNext();
    });
  }

  void _navigateToNext() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            widget.nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _animController.dispose();
    _glowPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor;
    final isDark = AppTheme.isDark;
    final bgColor = AppTheme.background;

    return Scaffold(
      backgroundColor: bgColor,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToNext, // Instant skip on tap
        child: AnimatedBuilder(
          animation: Listenable.merge([_animController, _glowPulseController]),
          builder: (context, _) {
            final pulseVal = _glowPulseController.value;
            final glowRadius = 70.0 + (pulseVal * 25.0);
            final glowOpacity = (0.28 + (pulseVal * 0.18)).clamp(0.0, 1.0);

            return Stack(
              children: [
                // 1. Subtle musical ambient aura in the center
                Center(
                  child: Container(
                    width: glowRadius * 2.8,
                    height: glowRadius * 2.8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withOpacity(glowOpacity * _fadeAnimation.value),
                          accent.withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.85],
                      ),
                    ),
                  ),
                ),

                // 2. Main Branded Content
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo Box with Scale + Fade + Light Shimmer
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Multi-layered soft glow shadow behind icon
                              Container(
                                width: 104,
                                height: 104,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(26),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withOpacity(
                                          (0.42 + (pulseVal * 0.18)) *
                                              _fadeAnimation.value),
                                      blurRadius: 32,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                              ),

                              // App Icon Box
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: accent.withOpacity(0.6),
                                    width: 1.6,
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isDark
                                        ? [
                                            const Color(0xFF1E2632),
                                            const Color(0xFF0D131A),
                                          ]
                                        : [
                                            Colors.white,
                                            const Color(0xFFF0F4F8),
                                          ],
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.asset(
                                        'assets/images/app_icon.png',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.music_note_rounded,
                                          color: accent,
                                          size: 50,
                                        ),
                                      ),

                                      // Specular Light Sweep flare
                                      Transform.translate(
                                        offset: Offset(
                                            _shimmerAnimation.value * 96,
                                            _shimmerAnimation.value * 96),
                                        child: Transform.rotate(
                                          angle: math.pi / 4,
                                          child: Container(
                                            width: 32,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.white.withOpacity(0.0),
                                                  Colors.white.withOpacity(0.45),
                                                  Colors.white.withOpacity(0.0),
                                                ],
                                                stops: const [0.0, 0.5, 1.0],
                                              ),
                                            ),
                                          ),
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

                      const SizedBox(height: 24),

                      // Brand Name & Musical Identity
                      SlideTransition(
                        position: _titleSlideAnimation,
                        child: FadeTransition(
                          opacity: _titleFadeAnimation,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'MD',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                      shadows: [
                                        Shadow(
                                          color: accent.withOpacity(0.6),
                                          blurRadius: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'MUSIC',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2.2,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Musical Soundwave Equalizer Micro-bars
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(5, (i) {
                                  final heights = [12.0, 20.0, 16.0, 24.0, 10.0];
                                  final waveHeight = heights[i] *
                                      (0.55 +
                                          (0.45 *
                                              math.sin(
                                                  (pulseVal * math.pi * 2) +
                                                      (i * 0.8))));

                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 2.5),
                                    width: 3.5,
                                    height: waveHeight,
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.85),
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: accent.withOpacity(0.4),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
