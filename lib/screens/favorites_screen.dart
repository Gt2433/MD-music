import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../theme/app_theme.dart';
import '../widgets/now_playing_sheet.dart';
import '../widgets/song_tile.dart';
import '../widgets/staggered_song_item.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = AudioService();

    return AnimatedBuilder(
      animation: Listenable.merge([audio, AppTheme.listDensityNotifier]),
      builder: (context, _) {
        final favSongs = audio.allSongs.where((s) => audio.favoriteIds.contains(s.id)).toList();

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: Row(
              children: [
                Text(LanguageService().t('favorites_title')),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5252).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${favSongs.length}',
                    style: const TextStyle(
                      color: Color(0xFFFF5252),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: favSongs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: AppTheme.isDark ? const Color(0xFF141A22) : const Color(0xFFFFEBEE),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.isDark ? const Color(0xFF261A22) : const Color(0xFFFFCDD2),
                              width: 1,
                            ),
                          ),
                          child: const Icon(Icons.favorite_border_rounded, color: Color(0xFFFF5252), size: 48),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          LanguageService().t('no_favorites_title'),
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          LanguageService().t('no_favorites_hint'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Action Bar: Play All & Shuffle Favorites
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
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
                              LanguageService().t('play'),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              await audio.playSong(favSongs.first, playlist: favSongs);
                              if (context.mounted) {
                                NowPlayingSheet.show(context);
                              }
                            },
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textPrimary,
                              side: BorderSide(color: AppTheme.cardBorder),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            icon: Icon(Icons.shuffle_rounded, color: AppTheme.accentColor, size: 18),
                            label: Text(LanguageService().t('shuffle'), style: const TextStyle(fontSize: 12.5)),
                            onPressed: () async {
                              await audio.playWithShuffle(favSongs);
                              if (context.mounted) {
                                NowPlayingSheet.show(context);
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    // List of Favorites
                    Expanded(
                      child: AppTheme.listDensityNotifier.value == 'grid'
                          ? GridView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
                              physics: const BouncingScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.74,
                              ),
                              itemCount: favSongs.length,
                              itemBuilder: (context, index) {
                                return StaggeredSongItem(
                                  index: index,
                                  child: SongGridTile(
                                    song: favSongs[index],
                                    playlist: favSongs,
                                  ),
                                );
                              },
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 110),
                              physics: const BouncingScrollPhysics(),
                              itemCount: favSongs.length,
                              itemBuilder: (context, index) {
                                return StaggeredSongItem(
                                  index: index,
                                  child: SongTile(
                                    song: favSongs[index],
                                    playlist: favSongs,
                                    isCompact: AppTheme.listDensityNotifier.value == 'compact',
                                  ),
                                );
                              },
                              ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
