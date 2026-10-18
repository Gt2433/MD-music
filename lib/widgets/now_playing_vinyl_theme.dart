import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/artwork_color_extractor.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';
import 'query_artwork_or_fallback.dart';

/// Now Playing Screen - Vinyl Disc Theme
/// Features a stylish square album jacket with a realistic black vinyl disc
/// peeking out and rotating smoothly while music is playing.
class NowPlayingVinylTheme extends StatefulWidget {
  final SongModel song;
  final AudioService audio;
  final double size;

  const NowPlayingVinylTheme({
    super.key,
    required this.song,
    required this.audio,
    required this.size,
  });

  @override
  State<NowPlayingVinylTheme> createState() => _NowPlayingVinylThemeState();
}

class _NowPlayingVinylThemeState extends State<NowPlayingVinylTheme>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _swipeController;
  late Animation<double> _swipeAnimation;
  StreamSubscription<bool>? _playerSubscription;

  Uint8List? _artworkBytes;
  Color? _artworkColor;
  double _dragOffset = 0.0;
  bool _isSwiping = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    if (widget.audio.player.playing) {
      _rotationController.repeat();
    }

    _playerSubscription = widget.audio.player.playingStream.listen((isPlaying) {
      if (!mounted) return;
      if (isPlaying && !_rotationController.isAnimating) {
        _rotationController.repeat();
      } else if (!isPlaying && _rotationController.isAnimating) {
        _rotationController.stop();
      }
    });

    _artworkColor = ArtworkColorExtractor.getCachedColor(widget.song.id);
    _loadArtwork();
  }

  @override
  void didUpdateWidget(covariant NowPlayingVinylTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _artworkColor = ArtworkColorExtractor.getCachedColor(widget.song.id);
      _loadArtwork();
    }
    if (oldWidget.audio != widget.audio) {
      _playerSubscription?.cancel();
      _playerSubscription = widget.audio.player.playingStream.listen((isPlaying) {
        if (!mounted) return;
        if (isPlaying && !_rotationController.isAnimating) {
          _rotationController.repeat();
        } else if (!isPlaying && _rotationController.isAnimating) {
          _rotationController.stop();
        }
      });
    }

    final isPlaying = widget.audio.player.playing;
    if (isPlaying && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!isPlaying && _rotationController.isAnimating) {
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _playerSubscription?.cancel();
    _rotationController.dispose();
    _swipeController.dispose();
    super.dispose();
  }

  Future<void> _loadArtwork() async {
    final bytes = await widget.audio.getSongArtworkBytes(widget.song.id);
    Color? color = ArtworkColorExtractor.getCachedColor(widget.song.id);
    if (color == null && bytes != null && bytes.isNotEmpty) {
      color = await ArtworkColorExtractor.extract(widget.song.id, bytes);
    }
    if (mounted) {
      setState(() {
        _artworkBytes = bytes;
        _artworkColor = color;
      });
    }
  }

  // Horizontal Swipe Gestures for Next / Previous track
  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isSwiping) return;
    setState(() {
      _dragOffset += details.primaryDelta!;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_isSwiping) return;
    final velocity = details.primaryVelocity ?? 0.0;
    const threshold = 55.0;

    if (_dragOffset < -threshold || velocity < -320) {
      // Swiped Left -> Next Track
      _animateSwipe(isNext: true);
    } else if (_dragOffset > threshold || velocity > 320) {
      // Swiped Right -> Previous Track
      _animateSwipe(isNext: false);
    } else {
      // Snap back to center
      _snapBack();
    }
  }

  void _animateSwipe({required bool isNext}) {
    _isSwiping = true;
    final targetOffset = isNext ? -360.0 : 360.0;

    _swipeAnimation = Tween<double>(
      begin: _dragOffset,
      end: targetOffset,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeOutCubic,
    ));

    _swipeController.duration = const Duration(milliseconds: 170);
    _swipeController.forward(from: 0.0).then((_) {
      if (isNext) {
        widget.audio.playNext();
      } else {
        widget.audio.playPrevious();
      }

      if (mounted) {
        setState(() {
          _dragOffset = isNext ? 140.0 : -140.0;
        });

        _swipeAnimation = Tween<double>(
          begin: _dragOffset,
          end: 0.0,
        ).animate(CurvedAnimation(
          parent: _swipeController,
          curve: Curves.easeOutBack,
        ));

        _swipeController.duration = const Duration(milliseconds: 300);
        _swipeController.forward(from: 0.0).then((_) {
          if (mounted) {
            setState(() {
              _dragOffset = 0.0;
              _isSwiping = false;
            });
          }
        });
      }
    });
  }

  void _snapBack() {
    _swipeAnimation = Tween<double>(
      begin: _dragOffset,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeOutCubic,
    ));

    _swipeController.duration = const Duration(milliseconds: 220);
    _swipeController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor;
    final glowColor = _artworkColor ?? accent;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxAvailableWidth = screenWidth - 28.0;

    // Sizing calculations:
    // 1. Enlarge sleeve and vinyl disc slightly overall for a bold, prominent look
    double sleeveSize = (widget.size * 0.90).clamp(220.0, 270.0);

    // 2. Vinyl disc diameter is strictly smaller than the square sleeve height (88.5%),
    // giving ~14-16px vertical margin so the disc NEVER protrudes from top or bottom of the sleeve!
    const double vinylRatio = 0.885;

    // 3. Peeking out slightly more than half (~53.5%) to the right,
    // revealing the spindle hole and the circular artwork label exactly as requested
    const double exposedRatio = 0.535;

    final compositionRatio = 1.0 + (vinylRatio * exposedRatio);
    if (sleeveSize * compositionRatio > maxAvailableWidth) {
      sleeveSize = maxAvailableWidth / compositionRatio;
    }

    final vinylSize = sleeveSize * vinylRatio;
    final exposedVinyl = vinylSize * exposedRatio;
    final totalWidth = sleeveSize + exposedVinyl;
    final totalHeight = sleeveSize;
    final verticalOffset = (sleeveSize - vinylSize) / 2;

    return AnimatedBuilder(
      animation: _swipeController,
      builder: (context, child) {
        final currentOffset = _swipeController.isAnimating
            ? _swipeAnimation.value
            : _dragOffset;
        final rotation = currentOffset * 0.0003;
        final opacity = (1.0 - (currentOffset.abs() / 650.0)).clamp(0.65, 1.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onTap: () {
            HapticFeedback.lightImpact();
            widget.audio.togglePlayPause();
          },
          child: Transform.translate(
            offset: Offset(currentOffset, 0),
            child: Transform.rotate(
              angle: rotation,
              child: Opacity(
                opacity: opacity,
                child: child,
              ),
            ),
          ),
        );
      },
      child: Center(
        child: SizedBox(
          width: totalWidth,
          height: totalHeight,
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              // 1. Direct Image-Blurred Radiance Halo (Exact Multi-Color Palette from the Artwork)
              if (_artworkBytes != null && _artworkBytes!.isNotEmpty)
                Positioned(
                  left: 0,
                  top: 0,
                  width: sleeveSize,
                  height: sleeveSize,
                  child: Transform.scale(
                    scale: 1.15,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 42, sigmaY: 42),
                      child: Opacity(
                        opacity: 0.88,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.memory(
                            _artworkBytes!,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.low,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 2. Ambient Radiance Halo using extracted artwork dominant colors
              Positioned(
                left: 10,
                right: 12,
                top: 8,
                bottom: 8,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withOpacity(0.55),
                        blurRadius: 55,
                        spreadRadius: 8,
                      ),
                      BoxShadow(
                        color: glowColor.withOpacity(0.25),
                        blurRadius: 90,
                        spreadRadius: 20,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.60),
                        blurRadius: 32,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),
              ),

              // Disc specific glowing aura matching artwork color
              Positioned(
                right: 0,
                top: verticalOffset,
                width: vinylSize,
                height: vinylSize,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withOpacity(0.38),
                        blurRadius: 40,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Black Vinyl Record peeking out to the Right (strictly vertically within sleeve, rotates when playing)
              Positioned(
                right: 0,
                top: verticalOffset,
                width: vinylSize,
                height: vinylSize,
                child: RepaintBoundary(
                  child: RotationTransition(
                    turns: _rotationController,
                    child: _VinylDisc(
                      size: vinylSize,
                      artworkBytes: _artworkBytes,
                      accentColor: glowColor,
                      songId: widget.song.id,
                    ),
                  ),
                ),
              ),

              // 4. Album Cover Sleeve / Jacket (Overlaps left portion of vinyl)
              Positioned(
                left: 0,
                top: 0,
                width: sleeveSize,
                height: sleeveSize,
                child: RepaintBoundary(
                  child: _AlbumCoverSleeve(
                    size: sleeveSize,
                    artworkBytes: _artworkBytes,
                    songId: widget.song.id,
                    accentColor: glowColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Album Cover Jacket with realistic edge seam, gloss reflection, and drop shadow
class _AlbumCoverSleeve extends StatelessWidget {
  final double size;
  final Uint8List? artworkBytes;
  final int songId;
  final Color accentColor;

  const _AlbumCoverSleeve({
    required this.size,
    required this.artworkBytes,
    required this.songId,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final radius = (size * 0.08).clamp(16.0, 22.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          // Heavy depth shadow cast over the vinyl disc underneath
          BoxShadow(
            color: Colors.black.withOpacity(0.85),
            blurRadius: 22,
            offset: const Offset(8, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(-2, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Artwork Image
            if (artworkBytes != null && artworkBytes!.isNotEmpty)
              Image.memory(
                artworkBytes!,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (context, error, stackTrace) => _buildFallback(),
              )
            else
              QueryArtworkOrFallback(
                id: songId,
                size: size,
                borderRadius: radius,
              ),

            // Subtle Vinyl Sleeve Outer Edge Border
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: Colors.white.withOpacity(0.22),
                  width: 1.2,
                ),
              ),
            ),

            // Diagonal Gloss Specular Sheen across the jacket
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.20),
                    Colors.white.withOpacity(0.04),
                    Colors.transparent,
                    Colors.black.withOpacity(0.25),
                  ],
                  stops: const [0.0, 0.28, 0.6, 1.0],
                ),
              ),
            ),

            // Sleeve opening notch highlight on the right edge
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.white.withOpacity(0.35),
                      Colors.black.withOpacity(0.6),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: const Color(0xFF161A22),
      child: Center(
        child: Icon(Icons.music_note_rounded,
            color: accentColor.withOpacity(0.8), size: size * 0.4),
      ),
    );
  }
}

/// The Authentic Black Vinyl Disc with Grooves, Bowtie Specular Light & Spindle Hole
class _VinylDisc extends StatelessWidget {
  final double size;
  final Uint8List? artworkBytes;
  final Color accentColor;
  final int songId;

  const _VinylDisc({
    required this.size,
    required this.artworkBytes,
    required this.accentColor,
    required this.songId,
  });

  @override
  Widget build(BuildContext context) {
    final labelSize = size * 0.40;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0C0E14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.7),
            blurRadius: 18,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Concentric Vinyl Grooves
          CustomPaint(
            size: Size(size, size),
            painter: _VinylGroovesPainter(),
          ),

          // 2. Specular Bowtie Light Reflection
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.08),
                  Colors.transparent,
                  Colors.white.withOpacity(0.08),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
              ),
            ),
          ),

          // 3. Outer Edge Highlight Ring
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1.2,
              ),
            ),
          ),

          // 4. Center Label (Circular Album Artwork)
          Container(
            width: labelSize,
            height: labelSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF161A22),
              border: Border.all(
                color: Colors.white.withOpacity(0.28),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.65),
                  blurRadius: 6,
                ),
              ],
            ),
            child: ClipOval(
              child: artworkBytes != null && artworkBytes!.isNotEmpty
                  ? Image.memory(
                      artworkBytes!,
                      fit: BoxFit.cover,
                      width: labelSize,
                      height: labelSize,
                    )
                  : QueryArtworkOrFallback(
                      id: songId,
                      size: labelSize,
                      borderRadius: labelSize / 2,
                    ),
            ),
          ),

          // 5. Center Spindle Metallic Ring & Center Hole
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF07090E),
              border: Border.all(
                color: Colors.white.withOpacity(0.75),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.9),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Concentric rings painter simulating authentic vinyl record grooves
class _VinylGroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final minRadius = size.width * 0.21;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final step = (maxRadius - minRadius) / 22;
    for (double r = minRadius + 4; r < maxRadius - 2; r += step) {
      final opacity = ((math.sin(r * 0.8) + 1.0) / 2.0 * 0.05) + 0.02;
      paint.color = Colors.white.withOpacity(opacity);
      paint.strokeWidth = (r % (step * 3) == 0) ? 0.8 : 0.4;
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
