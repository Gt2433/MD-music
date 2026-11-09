import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../models/lyric_line.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../services/lyrics_service.dart';
import '../services/song_edit_service.dart';
import '../theme/app_theme.dart';
import 'glass_dialog.dart';

class LyricsSheet extends StatefulWidget {
  final SongModel song;

  const LyricsSheet({super.key, required this.song});

  static void show(BuildContext context, SongModel song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => LyricsSheet(song: song),
    );
  }

  @override
  State<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<LyricsSheet> {
  final LyricsService _lyricsService = LyricsService();
  final ScrollController _scrollController = ScrollController();

  SongLyrics? _lyrics;
  bool _isLoading = true;
  bool _isSyncedMode = true;
  int _currentActiveIndex = -1;

  bool _isUserScrolling = false;
  Timer? _resumeAutoScrollTimer;
  StreamSubscription? _posSubscription;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
    _listenToPlayback();
  }

  Future<void> _loadLyrics({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final lyrics = await _lyricsService.getLyrics(
      widget.song,
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;
    setState(() {
      _lyrics = lyrics;
      _isLoading = false;
      _isSyncedMode = lyrics?.isSynced ?? false;
    });
  }

  void _listenToPlayback() {
    final player = AudioService().player;
    _posSubscription = player.positionStream.listen((position) {
      if (!mounted || _lyrics == null || !_lyrics!.isSynced || _lyrics!.lines.isEmpty) {
        return;
      }

      final lines = _lyrics!.lines;
      int active = -1;
      for (int i = 0; i < lines.length; i++) {
        if (position >= lines[i].time) {
          active = i;
        } else {
          break;
        }
      }

      if (active != _currentActiveIndex) {
        setState(() => _currentActiveIndex = active);
        if (!_isUserScrolling && active >= 0) {
          _scrollToIndex(active);
        }
      }
    });
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    // Estimated average item height for centered smooth scrolling
    const itemHeight = 52.0;
    final screenHeight = MediaQuery.of(context).size.height * 0.72;
    final targetOffset = (index * itemHeight) - (screenHeight / 2) + 60;
    final clampedOffset = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _onUserScrollStart() {
    _isUserScrolling = true;
    _resumeAutoScrollTimer?.cancel();
    _resumeAutoScrollTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _isUserScrolling = false);
        if (_currentActiveIndex >= 0) {
          _scrollToIndex(_currentActiveIndex);
        }
      }
    });
  }

  @override
  void dispose() {
    _posSubscription?.cancel();
    _resumeAutoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor;
    final isDark = AppTheme.isDark;
    final size = MediaQuery.of(context).size;
    final songTitle = SongEditService().getDisplayTitle(widget.song);
    final songArtist = SongEditService().getDisplayArtist(widget.song);

    return Directionality(
      textDirection: LanguageService().textDirection,
      child: Container(
        height: size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D131A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 28,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Column(
              children: [
                // 1. Top Drag Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 38,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // 2. Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Row(
                    children: [
                      // Song Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              songTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              songArtist,
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

                      // Synced/Plain Mode Toggle (only if synced exists)
                      if (_lyrics != null && _lyrics!.isSynced)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: _isSyncedMode
                                ? accent.withOpacity(0.16)
                                : (isDark ? Colors.white10 : Colors.black12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isSyncedMode
                                  ? accent.withOpacity(0.4)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            icon: Icon(
                              _isSyncedMode
                                  ? Icons.mic_rounded
                                  : Icons.subtitles_rounded,
                              size: 19,
                              color: _isSyncedMode ? accent : AppTheme.textMuted,
                            ),
                            tooltip: _isSyncedMode
                                ? LanguageService().t('lyrics_live_synced')
                                : LanguageService().t('lyrics_plain_text'),
                            onPressed: () {
                              setState(() => _isSyncedMode = !_isSyncedMode);
                            },
                          ),
                        ),

                      // Action Menu (Search Online, Edit, Copy, Refresh)
                      _buildActionMenu(context, accent),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 1),

                // 3. Body Content
                Expanded(
                  child: Stack(
                    children: [
                      if (_isLoading)
                        _buildLoadingState(accent)
                      else if (_lyrics == null || _lyrics!.isEmpty)
                        _buildEmptyState(context, accent)
                      else if (_isSyncedMode && _lyrics!.isSynced)
                        _buildSyncedKaraokeList(accent)
                      else
                        _buildPlainTextList(),

                      // Floating "Resume Auto Scroll" button
                      if (_isUserScrolling &&
                          _lyrics != null &&
                          _lyrics!.isSynced &&
                          _currentActiveIndex >= 0)
                        Positioned(
                          bottom: 24,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: () {
                                  setState(() => _isUserScrolling = false);
                                  _scrollToIndex(_currentActiveIndex);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8.5),
                                  decoration: BoxDecoration(
                                    color: accent,
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accent.withOpacity(0.45),
                                        blurRadius: 12,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.sync_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        LanguageService().t('lyrics_return_to_current'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
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

  // -------------------------------------------------------------
  // Synchronized Karaoke List View
  // -------------------------------------------------------------
  Widget _buildSyncedKaraokeList(Color accent) {
    final lines = _lyrics!.lines;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is UserScrollNotification) {
          _onUserScrollStart();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          final isActive = index == _currentActiveIndex;
          final isPast = index < _currentActiveIndex;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.mediumImpact();
              AudioService().seek(line.time);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? accent.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: isActive
                    ? Border.all(color: accent.withOpacity(0.35), width: 1.2)
                    : null,
              ),
              child: Text(
                line.text.isEmpty ? '•••' : line.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isActive ? 20.0 : 16.0,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  color: isActive
                      ? accent
                      : (isPast
                          ? AppTheme.textMuted.withOpacity(0.55)
                          : AppTheme.textSecondary.withOpacity(0.85)),
                  height: 1.45,
                  shadows: isActive
                      ? [
                          Shadow(
                            color: accent.withOpacity(0.6),
                            blurRadius: 14,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // Plain Text List View
  // -------------------------------------------------------------
  Widget _buildPlainTextList() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SelectableText(
        _lyrics!.plainLyrics,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16.0,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
          height: 1.85,
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Loading State
  // -------------------------------------------------------------
  Widget _buildLoadingState(Color accent) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            strokeWidth: 2.8,
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
          const SizedBox(height: 16),
          Text(
            LanguageService().t('lyrics_searching'),
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Empty State
  // -------------------------------------------------------------
  Widget _buildEmptyState(BuildContext context, Color accent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withOpacity(0.3), width: 1.5),
              ),
              child: Icon(Icons.music_note_rounded, color: accent, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              LanguageService().t('lyrics_not_found'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              LanguageService().t('lyrics_not_found_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13.0,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. Retry Button (إعادة المحاولة)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(LanguageService().t('lyrics_retry')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    onPressed: () => _loadLyrics(forceRefresh: true),
                  ),
                  const SizedBox(width: 8),

                  // 2. Search Online Button (بحث بالاسم)
                  OutlinedButton.icon(
                    icon: Icon(Icons.search_rounded, size: 18, color: accent),
                    label: Text(LanguageService().t('lyrics_search_title')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: BorderSide(
                          color: accent.withOpacity(0.45), width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onPressed: () => _openSearchDialog(),
                  ),
                  const SizedBox(width: 8),

                  // 3. Add Manually Button (إضافة يدوياً)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: Text(LanguageService().t('lyrics_add_manually')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: BorderSide(color: AppTheme.cardBorder, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onPressed: () => _openEditDialog(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Header Action Menu
  // -------------------------------------------------------------
  Widget _buildActionMenu(BuildContext context, Color accent) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: AppTheme.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppTheme.cardColor,
      onSelected: (value) {
        switch (value) {
          case 'search':
            _openSearchDialog();
            break;
          case 'edit':
            _openEditDialog();
            break;
          case 'refresh':
            _loadLyrics(forceRefresh: true);
            break;
          case 'copy':
            if (_lyrics != null && _lyrics!.isNotEmpty) {
              Clipboard.setData(ClipboardData(text: _lyrics!.plainLyrics));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    LanguageService().t('lyrics_copied'),
                  ),
                  backgroundColor: AppTheme.surface,
                ),
              );
            }
            break;
          case 'delete':
            _lyricsService.deleteLyrics(widget.song.id);
            setState(() => _lyrics = null);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'search',
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 19, color: accent),
              const SizedBox(width: 10),
              Text(
                LanguageService().t('lyrics_search_online'),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 19, color: accent),
              const SizedBox(width: 10),
              Text(
                LanguageService().t('lyrics_edit_paste'),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
              ),
            ],
          ),
        ),
        if (_lyrics != null && _lyrics!.isNotEmpty)
          PopupMenuItem(
            value: 'copy',
            child: Row(
              children: [
                Icon(Icons.copy_rounded, size: 19, color: accent),
                const SizedBox(width: 10),
                Text(
                  LanguageService().t('lyrics_copy'),
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
                ),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh_rounded, size: 19, color: accent),
              const SizedBox(width: 10),
              Text(
                LanguageService().t('lyrics_reload'),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
              ),
            ],
          ),
        ),
        if (_lyrics != null)
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                const Icon(Icons.delete_outline_rounded,
                    size: 19, color: Colors.redAccent),
                const SizedBox(width: 10),
                Text(
                  LanguageService().t('lyrics_delete_saved'),
                  style: const TextStyle(
                      color: Colors.redAccent, fontSize: 13.5),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Search Online Dialog
  // -------------------------------------------------------------
  void _openSearchDialog() {
    final title = SongEditService().getDisplayTitle(widget.song);
    final artist = SongEditService().getDisplayArtist(widget.song);
    final controller = TextEditingController(text: '$title $artist'.trim());

    showGlassDialog(
      context: context,
      builder: (ctx) => GlassDialog(
        title: Text(
          LanguageService().t('lyrics_search_dialog_title'),
        ),
        content: StatefulBuilder(
          builder: (ctx2, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: LanguageService().t('lyrics_search_dialog_hint'),
                    hintStyle: TextStyle(color: AppTheme.textMuted),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: AppTheme.accentColor, size: 20),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppTheme.cardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final q = controller.text.trim();
                    if (q.isEmpty) return;
                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    final candidates =
                        await _lyricsService.searchOnlineCandidates(q);
                    if (!mounted) return;
                    if (candidates.isNotEmpty) {
                      _showCandidatesPicker(candidates);
                    } else {
                      setState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            LanguageService().t('lyrics_no_results'),
                          ),
                          backgroundColor: AppTheme.surface,
                        ),
                      );
                    }
                  },
                  child: Text(
                    LanguageService().t('search'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showCandidatesPicker(
    List<Map<String, dynamic>> candidates,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          itemCount: candidates.length,
          separatorBuilder: (_, _) =>
              Divider(color: AppTheme.dividerColor, height: 1),
          itemBuilder: (ctx, index) {
            final c = candidates[index];
            final trackName = c['trackName'] ?? '';
            final artistName = c['artistName'] ?? '';
            final hasSynced =
                (c['syncedLyrics'] as String?)?.isNotEmpty == true;

            return ListTile(
              leading: Icon(
                hasSynced ? Icons.mic_rounded : Icons.subtitles_rounded,
                color: AppTheme.accentColor,
              ),
              title: Text(
                trackName,
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                artistName,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              trailing: hasSynced
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        LanguageService().t('lyrics_synced_badge'),
                        style: TextStyle(
                            color: AppTheme.accentColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold),
                      ),
                    )
                  : null,
              onTap: () async {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                final lyrics = await _lyricsService.applyOnlineCandidate(
                  widget.song,
                  c,
                );
                if (mounted) {
                  setState(() {
                    _lyrics = lyrics;
                    _isLoading = false;
                    _isSyncedMode = lyrics?.isSynced ?? false;
                  });
                }
              },
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // Manual Edit / Paste Dialog
  // -------------------------------------------------------------
  void _openEditDialog() {
    final controller = TextEditingController(
      text: _lyrics?.plainLyrics ?? '',
    );

    showGlassDialog(
      context: context,
      builder: (ctx) => GlassDialog(
        title: Text(
          LanguageService().t('lyrics_edit_paste'),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                LanguageService().t('lyrics_edit_instruction'),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 12,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: LanguageService().t('lyrics_edit_placeholder'),
                  hintStyle: TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppTheme.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        LanguageService().t('cancel'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final text = controller.text.trim();
                        Navigator.pop(ctx);
                        if (text.isNotEmpty) {
                          setState(() => _isLoading = true);
                          final saved = await _lyricsService.saveManualLyrics(
                            widget.song,
                            text,
                          );
                          if (mounted) {
                            setState(() {
                              _lyrics = saved;
                              _isLoading = false;
                              _isSyncedMode = saved.isSynced;
                            });
                          }
                        }
                      },
                      child: Text(
                        LanguageService().t('save'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
