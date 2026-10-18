import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fast_scroller.dart';
import '../widgets/now_playing_sheet.dart';
import '../widgets/song_tile.dart';

enum SortMode { dateAdded, name, artist, duration }

class SongsScreen extends StatefulWidget {
  const SongsScreen({super.key});

  @override
  State<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends State<SongsScreen> {
  SortMode _sortMode = SortMode.dateAdded;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getSortLabel(SortMode mode) {
    switch (mode) {
      case SortMode.dateAdded:
        return LanguageService.tr('sort_date_added');
      case SortMode.name:
        return LanguageService.tr('sort_name');
      case SortMode.artist:
        return LanguageService.tr('sort_artist');
      case SortMode.duration:
        return LanguageService.tr('sort_duration');
    }
  }

  List<SongModel> _getSortedSongs(List<SongModel> songs) {
    final list = List<SongModel>.from(songs);
    switch (_sortMode) {
      case SortMode.name:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortMode.artist:
        list.sort((a, b) => (a.artist ?? '').toLowerCase().compareTo((b.artist ?? '').toLowerCase()));
        break;
      case SortMode.duration:
        list.sort((a, b) => (b.duration ?? 0).compareTo(a.duration ?? 0));
        break;
      case SortMode.dateAdded:
        list.sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final audio = AudioService();

    return AnimatedBuilder(
      animation: audio,
      builder: (context, _) {
        final sortedSongs = _getSortedSongs(audio.allSongs);

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
                          PopupMenuButton<SortMode>(
                            color: AppTheme.cardColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            onSelected: (mode) {
                              setState(() {
                                _sortMode = mode;
                              });
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: SortMode.dateAdded,
                                child: Text(LanguageService.tr('sort_date_added'), style: TextStyle(color: AppTheme.textPrimary)),
                              ),
                              PopupMenuItem(
                                value: SortMode.name,
                                child: Text(LanguageService.tr('sort_name'), style: TextStyle(color: AppTheme.textPrimary)),
                              ),
                              PopupMenuItem(
                                value: SortMode.artist,
                                child: Text(LanguageService.tr('sort_artist'), style: TextStyle(color: AppTheme.textPrimary)),
                              ),
                              PopupMenuItem(
                                value: SortMode.duration,
                                child: Text(LanguageService.tr('sort_duration'), style: TextStyle(color: AppTheme.textPrimary)),
                              ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.cardBorder),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.sort_rounded, color: AppTheme.textSecondary, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    _getSortLabel(_sortMode),
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary, size: 18),
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
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 110),
                          physics: const BouncingScrollPhysics(),
                          itemCount: sortedSongs.length,
                          itemBuilder: (context, index) {
                            return SongTile(song: sortedSongs[index], playlist: sortedSongs);
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
