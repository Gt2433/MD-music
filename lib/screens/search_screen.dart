import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../services/song_edit_service.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';
import '../widgets/staggered_song_item.dart';
import 'music_recognition_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SongModel> _filteredSongs = [];

  @override
  void initState() {
    super.initState();
    _filteredSongs = AudioService().allSongs;
  }

  void _onSearchChanged(String query) {
    final all = AudioService().allSongs;
    final editService = SongEditService();
    if (query.trim().isEmpty) {
      setState(() {
        _filteredSongs = all;
      });
      return;
    }
    final q = query.toLowerCase().trim();
    setState(() {
      _filteredSongs = all.where((s) {
        final title = s.title.toLowerCase();
        final displayTitle = editService.getDisplayTitle(s).toLowerCase();
        final artist = (s.artist ?? '').toLowerCase();
        final displayArtist = editService.getDisplayArtist(s).toLowerCase();
        final album = (s.album ?? '').toLowerCase();
        return title.contains(q) ||
            displayTitle.contains(q) ||
            artist.contains(q) ||
            displayArtist.contains(q) ||
            album.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final langService = LanguageService();

    return Directionality(
      textDirection: langService.textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  margin: EdgeInsets.only(
                    left: langService.isRtl ? 8 : 0,
                    right: langService.isRtl ? 0 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder, width: 1),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      langService.isRtl
                          ? Icons.arrow_forward_rounded
                          : Icons.arrow_back_rounded,
                      color: AppTheme.textPrimary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: AppTheme.accentColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14.5),
                            cursorColor: AppTheme.accentColor,
                            decoration: InputDecoration(
                              hintText: langService.t('search_hint'),
                              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            child: Icon(Icons.close_rounded,
                                color: AppTheme.textSecondary, size: 18),
                          )
                        else
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const MusicRecognitionScreen()),
                              );
                            },
                            child: Tooltip(
                              message: LanguageService().t('music_recognition_title'),
                              child: Icon(Icons.graphic_eq_rounded,
                                  color: AppTheme.accentColor, size: 20),
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
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                child: Text(
                  '${_filteredSongs.length}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ),
            Expanded(
              child: _filteredSongs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppTheme.cardColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Icon(Icons.search_off_rounded, color: AppTheme.textMuted, size: 40),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            langService.t('no_songs'),
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 95),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filteredSongs.length,
                      itemBuilder: (context, index) {
                        final song = _filteredSongs[index];
                        return StaggeredSongItem(
                          key: ValueKey('stagger_${song.id}'),
                          index: index,
                          child: SongTile(
                            key: ValueKey('search_song_${song.id}'),
                            song: song,
                            playlist: _filteredSongs,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
