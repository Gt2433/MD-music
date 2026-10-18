import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/artwork_color_extractor.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../services/song_edit_service.dart';
import '../theme/app_theme.dart';
import 'glass_dialog.dart';
import 'audio_effects_sheet.dart';

/// MBD Vinyl Cinema: Premium Landscape Music Player
class LandscapeVinylPlayer extends StatefulWidget {
  final SongModel song;
  final AudioService audio;
  final VoidCallback? onExitLandscape;

  const LandscapeVinylPlayer({
    super.key,
    required this.song,
    required this.audio,
    this.onExitLandscape,
  });

  @override
  State<LandscapeVinylPlayer> createState() => _LandscapeVinylPlayerState();
}

class _LandscapeVinylPlayerState extends State<LandscapeVinylPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _vinylController;
  final SongEditService _editService = SongEditService();

  Uint8List? _artworkBytes;
  Color? _artworkColor;
  bool _isSeeking = false;
  double _dragPositionMs = 0.0;

  // Interactive Turntable Scrubbing (دوران وتخطي القرص الموسيقي)
  bool _isScrubbingVinyl = false;
  bool _hasMovedVinyl = false;
  double _discRotationAngle = 0.0;
  double _lastTouchAngle = 0.0;
  bool _wasPlayingBeforeScrub = false;
  double _lastHapticTickPos = 0.0;
  int _scrubDirection = 0; // 1 = forward, -1 = rewind, 0 = neutral

  @override
  void initState() {
    super.initState();
    // 1. Hide the status bar (notifications, clock, battery) in landscape display mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _vinylController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    if (widget.audio.player.playing) {
      _vinylController.repeat();
    }

    _loadArtwork();
  }

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
    _discRotationAngle = _vinylController.value * 2 * math.pi;

    final pos = widget.audio.player.position.inMilliseconds.toDouble();
    _dragPositionMs = pos;
    _lastHapticTickPos = pos;
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
      _isSeeking = true;
      _vinylController.stop();
      if (_wasPlayingBeforeScrub) {
        widget.audio.player.pause();
      }
      HapticFeedback.selectionClick();
    }

    final totalDurationMs = (widget.audio.player.duration?.inMilliseconds ??
            widget.song.duration ??
            0)
        .toDouble();

    // 1 full revolution (2*pi) = 20 seconds of audio scrubbing (دوران طبيعي واقعي)
    const double msPerRevolution = 20000.0;
    final deltaMs = (deltaAngle / (2 * math.pi)) * msPerRevolution;
    final targetMs = _dragPositionMs + deltaMs;

    if (targetMs <= 0.0) {
      // Reached the very beginning of the song (بداية الأغنية 00:00)
      // "ولما يوصل لبداية الأغنية، يعني ما تقدر ترجع أكثر، الدائرة تتوقف عن الدوران للخلف، تظل مثل ما هي"
      _dragPositionMs = 0.0;
      _scrubDirection = -1;
      // لا تدور الدائرة للخلف إذا كانت عند البداية، وتدور فقط للأمام إذا حرك المستخدم مع عقارب الساعة
      if (deltaAngle > 0) {
        _discRotationAngle += deltaAngle;
        _scrubDirection = 1;
      }
    } else if (targetMs >= totalDurationMs && totalDurationMs > 0) {
      // Reached the end of the song
      _dragPositionMs = totalDurationMs;
      _scrubDirection = 1;
      // لا تدور للأمام بعد نهاية الأغنية
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
      // Just a touch down without rotation
      setState(() {
        _isScrubbingVinyl = false;
        _isSeeking = false;
        _scrubDirection = 0;
      });
      return;
    }

    final seekTarget = Duration(milliseconds: _dragPositionMs.toInt());
    final shouldResume = _wasPlayingBeforeScrub;

    // 1. Sync animation controller seamlessly to current disc angle without jump
    final normalized = (_discRotationAngle / (2 * math.pi)) % 1.0;
    _vinylController.value = normalized < 0 ? normalized + 1.0 : normalized;

    // 2. Immediately unfreeze the UI state: remove HUD badge, clear seeking flags
    setState(() {
      _isScrubbingVinyl = false;
      _isSeeking = false;
      _scrubDirection = 0;
      _hasMovedVinyl = false;
    });

    // 3. Immediately resume disc animation if song was playing
    if (shouldResume) {
      _vinylController.repeat();
    }

    HapticFeedback.mediumImpact();

    // 4. Seek and resume playback asynchronously.
    // Note: In just_audio, AudioPlayer.play() Future does NOT resolve until paused/stopped.
    // Therefore, never 'await' player.play() directly in a synchronous UI flow.
    widget.audio.seek(seekTarget).then((_) {
      if (shouldResume && mounted) {
        widget.audio.player.play();
      }
    }).catchError((e) {
      debugPrint('Vinyl seek error: $e');
    });
  }

  @override
  void didUpdateWidget(covariant LandscapeVinylPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _artworkColor = ArtworkColorExtractor.getCachedColor(widget.song.id);
      _loadArtwork();
    }

    if (!_isScrubbingVinyl) {
      final isPlaying = widget.audio.player.playing;
      if (isPlaying && !_vinylController.isAnimating) {
        _vinylController.repeat();
      } else if (!isPlaying && _vinylController.isAnimating) {
        _vinylController.stop();
      }
    }
  }

  @override
  void dispose() {
    // 2. Restore standard system status bar & nav bar when exiting landscape mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    AppTheme.updateSystemUIOverlay();
    _vinylController.dispose();
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

  void _restorePortrait() {
    HapticFeedback.selectionClick();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    AppTheme.updateSystemUIOverlay();
    if (widget.onExitLandscape != null) {
      widget.onExitLandscape!();
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = widget.audio.player.playing;
    final isFav = widget.audio.isFavorite(widget.song.id);
    final songTitle = _editService.getDisplayTitle(widget.song);
    final artistName = _editService.getDisplayArtist(widget.song);

    // Keep rotation in sync with playback
    if (isPlaying && !_vinylController.isAnimating) {
      _vinylController.repeat();
    } else if (!isPlaying && _vinylController.isAnimating) {
      _vinylController.stop();
    }

    return ValueListenableBuilder<String>(
      valueListenable: AppTheme.landscapeColorModeNotifier,
      builder: (context, colorMode, _) {
        final isArtworkMode = colorMode == 'artwork';
        final effectiveAccent = isArtworkMode
            ? (_artworkColor ?? AppTheme.accentColor)
            : AppTheme.accentColor;

        return Scaffold(
          backgroundColor: const Color(0xFF07090E),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Deep Atmospheric Vinyl Cinema Background
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.6, 0.0),
                      radius: 1.25,
                      colors: [
                        effectiveAccent.withOpacity(0.18),
                        const Color(0xFF0F1219),
                        const Color(0xFF07090E),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),

              // 1.1 Soft ambient artwork radiance behind the vinyl disc when in artwork mode
              if (isArtworkMode && _artworkBytes != null && _artworkBytes!.isNotEmpty)
                Positioned(
                  left: -MediaQuery.of(context).size.height * 0.28,
                  top: 0,
                  bottom: 0,
                  width: MediaQuery.of(context).size.height * 1.02,
                  child: IgnorePointer(
                    child: Center(
                      child: Opacity(
                        opacity: 0.26,
                        child: ImageFiltered(
                          imageFilter:
                              ui.ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                          child: ClipOval(
                            child: Image.memory(
                              _artworkBytes!,
                              fit: BoxFit.cover,
                              width: MediaQuery.of(context).size.height * 0.80,
                              height: MediaQuery.of(context).size.height * 0.80,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 2. Cinematic Vinyl Record emerging from the left edge, extending top-to-bottom
              Builder(
                builder: (context) {
                  final screenSize = MediaQuery.of(context).size;
                  // Disc diameter matches screen height to span from top to bottom
                  final discSize = screenSize.height * 1.02;
                  // Negative left offset to submerge ~28% inside the left bezel
                  final leftOffset = -discSize * 0.28;
                  // Controls column starts right past the visible arc of the disc
                  final controlsLeft =
                      (discSize * 0.74).clamp(0.0, screenSize.width * 0.48);

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // --- LEFT: VINYL RECORD & TONEARM ---
                      Positioned(
                        left: leftOffset,
                        top: (screenSize.height - discSize) / 2,
                        width: discSize,
                        height: discSize,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.audio.togglePlayPause();
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              // Vinyl Record Shadow & Ambient Glow
                              Container(
                                width: discSize,
                                height: discSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: effectiveAccent.withOpacity(0.35),
                                      blurRadius: 42,
                                      spreadRadius: 4,
                                      offset: const Offset(10, 0),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.85),
                                      blurRadius: 32,
                                      offset: const Offset(12, 0),
                                    ),
                                  ],
                                ),
                              ),

                              // Rotating Interactive Vinyl Disc (Jog Wheel & DJ Scrubbing)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanStart: (details) =>
                                    _onVinylPanStart(details, discSize),
                                onPanUpdate: (details) =>
                                    _onVinylPanUpdate(details, discSize),
                                onPanEnd: _onVinylPanEnd,
                                onPanCancel: _onVinylPanCancel,
                                child: AnimatedBuilder(
                                  animation: _vinylController,
                                  builder: (context, child) {
                                    final currentAngle = _isScrubbingVinyl
                                        ? _discRotationAngle
                                        : (_vinylController.value * 2 * math.pi);
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

                              // Real-Time DJ Scrubbing HUD Badge
                              if (_isScrubbingVinyl && _hasMovedVinyl)
                                Positioned(
                                  top: discSize * 0.15,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF090E18)
                                          .withOpacity(0.90),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: effectiveAccent.withOpacity(0.7),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: effectiveAccent
                                              .withOpacity(0.40),
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
                                              ? '00:00 (${LanguageService().isArabic ? "البداية" : "Start"})'
                                              : _formatDuration(Duration(
                                                  milliseconds:
                                                      _dragPositionMs.toInt())),
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

                              // Interactive Tonearm (Needle Arm)
                              Positioned(
                                right: -discSize * 0.04,
                                top: -8,
                                child: IgnorePointer(
                                  child: _TonearmWidget(
                                    isPlaying: isPlaying || _isScrubbingVinyl,
                                    vinylSize: discSize,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // --- RIGHT: TRACK INFO & CONTROLS ---
                      Positioned(
                        left: controlsLeft,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: SafeArea(
                          left: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 20, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Top Header Row
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Badge
                                    Flexible(
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: effectiveAccent
                                              .withOpacity(0.16),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: effectiveAccent
                                                .withOpacity(0.45),
                                            width: 1.4,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.album_rounded,
                                                color: effectiveAccent,
                                                size: 16),
                                            const SizedBox(width: 7),
                                            Text(
                                              'MBD VINYL CINEMA',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: effectiveAccent,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.9,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Top action icons
                                    Row(
                                      children: [
                                        // 1. Display Colors Mode Button (Exclusive to Display Mode)
                                        IconButton(
                                          icon: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 250),
                                            padding: const EdgeInsets.all(5.5),
                                            decoration: BoxDecoration(
                                              color: effectiveAccent
                                                  .withOpacity(0.18),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: effectiveAccent
                                                    .withOpacity(0.65),
                                                width: 1.8,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: effectiveAccent
                                                      .withOpacity(0.40),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.palette_rounded,
                                              color: effectiveAccent,
                                              size: 20,
                                            ),
                                          ),
                                          tooltip: LanguageService.tr(
                                              'landscape_display_colors'),
                                          onPressed: () =>
                                              _showDisplayColorModeSheet(
                                                  context),
                                        ),
                                        // 1.1 Audio Effects Button
                                        IconButton(
                                          icon: Icon(
                                              Icons.auto_awesome_rounded,
                                              color: effectiveAccent,
                                              size: 24),
                                          tooltip: LanguageService().isArabic
                                              ? 'المؤثرات الصوتية (الصدى)'
                                              : 'Audio Effects (Echo)',
                                          onPressed: () =>
                                              showAudioEffectsSheet(context),
                                        ),
                                        // 2. Queue Button
                                        IconButton(
                                          icon: const Icon(
                                              Icons.queue_music_rounded,
                                              color: Colors.white,
                                              size: 26),
                                          tooltip:
                                              LanguageService.tr('queue'),
                                          onPressed: () =>
                                              _showLandscapeQueue(
                                                  context, effectiveAccent),
                                        ),
                                        // 3. Return to Portrait Button
                                        IconButton(
                                          icon: const Icon(
                                              Icons
                                                  .screen_lock_portrait_rounded,
                                              color: Colors.white,
                                              size: 26),
                                          tooltip: 'العودة للوضع الرأسي',
                                          onPressed: _restorePortrait,
                                        ),
                                        // 4. Close / Dismiss
                                        IconButton(
                                          icon: const Icon(Icons.close_rounded,
                                              color: Colors.white,
                                              size: 26),
                                          tooltip:
                                              LanguageService.tr('close'),
                                          onPressed: () {
                                            SystemChrome
                                                .setEnabledSystemUIMode(
                                                    SystemUiMode.edgeToEdge);
                                            AppTheme.updateSystemUIOverlay();
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const Spacer(flex: 1),

                                // Track Title & Artist
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        songTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        artistName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color:
                                              Colors.white.withOpacity(0.65),
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // Seek Bar & Timers
                                StreamBuilder<Duration>(
                                  stream:
                                      widget.audio.player.positionStream,
                                  builder: (context, snapshot) {
                                    final position =
                                        snapshot.data ?? Duration.zero;
                                    final duration = widget
                                            .audio.player.duration ??
                                        Duration(
                                            milliseconds:
                                                widget.song.duration ?? 0);

                                    final totalMs =
                                        duration.inMilliseconds > 0
                                            ? duration.inMilliseconds
                                                .toDouble()
                                            : 1.0;
                                    final currentMs = _isSeeking
                                        ? _dragPositionMs
                                        : position.inMilliseconds
                                            .toDouble()
                                            .clamp(0.0, totalMs);

                                    return Column(
                                      children: [
                                        SliderTheme(
                                          data: SliderThemeData(
                                            trackHeight: 5.0,
                                            activeTrackColor:
                                                effectiveAccent,
                                            inactiveTrackColor: Colors.white
                                                .withOpacity(0.15),
                                            thumbColor: effectiveAccent,
                                            thumbShape:
                                                const RoundSliderThumbShape(
                                                    enabledThumbRadius: 7.5,
                                                    elevation: 3),
                                            overlayColor: effectiveAccent
                                                .withOpacity(0.25),
                                            overlayShape:
                                                const RoundSliderOverlayShape(
                                                    overlayRadius: 16),
                                          ),
                                          child: Slider(
                                            value: currentMs.clamp(
                                                0.0, totalMs),
                                            min: 0.0,
                                            max: totalMs,
                                            onChangeStart: (val) {
                                              setState(() {
                                                _isSeeking = true;
                                                _dragPositionMs = val;
                                              });
                                            },
                                            onChanged: (val) {
                                              setState(() {
                                                _dragPositionMs = val;
                                              });
                                            },
                                            onChangeEnd: (val) {
                                              widget.audio.seek(Duration(
                                                  milliseconds:
                                                      val.toInt()));
                                              setState(() {
                                                _isSeeking = false;
                                              });
                                            },
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 10),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              Text(
                                                _formatDuration(_isSeeking
                                                    ? Duration(
                                                        milliseconds:
                                                            _dragPositionMs
                                                                .toInt())
                                                    : position),
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.55),
                                                  fontSize: 11.5,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                _formatDuration(duration),
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.55),
                                                  fontSize: 11.5,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),

                                const SizedBox(height: 8),

                                // Main Controls Row
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // Favorite Button (Bolder filled heart icon)
                                    IconButton(
                                      icon: Icon(
                                        Icons.favorite_rounded,
                                        color: isFav
                                            ? const Color(0xFFFF2D55)
                                            : Colors.white.withOpacity(0.42),
                                        size: 28,
                                      ),
                                      tooltip: isFav
                                          ? LanguageService.tr(
                                              'remove_from_favorites')
                                          : LanguageService.tr(
                                              'add_to_favorites'),
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        widget.audio
                                            .toggleFavorite(widget.song.id);
                                      },
                                    ),

                                    // Shuffle Button
                                    IconButton(
                                      icon: Icon(
                                        Icons.shuffle_rounded,
                                        color: widget.audio.isShuffle
                                            ? effectiveAccent
                                            : Colors.white.withOpacity(0.85),
                                        size: 26,
                                      ),
                                      tooltip:
                                          LanguageService.tr('shuffle'),
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        widget.audio.toggleShuffle();
                                      },
                                    ),

                                    // Previous Track
                                    IconButton(
                                      icon: const Icon(
                                        Icons.skip_previous_rounded,
                                        color: Colors.white,
                                        size: 44,
                                      ),
                                      tooltip:
                                          LanguageService.tr('previous'),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        widget.audio.playPrevious();
                                      },
                                    ),

                                    // Play / Pause Prominent Center Button
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.mediumImpact();
                                        widget.audio.togglePlayPause();
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                            milliseconds: 250),
                                        width: 66,
                                        height: 66,
                                        decoration: BoxDecoration(
                                          color: effectiveAccent,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: effectiveAccent
                                                  .withOpacity(0.48),
                                              blurRadius: 20,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Icon(
                                            isPlaying
                                                ? Icons.pause_rounded
                                                : Icons
                                                    .play_arrow_rounded,
                                            color: effectiveAccent
                                                        .computeLuminance() >
                                                    0.4
                                                ? Colors.black
                                                : Colors.white,
                                            size: 38,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Next Track
                                    IconButton(
                                      icon: const Icon(
                                        Icons.skip_next_rounded,
                                        color: Colors.white,
                                        size: 44,
                                      ),
                                      tooltip: LanguageService.tr('next'),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        widget.audio.playNext();
                                      },
                                    ),

                                    // Repeat Button
                                    IconButton(
                                      icon: Icon(
                                        widget.audio.loopMode ==
                                                LoopMode.one
                                            ? Icons.repeat_one_rounded
                                            : Icons.repeat_rounded,
                                        color: widget.audio.loopMode !=
                                                LoopMode.off
                                            ? effectiveAccent
                                            : Colors.white.withOpacity(0.85),
                                        size: 26,
                                      ),
                                      tooltip:
                                          LanguageService.tr('repeat'),
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        widget.audio.toggleLoop();
                                      },
                                    ),
                                  ],
                                ),

                                const Spacer(flex: 1),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLandscapeQueue(BuildContext context, Color activeAccent) {
    showGlassBottomSheet(
      context: context,
      builder: (ctx) => GlassBottomSheet(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.queue_music_rounded,
                      color: activeAccent, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    LanguageService.tr('queue'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: widget.audio.currentPlaylist.length,
                itemBuilder: (context, index) {
                  final s = widget.audio.currentPlaylist[index];
                  final isCurrent = s.id == widget.song.id;
                  return ListTile(
                    leading: isCurrent
                        ? Icon(Icons.equalizer_rounded,
                            color: activeAccent, size: 26)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                    title: Text(
                      _editService.getDisplayTitle(s),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrent ? activeAccent : Colors.white,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13.5,
                      ),
                    ),
                    subtitle: Text(
                      _editService.getDisplayArtist(s),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.audio.playSong(s,
                          playlist: widget.audio.currentPlaylist);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays the luxury glass modal sheet for selecting landscape display mode colors:
  /// Either App Colors (ألوان التطبيق) or Album Artwork Colors (ألوان غلاف الموسيقى)
  void _showDisplayColorModeSheet(BuildContext context) {
    HapticFeedback.selectionClick();

    showGlassBottomSheet(
      context: context,
      builder: (sheetContext) {
        return ValueListenableBuilder<String>(
          valueListenable: AppTheme.landscapeColorModeNotifier,
          builder: (context, currentMode, _) {
            final appAccent = AppTheme.accentColor;
            final artColor = _artworkColor ?? appAccent;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: GlassBottomSheet(
                  borderRadius: 24,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (currentMode == 'artwork'
                                      ? artColor
                                      : appAccent)
                                  .withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.palette_rounded,
                              color: currentMode == 'artwork'
                                  ? artColor
                                  : appAccent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  LanguageService.tr(
                                      'landscape_display_colors'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  LanguageService.tr(
                                      'landscape_display_colors_subtitle'),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.55),
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 24),
                            tooltip: LanguageService.tr('close'),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Two Options side by side in a Row
                      Row(
                        children: [
                          // 1. App Colors Option Card (ألوان التطبيق)
                          Expanded(
                            child: _buildColorModeCard(
                              title:
                                   LanguageService.tr('landscape_color_app'),
                              subtitle: LanguageService.tr(
                                  'landscape_color_app_desc'),
                              isSelected: currentMode == 'app',
                              accentColor: appAccent,
                              icon: Icons.smartphone_rounded,
                              previewWidget: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: appAccent,
                                  boxShadow: [
                                    BoxShadow(
                                      color: appAccent.withOpacity(0.45),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.palette_rounded,
                                  color: appAccent.computeLuminance() > 0.4
                                      ? Colors.black
                                      : Colors.white,
                                  size: 22,
                                ),
                              ),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                AppTheme.setLandscapeColorMode('app');
                              },
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 2. Cover Artwork Colors Option Card (ألوان غلاف الموسيقى)
                          Expanded(
                            child: _buildColorModeCard(
                              title: LanguageService.tr(
                                  'landscape_color_artwork'),
                              subtitle: LanguageService.tr(
                                  'landscape_color_artwork_desc'),
                              isSelected: currentMode == 'artwork',
                              accentColor: artColor,
                              icon: Icons.auto_awesome_rounded,
                              previewWidget: _artworkBytes != null &&
                                      _artworkBytes!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(19),
                                      child: SizedBox(
                                        width: 38,
                                        height: 38,
                                        child: Image.memory(
                                          _artworkBytes!,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            artColor,
                                            artColor.withOpacity(0.4),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: artColor.withOpacity(0.45),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.album_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                AppTheme.setLandscapeColorMode('artwork');
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColorModeCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color accentColor,
    required IconData icon,
    required Widget previewWidget,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withOpacity(0.12)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : Colors.white.withOpacity(0.10),
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  previewWidget,
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? accentColor : Colors.white10,
                      border: Border.all(
                        color: isSelected ? accentColor : Colors.white24,
                        width: 2.0,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: accentColor.computeLuminance() > 0.4
                                ? Colors.black
                                : Colors.white,
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white.withOpacity(0.75)
                      : Colors.white.withOpacity(0.50),
                  fontSize: 10.5,
                  height: 1.25,
                ),
              ),
            ],
          ),
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
    final labelSize = size * 0.44;

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
                  : _buildFallbackLabel(labelSize),
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
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final minRadius = size.width * 0.22;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Draw realistic micro grooves
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

/// Realistic Tonearm with animated angle
class _TonearmWidget extends StatelessWidget {
  final bool isPlaying;
  final double vinylSize;

  const _TonearmWidget({
    required this.isPlaying,
    required this.vinylSize,
  });

  @override
  Widget build(BuildContext context) {
    // When playing: arm rotates ~0.26 radians onto record
    // When paused: arm rests at ~ -0.06 radians away
    final targetAngle = isPlaying ? 0.26 : -0.06;

    return AnimatedRotation(
      turns: targetAngle / (2 * math.pi),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topRight,
      child: CustomPaint(
        size: Size(vinylSize * 0.38, vinylSize * 0.58),
        painter: _TonearmPainter(),
      ),
    );
  }
}

class _TonearmPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width - 12, 12);

    // 1. Pivot Base
    final pivotPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pivot, 12, pivotPaint);

    final pivotHighlight = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pivot, 7.5, pivotHighlight);

    // 2. Arm Rod
    final armPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;

    final armPath = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..lineTo(size.width * 0.45, size.height * 0.55)
      ..lineTo(size.width * 0.18, size.height * 0.90);

    canvas.drawPath(armPath, armPaint);

    // 3. Cartridge / Headshell
    final headshellPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;

    final headshellPos = Offset(size.width * 0.18, size.height * 0.90);
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: headshellPos, width: 12, height: 18),
      const Radius.circular(3),
    );
    canvas.drawRRect(rect, headshellPaint);

    // Stylus Needle point
    final needlePaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(headshellPos.dx, headshellPos.dy + 9), 2.8, needlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
