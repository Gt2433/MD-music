import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/language_service.dart';
import '../services/music_recognition_service.dart';
import '../theme/app_theme.dart';

class MusicRecognitionScreen extends StatefulWidget {
  const MusicRecognitionScreen({super.key});

  @override
  State<MusicRecognitionScreen> createState() => _MusicRecognitionScreenState();
}

class _MusicRecognitionScreenState extends State<MusicRecognitionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final MusicRecognitionService _service = MusicRecognitionService();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _service.init();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService();
    final isArabic = lang.isArabic;
    final accent = AppTheme.accentColor;

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E14),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _service,
            builder: (context, _) {
              final isSuccess = _service.state == RecognitionState.success &&
                  _service.currentResult != null;

              return Stack(
                children: [
                  // Ambient Background Glows
                  _buildAmbientBackground(accent),

                  Column(
                    children: [
                      // Top Bar
                      _buildTopBar(context, isArabic, accent),

                      // Main Content: Animated Switcher between Radar and Success Card
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween<double>(begin: 0.92, end: 1.0)
                                        .animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: isSuccess
                                  ? _buildSuccessCard(
                                      context, isArabic, accent)
                                  : _buildRadarSection(isArabic, accent),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Ambient Glows
  // -------------------------------------------------------------
  Widget _buildAmbientBackground(Color accent) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: 100,
            left: 30,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(0.09),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: const SizedBox(),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            right: 30,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.06),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: const SizedBox(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Top App Bar
  // -------------------------------------------------------------
  Widget _buildTopBar(BuildContext context, bool isArabic, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: IconButton(
              icon: Icon(
                isArabic
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.arrow_back_ios_rounded,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            LanguageService().t('music_recognition_title'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),

          // History Button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: IconButton(
              tooltip: LanguageService().t('music_recognition_history'),
              icon: Icon(Icons.history_rounded, color: accent, size: 22),
              onPressed: () => _openHistorySheet(context, isArabic, accent),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Radar Section: Continuous pulsating visual without any timers
  // -------------------------------------------------------------
  Widget _buildRadarSection(bool isArabic, Color accent) {
    // Both listening & analyzing look like continuous active listening
    final isBusy = _service.state == RecognitionState.listening ||
        _service.state == RecognitionState.analyzing;
    final isNotFound = _service.state == RecognitionState.notFound;
    final isError = _service.state == RecognitionState.error;
    final amp = _service.amplitude;

    String title;
    String subtitle;

    if (isBusy) {
      title = LanguageService().t('music_recognition_listening');
      subtitle = LanguageService().t('music_recognition_listening_sub');
    } else if (isNotFound) {
      title = LanguageService().t('music_recognition_no_match');
      subtitle = LanguageService().t('music_recognition_no_match_sub');
    } else if (isError) {
      title = LanguageService().t('music_recognition_notice');
      subtitle = _service.errorMessage ??
          LanguageService().t('music_recognition_conn_error');
    } else {
      title = LanguageService().t('music_recognition_tap_radar');
      subtitle = LanguageService().t('music_recognition_tap_radar_sub');
    }

    return Column(
      key: const ValueKey('radar_section'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            if (isBusy) {
              _service.cancelRecognition();
            } else {
              _service.startRecognition();
            }
          },
          child: SizedBox(
            width: 270,
            height: 270,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Animated Concentric Pulsing Ripples (continuous during both listening & searching)
                if (isBusy)
                  ...List.generate(3, (index) {
                    return AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        final progress =
                            (_pulseController.value + (index / 3.0)) % 1.0;
                        final size = 110 + (progress * 150) + (amp * 20);
                        final opacity =
                            (1.0 - progress).clamp(0.0, 1.0) * 0.45;

                        return Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent.withOpacity(opacity),
                              width: 2.2 - (progress * 1.3),
                            ),
                          ),
                        );
                      },
                    );
                  }),

                // Outer glowing gradient ring
                Container(
                  width: 176,
                  height: 176,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withOpacity(isBusy ? 0.28 : 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // Core Orb Button with soundwave icon
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 126 + (amp * 16),
                  height: 126 + (amp * 16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        accent,
                        Color.lerp(accent, Colors.black, 0.28)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(isBusy ? 0.65 : 0.35),
                        blurRadius: isBusy ? 40 : 22,
                        spreadRadius: isBusy ? 5 : 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isBusy
                          ? Icons.graphic_eq_rounded
                          : Icons.music_note_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 38),

        // Title and Subtitle without countdown
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),

        if (isNotFound || isError) ...[
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(LanguageService().t('music_recognition_try_again')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                ),
                onPressed: () => _service.startRecognition(),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------------
  // Hero Identified Song Card (Appears suddenly when recognized)
  // -------------------------------------------------------------
  Widget _buildSuccessCard(
      BuildContext context, bool isArabic, Color accent) {
    final track = _service.currentResult!;
    final localMatch = track.findLocalMatch();

    return Padding(
      key: const ValueKey('success_card'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141922),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: accent.withOpacity(0.45), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.22),
              blurRadius: 36,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Large Album Artwork
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 140,
                  height: 140,
                  color: Colors.white.withOpacity(0.08),
                  child: track.artworkUrl != null
                      ? Image.network(
                          track.artworkUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Image.asset(
                            'assets/images/app_icon.png',
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          'assets/images/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Song Title
            Text(
              track.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19.0,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 6),

            // Artist Name
            Text(
              track.artist,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 15.0,
                fontWeight: FontWeight.w600,
              ),
            ),

            if (track.album != null && track.album!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                track.album!,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 12.0,
                ),
              ),
            ],

            // Local Match Banner
            if (localMatch != null) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        LanguageService().t('music_recognition_in_library'),
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        await _service.playLocalMatch(localMatch);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                LanguageService().t('music_recognition_playing_local'),
                              ),
                              backgroundColor: const Color(0xFF1E2530),
                            ),
                          );
                        }
                      },
                      child: Text(
                        LanguageService().t('music_recognition_play_now'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Streaming Listen Buttons
            Row(
              children: [
                // YouTube Button
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 22),
                    label: Text(
                      LanguageService().t('music_recognition_youtube'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0000),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _service.openInYouTube(track),
                  ),
                ),
                const SizedBox(width: 10),

                // Spotify Button
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.graphic_eq_rounded,
                        color: Colors.black, size: 20),
                    label: Text(
                      LanguageService().t('music_recognition_spotify'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 13.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.black,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _service.openInSpotify(track),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Secondary Buttons: [ نسخ التفاصيل ] & [ الاستماع لأغنية أخرى ]
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 17),
                    label: Text(
                      LanguageService().t('music_recognition_copy_info'),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withOpacity(0.18)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                          text: '${track.title} - ${track.artist}'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            LanguageService().t('music_recognition_copied'),
                          ),
                          backgroundColor: const Color(0xFF1E2530),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.radar_rounded, size: 18, color: accent),
                    label: Text(
                      LanguageService().t('music_recognition_identify_another'),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () {
                      _service.reset();
                      _service.startRecognition();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Recognition History Sheet
  // -------------------------------------------------------------
  void _openHistorySheet(BuildContext context, bool isArabic, Color accent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10151D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final history = _service.history;

            return Column(
              children: [
                // Pill Handle
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Sheet Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, color: accent, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        LanguageService().t('music_recognition_history_title'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (history.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            await _service.clearHistory();
                            setSheetState(() {});
                          },
                          child: Text(
                            LanguageService().t('music_recognition_clear_all'),
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),

                // History List
                Expanded(
                  child: history.isEmpty
                      ? Center(
                          child: Text(
                            LanguageService().t('music_recognition_empty_history'),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemCount: history.length,
                          separatorBuilder: (_, _) =>
                              const Divider(color: Colors.white10, height: 1),
                          itemBuilder: (ctx, index) {
                            final item = history[index];
                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  color: Colors.white.withOpacity(0.08),
                                  child: item.artworkUrl != null
                                      ? Image.network(
                                          item.artworkUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              Image.asset(
                                            'assets/images/app_icon.png',
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Image.asset(
                                          'assets/images/app_icon.png',
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              title: Text(
                                item.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                item.artist,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.65),
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.play_arrow_rounded,
                                        color: Colors.redAccent, size: 22),
                                    onPressed: () =>
                                        _service.openInYouTube(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.graphic_eq_rounded,
                                        color: Colors.greenAccent, size: 19),
                                    onPressed: () =>
                                        _service.openInSpotify(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.white38,
                                        size: 19),
                                    onPressed: () async {
                                      await _service.deleteHistoryItem(index);
                                      setSheetState(() {});
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
