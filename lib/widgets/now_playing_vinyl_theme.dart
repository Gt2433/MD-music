import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/artwork_color_extractor.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../theme/app_theme.dart';
import 'query_artwork_or_fallback.dart';

/// Now Playing Screen - Interactive Vinyl Turntable Theme
/// Features a prominent, realistic vinyl disc that spins smoothly during playback,
/// and supports interactive DJ turntable scrubbing: touch & rotate to seek forward
/// or rewind music, with real-time HUD badges, haptic ticks, and boundary clamping.
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

typedef NowPlayingVinylTurntableTheme = NowPlayingVinylTheme;

class _NowPlayingVinylThemeState extends State<NowPlayingVinylTheme>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  StreamSubscription<bool>? _playerSubscription;

  Uint8List? _artworkBytes;
  Color? _artworkColor;

  // Interactive DJ Turntable Scrubbing (تدوير وتخطي القرص الموسيقي)
  bool _isScrubbingVinyl = false;
  bool _hasMovedVinyl = false;
  double _discRotationAngle = 0.0;
  double _lastTouchAngle = 0.0;
  bool _wasPlayingBeforeScrub = false;
  double _dragPositionMs = 0.0;
  double _lastHapticTickPos = 0.0;
  int _scrubDirection = 0; // 1 = forward, -1 = rewind, 0 = neutral

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    if (widget.audio.player.playing) {
      _rotationController.repeat();
    }

    _playerSubscription = widget.audio.player.playingStream.listen((isPlaying) {
      if (!mounted) return;
      if (_isScrubbingVinyl) return;
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
        if (_isScrubbingVinyl) return;
        if (isPlaying && !_rotationController.isAnimating) {
          _rotationController.repeat();
        } else if (!isPlaying && _rotationController.isAnimating) {
          _rotationController.stop();
        }
      });
    }

    if (!_isScrubbingVinyl) {
      final isPlaying = widget.audio.player.playing;
      if (isPlaying && !_rotationController.isAnimating) {
        _rotationController.repeat();
      } else if (!isPlaying && _rotationController.isAnimating) {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _playerSubscription?.cancel();
    _rotationController.dispose();
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

  // ---------------------------------------------------------------------------
  // DJ Turntable Scrubbing Gestures
  // ---------------------------------------------------------------------------

  void _onVinylPanStart(DragStartDetails details, double discSize) {
    final center = Offset(discSize / 2, discSize / 2);
    _lastTouchAngle = math.atan2(
      details.localPosition.dy - center.dy,
      details.localPosition.dx - center.dx,
    );
    _isScrubbingVinyl = true;
    _hasMovedVinyl = false;
    _wasPlayingBeforeScrub = widget.audio.player.playing;

    // Capture current continuous rotation angle from controller
    _discRotationAngle = _rotationController.value * 2 * math.pi;

    final pos = widget.audio.player.position.inMilliseconds.toDouble();
    final totalDurationMs = (widget.audio.player.duration?.inMilliseconds ??
            widget.song.duration ??
            0)
        .toDouble();
    final effectiveMax = totalDurationMs > 0 ? totalDurationMs : 1.0;
    _dragPositionMs = pos.clamp(0.0, effectiveMax);
    _lastHapticTickPos = _dragPositionMs;
    _scrubDirection = 0;
  }

  void _onVinylPanUpdate(DragUpdateDetails details, double discSize) {
    final center = Offset(discSize / 2, discSize / 2);
    final currentTouchAngle = math.atan2(
      details.localPosition.dy - center.dy,
      details.localPosition.dx - center.dx,
    );

    double deltaAngle = currentTouchAngle - _lastTouchAngle;
    if (deltaAngle > math.pi) deltaAngle -= 2 * math.pi;
    if (deltaAngle < -math.pi) deltaAngle += 2 * math.pi;
    _lastTouchAngle = currentTouchAngle;

    if (deltaAngle.abs() < 0.0001) return;

    if (!_hasMovedVinyl) {
      _hasMovedVinyl = true;
      _rotationController.stop();
      if (_wasPlayingBeforeScrub) {
        widget.audio.player.pause();
      }
      HapticFeedback.selectionClick();
    }

    final totalDurationMs = (widget.audio.player.duration?.inMilliseconds ??
            widget.song.duration ??
            0)
        .toDouble();

    // 1 full revolution (2*pi) = 20 seconds of audio scrubbing
    const double msPerRevolution = 20000.0;
    final deltaMs = (deltaAngle / (2 * math.pi)) * msPerRevolution;
    final targetMs = _dragPositionMs + deltaMs;

    if (targetMs <= 0.0) {
      // Reached start (00:00)
      _dragPositionMs = 0.0;
      _scrubDirection = -1;
      if (deltaAngle > 0) {
        _discRotationAngle += deltaAngle;
        _scrubDirection = 1;
      }
    } else if (targetMs >= totalDurationMs && totalDurationMs > 0) {
      // Reached end
      _dragPositionMs = totalDurationMs;
      _scrubDirection = 1;
      if (deltaAngle < 0) {
        _discRotationAngle += deltaAngle;
        _scrubDirection = -1;
      }
    } else {
      // Normal continuous scrubbing within range
      _dragPositionMs = targetMs;
      _discRotationAngle += deltaAngle;
      _scrubDirection = deltaAngle >= 0 ? 1 : -1;
    }

    // Sensory tactile feedback on every 1-second interval
    if ((_dragPositionMs - _lastHapticTickPos).abs() >= 1000.0) {
      HapticFeedback.selectionClick();
      _lastHapticTickPos = _dragPositionMs;
    }

    setState(() {});
  }

  void _onVinylPanEnd(DragEndDetails details) {
    _finishVinylScrub();
  }

  void _onVinylPanCancel() {
    _finishVinylScrub();
  }

  void _finishVinylScrub() {
    if (!_isScrubbingVinyl) return;

    if (!_hasMovedVinyl) {
      // Just a touch down without rotation -> toggle play/pause
      setState(() {
        _isScrubbingVinyl = false;
        _scrubDirection = 0;
      });
      HapticFeedback.lightImpact();
      widget.audio.togglePlayPause();
      return;
    }

    final seekTarget = Duration(milliseconds: _dragPositionMs.toInt());
    final shouldResume = _wasPlayingBeforeScrub;

    // 1. Sync animation controller seamlessly to current disc angle without jump
    final normalized = (_discRotationAngle / (2 * math.pi)) % 1.0;
    _rotationController.value = normalized < 0 ? normalized + 1.0 : normalized;

    // 2. Immediately unfreeze the UI state
    setState(() {
      _isScrubbingVinyl = false;
      _scrubDirection = 0;
      _hasMovedVinyl = false;
    });

    // 3. Immediately resume disc animation if song was playing
    if (shouldResume) {
      _rotationController.repeat();
    }

    HapticFeedback.mediumImpact();

    // 4. Seek and resume playback asynchronously
    widget.audio.seek(seekTarget).then((_) {
      if (shouldResume && mounted) {
        widget.audio.player.play();
      }
    }).catchError((e) {
      debugPrint('Vinyl seek error: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = _artworkColor ?? AppTheme.accentColor;
    final screenWidth = MediaQuery.of(context).size.width;

    // Make the turntable disc comfortably large for touch control
    final double discSize =
        (widget.size * 1.02).clamp(260.0, math.min(320.0, screenWidth - 36.0)).toDouble();

    return Center(
      child: SizedBox(
        width: discSize + 30,
        height: discSize + 30,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 1. Ambient Glow Aura matching artwork colors
            Container(
              width: discSize,
              height: discSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: effectiveAccent.withOpacity(0.38),
                    blurRadius: 46,
                    spreadRadius: 6,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.85),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),

            // 2. Rotating Interactive Vinyl Disc (Touch & DJ Scrubbing)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) => _onVinylPanStart(details, discSize),
              onPanUpdate: (details) => _onVinylPanUpdate(details, discSize),
              onPanEnd: _onVinylPanEnd,
              onPanCancel: _onVinylPanCancel,
              child: AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  final currentAngle = _isScrubbingVinyl
                      ? _discRotationAngle
                      : (_rotationController.value * 2 * math.pi);
                  return Transform.rotate(
                    angle: currentAngle,
                    child: child,
                  );
                },
                child: _VinylDiscWidget(
                  size: discSize,
                  artworkBytes: _artworkBytes,
                  accentColor: effectiveAccent,
                  songId: widget.song.id,
                ),
              ),
            ),

            // 3. Real-Time DJ Scrubbing HUD Badge (Feedback pill when scrubbing)
            if (_isScrubbingVinyl && _hasMovedVinyl)
              Positioned(
                top: discSize * 0.12,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090E18).withOpacity(0.92),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: effectiveAccent.withOpacity(0.75),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: effectiveAccent.withOpacity(0.40),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _dragPositionMs <= 0.0
                              ? Icons.first_page_rounded
                              : (_scrubDirection >= 0
                                  ? Icons.fast_forward_rounded
                                  : Icons.fast_rewind_rounded),
                          color: effectiveAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _dragPositionMs <= 0.0
                              ? '00:00 (${LanguageService().t("vinyl_start")})'
                              : widget.audio.formatDuration(_dragPositionMs.toInt()),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Custom Vinyl Disc Widget with realistic concentric grooves & specular reflection
class _VinylDiscWidget extends StatelessWidget {
  final double size;
  final Uint8List? artworkBytes;
  final Color accentColor;
  final int songId;

  const _VinylDiscWidget({
    required this.size,
    required this.artworkBytes,
    required this.accentColor,
    required this.songId,
  });

  @override
  Widget build(BuildContext context) {
    // Song cover artwork inside vinyl disc made larger (55% of disc diameter)
    final labelSize = size * 0.55;

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF0E0E12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Concentric Vinyl Grooves
          CustomPaint(
            size: Size(size, size),
            painter: _VinylGroovesPainter(labelRadius: labelSize / 2),
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
                  Colors.white.withOpacity(0.09),
                  Colors.transparent,
                  Colors.white.withOpacity(0.09),
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
                width: 1.5,
              ),
            ),
          ),

          // 4. Center Label (Album Artwork)
          Container(
            width: labelSize,
            height: labelSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF161A22),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 8,
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
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallbackLabel(labelSize),
                    )
                  : QueryArtworkOrFallback(
                      id: songId,
                      size: labelSize,
                      borderRadius: labelSize / 2,
                    ),
            ),
          ),

          // 5. Center Spindle Hole
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF07090E),
              border: Border.all(
                color: Colors.white.withOpacity(0.7),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.8),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackLabel(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            accentColor.withOpacity(0.8),
            const Color(0xFF121620),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.white.withOpacity(0.85),
          size: size * 0.45,
        ),
      ),
    );
  }
}

/// Concentric rings painter simulating authentic vinyl record grooves
class _VinylGroovesPainter extends CustomPainter {
  final double labelRadius;

  _VinylGroovesPainter({required this.labelRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final minRadius = labelRadius;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Draw realistic micro grooves
    final step = (maxRadius - minRadius) / 18;
    for (double r = minRadius + 3; r < maxRadius - 2; r += step) {
      final opacity = ((math.sin(r * 0.8) + 1.0) / 2.0 * 0.05) + 0.02;
      paint.color = Colors.white.withOpacity(opacity);
      paint.strokeWidth = (r % (step * 3) == 0) ? 0.8 : 0.4;
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VinylGroovesPainter oldDelegate) =>
      oldDelegate.labelRadius != labelRadius;
}
