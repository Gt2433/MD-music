import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fast_scroller.dart';
import '../widgets/now_playing_sheet.dart';
import '../widgets/song_sort_sheet.dart';
import '../widgets/song_tile.dart';
import '../widgets/staggered_song_item.dart';

class SongsScreen extends StatefulWidget {
  const SongsScreen({super.key});

  @override
  State<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends State<SongsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = AudioService();

    return AnimatedBuilder(
      animation: Listenable.merge([audio, AppTheme.listDensityNotifier]),
      builder: (context, _) {
        final sortedSongs = audio.allSongs;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: Row(
              children: [
                Text(LanguageService.tr('songs')),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${sortedSongs.length}',
                    style: TextStyle(
                      color: AppTheme.accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: sortedSongs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.library_music_outlined, color: AppTheme.textMuted, size: 54),
                      const SizedBox(height: 14),
                      Text(
                        LanguageService.tr('no_local_songs'),
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          foregroundColor: AppTheme.accentColor.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => audio.checkAndRequestPermissions(),
                        child: Text(LanguageService.tr('scan_device'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Lark Player Action Bar: Play All & Sort Dropdown Chip
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Play All button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentColor,
                              foregroundColor: AppTheme.accentColor.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                            label: Text(
                              LanguageService.tr('play_all'),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              if (sortedSongs.isNotEmpty) {
                                await audio.playSong(sortedSongs.first, playlist: sortedSongs);
                                if (context.mounted) {
                                  NowPlayingSheet.show(context);
                                }
                              }
                            },
                          ),

                          // Sort Chip
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => SongSortSheet.show(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.cardBorder),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.swap_vert_rounded, color: AppTheme.accentColor, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    audio.currentSortShortLabel,
                                    style: TextStyle(
                                      color: AppTheme.accentColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.accentColor, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Songs List with FastScroller
                    Expanded(
                      child: FastScroller(
                        controller: _scrollController,
                        child: AppTheme.listDensityNotifier.value == 'grid'
                            ? GridView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
                                physics: const BouncingScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 0.74,
                                ),
                                itemCount: sortedSongs.length,
                                itemBuilder: (context, index) {
                                  return StaggeredSongItem(
                                    index: index,
                                    child: SongGridTile(
                                      song: sortedSongs[index],
                                      playlist: sortedSongs,
                                    ),
                                  );
                                },
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.only(bottom: 110),
                                physics: const BouncingScrollPhysics(),
                                itemCount: sortedSongs.length,
                                itemBuilder: (context, index) {
                                  return StaggeredSongItem(
                                    index: index,
                                    child: SongTile(
                                      song: sortedSongs[index],
                                      playlist: sortedSongs,
                                      isCompact: AppTheme.listDensityNotifier.value == 'compact',
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
