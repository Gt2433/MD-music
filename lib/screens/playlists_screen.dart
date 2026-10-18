import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../theme/app_theme.dart';
import '../widgets/now_playing_sheet.dart';
import '../widgets/song_tile.dart';
import '../widgets/glass_dialog.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  void _openPlaylistDetails(
    BuildContext context, {
    required String title,
    required List<SongModel> songs,
    required IconData icon,
    required Color iconColor,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: LanguageService().textDirection,
        child: GlassBottomSheet(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              // Sheet Header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: iconColor, size: 24),
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
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            LanguageService.formatSongCount(songs.length),
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (songs.isNotEmpty)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                          foregroundColor: AppTheme.accentColor.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(LanguageService().t('play'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await AudioService().playSong(songs.first, playlist: songs);
                          if (context.mounted) {
                            NowPlayingSheet.show(context);
                          }
                        },
                      ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Divider(color: AppTheme.dividerColor, height: 1),

              // Songs List
              Expanded(
                child: songs.isEmpty
                    ? Center(
                        child: Text(
                          LanguageService().t('no_songs_in_playlist').replaceAll('{name}', title),
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: songs.length,
                        itemBuilder: (context, index) {
                          return SongTile(song: songs[index], playlist: songs);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audio = AudioService();

    return AnimatedBuilder(
      animation: audio,
      builder: (context, _) {
        final favSongs = audio.allSongs.where((s) => audio.favoriteIds.contains(s.id)).toList();

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: Text(LanguageService().t('playlists')),
            actions: [
              IconButton(
                icon: Icon(Icons.playlist_add_rounded, color: AppTheme.accentColor, size: 26),
                onPressed: () => _showCreatePlaylistDialog(context),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            physics: const BouncingScrollPhysics(),
            children: [
              // 1. Favorites Playlist Card
              _buildPlaylistCard(
                context,
                title: LanguageService().t('favorites_title'),
                subtitle: LanguageService().t('saved_songs_count').replaceAll('{count}', '${favSongs.length}'),
                icon: Icons.favorite_rounded,
                iconColor: const Color(0xFFFF5252),
                gradient: const [Color(0xFF26191D), Color(0xFF14171E)],
                borderColor: const Color(0xFF3F2128),
                onTap: () {
                  _openPlaylistDetails(
                    context,
                    title: LanguageService().t('favorites_title'),
                    songs: favSongs,
                    icon: Icons.favorite_rounded,
                    iconColor: const Color(0xFFFF5252),
                  );
                },
                onQuickPlay: favSongs.isNotEmpty
                    ? () async {
                        await audio.playSong(favSongs.first, playlist: favSongs);
                        if (context.mounted) {
                          NowPlayingSheet.show(context);
                        }
                      }
                    : null,
              ),

              const SizedBox(height: 12),

              // 2. Recently Played Card
              _buildPlaylistCard(
                context,
                title: LanguageService().t('recent_songs'),
                subtitle: LanguageService().t('recent_songs_sub').replaceAll('{count}', '${audio.recentlyPlayed.length}'),
                icon: Icons.history_rounded,
                iconColor: AppTheme.accentTeal,
                gradient: const [Color(0xFF13222B), Color(0xFF10161C)],
                borderColor: const Color(0xFF1C3442),
                onTap: () {
                  _openPlaylistDetails(
                    context,
                    title: LanguageService().t('recent_songs'),
                    songs: audio.recentlyPlayed,
                    icon: Icons.history_rounded,
                    iconColor: AppTheme.accentTeal,
                  );
                },
                onQuickPlay: audio.recentlyPlayed.isNotEmpty
                    ? () async {
                        await audio.playSong(audio.recentlyPlayed.first, playlist: audio.recentlyPlayed);
                        if (context.mounted) {
                          NowPlayingSheet.show(context);
                        }
                      }
                    : null,
              ),

              const SizedBox(height: 12),

              // 3. Complete Library Card
              _buildPlaylistCard(
                context,
                title: LanguageService().t('phone_library'),
                subtitle: LanguageService().t('phone_library_sub').replaceAll('{count}', '${audio.allSongs.length}'),
                icon: Icons.library_music_rounded,
                iconColor: AppTheme.accentColor,
                gradient: const [Color(0xFF14241B), Color(0xFF0F1519)],
                borderColor: const Color(0xFF1D3828),
                onTap: () {
                  _openPlaylistDetails(
                    context,
                    title: LanguageService().t('phone_library'),
                    songs: audio.allSongs,
                    icon: Icons.library_music_rounded,
                    iconColor: AppTheme.accentColor,
                  );
                },
                onQuickPlay: audio.allSongs.isNotEmpty
                    ? () async {
                        await audio.playSong(audio.allSongs.first, playlist: audio.allSongs);
                        if (context.mounted) {
                          NowPlayingSheet.show(context);
                        }
                      }
                    : null,
              ),

              const SizedBox(height: 24),

              // Create Custom Playlist Button
              Center(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentColor,
                    side: BorderSide(color: AppTheme.accentColor.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text(
                    LanguageService().t('create_custom_playlist'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showCreatePlaylistDialog(context),
                ),
              ),

              const SizedBox(height: 95),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaylistCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required List<Color> gradient,
    required Color borderColor,
    required VoidCallback onTap,
    VoidCallback? onQuickPlay,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(14),
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
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: iconColor.withOpacity(0.25)),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (onQuickPlay != null)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.play_arrow_rounded, color: AppTheme.accentColor, size: 24),
                    onPressed: onQuickPlay,
                  ),
                )
              else
                Icon(
                  LanguageService().isArabic
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.textMuted,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: LanguageService().textDirection,
        child: GlassDialog(
          title: Text(LanguageService().t('new_playlist'), style: TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: AppTheme.textPrimary),
            cursorColor: AppTheme.accentColor,
            decoration: InputDecoration(
              hintText: LanguageService().t('playlist_name'),
              hintStyle: TextStyle(color: AppTheme.textMuted),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.accentColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.cardBorder),
              ),
            ),
          ),
          actions: [
            TextButton(
              child: Text(LanguageService().t('cancel'), style: TextStyle(color: AppTheme.textSecondary)),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: AppTheme.accentColor.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(LanguageService().t('save'), style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                final name = controller.text.trim();
                Navigator.pop(ctx);
                if (name.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        LanguageService().t('playlist_created_success').replaceAll('{name}', name),
                      ),
                      backgroundColor: const Color(0xFF161F28),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
