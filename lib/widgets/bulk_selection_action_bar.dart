import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/album_service.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../services/song_edit_service.dart';
import '../services/song_selection_service.dart';
import '../theme/app_theme.dart';
import 'glass_dialog.dart';
import 'now_playing_sheet.dart';

class BulkSelectionActionBar extends StatelessWidget {
  final double bottomOffset;

  const BulkSelectionActionBar({
    super.key,
    this.bottomOffset = 82,
  });

  @override
  Widget build(BuildContext context) {
    final selection = SongSelectionService();

    return AnimatedBuilder(
      animation: selection,
      builder: (context, _) {
        final isVisible = selection.isSelectionMode;
        final count = selection.selectedCount;

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          left: 14,
          right: 14,
          bottom: isVisible ? bottomOffset : -100,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 240),
            opacity: isVisible ? 1.0 : 0.0,
            child: isVisible
                ? _buildDock(context, selection, count)
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  Widget _buildDock(BuildContext context, SongSelectionService selection, int count) {
    final accent = AppTheme.accentColor;
    final onAccent = accent.computeLuminance() > 0.4 ? Colors.black : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accent.withOpacity(0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: accent.withOpacity(0.15),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // 1. Counter Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withOpacity(0.4), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: accent, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$count',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 2. Play Selected in Order Button (PRIMARY ACTION)
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: count > 0
                          ? () => _playSelectedInOrder(context, selection)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent,
                              accent.withOpacity(0.85),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              color: onAccent,
                              size: 22,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                LanguageService().isArabic
                                    ? 'تشغيل بالترتيب ($count)'
                                    : 'Play in Order ($count)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: onAccent,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // 3. Add to Album Icon Button
                IconButton(
                  tooltip: LanguageService.tr('bulk_add_to_album'),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(Icons.playlist_add_rounded, color: accent, size: 22),
                  onPressed: count > 0
                      ? () => _showBulkAddToAlbumSheet(context, selection)
                      : null,
                ),

                // 4. Bulk Delete Icon Button
                IconButton(
                  tooltip: LanguageService.tr('delete'),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFFF5252), size: 21),
                  onPressed: count > 0
                      ? () => _showBulkDeleteDialog(context, selection)
                      : null,
                ),

                // 5. Cancel / Close Button
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(Icons.close_rounded,
                      color: AppTheme.textSecondary, size: 20),
                  onPressed: () => selection.clearSelection(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _playSelectedInOrder(BuildContext context, SongSelectionService selection) async {
    final songs = selection.selectedSongs;
    if (songs.isEmpty) return;

    HapticFeedback.mediumImpact();

    // 1. Snapshot ordered list before clearing selection state
    final orderedSongs = List<SongModel>.from(songs);

    // 2. Clear selection mode
    selection.clearSelection();

    // 3. Play temporary album queue in exact selection order with loop enabled
    await AudioService().playSelectedSongsQueue(orderedSongs);

    // 4. Open Now Playing View
    if (context.mounted) {
      NowPlayingSheet.show(context);
    }
  }

  // -------------------------------------------------------------
  // Bulk Add to Album Sheet
  // -------------------------------------------------------------
  void _showBulkAddToAlbumSheet(BuildContext context, SongSelectionService selection) {
    final accent = AppTheme.accentColor;
    final selectedIds = selection.selectedIds;
    final count = selectedIds.length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AnimatedBuilder(
        animation: AlbumService(),
        builder: (context, _) {
          final albumService = AlbumService();
          final albums = albumService.albums;

          return GlassBottomSheet(
            height: MediaQuery.of(context).size.height * 0.65,
            child: Column(
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 42,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.playlist_add_rounded, color: accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LanguageService.tr('choose_album'),
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              LanguageService.tr('selected_count').replaceAll('{count}', '$count'),
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 22),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Divider(color: AppTheme.dividerColor, height: 1),

                // Create New Album Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showCreateAlbumDialog(context, selection);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: accent.withOpacity(0.35), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                color: accent.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    LanguageService.tr('new_album'),
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    LanguageService.tr('bulk_create_and_add'),
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, color: accent, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Albums List
                Expanded(
                  child: albums.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.album_outlined, color: AppTheme.textMuted, size: 48),
                                const SizedBox(height: 10),
                                Text(
                                  LanguageService.tr('no_custom_albums_yet'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          itemCount: albums.length,
                          itemBuilder: (context, index) {
                            final album = albums[index];
                            final songCount = album.songIds.length;

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.cardBorder),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: accent.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.album_rounded, color: accent, size: 24),
                                ),
                                title: Text(
                                  album.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  LanguageService.formatSongCount(songCount),
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accent,
                                    foregroundColor: accent.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () async {
                                    await albumService.addSongsToAlbum(album.id, selectedIds);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    selection.clearSelection();

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            LanguageService.tr('bulk_add_success')
                                                .replaceAll('{count}', '$count')
                                                .replaceAll('{album}', album.name),
                                            style: TextStyle(color: AppTheme.textPrimary),
                                          ),
                                          backgroundColor: AppTheme.surface,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    LanguageService.tr('add'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
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

  // -------------------------------------------------------------
  // Create Album Dialog
  // -------------------------------------------------------------
  void _showCreateAlbumDialog(BuildContext context, SongSelectionService selection) {
    final controller = TextEditingController();
    final accent = AppTheme.accentColor;
    final selectedIds = selection.selectedIds;
    final count = selectedIds.length;

    showDialog(
      context: context,
      builder: (ctx) => GlassDialog(
        title: Text(
          LanguageService.tr('create_new_album'),
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16.5,
            fontWeight: FontWeight.bold,
          ),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              foregroundColor: accent.computeLuminance() > 0.4 ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await AlbumService().createAlbum(name, songIds: selectedIds);
                if (ctx.mounted) Navigator.pop(ctx);
                selection.clearSelection();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        LanguageService.tr('bulk_add_success')
                            .replaceAll('{count}', '$count')
                            .replaceAll('{album}', name),
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      ),
                      backgroundColor: AppTheme.surface,
                      behavior: SnackBarBehavior.floating,
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

  // -------------------------------------------------------------
  // Bulk Delete Dialog
  // -------------------------------------------------------------
  void _showBulkDeleteDialog(BuildContext context, SongSelectionService selection) {
    final songsToDelete = selection.selectedSongs;
    final count = songsToDelete.length;

    showDialog(
      context: context,
      builder: (ctx) => GlassDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded,
                  color: Color(0xFFFF5252), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                LanguageService.tr('bulk_delete_confirm_title')
                    .replaceAll('{count}', '$count'),
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          LanguageService.tr('bulk_delete_confirm_desc')
              .replaceAll('{count}', '$count'),
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              LanguageService.tr('cancel'),
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final deletedCount = await SongEditService().deleteMultiplePermanently(songsToDelete);
              selection.clearSelection();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      LanguageService.tr('bulk_delete_success')
                          .replaceAll('{count}', '$deletedCount'),
                    ),
                    backgroundColor: deletedCount > 0 ? AppTheme.accentColor : AppTheme.errorColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(
              LanguageService.tr('delete'),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
