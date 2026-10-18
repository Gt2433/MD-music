import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/album_service.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../services/song_edit_service.dart';
import '../services/song_selection_service.dart';
import '../theme/app_theme.dart';
import 'now_playing_sheet.dart';
import 'query_artwork_or_fallback.dart';
import 'glass_dialog.dart';
import '../screens/edit_song_screen.dart';

class SongTile extends StatelessWidget {
  final SongModel song;
  final List<SongModel>? playlist;

  const SongTile({
    super.key,
    required this.song,
    this.playlist,
  });

  void _showSongOptions(BuildContext context, AudioService audio, bool isFav) {
    final editService = SongEditService();
    final displayTitle = editService.getDisplayTitle(song);
    final displayArtist = editService.getDisplayArtist(song);
    final isCurrent = audio.currentSong?.id == song.id;
    final accent = AppTheme.accentColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (ctx) => GlassBottomSheet(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Drag handle
                Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),

                // Header with Song Info Card
                GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      QueryArtworkOrFallback(
                        id: song.id,
                        size: 68,
                        borderRadius: 16,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    displayArtist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: accent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    audio.formatDuration(song.duration),
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: AppTheme.textSecondary, size: 22),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Group 1: Playback & Music Actions
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // Option 1: Play Now
                      _buildOptionTile(
                        icon: Icons.play_arrow_rounded,
                        iconColor: accent,
                        badgeBg: accent.withOpacity(0.16),
                        title: LanguageService.tr('play_now'),
                        onTap: () {
                          Navigator.pop(ctx);
                          if (isCurrent) {
                            if (!audio.player.playing) {
                              audio.player.play();
                            }
                          } else {
                            audio.playSong(song, playlist: playlist);
                          }
                          if (context.mounted) {
                            NowPlayingSheet.show(context);
                          }
                        },
                      ),
                      Divider(
                          color: AppTheme.dividerColor,
                          height: 1,
                          indent: 68),

                      // Option 2: Favorite toggle
                      _buildOptionTile(
                        icon: isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        iconColor: const Color(0xFFFF2D55),
                        badgeBg: const Color(0xFFFF2D55).withOpacity(0.16),
                        title: isFav
                            ? LanguageService.tr('remove_from_favorites')
                            : LanguageService.tr('add_to_favorites'),
                        trailingText:
                            isFav ? LanguageService.tr('favorite_badge') : null,
                        trailingBadgeBg:
                            const Color(0xFFFF2D55).withOpacity(0.14),
                        trailingTextColor: const Color(0xFFFF2D55),
                        onTap: () {
                          audio.toggleFavorite(song.id);
                          Navigator.pop(ctx);
                        },
                      ),
                      Divider(
                          color: AppTheme.dividerColor,
                          height: 1,
                          indent: 68),

                      // Option 3: Edit Song & Artist
                      _buildOptionTile(
                        icon: Icons.edit_note_rounded,
                        iconColor: const Color(0xFFA78BFA),
                        badgeBg: const Color(0xFFA78BFA).withOpacity(0.16),
                        title: LanguageService.tr('edit_song_info'),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditSongScreen(song: song),
                            ),
                          );
                        },
                      ),
                      Divider(
                          color: AppTheme.dividerColor,
                          height: 1,
                          indent: 68),

                      // Option 4: Ringtone
                      _buildOptionTile(
                        icon: Icons.notifications_active_rounded,
                        iconColor: const Color(0xFF00B4D8),
                        badgeBg: const Color(0xFF00B4D8).withOpacity(0.16),
                        title: LanguageService.tr('set_as_ringtone'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _handleSetRingtone(context, editService);
                        },
                      ),
                      Divider(
                          color: AppTheme.dividerColor,
                          height: 1,
                          indent: 68),

                      // Option 5: Add to Custom Album
                      _buildOptionTile(
                        icon: Icons.playlist_add_rounded,
                        iconColor: accent,
                        badgeBg: accent.withOpacity(0.16),
                        title: LanguageService.tr('add_to_custom_album'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showAddToAlbumSheet(context, song);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Group 2: Management & Info
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // Option 6: Song Details
                      _buildOptionTile(
                        icon: Icons.info_outline_rounded,
                        iconColor: AppTheme.textSecondary,
                        badgeBg: AppTheme.isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.05),
                        title: LanguageService.tr('song_details'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showDetailsDialog(
                              context, audio, displayTitle, displayArtist);
                        },
                      ),
                      Divider(
                          color: AppTheme.dividerColor,
                          height: 1,
                          indent: 68),

                      // Option 7: Delete Permanently
                      _buildOptionTile(
                        icon: Icons.delete_forever_rounded,
                        iconColor: const Color(0xFFFF4D4D),
                        badgeBg: const Color(0xFFFF4D4D).withOpacity(0.16),
                        title: LanguageService.tr('delete_permanently'),
                        titleColor: const Color(0xFFFF5252),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showDeleteDialog(context, editService);
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

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required Color badgeBg,
    required String title,
    String? trailingText,
    Color? trailingTextColor,
    Color? trailingBadgeBg,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    final effectiveTitleColor = titleColor ?? AppTheme.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: effectiveTitleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailingText != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: trailingBadgeBg ?? Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trailingText,
                  style: TextStyle(
                    color: trailingTextColor ?? AppTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Icon(
                Icons.adaptive.arrow_forward,
                color: AppTheme.textMuted,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  void _handleSetRingtone(
      BuildContext context, SongEditService editService) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(LanguageService.tr('setting_ringtone')),
          ],
        ),
        backgroundColor: const Color(0xFF161E2B),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final res = await editService.setAsRingtone(song.data);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (res == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(LanguageService.tr('ringtone_success'))),
            ],
          ),
          backgroundColor: AppTheme.accentColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (res == 'need_permission') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.tr('ringtone_permission')),
          backgroundColor: Colors.amber.shade800,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: LanguageService.tr('retry'),
            textColor: Colors.white,
            onPressed: () => _handleSetRingtone(context, editService),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${LanguageService.tr("ringtone_error")} ($res)'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showDeleteDialog(BuildContext context, SongEditService editService) {
    showDialog(
      context: context,
      builder: (ctx) => GlassDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Color(0xFFFF5252)),
            const SizedBox(width: 10),
            Text(LanguageService.tr('delete_song_title'),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
          ],
        ),
        content: Text(
          LanguageService.tr('delete_song_confirm')
              .replaceAll('{title}', editService.getDisplayTitle(song)),
          style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LanguageService.tr('cancel'),
                style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await editService.deletePermanently(song);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? LanguageService.tr('delete_song_success')
                        : LanguageService.tr('delete_song_error')),
                    backgroundColor:
                        ok ? AppTheme.accentColor : AppTheme.errorColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(LanguageService.tr('delete'),
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(BuildContext context, AudioService audio,
      String title, String artist) {
    showDialog(
      context: context,
      builder: (ctx) => GlassDialog(
        title: Row(
          children: [
            Icon(Icons.audio_file_rounded, color: AppTheme.accentColor),
            const SizedBox(width: 10),
            Text(LanguageService.tr('song_details'),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(LanguageService.tr('detail_title'), title),
            _detailRow(LanguageService.tr('detail_artist'), artist),
            _detailRow(LanguageService.tr('detail_album'),
                song.album ?? LanguageService.tr('unknown')),
            _detailRow(LanguageService.tr('detail_duration'),
                audio.formatDuration(song.duration)),
            if (song.size > 0)
              _detailRow(
                LanguageService.tr('detail_size'),
                '${(song.size / (1024 * 1024)).toStringAsFixed(2)} ${LanguageService.tr("mb")}',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LanguageService.tr('close'),
                style: TextStyle(color: AppTheme.accentColor)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              '$label:',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audio = AudioService();
    final editService = SongEditService();
    final selection = SongSelectionService();

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([audio, editService, selection]),
        builder: (context, _) {
          final isCurrent = audio.currentSong?.id == song.id;
          final isFav = audio.isFavorite(song.id);
          final title = editService.getDisplayTitle(song);
          final artist = editService.getDisplayArtist(song);
          final isSelectionMode = selection.isSelectionMode;
          final isSelected = selection.isSelected(song.id);
          final accent = AppTheme.accentColor;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
            decoration: BoxDecoration(
              color: isSelected
                  ? accent.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? accent.withOpacity(0.5)
                    : Colors.transparent,
                width: 1.4,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  if (isSelectionMode) {
                    HapticFeedback.selectionClick();
                    selection.toggleSelection(song);
                  } else {
                    if (isCurrent) {
                      if (!audio.player.playing) {
                        audio.player.play();
                      }
                    } else {
                      audio.playSong(song, playlist: playlist);
                    }
                    if (context.mounted) {
                      NowPlayingSheet.show(context);
                    }
                  }
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  if (!selection.isSelectionMode) {
                    selection.startSelection(song);
                  } else {
                    selection.toggleSelection(song);
                  }
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      // Cover artwork
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: QueryArtworkOrFallback(
                          id: song.id,
                          size: 72,
                          borderRadius: 18,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Song Title & Artist & Duration
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent
                                    ? accent
                                    : AppTheme.textPrimary,
                                fontSize: 15.0,
                                fontWeight: isCurrent
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    audio.formatDuration(song.duration),
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Trailing: Animated Switcher between 3-dots and Sequential Checkbox
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: isSelectionMode
                            ? AnimatedContainer(
                                key: ValueKey('chk_${song.id}_$isSelected'),
                                duration: const Duration(milliseconds: 180),
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? accent
                                      : AppTheme.cardColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? accent
                                        : AppTheme.textSecondary
                                            .withOpacity(0.4),
                                    width: 1.8,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: accent.withOpacity(0.35),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: isSelected
                                    ? Center(
                                        child: Text(
                                          '${selection.getSelectionOrder(song.id)}',
                                          style: TextStyle(
                                            color: accent.computeLuminance() > 0.4
                                                ? Colors.black
                                                : Colors.white,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      )
                                    : null,
                              )
                            : Container(
                                key: const ValueKey('more_btn'),
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.cardColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color:
                                          AppTheme.cardBorder.withOpacity(0.5)),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.more_vert_rounded,
                                    color: AppTheme.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      _showSongOptions(context, audio, isFav),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddToAlbumSheet(BuildContext context, SongModel song) {
    final accent = AppTheme.accentColor;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (ctx) => AnimatedBuilder(
        animation: AlbumService(),
        builder: (context, _) {
          final albumService = AlbumService();
          final albums = albumService.albums;

          return GlassBottomSheet(
            height: MediaQuery.of(context).size.height * 0.65,
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LanguageService.tr('add_to_custom_album'),
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: accent,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: AppTheme.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                // New Album button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCreateAlbumForSongDialog(context, song);
                    },
                    child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.add_rounded,
                                color: accent, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              LanguageService.tr('create_album_and_add_song'),
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(Icons.adaptive.arrow_forward,
                              color: AppTheme.textSecondary, size: 18),
                        ],
                      ),
                    ),
                  ),
                Divider(color: AppTheme.dividerColor, height: 16),
                // List of albums
                Expanded(
                  child: albums.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              LanguageService.tr('no_custom_albums_yet'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                  height: 1.4),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: albums.length,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          itemBuilder: (context, index) {
                            final album = albums[index];
                            final isInAlbum =
                                album.songIds.contains(song.id);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  final added = await albumService
                                      .toggleSongInAlbum(album.id, song.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          added
                                              ? LanguageService.tr(
                                                      'added_to_album')
                                                  .replaceAll(
                                                      '{title}', song.title)
                                                  .replaceAll(
                                                      '{album}', album.name)
                                              : LanguageService.tr(
                                                      'removed_from_album')
                                                  .replaceAll(
                                                      '{title}', song.title)
                                                  .replaceAll(
                                                      '{album}', album.name),
                                          style: TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontSize: 13),
                                        ),
                                        backgroundColor: AppTheme.surface,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.isDark
                                        ? Colors.white.withOpacity(0.065)
                                        : Colors.black.withOpacity(0.038),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isInAlbum
                                          ? accent.withOpacity(0.6)
                                          : (AppTheme.isDark
                                              ? Colors.white.withOpacity(0.09)
                                              : Colors.black.withOpacity(0.06)),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceLight,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.album_rounded,
                                          color: accent,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              album.name,
                                              style: TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              LanguageService.tr(
                                                      'songs_count')
                                                  .replaceAll('{count}',
                                                      '${album.songIds.length}'),
                                              style: TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isInAlbum
                                              ? accent.withOpacity(0.15)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isInAlbum
                                                  ? Icons.check_circle_rounded
                                                  : Icons
                                                      .add_circle_outline_rounded,
                                              color: isInAlbum
                                                  ? accent
                                                  : AppTheme.textSecondary,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isInAlbum
                                                  ? LanguageService.tr(
                                                      'added_badge')
                                                  : LanguageService.tr(
                                                      'add_badge'),
                                              style: TextStyle(
                                                color: isInAlbum
                                                    ? accent
                                                    : AppTheme.textSecondary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
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
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCreateAlbumForSongDialog(BuildContext context, SongModel song) {
    final controller = TextEditingController();
    final accent = AppTheme.accentColor;

    showDialog(
      context: context,
      builder: (ctx) => GlassDialog(
        title: Text(
          LanguageService.tr('create_new_album'),
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16.5,
              fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: LanguageService.tr('album_name_hint'),
            hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            filled: true,
            fillColor: AppTheme.surfaceLight,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accent, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LanguageService.tr('cancel'),
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await AlbumService().createAlbum(name, songIds: [song.id]);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        LanguageService.tr('album_created_and_song_added')
                            .replaceAll('{album}', name)
                            .replaceAll('{title}', song.title),
                        style: TextStyle(
                            color: AppTheme.textPrimary, fontSize: 13),
                      ),
                      backgroundColor: AppTheme.surface,
                    ),
                  );
                }
              }
            },
            child: Text(LanguageService.tr('create_and_add'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
