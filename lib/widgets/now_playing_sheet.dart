import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../services/song_edit_service.dart';
import '../theme/app_theme.dart';
import 'cinematic_orientation_transition.dart';
import 'landscape_vinyl_player.dart';
import 'now_playing_artwork.dart';
import 'now_playing_vinyl_theme.dart';
import 'player_theme_selector.dart';
import 'glass_dialog.dart';
import 'query_artwork_or_fallback.dart';
import '../services/audio_effects_service.dart';
import 'audio_effects_sheet.dart';

class NowPlayingSheet extends StatefulWidget {
  const NowPlayingSheet({super.key});

  static bool _isOpen = false;

  static void show(BuildContext context) {
    if (_isOpen) return;
    _isOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      isDismissible: true,
      enableDrag: true,
      barrierColor: Colors.black.withOpacity(0.20),
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(
        maxWidth: double.infinity,
        minWidth: double.infinity,
      ),
      builder: (context) => const NowPlayingSheet(),
    ).whenComplete(() {
      _isOpen = false;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      AppTheme.updateSystemUIOverlay();
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    });
  }

  @override
  State<NowPlayingSheet> createState() => _NowPlayingSheetState();
}

class _NowPlayingSheetState extends State<NowPlayingSheet> {
  bool _isCinematicTransitionActive = false;
  bool _wasLandscape = false;

