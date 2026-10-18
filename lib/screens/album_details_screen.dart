import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import '../services/album_service.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../services/song_edit_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/now_playing_sheet.dart';
import '../widgets/query_artwork_or_fallback.dart';
import '../widgets/glass_dialog.dart';

class AlbumDetailsScreen extends StatefulWidget {
  final CustomAlbum album;

  const AlbumDetailsScreen({super.key, required this.album});

  static void showAddSongsSheet(
    BuildContext context,
    CustomAlbum album, {
    AudioService? audioService,
    AlbumService? albumService,
  }) {
    _AlbumDetailsScreenState.showAddSongsSheet(
      context,
      album,
      audioService: audioService,
      albumService: albumService,
    );
  }

  @override
  State<AlbumDetailsScreen> createState() => _AlbumDetailsScreenState();
}

class _AlbumDetailsScreenState extends State<AlbumDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final audio = AudioService();
    final albumService = AlbumService();
    final lang = LanguageService();

    return Directionality(
      textDirection: lang.textDirection,
      child: AnimatedBuilder(
        animation: Listenable.merge([audio, albumService, lang.currentLanguage]),
        builder: (context, _) {
          final currentAlbum = albumService.albums.firstWhere(
            (a) => a.id == widget.album.id,
            orElse: () => widget.album,
          );
          final albumSongs = albumService.getSongsForAlbum(currentAlbum.id, audio.allSongs);
          final hasSongs = albumSongs.isNotEmpty;
          final firstSong = hasSongs ? albumSongs.first : null;

          return Scaffold(
            backgroundColor: AppTheme.background,
            body: Stack(
              children: [
                // Background Gradient (Adaptive: Deep emerald dark tint at top in dark mode, soft accent glow in light mode)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: AppTheme.isDark
                            ? const [
                                Color(0xFF0A2417), // Deep emerald top
                                Color(0xFF091B12),
                                Color(0xFF0A120E),
                                Color(0xFF090C10),
                              ]
                            : [
                                AppTheme.accentColor.withValues(alpha: 0.12),
                                AppTheme.surfaceLight.withValues(alpha: 0.40),
                                AppTheme.background,
                                AppTheme.background,
                              ],
                        stops: const [0.0, 0.28, 0.65, 1.0],
                      ),
                    ),
                  ),
                ),

                // Main Scrollable Content
                Positioned.fill(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // Top Bar
                      SliverToBoxAdapter(
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Action Buttons (Leading)
                                Row(
                                  children: [
                                    // Add songs icon button
                                    _buildCircleButton(
                                      icon: Icons.playlist_add_rounded,
                                      tooltip: LanguageService.tr('add_music_to_album'),
                                      onTap: () => _showAddSongsDialog(context, currentAlbum, audio, albumService),
                                    ),
                                    const SizedBox(width: 10),
                                    // 3-dots More options: Opens center frosted glass popup
                                    _buildCircleButton(
                                      icon: Icons.more_vert_rounded,
                                      tooltip: LanguageService.tr('album_options'),
                                      onTap: () => _showAlbumOptionsGlassDialog(
                                        context,
                                        currentAlbum,
                                        audio,
                                        albumService,
                                      ),
                                    ),
                                  ],
                                ),

                                // Back Button (Trailing)
                                _buildCircleButton(
                                  icon: lang.isArabic
                                      ? Icons.arrow_forward_ios_rounded
                                      : Icons.arrow_back_ios_new_rounded,
                                  tooltip: LanguageService.tr('back'),
                                  onTap: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Large Center Artwork
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 18),
                          child: Center(
                            child: Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(AppTheme.isDark ? 0.55 : 0.10),
                                    blurRadius: 30,
                                    offset: const Offset(0, 14),
                                  ),
                                  if (hasSongs || currentAlbum.customArtworkPath != null)
                                    BoxShadow(
                                      color: AppTheme.accentColor.withOpacity(AppTheme.isDark ? 0.18 : 0.12),
                                      blurRadius: 42,
                                      spreadRadius: 2,
                                    ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: _AlbumHeroArtwork(
                                  song: firstSong,
                                  customArtworkPath: currentAlbum.customArtworkPath,
                                  size: 220,
                                  borderRadius: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Album Title
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            currentAlbum.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),

                      // Song Count
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 22),
                          child: Text(
                            LanguageService.formatSongCount(albumSongs.length),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                      // Two Large Pill Action Buttons: [Shuffle All] [Play]
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              // 1. Shuffle Play All Button
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(28),
                                  onTap: () async {
                                    if (albumSongs.isNotEmpty) {
                                      await audio.playWithShuffle(albumSongs);
                                      if (context.mounted) {
                                        NowPlayingSheet.show(context);
                                      }
                                    } else {
                                      _showEmptySnackBar(context);
                                    }
                                  },
                                  child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: AppTheme.isDark ? const Color(0xFF16221A) : AppTheme.cardColor,
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: AppTheme.isDark ? const Color(0xFF223629) : AppTheme.cardBorder,
                                        width: 1,
                                      ),
                                      boxShadow: AppTheme.isDark
                                          ? null
                                          : [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.04),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.shuffle_rounded, color: AppTheme.accentColor, size: 20),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            LanguageService.tr('shuffle_all_play'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: AppTheme.accentColor,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // 2. Play All Button
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(28),
                                  onTap: () async {
                                    if (albumSongs.isNotEmpty) {
                                      await audio.playSong(albumSongs.first, playlist: albumSongs);
                                      if (context.mounted) {
                                        NowPlayingSheet.show(context);
                                      }
                                    } else {
                                      _showEmptySnackBar(context);
                                    }
                                  },
                                  child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: AppTheme.isDark ? const Color(0xFF16221A) : AppTheme.cardColor,
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: AppTheme.isDark ? const Color(0xFF223629) : AppTheme.cardBorder,
                                        width: 1,
                                      ),
                                      boxShadow: AppTheme.isDark
                                          ? null
                                          : [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.04),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.play_arrow_rounded, color: AppTheme.accentColor, size: 26),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            LanguageService.tr('play_album'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: AppTheme.accentColor,
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.bold,
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
                      ),

                      const SliverToBoxAdapter(
                        child: SizedBox(height: 18),
                      ),

                      // Songs List or Empty State
                      if (albumSongs.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: AppTheme.cardBorder, width: 1),
                                boxShadow: AppTheme.isDark
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentColor.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.music_note_rounded,
                                      color: AppTheme.accentColor,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    LanguageService.tr('album_empty'),
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    LanguageService.tr('album_empty_desc'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                                  ),
                                  const SizedBox(height: 18),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentColor,
                                      foregroundColor: AppTheme.accentColor.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                    icon: const Icon(Icons.add_rounded, size: 19),
                                    label: Text(
                                      LanguageService.tr('add_songs_now'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    onPressed: () {
                                      _showAddSongsDialog(context, currentAlbum, audio, albumService);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final song = albumSongs[index];
                              final isCurrent = audio.currentSong?.id == song.id;
                              final isPlaying = isCurrent && audio.player.playing;

                              return InkWell(
                                onTap: () {
                                  if (isCurrent) {
                                    if (!audio.player.playing) {
                                      audio.player.play();
                                    }
                                  } else {
                                    audio.playSong(song, playlist: albumSongs);
                                  }
                                  if (context.mounted) {
                                    NowPlayingSheet.show(context);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                  child: Row(
                                    children: [
                                      // Right Thumbnail (RTL layout) - Enlarged for stunning visuals
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: SizedBox(
                                          width: 68,
                                          height: 68,
                                          child: Stack(
                                            children: [
                                              QueryArtworkOrFallback(
                                                id: song.id,
                                                size: 68,
                                                borderRadius: 16,
                                              ),
                                              if (isCurrent)
                                                Container(
                                                  width: 68,
                                                  height: 68,
                                                  color: Colors.black.withOpacity(0.55),
                                                  child: Center(
                                                    child: Icon(
                                                      isPlaying ? Icons.equalizer_rounded : Icons.pause_rounded,
                                                      color: AppTheme.accentColor,
                                                      size: 30,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Song Title & Artist info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              song.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isCurrent ? AppTheme.accentColor : AppTheme.textPrimary,
                                                fontSize: 15.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    '${song.artist ?? 'غير معروف'} - ${song.album ?? currentAlbum.name}',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: AppTheme.textSecondary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Pill badge matching image design
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.isDark ? const Color(0xFF19251E) : AppTheme.surfaceLight,
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: AppTheme.cardBorder, width: 0.8),
                                                  ),
                                                  child: Text(
                                                    audio.formatDuration(song.duration),
                                                    style: TextStyle(
                                                      color: AppTheme.textSecondary,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Trailing options button
                                      PopupMenuButton<String>(
                                        icon: Icon(
                                          Icons.more_vert_rounded,
                                          color: AppTheme.textMuted,
                                          size: 20,
                                        ),
                                        color: AppTheme.cardColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          side: BorderSide(color: AppTheme.cardBorder, width: 1),
                                        ),
                                        onSelected: (val) async {
                                          if (val == 'remove') {
                                            await albumService.removeSongFromAlbum(currentAlbum.id, song.id);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    LanguageService.tr('song_removed_from_album_msg').replaceAll('{title}', song.title),
                                                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                                  ),
                                                  backgroundColor: AppTheme.cardColor,
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          } else if (val == 'play_now') {
                                            audio.playSong(song, playlist: albumSongs);
                                            if (context.mounted) {
                                              NowPlayingSheet.show(context);
                                            }
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            value: 'play_now',
                                            child: Row(
                                              children: [
                                                Icon(Icons.play_arrow_rounded, color: AppTheme.accentColor, size: 18),
                                                const SizedBox(width: 8),
                                                Text(LanguageService.tr('play_now'), style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'remove',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFFF5252), size: 18),
                                                const SizedBox(width: 8),
                                                Text(LanguageService.tr('remove_from_this_album'), style: const TextStyle(color: Color(0xFFFF5252), fontSize: 13)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: albumSongs.length,
                          ),
                        ),

                      // Bottom spacing so songs aren't covered by the mini player
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 110),
                      ),
                    ],
                  ),
                ),

                // Docked MiniPlayer at the bottom
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: MiniPlayer(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: _buildCircleContainer(
        child: Icon(
          icon,
          color: AppTheme.textPrimary,
          size: icon == Icons.arrow_forward_ios_rounded ? 18 : 22,
        ),
      ),
    );
  }

  Widget _buildCircleContainer({required Widget child}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppTheme.isDark ? const Color(0xFF19251E).withOpacity(0.75) : AppTheme.cardColor,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.cardBorder, width: 1),
        boxShadow: AppTheme.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Center(child: child),
    );
  }

  void _showEmptySnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LanguageService.tr('album_empty'), style: TextStyle(color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.cardColor,
      ),
    );
  }

  // -------------------------------------------------------------
  // Center Frosted Glass Album Options Dialog (3 Dots Action)
  // -------------------------------------------------------------
  void _showAlbumOptionsGlassDialog(
    BuildContext context,
    CustomAlbum album,
    AudioService audio,
    AlbumService albumService,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: LanguageService.tr('close'),
      barrierColor: Colors.black.withOpacity(0.72),
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curve),
          child: FadeTransition(
            opacity: anim,
            child: child,
          ),
        );
      },
      pageBuilder: (dialogContext, anim1, anim2) {
        return Directionality(
          textDirection: LanguageService().textDirection,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(dialogContext).size.width * 0.88,
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(AppTheme.isDark ? 0.65 : 0.12),
                      blurRadius: 36,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: AppTheme.accentColor.withOpacity(0.1),
                      blurRadius: 30,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      decoration: BoxDecoration(
                        color: (AppTheme.isDark ? const Color(0xFF121B16) : AppTheme.surface).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: AppTheme.cardBorder,
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Top Header
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentColor.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.accentColor.withOpacity(0.28),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.album_rounded,
                                  color: AppTheme.accentColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      LanguageService.tr('album_options'),
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      album.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => Navigator.pop(dialogContext),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: (AppTheme.isDark ? Colors.white : Colors.black).withOpacity(0.06),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: AppTheme.textSecondary,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),
                          Container(
                            height: 1,
                            color: AppTheme.dividerColor,
                          ),
                          const SizedBox(height: 12),

                          // 1. Change Album Cover
                          _buildGlassOptionTile(
                            icon: Icons.photo_library_rounded,
                            iconColor: AppTheme.accentColor,
                            title: LanguageService.tr('change_album_cover'),
                            subtitle: LanguageService.tr('change_cover_subtitle'),
                            onTap: () {
                              Navigator.pop(dialogContext);
                              _pickAlbumCover(context, album, albumService);
                            },
                          ),
                          const SizedBox(height: 9),

                          // 2. Rename Album
                          _buildGlassOptionTile(
                            icon: Icons.edit_note_rounded,
                            iconColor: AppTheme.accentColor,
                            title: LanguageService.tr('rename_album'),
                            subtitle: LanguageService.tr('rename_album_subtitle'),
                            onTap: () {
                              Navigator.pop(dialogContext);
                              _showRenameDialog(context, album, albumService);
                            },
                          ),
                          const SizedBox(height: 9),

                          // 3. Add Songs to Album
                          _buildGlassOptionTile(
                            icon: Icons.playlist_add_rounded,
                            iconColor: AppTheme.accentColor,
                            title: LanguageService.tr('add_music_to_album'),
                            subtitle: LanguageService.tr('add_music_subtitle'),
                            onTap: () {
                              Navigator.pop(dialogContext);
                              _showAddSongsDialog(context, album, audio, albumService);
                            },
                          ),
                          const SizedBox(height: 9),

                          // 4. Reorder Songs
                          _buildGlassOptionTile(
                            icon: Icons.swap_vert_rounded,
                            iconColor: AppTheme.accentColor,
                            title: LanguageService.tr('reorder_songs'),
                            subtitle: LanguageService.tr('reorder_songs_subtitle'),
                            onTap: () {
                              Navigator.pop(dialogContext);
                              _showReorderSongsDialog(context, album, audio, albumService);
                            },
                          ),

                          const SizedBox(height: 12),
                          Container(
                            height: 1,
                            color: AppTheme.dividerColor,
                          ),
                          const SizedBox(height: 8),

                          // Delete Album action
                          InkWell(
                            onTap: () {
                              Navigator.pop(dialogContext);
                              _showDeleteDialog(context, album, albumService);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF5252), size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    LanguageService.tr('delete_album'),
                                    style: const TextStyle(
                                      color: Color(0xFFFF5252),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
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
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppTheme.accentColor.withOpacity(0.12),
        highlightColor: AppTheme.accentColor.withOpacity(0.06),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: (AppTheme.isDark ? const Color(0xFF18241D) : AppTheme.surfaceLight).withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.cardBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: iconColor.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 21),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LanguageService().isArabic
                    ? Icons.arrow_back_ios_new_rounded
                    : Icons.arrow_forward_ios_rounded,
                color: AppTheme.textMuted,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 1. Pick Album Cover Functionality
  // -------------------------------------------------------------
  Future<void> _pickAlbumCover(
    BuildContext context,
    CustomAlbum album,
    AlbumService albumService,
  ) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (picked == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final ext = picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
      final newCoverFile = File('${appDir.path}/album_cover_${album.id}_${DateTime.now().millisecondsSinceEpoch}.$ext');

      // Clean up previous custom artwork file if exists
      if (album.customArtworkPath != null && File(album.customArtworkPath!).existsSync()) {
        try {
          await File(album.customArtworkPath!).delete();
        } catch (_) {}
      }

      await File(picked.path).copy(newCoverFile.path);
      await albumService.setAlbumArtwork(album.id, newCoverFile.path);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LanguageService.tr('album_cover_updated'),
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
            ),
            backgroundColor: AppTheme.cardColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking album cover: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageService.tr('album_cover_error')),
            backgroundColor: AppTheme.cardColor,
          ),
        );
      }
    }
  }

  // -------------------------------------------------------------
  // 2. Rename Album Dialog
  // -------------------------------------------------------------
  void _showRenameDialog(BuildContext context, CustomAlbum album, AlbumService albumService) {
    final controller = TextEditingController(text: album.name);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: LanguageService().textDirection,
        child: GlassDialog(
          title: Text(LanguageService.tr('edit_album_name'), style: TextStyle(color: AppTheme.textPrimary, fontSize: 16.5, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.cardColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.accentColor, width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(LanguageService.tr('cancel'), style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: AppTheme.accentColor.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  await albumService.renameAlbum(album.id, newName);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(LanguageService.tr('save'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 3. Add Songs Searchable Modal Sheet (Static for easy reuse)
  // -------------------------------------------------------------
  static void showAddSongsSheet(
    BuildContext context,
    CustomAlbum album, {
    AudioService? audioService,
    AlbumService? albumService,
  }) {
    final audio = audioService ?? AudioService();
    final albums = albumService ?? AlbumService();
    final selectedIds = Set<int>.from(album.songIds);
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filteredSongs = audio.allSongs.where((s) {
            if (searchQuery.trim().isEmpty) return true;
            final q = searchQuery.toLowerCase();
            return s.title.toLowerCase().contains(q) ||
                (s.artist != null && s.artist!.toLowerCase().contains(q));
          }).toList();

          return Directionality(
            textDirection: LanguageService().textDirection,
            child: GlassBottomSheet(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LanguageService.tr('add_songs_to_album').replaceAll('{album}', album.name),
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              LanguageService.tr('selected_songs_count')
                                  .replaceAll('{selected}', '${selectedIds.length}')
                                  .replaceAll('{total}', '${audio.allSongs.length}'),
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  // Search & Toggles
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
                            decoration: InputDecoration(
                              hintText: LanguageService.tr('search_hint'),
                              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                              prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
                              filled: true,
                              fillColor: AppTheme.cardColor,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: AppTheme.cardBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: AppTheme.cardBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: AppTheme.accentColor, width: 1.5),
                              ),
                            ),
                            onChanged: (val) {
                              setSheetState(() {
                                searchQuery = val;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              if (selectedIds.length == audio.allSongs.length) {
                                selectedIds.clear();
                              } else {
                                selectedIds.addAll(audio.allSongs.map((s) => s.id));
                              }
                            });
                          },
                          child: Text(
                            selectedIds.length == audio.allSongs.length
                                ? LanguageService.tr('deselect_all')
                                : LanguageService.tr('select_all'),
                            style: TextStyle(color: AppTheme.accentColor, fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: AppTheme.dividerColor, height: 1),
                  // Songs List
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredSongs.length,
                      itemBuilder: (context, index) {
                        final song = filteredSongs[index];
                        final isSelected = selectedIds.contains(song.id);

                        return InkWell(
                          onTap: () {
                            setSheetState(() {
                              if (isSelected) {
                                selectedIds.remove(song.id);
                              } else {
                                selectedIds.add(song.id);
                              }
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (AppTheme.isDark
                                      ? const Color(0xFF16251C)
                                      : AppTheme.accentColor.withOpacity(0.08))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? AppTheme.accentColor.withOpacity(0.3) : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Larger Checkbox
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.accentColor : Colors.transparent,
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                      color: isSelected ? AppTheme.accentColor : AppTheme.cardBorder,
                                      width: 1.6,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Icon(
                                          Icons.check_rounded,
                                          color: AppTheme.accentColor.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                                          size: 20,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                // Larger Artwork Thumbnail (68x68) for effortless recognition
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: SizedBox(
                                    width: 68,
                                    height: 68,
                                    child: QueryArtworkOrFallback(
                                      id: song.id,
                                      size: 68,
                                      borderRadius: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isSelected ? AppTheme.accentColor : AppTheme.textPrimary,
                                          fontSize: 15,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        song.artist ?? LanguageService.tr('unknown_artist'),
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
                                Text(
                                  audio.formatDuration(song.duration),
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Save Button
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      border: Border(top: BorderSide(color: AppTheme.dividerColor, width: 1)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          foregroundColor: AppTheme.accentColor.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          await albums.setAlbumSongs(album.id, selectedIds.toList());
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  LanguageService.tr('songs_saved_in_album')
                                      .replaceAll('{album}', album.name)
                                      .replaceAll('{count}', '${selectedIds.length}'),
                                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                ),
                                backgroundColor: AppTheme.cardColor,
                              ),
                            );
                          }
                        },
                        child: Text(
                          '${LanguageService.tr('save_changes')} (${selectedIds.length})',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
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

  void _showAddSongsDialog(
    BuildContext context,
    CustomAlbum album,
    AudioService audio,
    AlbumService albumService,
  ) {
    showAddSongsSheet(
      context,
      album,
      audioService: audio,
      albumService: albumService,
    );
  }

  // -------------------------------------------------------------
  // 4. Change Song Order (Reorderable List Dialog)
  // -------------------------------------------------------------
  void _showReorderSongsDialog(
    BuildContext context,
    CustomAlbum album,
    AudioService audio,
    AlbumService albumService,
  ) {
    final songs = albumService.getSongsForAlbum(album.id, audio.allSongs);
    if (songs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.tr('no_songs_in_album_to_reorder'), style: TextStyle(color: AppTheme.textPrimary)),
          backgroundColor: AppTheme.cardColor,
        ),
      );
      return;
    }

    final reorderedSongs = List<SongModel>.from(songs);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setOrderState) {
          return Directionality(
            textDirection: LanguageService().textDirection,
            child: GlassBottomSheet(
              height: MediaQuery.of(context).size.height * 0.82,
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LanguageService.tr('reorder_songs'),
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              LanguageService.tr('reorder_instructions'),
                              style: TextStyle(
                                color: AppTheme.accentColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: AppTheme.dividerColor, height: 1),
                  Expanded(
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        canvasColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: ReorderableListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: reorderedSongs.length,
                        onReorder: (oldIndex, newIndex) {
                          setOrderState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = reorderedSongs.removeAt(oldIndex);
                            reorderedSongs.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final song = reorderedSongs[index];
                          return Material(
                            key: ValueKey(song.id),
                            color: Colors.transparent,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.cardBorder, width: 0.8),
                              ),
                              child: Row(
                                children: [
                                  // Drag handle indicator
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.drag_indicator_rounded,
                                        color: AppTheme.accentColor,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Order number badge
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Thumbnail (Enlarged)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: QueryArtworkOrFallback(
                                        id: song.id,
                                        size: 56,
                                        borderRadius: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Title & artist
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          song.artist ?? LanguageService.tr('unknown_artist'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Save Order Button
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      border: Border(top: BorderSide(color: AppTheme.dividerColor, width: 1)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          foregroundColor: AppTheme.accentColor.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: Text(
                          LanguageService.tr('save_order'),
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final newIds = reorderedSongs.map((s) => s.id).toList();
                          await albumService.setAlbumSongs(album.id, newIds);
                          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  LanguageService.tr('order_saved'),
                                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                                ),
                                backgroundColor: AppTheme.cardColor,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
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

  // -------------------------------------------------------------
  // Delete Album Dialog
  // -------------------------------------------------------------
  void _showDeleteDialog(BuildContext context, CustomAlbum album, AlbumService albumService) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: LanguageService().textDirection,
        child: GlassDialog(
          title: Text(LanguageService.tr('delete_album'), style: TextStyle(color: AppTheme.textPrimary, fontSize: 16.5, fontWeight: FontWeight.bold)),
          content: Text(
            LanguageService.tr('delete_album_confirm').replaceAll('{album}', album.name),
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(LanguageService.tr('cancel'), style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5252),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await albumService.deleteAlbum(album.id);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  Navigator.pop(context); // Exit album screen
                }
              },
              child: Text(LanguageService.tr('delete_album'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumHeroArtwork extends StatefulWidget {
  final SongModel? song;
  final String? customArtworkPath;
  final double size;
  final double borderRadius;

  const _AlbumHeroArtwork({
    required this.song,
    this.customArtworkPath,
    required this.size,
    required this.borderRadius,
  });

  @override
  State<_AlbumHeroArtwork> createState() => _AlbumHeroArtworkState();
}

class _AlbumHeroArtworkState extends State<_AlbumHeroArtwork> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _loadArtwork();
  }

  @override
  void didUpdateWidget(covariant _AlbumHeroArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song?.id != widget.song?.id ||
        oldWidget.customArtworkPath != widget.customArtworkPath) {
      _loadArtwork();
    }
  }

  Future<void> _loadArtwork() async {
    // If custom album artwork is present, we render it directly in build()
    if (widget.customArtworkPath != null && File(widget.customArtworkPath!).existsSync()) {
      if (mounted) setState(() {});
      return;
    }

    final song = widget.song;
    if (song == null) return;

    // 1. Check custom user-edited artwork
    final customArt = SongEditService().getCustomArtworkPath(song.id);
    if (customArt != null && File(customArt).existsSync()) {
      if (mounted) {
        setState(() {
          _bytes = File(customArt).readAsBytesSync();
        });
      }
      return;
    }

    // 2. Extract 100% full original uncompressed embedded artwork directly from audio file
    final bytes = await AudioService().getSongArtworkBytes(song.id, filePath: song.data);
    if (mounted) {
      setState(() {
        _bytes = bytes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. If user set a custom album artwork, show it at original quality
    if (widget.customArtworkPath != null && File(widget.customArtworkPath!).existsSync()) {
      return Image.file(
        File(widget.customArtworkPath!),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      );
    }

    if (widget.song == null) {
      return Container(
        color: AppTheme.cardColor,
        child: Center(
          child: Icon(
            Icons.album_rounded,
            size: 80,
            color: AppTheme.textMuted,
          ),
        ),
      );
    }

    // 2. High quality original bytes
    if (_bytes != null && _bytes!.isNotEmpty) {
      return Image.memory(
        _bytes!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      );
    }

    // 3. Fallback query artwork with max resolution size (1000px)
    return QueryArtworkOrFallback(
      id: widget.song!.id,
      size: widget.size,
      borderRadius: widget.borderRadius,
      artworkRequestSize: 1000,
    );
  }
}
