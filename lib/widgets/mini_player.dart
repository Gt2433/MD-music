import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../theme/app_theme.dart';
import 'now_playing_sheet.dart';
import 'query_artwork_or_fallback.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = AudioService();

    return AnimatedBuilder(
      animation: audio,
      builder: (context, _) {
        final song = audio.currentSong;
        if (song == null) {
          return const SizedBox.shrink();
        }

        final isPlaying = audio.player.playing;

        return Directionality(
          textDirection: Directionality.of(context),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  NowPlayingSheet.show(context);
                },
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppTheme.isDark
                          ? (AppTheme.amoledBlackNotifier.value
                              ? const [Color(0xFF0F0F0F), Color(0xFF050505)]
                              : const [Color(0xF21C2533), Color(0xF2141A24)])
                          : const [Color(0xF8FFFFFF), Color(0xF2F1F5F9)],
                    ),
                    border: Border.all(
                      color: AppTheme.isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: AppTheme.isDark ? 0.60 : 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: AppTheme.accentColor.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Stack(
                        children: [
                          // Thin progress indicator at top of floating capsule
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: StreamBuilder<Duration>(
                              stream: audio.player.positionStream,
                              builder: (context, snapshot) {
                                final pos = snapshot.data?.inMilliseconds ?? 0;
                                final total = audio.player.duration?.inMilliseconds ?? (song.duration ?? 1);
                                final progress = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
                                return ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: (AppTheme.isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
                                    minHeight: 2.5,
                                  ),
                                );
                              },
                            ),
                          ),

                          // Content Row
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                // Cover art (Enlarged modern squircle)
                                QueryArtworkOrFallback(
                                  id: song.id,
                                  size: 52,
                                  borderRadius: 14,
                                ),
                                const SizedBox(width: 12),

                                // Song Title & Artist
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        song.artist ??
                                            LanguageService.tr('unknown_artist'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Previous Song Button
                                _MiniBouncyButton(
                                  icon: Icons.skip_previous_rounded,
                                  iconSize: 26,
                                  color: AppTheme.textSecondary,
                                  onTap: audio.playPrevious,
                                ),
                                const SizedBox(width: 4),

                                // Play / Pause Button with morph animation
                                _MiniPlayPauseButton(
                                  isPlaying: isPlaying,
                                  onTap: audio.togglePlayPause,
                                ),
                                const SizedBox(width: 4),

                                // Next Song Button
                                _MiniBouncyButton(
                                  icon: Icons.skip_next_rounded,
                                  iconSize: 26,
                                  color: AppTheme.textSecondary,
                                  onTap: audio.playNext,
                                ),
                              ],
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
        );
      },
    );
  }
}

class _MiniBouncyButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final Color color;
  final VoidCallback onTap;

  const _MiniBouncyButton({
    required this.icon,
    required this.iconSize,
    required this.color,
    required this.onTap,
  });

  @override
  State<_MiniBouncyButton> createState() => _MiniBouncyButtonState();
}

class _MiniBouncyButtonState extends State<_MiniBouncyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.78), weight: 40),
      TweenSequenceItem(
        tween: Tween(begin: 0.78, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
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
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _MiniPlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _MiniPlayPauseButton({
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<_MiniPlayPauseButton> createState() => _MiniPlayPauseButtonState();
}

class _MiniPlayPauseButtonState extends State<_MiniPlayPauseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      lowerBound: 0.85,
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: child,
            );
          },
          child: Container(
            key: ValueKey<bool>(widget.isPlaying),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.accentColor, AppTheme.accentColor.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentColor.withValues(alpha: 0.38),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: AppTheme.accentColor.computeLuminance() > 0.4 ? Colors.black : Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

