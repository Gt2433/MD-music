import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../services/listening_insights_service.dart';
import '../services/song_edit_service.dart';
import '../theme/app_theme.dart';
import 'glass_dialog.dart';
import 'now_playing_sheet.dart';
import 'query_artwork_or_fallback.dart';

class ListeningInsightsSheet extends StatefulWidget {
  const ListeningInsightsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showGlassBottomSheet(
      context: context,
      builder: (_) => const ListeningInsightsSheet(),
    );
  }

  @override
  State<ListeningInsightsSheet> createState() => _ListeningInsightsSheetState();
}

class _ListeningInsightsSheetState extends State<ListeningInsightsSheet> {
  final ListeningInsightsService _insights = ListeningInsightsService();
  final AudioService _audio = AudioService();

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor;

    return Directionality(
      textDirection: LanguageService().textDirection,
      child: GlassBottomSheet(
        child: AnimatedBuilder(
          animation: _insights,
          builder: (context, _) {
            final topSongs = _insights.getTopSongs(_audio.allSongs, limit: 10);
            final topArtists = _insights.getTopArtists(limit: 3);
            final totalPlays = _insights.songPlayCounts.values.fold<int>(0, (sum, val) => sum + val);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.dividerColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  // Header Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: accent.withOpacity(0.4)),
                        ),
                        child: Icon(Icons.auto_graph_rounded, color: accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LanguageService().t('listening_insights_title'),
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              LanguageService().t('insights_header_desc'),
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.restart_alt_rounded, color: AppTheme.textSecondary, size: 22),
                        tooltip: LanguageService().t('reset'),
                        onPressed: () => _confirmReset(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Quick Stats Cards (2 columns)
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.access_time_filled_rounded,
                          label: LanguageService().t('insights_total_playtime'),
                          value: _insights.getFormattedTotalTime(),
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.play_circle_fill_rounded,
                          label: LanguageService().t('insights_total_plays'),
                          value: '$totalPlays',
                          color: Colors.amberAccent,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Top Artist Hero Card
                  if (topArtists.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withOpacity(0.18),
                            accent.withOpacity(0.06),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: accent.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '👑',
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  LanguageService().t('insights_top_artist'),
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  topArtists.first.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${topArtists.first.value} ${LanguageService().t('insights_plays')}',
                              style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Top Songs Section Header & Play Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        LanguageService().t('insights_top_songs'),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (topSongs.isNotEmpty)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            Navigator.pop(context);
                            await _audio.playSelectedSongsQueue(topSongs);
                            if (context.mounted) {
                              NowPlayingSheet.show(context);
                            }
                          },
                          icon: Icon(Icons.play_arrow_rounded, color: accent, size: 18),
                          label: Text(
                            LanguageService().t('play_all'),
                            style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  if (topSongs.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.library_music_rounded, color: AppTheme.textSecondary.withOpacity(0.5), size: 40),
                          const SizedBox(height: 8),
                          Text(
                            LanguageService().t('insights_empty_hint'),
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    ...List.generate(topSongs.length, (index) {
                      final song = topSongs[index];
                      final plays = _insights.getPlayCount(song.id);
                      final isTop3 = index < 3;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isTop3
                                ? accent.withOpacity(0.35)
                                : AppTheme.cardBorder.withOpacity(0.35),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Rank number or medal
                              SizedBox(
                                width: 26,
                                child: Center(
                                  child: isTop3
                                      ? Text(
                                          index == 0 ? '🥇' : (index == 1 ? '🥈' : '🥉'),
                                          style: const TextStyle(fontSize: 16),
                                        )
                                      : Text(
                                          '#${index + 1}',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              QueryArtworkOrFallback(
                                id: song.id,
                                size: 44,
                                borderRadius: 10,
                              ),
                            ],
                          ),
                          title: Text(
                            SongEditService().getDisplayTitle(song),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            SongEditService().getDisplayArtist(song),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$plays ${LanguageService().t('insights_plays')}',
                              style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            Navigator.pop(context);
                            await _audio.playSong(song, playlist: topSongs);
                            if (context.mounted) {
                              NowPlayingSheet.show(context);
                            }
                          },
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => GlassDialog(
        title: Text(
          LanguageService().t('insights_reset_title'),
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          LanguageService().t('insights_reset_confirm'),
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LanguageService().t('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _insights.resetStats();
            },
            child: Text(LanguageService().t('insights_reset_btn')),
          ),
        ],
      ),
    );
  }
}