  void _startCinematicLandscapeTransition() {
    if (_isCinematicTransitionActive) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isCinematicTransitionActive = true;
    });
  }

  @override
  void initState() {
    super.initState();
    // Allow landscape orientation while player is open
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Restore portrait and system bars when player is dismissed
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    AppTheme.updateSystemUIOverlay();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = AudioService();
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      _wasLandscape = true;
    } else if (_wasLandscape) {
      _wasLandscape = false;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      AppTheme.updateSystemUIOverlay();
    }

    return AnimatedBuilder(
      animation: audio,
      builder: (context, _) {
        final song = audio.currentSong;
        if (song == null) {
          return const SizedBox.shrink();
        }

        Widget mainContent;
        // Return dedicated MBD Vinyl Cinema player when in landscape
        if (isLandscape) {
          mainContent = LandscapeVinylPlayer(
            song: song,
            audio: audio,
            onExitLandscape: () {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              AppTheme.updateSystemUIOverlay();
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
              ]);
            },
          );
        } else {
          final screenSize = MediaQuery.of(context).size;
          final artSize = (screenSize.height < 720)
              ? 200.0
              : (screenSize.width - 56).clamp(230.0, 290.0);
          final isFav = audio.isFavorite(song.id);
          final isPlaying = audio.player.playing;

          mainContent = ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: SizedBox(
              height: screenSize.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                // 1. Background Music Playlist (قائمة الموسيقى في الخلفية)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _BackgroundPlaylistView(
                      audio: audio,
                      currentSongId: song.id,
                    ),
                  ),
                ),

                // 2. Full Frosted Glass Blur & Gradient Overlay (خلفية زجاجية ضبابية لكامل الواجهة)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: AppTheme.isDark
                              ? [
                                  const Color(0xFF0B1119).withOpacity(0.52),
                                  const Color(0xFF101722).withOpacity(0.44),
                                  const Color(0xFF070B10).withOpacity(0.58),
                                ]
                              : [
                                  Colors.white.withOpacity(0.88),
                                  const Color(0xFFF8FAFC).withOpacity(0.92),
                                  const Color(0xFFF1F5F9).withOpacity(0.95),
                                ],
                        ),
                        border: Border(
                          top: BorderSide(
                            color: AppTheme.isDark
                                ? Colors.white.withOpacity(0.22)
                                : Colors.black.withOpacity(0.08),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Foreground Player Interface (واجهة المشغل الأساسية)
                SafeArea(
                  top: false,
                  bottom: true,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Top Safe area padding
                    SizedBox(
                      height: (MediaQuery.of(context).viewPadding.top > 0
                              ? MediaQuery.of(context).viewPadding.top
                              : (MediaQuery.of(context).padding.top > 0
                                  ? MediaQuery.of(context).padding.top
                                  : 28.0)) +
                          10.0,
                    ),

                    // Clean Drag Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),

                    // Top Bar (Down arrow, Header Title, Info)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 32,
                            color: AppTheme.isDark ? Colors.white : AppTheme.textPrimary,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              song.album ?? LanguageService.tr('now_playing'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.isDark ? Colors.white.withOpacity(0.85) : AppTheme.textSecondary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        // 3-dots More Options Glass Menu (Landscape Mode, Player Themes, Song Details)
                        IconButton(
                          icon: Icon(
                            Icons.more_vert_rounded,
                            size: 24,
                            color: AppTheme.isDark ? Colors.white : AppTheme.textSecondary,
                          ),
                          tooltip: LanguageService.tr('more_options'),
                          onPressed: () => _showNowPlayingOptionsMenu(context, song, audio),
                        ),
                      ],
                    ),

                    const Spacer(flex: 1),

                    // Dynamic Player Interface: Default / Vinyl Disc / Audio Waves
                    Center(
                      child: ValueListenableBuilder<String>(
                        valueListenable: AppTheme.playerThemeNotifier,
                        builder: (context, theme, _) {
                          Widget themeArtwork;
                          switch (theme) {
                            case 'vinyl':
                              themeArtwork = NowPlayingVinylTheme(
                                key: ValueKey('vinyl_${song.id}'),
                                song: song,
                                audio: audio,
                                size: artSize,
                              );
                              break;
                            case 'default':
                            default:
                              themeArtwork = _SwipeableArtwork(
                                key: ValueKey('default_${song.id}'),
                                song: song,
                                audio: audio,
                                size: artSize,
                              );
                              break;
                          }
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 320),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 0.93, end: 1.0)
                                      .animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: themeArtwork,
                          );
                        },
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Song Title, Artist & Favorite Heart
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                SongEditService().getDisplayTitle(song),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.isDark ? Colors.white : AppTheme.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                SongEditService().getDisplayArtist(song),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.isDark ? Colors.white.withOpacity(0.55) : AppTheme.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _AnimatedHeartButton(
                          isFav: isFav,
                          onTap: () => audio.toggleFavorite(song.id),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Interactive Progress Slider with Drag Mute & Resume
                    _InteractiveProgressBar(
                      song: song,
                      audio: audio,
                    ),

                    const SizedBox(height: 10),

                    // Standard Controls Row (LTR: Shuffle, Prev, Play/Pause, Next, Loop)
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _AnimatedShuffleButton(
                            isShuffle: audio.isShuffle,
                            onTap: audio.toggleShuffle,
                          ),
                          _AnimatedSkipButton(
                            icon: Icons.skip_previous_rounded,
                            isForward: false,
                            onTap: audio.playPrevious,
                          ),
                          _AnimatedPlayPauseButton(
                            isPlaying: isPlaying,
                            onTap: audio.togglePlayPause,
                          ),
                          _AnimatedSkipButton(
                            icon: Icons.skip_next_rounded,
                            isForward: true,
                            onTap: audio.playNext,
                          ),
                          _AnimatedRepeatButton(
                            loopMode: audio.loopMode,
                            onTap: audio.toggleLoop,
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Bottom Row: Separated standalone buttons
                    // LEFT: Playlist Queue | RIGHT: Speed & Pitch
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left: Playlist Queue (زر قائمة التشغيل على اليسار)
                            _buildStandaloneIconButton(
                              icon: Icons.queue_music_rounded,
                              color: AppTheme.accentColor,
                              tooltip: LanguageService().t('queue'),
                              onTap: () => _showQueueModal(context, audio),
                            ),

                            // Center drag pill
                            Container(
                              width: 38,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppTheme.isDark ? Colors.white12 : Colors.black12,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),

                            // Right: Speed & Pitch (زر السرعة على اليمين)
                            _buildStandaloneIconButton(
                              icon: audio.playbackSpeed > 1.0
                                  ? Icons.bolt_rounded
                                  : (audio.playbackSpeed < 1.0
                                      ? Icons.slow_motion_video_rounded
                                      : Icons.speed_rounded),
                              color: audio.playbackSpeed != 1.0
                                  ? AppTheme.accentColor
                                  : (AppTheme.isDark ? Colors.white70 : AppTheme.textSecondary),
                              hasGlow: audio.playbackSpeed != 1.0,
                              tooltip: LanguageService.tr('speed_pitch'),
                              onTap: () => _showSpeedModal(context, audio),
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
      ),
    ),
  );
}

        return Stack(
          fit: StackFit.expand,
          children: [
            mainContent,
            if (_isCinematicTransitionActive)
              Positioned.fill(
                child: CinematicOrientationTransition(
                  onOrientationChangeTrigger: () {
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.landscapeLeft,
                      DeviceOrientation.landscapeRight,
                    ]);
                  },
                  onFinished: () {
                    if (mounted) {
                      setState(() {
                        _isCinematicTransitionActive = false;
                      });
                    }
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStandaloneIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
    bool hasGlow = false,
  }) {
    final isDark = AppTheme.isDark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B232E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasGlow ? color.withOpacity(0.55) : (isDark ? const Color(0xFF2C3949) : AppTheme.cardBorder),
            width: 1.2,
          ),
          boxShadow: [
            if (hasGlow)
              BoxShadow(
                color: color.withOpacity(0.25),
                blurRadius: 12,
                spreadRadius: 0.5,
              ),
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.26 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            color: color,
            size: 25,
          ),
        ),
      ),
    );
  }

  void _showNowPlayingOptionsMenu(BuildContext context, SongModel song, AudioService audio) {
    showGlassBottomSheet(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: LanguageService().textDirection,
        child: GlassBottomSheet(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                // Song preview card
                GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      QueryArtworkOrFallback(
                        id: song.id,
                        size: 48,
                        borderRadius: 12,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              SongEditService().getDisplayTitle(song),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              SongEditService().getDisplayArtist(song),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Actions
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.auto_awesome_rounded,
                              color: AppTheme.accentColor, size: 20),
                        ),
                        title: Text(
                          LanguageService().isArabic
                              ? 'المؤثرات الصوتية (الصدى)'
                              : 'Audio Effects (Echo)',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          AudioEffectsService().activeEffectTitle,
                          style: TextStyle(
                            color: AppTheme.accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Icon(Icons.chevron_left_rounded,
                            color: AppTheme.textSecondary, size: 20),
                        onTap: () {
                          Navigator.pop(ctx);
                          showAudioEffectsSheet(context);
                        },
                      ),
                      Divider(color: AppTheme.dividerColor, height: 1, indent: 56),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.screen_rotation_rounded,
                              color: AppTheme.accentColor, size: 20),
                        ),
                        title: Text(
                          LanguageService.tr('landscape_mode'),
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600),
                        ),
                        trailing: Icon(Icons.chevron_left_rounded,
                            color: AppTheme.textSecondary, size: 20),
                        onTap: () {
                          Navigator.pop(ctx);
                          _startCinematicLandscapeTransition();
                        },
                      ),
                      Divider(color: AppTheme.dividerColor, height: 1, indent: 56),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.style_rounded,
                              color: AppTheme.accentColor, size: 20),
                        ),
                        title: Text(
                          LanguageService.tr('select_player_theme'),
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600),
                        ),
                        trailing: Icon(Icons.chevron_left_rounded,
                            color: AppTheme.textSecondary, size: 20),
                        onTap: () {
                          Navigator.pop(ctx);
                          showPlayerThemeSelector(context);
                        },
                      ),
                      Divider(color: AppTheme.dividerColor, height: 1, indent: 56),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.info_outline_rounded,
                              color: AppTheme.accentColor, size: 20),
                        ),
                        title: Text(
                          LanguageService.tr('song_details'),
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600),
                        ),
                        trailing: Icon(Icons.chevron_left_rounded,
                            color: AppTheme.textSecondary, size: 20),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showSongDetails(context, song, audio);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSpeedModal(BuildContext context, AudioService audio) {
    showGlassBottomSheet(
      context: context,
      builder: (ctx) => ValueListenableBuilder<Color>(
        valueListenable: AppTheme.accentColorNotifier,
        builder: (context, themeAccent, _) {
          return AnimatedBuilder(
            animation: audio,
            builder: (context, _) {
              final currentSpeed = audio.playbackSpeed;
              final isLinked = audio.linkPitchToSpeed;

              final Color accentColor = themeAccent;
              String speedLabel;
              IconData speedIcon;

              if (currentSpeed > 1.0) {
                speedLabel = LanguageService.tr('speed_fast');
                speedIcon = Icons.bolt_rounded;
              } else if (currentSpeed < 1.0) {
                speedLabel = LanguageService.tr('speed_slow');
                speedIcon = Icons.slow_motion_video_rounded;
              } else {
                speedLabel = LanguageService.tr('speed_normal');
                speedIcon = Icons.play_arrow_rounded;
              }

              final isDark = AppTheme.isDark;
              final subCardBg = isDark ? Colors.white.withOpacity(0.065) : Colors.black.withOpacity(0.038);
              final subCardBorder = isDark ? Colors.white.withOpacity(0.09) : Colors.black.withOpacity(0.06);
              final textMutedColor = AppTheme.textMuted;

              return Directionality(
                textDirection: LanguageService().textDirection,
                child: GlassBottomSheet(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Center(
                                child: Container(
                                  width: 44,
                                  height: 4.5,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white24 : Colors.black12,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: accentColor.withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(speedIcon, color: accentColor, size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        LanguageService.tr('speed_pitch'),
                                        style: TextStyle(
                                          color: isDark ? Colors.white : AppTheme.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      if (currentSpeed != 1.0)
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            backgroundColor: accentColor.withOpacity(0.12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          icon: Icon(Icons.restore_rounded, size: 16, color: accentColor),
                                          label: Text(
                                            '1.0x',
                                            style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: () => audio.setPlaybackSpeed(1.0),
                                        ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: Icon(Icons.close_rounded, color: textMutedColor),
                                        onPressed: () => Navigator.pop(ctx),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: subCardBg,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: accentColor.withOpacity(0.35), width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withOpacity(0.1),
                                      blurRadius: 16,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      currentSpeed.toStringAsFixed(2),
                                      style: TextStyle(
                                        color: accentColor,
                                        fontSize: 38,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'x',
                                      style: TextStyle(
                                        color: accentColor.withOpacity(0.8),
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: accentColor.withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        speedLabel,
                                        style: TextStyle(
                                          color: accentColor,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: [
                                    _buildSpeedChip(label: '0.8x', speed: 0.8, current: currentSpeed, icon: Icons.slow_motion_video_rounded, activeColor: accentColor, onTap: () => audio.setPlaybackSpeed(0.8)),
                                    const SizedBox(width: 8),
                                    _buildSpeedChip(label: '1.0x', speed: 1.0, current: currentSpeed, icon: Icons.play_arrow_rounded, activeColor: accentColor, onTap: () => audio.setPlaybackSpeed(1.0)),
                                    const SizedBox(width: 8),
                                    _buildSpeedChip(label: '1.3x', speed: 1.3, current: currentSpeed, icon: Icons.bolt_rounded, activeColor: accentColor, onTap: () => audio.setPlaybackSpeed(1.3)),
                                    const SizedBox(width: 8),
                                    _buildSpeedChip(label: '1.5x', speed: 1.5, current: currentSpeed, icon: Icons.fast_forward_rounded, activeColor: accentColor, onTap: () => audio.setPlaybackSpeed(1.5)),
                                    const SizedBox(width: 8),
                                    _buildSpeedChip(label: '2.0x', speed: 2.0, current: currentSpeed, icon: Icons.double_arrow_rounded, activeColor: accentColor, onTap: () => audio.setPlaybackSpeed(2.0)),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Fine slider stepping by 0.01 degree!
                              Row(
                                children: [
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: subCardBg,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: Icon(Icons.remove_rounded, color: isDark ? Colors.white : AppTheme.textPrimary, size: 20),
                                    onPressed: () {
                                      final newSpeed = double.parse(((currentSpeed - 0.01).clamp(0.1, 3.0)).toStringAsFixed(2));
                                      audio.setPlaybackSpeed(newSpeed);
                                    },
                                  ),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: accentColor,
                                        inactiveTrackColor: accentColor.withOpacity(0.2),
                                        thumbColor: accentColor,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                        overlayColor: accentColor.withOpacity(0.2),
                                        trackHeight: 4.5,
                                      ),
                                      child: Slider(
                                        value: currentSpeed.clamp(0.1, 3.0),
                                        min: 0.1,
                                        max: 3.0,
                                        onChanged: (val) {
                                          final rounded = double.parse(val.clamp(0.1, 3.0).toStringAsFixed(2));
                                          audio.setPlaybackSpeed(rounded);
                                        },
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: subCardBg,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: Icon(Icons.add_rounded, color: isDark ? Colors.white : AppTheme.textPrimary, size: 20),
                                    onPressed: () {
                                      final newSpeed = double.parse(((currentSpeed + 0.01).clamp(0.1, 3.0)).toStringAsFixed(2));
                                      audio.setPlaybackSpeed(newSpeed);
                                    },
                                  ),
                                ],
                              ),

                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('0.1x', style: TextStyle(color: textMutedColor, fontSize: 11)),
                                    Text('${currentSpeed.toStringAsFixed(2)}x', style: TextStyle(color: accentColor, fontSize: 11.5, fontWeight: FontWeight.bold)),
                                    Text('3.0x', style: TextStyle(color: textMutedColor, fontSize: 11)),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isLinked ? accentColor.withOpacity(0.12) : subCardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isLinked ? accentColor.withOpacity(0.45) : subCardBorder,
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isLinked ? accentColor.withOpacity(0.2) : (isDark ? const Color(0xFF222C3D) : AppTheme.cardColor),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.graphic_eq_rounded,
                                        color: isLinked ? accentColor : textMutedColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            LanguageService.tr('link_pitch_speed'),
                                            style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            isLinked ? LanguageService.tr('pitch_changes_with_speed') : LanguageService.tr('pitch_fixed'),
                                            style: TextStyle(color: isLinked ? accentColor : textMutedColor, fontSize: 10.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: isLinked,
                                      activeColor: accentColor,
                                      activeTrackColor: accentColor.withOpacity(0.35),
                                      inactiveThumbColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1),
                                      inactiveTrackColor: isDark ? const Color(0xFF263242) : const Color(0xFFE2E8F0),
                                      onChanged: (val) => audio.setLinkPitchToSpeed(val),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      }

  void _showQueueModal(BuildContext context, AudioService audio) {
    showGlassBottomSheet(
      context: context,
      builder: (ctx) => AnimatedBuilder(
        animation: audio,
        builder: (context, _) {
          return Directionality(
            textDirection: LanguageService().textDirection,
            child: GlassBottomSheet(
              height: MediaQuery.of(context).size.height * 0.68,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: AppTheme.isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.queue_music_rounded, color: AppTheme.accentColor, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              LanguageService().t('queue'),
                              style: TextStyle(
                                color: AppTheme.isDark ? Colors.white : AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${audio.currentPlaylist.length}',
                                style: TextStyle(
                                  color: AppTheme.accentColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (audio.isTemporarySelectedQueue) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppTheme.accentColor.withValues(alpha: 0.45),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.repeat_rounded, size: 12, color: AppTheme.accentColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      LanguageService().isArabic
                                          ? 'ألبوم مؤقت مكرر'
                                          : 'Looping Temp Album',
                                      style: TextStyle(
                                        color: AppTheme.accentColor,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: AppTheme.isDark ? Colors.white70 : AppTheme.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: AppTheme.dividerColor, height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: audio.currentPlaylist.length,
                      separatorBuilder: (context, index) => Divider(color: AppTheme.dividerColor, height: 1),
                      itemBuilder: (context, index) {
                        final itemSong = audio.currentPlaylist[index];
                        final isCurrent = audio.currentSong?.id == itemSong.id;

                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (audio.isTemporarySelectedQueue) ...[
                                Container(
                                  width: 22,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: isCurrent ? AppTheme.accentColor : AppTheme.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              QueryArtworkOrFallback(
                                id: itemSong.id,
                                size: 44,
                                borderRadius: 10,
                              ),
                            ],
                          ),
                          title: Text(
                            SongEditService().getDisplayTitle(itemSong),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrent ? AppTheme.accentColor : AppTheme.textPrimary,
                              fontSize: 13.5,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            SongEditService().getDisplayArtist(itemSong),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrent ? AppTheme.accentColor.withValues(alpha: 0.7) : AppTheme.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                          trailing: isCurrent
                              ? Icon(Icons.equalizer_rounded, color: AppTheme.accentColor, size: 22)
                              : null,
                          onTap: () {
                            audio.playSong(itemSong, playlist: audio.currentPlaylist);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSongDetails(BuildContext context, SongModel song, AudioService audio) {
    showGlassBottomSheet(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: LanguageService().textDirection,
        child: GlassBottomSheet(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppTheme.accentColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    LanguageService().t('details'),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  children: [
                    _detailRow(LanguageService.tr('detail_title'), SongEditService().getDisplayTitle(song)),
                    Divider(color: AppTheme.dividerColor, height: 12),
                    _detailRow(LanguageService.tr('detail_artist'), SongEditService().getDisplayArtist(song)),
                    Divider(color: AppTheme.dividerColor, height: 12),
                    _detailRow(LanguageService.tr('detail_album'), song.album ?? LanguageService.tr('unknown_album')),
                    Divider(color: AppTheme.dividerColor, height: 12),
                    _detailRow(LanguageService.tr('detail_duration'), audio.formatDuration(song.duration)),
                    if (song.size > 0) ...[
                      Divider(color: AppTheme.dividerColor, height: 12),
                      _detailRow(LanguageService.tr('detail_size'), '${(song.size / (1024 * 1024)).toStringAsFixed(2)} ${LanguageService.tr('mb')}'),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedChip({
    required String label,
    required double speed,
    required double current,
    required IconData icon,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final isSelected = (current - speed).abs() < 0.03;
    final isDark = AppTheme.isDark;
    final inactiveBg = isDark ? const Color(0xFF1A2230) : AppTheme.surfaceLight;
    final inactiveBorder = isDark ? const Color(0xFF283648) : AppTheme.cardBorder;
    final inactiveColor = AppTheme.textSecondary;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.18) : inactiveBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : inactiveBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? activeColor : inactiveColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : (isDark ? const Color(0xFFCBD5E1) : AppTheme.textPrimary),
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Swipeable Artwork Gesture Widget (Drag Left for Next, Drag Right for Prev)
// ---------------------------------------------------------------------------

class _SwipeableArtwork extends StatefulWidget {
  final SongModel song;
  final AudioService audio;
  final double size;

  const _SwipeableArtwork({
    super.key,
    required this.song,
    required this.audio,
    required this.size,
  });

  @override
  State<_SwipeableArtwork> createState() => _SwipeableArtworkState();
}

class _SwipeableArtworkState extends State<_SwipeableArtwork>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _isAnimating = false;
  late final AnimationController _resetController;
  late Animation<double> _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;
    setState(() {
      _dragOffset += details.primaryDelta!;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_isAnimating) return;
    final velocity = details.primaryVelocity ?? 0.0;
    const threshold = 60.0;

    if (_dragOffset < -threshold || velocity < -350) {
      // Swiped Left -> Next Track (الأغنية التالية)
      _animateAndTrigger(isNext: true);
    } else if (_dragOffset > threshold || velocity > 350) {
      // Swiped Right -> Previous Track (الأغنية السابقة)
      _animateAndTrigger(isNext: false);
    } else {
      // Snap back to center
      _snapBack();
    }
  }

  void _animateAndTrigger({required bool isNext}) {
    _isAnimating = true;
    final targetOffset = isNext ? -380.0 : 380.0;

    _resetAnimation = Tween<double>(
      begin: _dragOffset,
      end: targetOffset,
    ).animate(CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeOutCubic,
    ));

    _resetController.duration = const Duration(milliseconds: 170);
    _resetController.forward(from: 0.0).then((_) {
      if (isNext) {
        widget.audio.playNext();
      } else {
        widget.audio.playPrevious();
      }

      // Enter smoothly from opposite side
      if (mounted) {
        setState(() {
          _dragOffset = isNext ? 150.0 : -150.0;
        });

        _resetAnimation = Tween<double>(
          begin: _dragOffset,
          end: 0.0,
        ).animate(CurvedAnimation(
          parent: _resetController,
          curve: Curves.easeOutBack,
        ));

        _resetController.duration = const Duration(milliseconds: 300);
        _resetController.forward(from: 0.0).then((_) {
          if (mounted) {
            setState(() {
              _dragOffset = 0.0;
              _isAnimating = false;
            });
          }
        });
      }
    });
  }

  void _snapBack() {
    _resetAnimation = Tween<double>(
      begin: _dragOffset,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeOutCubic,
    ));

    _resetController.duration = const Duration(milliseconds: 220);
    _resetController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _resetController,
      builder: (context, child) {
        final currentOffset = _resetController.isAnimating
            ? _resetAnimation.value
            : _dragOffset;

        final rotation = currentOffset * 0.00032;
        final opacity = (1.0 - (currentOffset.abs() / 650.0)).clamp(0.65, 1.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
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
      child: NowPlayingArtwork(
        key: ValueKey(widget.song.id),
        songId: widget.song.id,
        size: widget.size,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated Controls & Interactive Draggable Progress Bar
// ---------------------------------------------------------------------------

class _AnimatedHeartButton extends StatefulWidget {
  final bool isFav;
  final VoidCallback onTap;

  const _AnimatedHeartButton({
    required this.isFav,
    required this.onTap,
  });

  @override
  State<_AnimatedHeartButton> createState() => _AnimatedHeartButtonState();
}

class _AnimatedHeartButtonState extends State<_AnimatedHeartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.45).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.45, end: 0.88).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.88, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: Icon(
              Icons.favorite_rounded,
              key: ValueKey<bool>(widget.isFav),
              color: widget.isFav
                  ? const Color(0xFFFF2D55)
                  : (AppTheme.isDark ? Colors.white.withOpacity(0.40) : AppTheme.textSecondary.withOpacity(0.45)),
              size: 29,
              shadows: widget.isFav
                  ? [
                      Shadow(
                        color: const Color(0xFFFF2D55).withOpacity(0.55),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _InteractiveProgressBar extends StatefulWidget {
  final SongModel song;
  final AudioService audio;

  const _InteractiveProgressBar({
    required this.song,
    required this.audio,
  });

  @override
  State<_InteractiveProgressBar> createState() => _InteractiveProgressBarState();
}

class _InteractiveProgressBarState extends State<_InteractiveProgressBar> {
  bool _isDragging = false;
  double _dragPositionMs = 0.0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.audio.player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final total = widget.audio.player.duration ??
            Duration(milliseconds: widget.song.duration ?? 0);
        final maxMs = total.inMilliseconds.toDouble();
        final effectiveMaxMs = maxMs > 0 ? maxMs : 1.0;

        final currentMs = _isDragging
            ? _dragPositionMs.clamp(0.0, effectiveMaxMs)
            : position.inMilliseconds.toDouble().clamp(0.0, effectiveMaxMs);

        final displayCurrentTime = _isDragging
            ? widget.audio.formatDuration(currentMs.round())
            : widget.audio.formatDuration(position.inMilliseconds);

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.accentColor,
                inactiveTrackColor: (AppTheme.isDark ? Colors.white : Colors.black).withOpacity(0.12),
                thumbColor: AppTheme.accentColor,
                trackHeight: _isDragging ? 5.5 : 3.8,
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: _isDragging ? 10.0 : 6.5,
                  elevation: _isDragging ? 6 : 2,
                  pressedElevation: 8,
                ),
                overlayShape: RoundSliderOverlayShape(
                  overlayRadius: _isDragging ? 22.0 : 14.0,
                ),
                overlayColor: AppTheme.accentColor.withValues(alpha: 0.25),
              ),
              child: Slider(
                value: currentMs,
                min: 0.0,
                max: effectiveMaxMs,
                onChangeStart: (val) {
                  setState(() {
                    _isDragging = true;
                    _dragPositionMs = val;
                  });
                  widget.audio.setScrubbingMuted(true);
                },
                onChanged: (val) {
                  setState(() {
                    _dragPositionMs = val;
                  });
                },
                onChangeEnd: (val) async {
                  final targetMs = val.round();
                  await widget.audio.seek(Duration(milliseconds: targetMs));
                  await widget.audio.setScrubbingMuted(false);
                  if (mounted) {
                    setState(() {
                      _isDragging = false;
                    });
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 150),
                    style: TextStyle(
                      color: _isDragging
                          ? AppTheme.accentColor
                          : (AppTheme.isDark ? Colors.white.withOpacity(0.55) : AppTheme.textSecondary),
                      fontSize: _isDragging ? 13 : 12,
                      fontWeight: _isDragging ? FontWeight.bold : FontWeight.w500,
                    ),
                    child: Text(displayCurrentTime),
                  ),
                  Text(
                    widget.audio.formatDuration(total.inMilliseconds),
                    style: TextStyle(
                      color: AppTheme.isDark ? Colors.white.withOpacity(0.55) : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedPlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _AnimatedPlayPauseButton({
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<_AnimatedPlayPauseButton> createState() => _AnimatedPlayPauseButtonState();
}

class _AnimatedPlayPauseButtonState extends State<_AnimatedPlayPauseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.reverse();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.forward();
    widget.onTap();
  }

  void _onTapCancel() {
    _scaleController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.accentColor,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentColor.withValues(alpha: widget.isPlaying ? 0.45 : 0.2),
                blurRadius: widget.isPlaying ? 20 : 10,
                spreadRadius: widget.isPlaying ? 2 : 0,
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return RotationTransition(
                turns: Tween<double>(begin: 0.15, end: 0.0).animate(animation),
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: Icon(
              widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey<bool>(widget.isPlaying),
              color: AppTheme.accentColor.computeLuminance() > 0.4 ? Colors.black : Colors.white,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedSkipButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isForward;

  const _AnimatedSkipButton({
    required this.icon,
    required this.onTap,
    this.isForward = true,
  });

  @override
  State<_AnimatedSkipButton> createState() => _AnimatedSkipButtonState();
}

class _AnimatedSkipButtonState extends State<_AnimatedSkipButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8), weight: 40),
      TweenSequenceItem(
        tween: Tween(begin: 0.8, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_controller);

    final offsetDistance = widget.isForward ? 0.22 : -0.22;
    _slideAnimation = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: Offset(offsetDistance, 0.0)), weight: 40),
      TweenSequenceItem(
        tween: Tween(begin: Offset(offsetDistance, 0.0), end: Offset.zero).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              widget.icon,
              size: 42,
              color: AppTheme.isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedShuffleButton extends StatefulWidget {
  final bool isShuffle;
  final VoidCallback onTap;

  const _AnimatedShuffleButton({
    required this.isShuffle,
    required this.onTap,
  });

  @override
  State<_AnimatedShuffleButton> createState() => _AnimatedShuffleButtonState();
}

class _AnimatedShuffleButtonState extends State<_AnimatedShuffleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotationAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _rotationAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: RotationTransition(
          turns: _rotationAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Icon(
              Icons.shuffle_rounded,
              color: widget.isShuffle
                  ? AppTheme.accentColor
                  : (AppTheme.isDark ? Colors.white54 : AppTheme.textSecondary),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedRepeatButton extends StatefulWidget {
  final LoopMode loopMode;
  final VoidCallback onTap;

  const _AnimatedRepeatButton({
    required this.loopMode,
    required this.onTap,
  });

  @override
  State<_AnimatedRepeatButton> createState() => _AnimatedRepeatButtonState();
}

class _AnimatedRepeatButtonState extends State<_AnimatedRepeatButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotationAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _rotationAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isOne = widget.loopMode == LoopMode.one;
    final isActive = widget.loopMode != LoopMode.off;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: RotationTransition(
          turns: _rotationAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(
                isOne ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                key: ValueKey<LoopMode>(widget.loopMode),
                color: isActive
                    ? AppTheme.accentColor
                    : (AppTheme.isDark ? Colors.white54 : AppTheme.textSecondary),
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundPlaylistView extends StatelessWidget {
  final AudioService audio;
  final int currentSongId;

  const _BackgroundPlaylistView({
    required this.audio,
    required this.currentSongId,
  });

  @override
  Widget build(BuildContext context) {
    final list = audio.currentPlaylist.isNotEmpty ? audio.currentPlaylist : audio.allSongs;
    if (list.isEmpty) {
      return const SizedBox.shrink();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 72,
          bottom: 120,
          left: 20,
          right: 20,
        ),
        itemCount: list.length.clamp(0, 30),
        itemBuilder: (context, index) {
          final song = list[index];
          final isCurrent = song.id == currentSongId;
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (AppTheme.isDark ? const Color(0xFF161F2A) : AppTheme.cardColor).withOpacity(0.70),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.cardBorder,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: QueryArtworkOrFallback(
                      id: song.id,
                      type: ArtworkType.AUDIO,
                      size: 50,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        SongEditService().getDisplayTitle(song),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent
                              ? AppTheme.accentColor
                              : AppTheme.textPrimary,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        SongEditService().getDisplayArtist(song),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isCurrent)
                  Icon(
                    Icons.equalizer_rounded,
                    color: AppTheme.accentColor,
                    size: 22,
                  )
                else
                  Icon(
                    Icons.more_vert_rounded,
                    color: AppTheme.textMuted,
                    size: 20,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

