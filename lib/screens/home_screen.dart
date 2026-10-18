import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/album_service.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../services/song_edit_service.dart';
import '../services/song_selection_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fast_scroller.dart';
import '../widgets/now_playing_sheet.dart';
import '../widgets/query_artwork_or_fallback.dart';
import '../widgets/song_tile.dart';
import '../widgets/glass_dialog.dart';
import 'album_details_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import '../services/app_update_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _headerAnimController;
  late final AnimationController _glowAnimController;
  bool _isHeaderVisible = true;

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1.0,
    );
    _glowAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _scrollController.addListener(_handleScroll);
    _scheduleUpdateCheck();
  }

  void _scheduleUpdateCheck() {
    Future.delayed(const Duration(seconds: 4), () async {
      if (!mounted) return;
      try {
        final release = await AppUpdateService().checkForUpdate();
        if (release != null && mounted) {
          AppUpdateService.showUpdateDialog(context, release);
        }
      } catch (_) {}
    });
  }

  void _handleScroll() {
    if (_scrollController.hasClients && _scrollController.offset <= 10) {
      if (!_isHeaderVisible) {
        _headerAnimController.forward();
        _isHeaderVisible = true;
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _headerAnimController.dispose();
    _glowAnimController.dispose();
    super.dispose();
  }

  final List<String> _categories = const [
    'all',
    'songs',
    'albums',
    'artists',
    'playlists',
    'favorites',
  ];

  String _selectedCategory = 'all';

  @override
  Widget build(BuildContext context) {
    final audio = AudioService();
    final albumService = AlbumService();
    final selection = SongSelectionService();

    return AnimatedBuilder(
      animation: Listenable.merge([audio, albumService, selection]),
      builder: (context, _) {
        final isSelectionMode = selection.isSelectionMode;

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // 1. Flat Top Header Bar (Hides on scroll down, shows on scroll up)
                SizeTransition(
                  sizeFactor: CurvedAnimation(
                    parent: _headerAnimController,
                    curve: Curves.easeInOutCubic,
                  ),
                  axisAlignment: -1.0,
                  child: FadeTransition(
                    opacity: _headerAnimController,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: isSelectionMode
                          ? _buildSelectionHeader(
                              context, selection, _getActiveSongs(audio))
                          : _buildStandardHeader(context),
                    ),
                  ),
                ),

                // 2. Horizontal Scrollable Category Bar (Ultra-modern Gradient Chips)
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: isSelectionMode
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: _categories.map((catKey) {
                        final isSelected = _selectedCategory == catKey;
                        final label = LanguageService().t(catKey);
                        final accent = AppTheme.accentColor;
                        final onAccentColor =
                            ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
                                ? Colors.white
                                : Colors.black;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () {
                              if (_selectedCategory != catKey) {
                                setState(() {
                                  _selectedCategory = catKey;
                                });
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              constraints: const BoxConstraints(minWidth: 76),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8.5),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? LinearGradient(
                                        colors: [accent, accent.withOpacity(0.85)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: isSelected ? null : AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isSelected
                                      ? accent
                                      : AppTheme.cardBorder,
                                  width: 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: accent.withOpacity(0.35),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected ? onAccentColor : AppTheme.textSecondary,
                                  fontSize: 13.0,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

                // 3. Dynamic Category Content with Smooth Animated Transition
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: CurvedAnimation(
                          parent: animation,
                          curve: const Interval(0.05, 1.0, curve: Curves.easeOut),
                        ),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.04, 0.0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey<String>(_selectedCategory),
                      child: NotificationListener<UserScrollNotification>(
                        onNotification: (notification) {
                          if (notification.direction == ScrollDirection.reverse) {
                            if (_isHeaderVisible && _scrollController.hasClients && _scrollController.offset > 20) {
                              _headerAnimController.reverse();
                              _isHeaderVisible = false;
                            }
                          } else if (notification.direction == ScrollDirection.forward) {
                            if (!_isHeaderVisible) {
                              _headerAnimController.forward();
                              _isHeaderVisible = true;
                            }
                          }
                          return false;
                        },
                        child: FastScroller(
                          controller: _scrollController,
                          child: RefreshIndicator(
                            color: AppTheme.primaryGreen,
                            backgroundColor: AppTheme.cardColor,
                            displacement: 24,
                            onRefresh: () async {
                              await audio.loadSongs();
                            },
                            child: CustomScrollView(
                              controller: _scrollController,
                              key: PageStorageKey<String>(_selectedCategory),
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              slivers: [
                                ..._buildCategorySlivers(context, audio),
                                // Bottom padding for mini-player
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 110),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        },
      );
    }

  List<SongModel> _getActiveSongs(AudioService audio) {
    if (_selectedCategory == 'favorites' || _selectedCategory == 'المفضلة') {
      return audio.allSongs
          .where((s) => audio.favoriteIds.contains(s.id))
          .toList();
    }
    return audio.allSongs;
  }

  Widget _buildStandardHeader(BuildContext context) {
    return Padding(
      key: const ValueKey('standard_header'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildGlowingHeaderTitle(),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder, width: 1),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.search_rounded,
                      color: AppTheme.textPrimary, size: 21),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder, width: 1),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.settings_outlined,
                      color: AppTheme.textPrimary, size: 21),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionHeader(
    BuildContext context,
    SongSelectionService selection,
    List<SongModel> activeSongs,
  ) {
    final accent = AppTheme.accentColor;
    final allSelected = selection.areAllSelected(activeSongs);
    final count = selection.selectedCount;

    return Padding(
      key: const ValueKey('selection_header'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close / Cancel Selection Button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder, width: 1),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.close_rounded,
                  color: AppTheme.textPrimary, size: 22),
              onPressed: () => selection.clearSelection(),
            ),
          ),

          // Selected Count Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withOpacity(0.4), width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.format_list_numbered_rounded, color: accent, size: 18),
                const SizedBox(width: 6),
                Text(
                  LanguageService.tr('selected_count')
                      .replaceAll('{count}', '$count'),
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Play in Order Action Button in Header
          if (count > 0)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final songs = selection.selectedSongs;
                  if (songs.isEmpty) return;
                  HapticFeedback.mediumImpact();
                  final ordered = List<SongModel>.from(songs);
                  selection.clearSelection();
                  await AudioService().playSelectedSongsQueue(ordered);
                  if (context.mounted) {
                    NowPlayingSheet.show(context);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent,
                        accent.withOpacity(0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          color: accent.computeLuminance() > 0.4
                              ? Colors.black
                              : Colors.white,
                          size: 19),
                      const SizedBox(width: 4),
                      Text(
                        LanguageService().isArabic
                            ? 'تشغيل بالترتيب'
                            : 'Play in Order',
                        style: TextStyle(
                          color: accent.computeLuminance() > 0.4
                              ? Colors.black
                              : Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Select All / Deselect All Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => selection.toggleSelectAll(activeSongs),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: allSelected ? accent : AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: allSelected ? accent : AppTheme.cardBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      allSelected
                          ? Icons.deselect_rounded
                          : Icons.select_all_rounded,
                      color: allSelected
                          ? (accent.computeLuminance() > 0.4
                              ? Colors.black
                              : Colors.white)
                          : accent,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      allSelected
                          ? LanguageService.tr('deselect_all')
                          : LanguageService.tr('select_all'),
                      style: TextStyle(
                        color: allSelected
                            ? (accent.computeLuminance() > 0.4
                                ? Colors.black
                                : Colors.white)
                            : AppTheme.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowingHeaderTitle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _glowAnimController.forward(from: 0.0);
      },
      child: AnimatedBuilder(
        animation: _glowAnimController,
        builder: (context, _) {
          final isGlowActive = _glowAnimController.isAnimating;
          final t = _glowAnimController.value;

          // Sweeps horizontally from left (-50px) to right (220px)
          final beamLeft = -50.0 + (t * 260.0);
          final beamOpacity = isGlowActive
              ? (1.0 - (t - 0.5).abs() * 0.75).clamp(0.0, 1.0)
              : 0.0;

          return SizedBox(
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // 1. Radiant glow beam that sweeps from left to right behind the text
                if (isGlowActive) ...[
                  Positioned(
                    left: beamLeft - 15,
                    top: -6,
                    child: Container(
                      width: 95,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.accentColor.withOpacity(0.75 * beamOpacity),
                            AppTheme.accentColor.withOpacity(0.25 * beamOpacity),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentColor.withOpacity(0.60 * beamOpacity),
                            blurRadius: 26,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: beamLeft + 18,
                    top: 6,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.90 * beamOpacity),
                            AppTheme.accentColor.withOpacity(0.40 * beamOpacity),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                // 2. Foreground Brand Logo & Title
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isGlowActive
                              ? AppTheme.accentColor.withOpacity(0.6 * beamOpacity)
                              : AppTheme.cardBorder,
                          width: 1,
                        ),
                        boxShadow: isGlowActive
                            ? [
                                BoxShadow(
                                  color: AppTheme.accentColor.withOpacity(0.35 * beamOpacity),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'MD',
                          style: TextStyle(
                            color: AppTheme.accentColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            shadows: isGlowActive
                                ? [
                                    Shadow(
                                      color: AppTheme.accentColor.withOpacity(0.9 * beamOpacity),
                                      blurRadius: 16,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'MUSIC',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            shadows: isGlowActive
                                ? [
                                    Shadow(
                                      color: AppTheme.accentColor.withOpacity(0.7 * beamOpacity),
                                      blurRadius: 14,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildCategorySlivers(BuildContext context, AudioService audio) {
    if (audio.isLoading) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                ),
                SizedBox(height: 16),
                Text(
                  'جاري فحص ذاكرة الهاتف...',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (audio.allSongs.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyState(context, audio),
        ),
      ];
    }

    switch (_selectedCategory) {
      case 'all':
      case 'songs':
      case 'الكل':
      case 'الأغاني':
        return _buildSongsSlivers(context, audio);
      case 'albums':
      case 'الألبومات':
        return _buildAlbumsSlivers(context, audio);
      case 'artists':
      case 'الفنانون':
        return _buildArtistsSlivers(context, audio);
      case 'playlists':
      case 'قوائم التشغيل':
        return _buildPlaylistsSlivers(context, audio);
      case 'favorites':
      case 'المفضلة':
        return _buildFavoritesSlivers(context, audio);
      default:
        return _buildSongsSlivers(context, audio);
    }
  }

  // -------------------------------------------------------------
  // Content: All / Songs
  // -------------------------------------------------------------
  List<Widget> _buildSongsSlivers(BuildContext context, AudioService audio) {
    return [
      // Flat Action Header
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Container(
                width: 3.5,
                height: 15,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                (_selectedCategory == 'all' || _selectedCategory == 'الكل')
                    ? LanguageService().t('all_songs')
                    : LanguageService().t('songs_list'),
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3), width: 1),
                ),
                child: Text(
                  '${audio.allSongs.length}',
                  style: TextStyle(
                    color: AppTheme.accentColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Songs List
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final song = audio.allSongs[index];
            return SongTile(song: song, playlist: audio.allSongs);
          },
          childCount: audio.allSongs.length,
        ),
      ),
    ];
  }

  // -------------------------------------------------------------
  // Content: Custom Albums (الميزة الجديدة: إنشاء وإدارة الألبومات الخاصة)
  // -------------------------------------------------------------
  List<Widget> _buildAlbumsSlivers(BuildContext context, AudioService audio) {
    final albumService = AlbumService();
    final albums = albumService.albums;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 15,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    LanguageService().t('custom_albums'),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Text(
                      '${albums.length}',
                      style: TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => _showCreateAlbumDialog(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      color: AppTheme.accentColor.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      if (albums.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.cardBorder, width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Icon(
                      Icons.album_rounded,
                      size: 38,
                      color: AppTheme.accentColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    LanguageService().t('no_albums_yet'),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    LanguageService().t('create_album_prompt'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateAlbumDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: AppTheme.accentColor.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text(
                      LanguageService().t('create_first_album_now'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.74,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final album = albums[index];
                final albumSongs = albumService.getSongsForAlbum(album.id, audio.allSongs);
                final hasSongs = albumSongs.isNotEmpty;
                final firstSongId = hasSongs ? albumSongs.first.id : null;

                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    _showAlbumDetailsSheet(context, album, audio);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.cardBorder, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(AppTheme.isDark ? 0.35 : 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Square Artwork with NO green play triangle and NO 3-dots
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: (album.customArtworkPath != null && File(album.customArtworkPath!).existsSync())
                                ? Image.file(
                                    File(album.customArtworkPath!),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    filterQuality: FilterQuality.high,
                                  )
                                : (hasSongs
                                    ? QueryArtworkOrFallback(
                                        id: firstSongId!,
                                        size: double.infinity,
                                        borderRadius: 15,
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          color: AppTheme.isDark ? const Color(0xFF1F2B23) : AppTheme.surfaceLight,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.album_rounded,
                                            size: 48,
                                            color: AppTheme.isDark ? const Color(0xFF45614F) : AppTheme.textMuted,
                                          ),
                                        ),
                                      )),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Album Name in the Center
                        Text(
                          album.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // Song count centered in small font
                        Text(
                          LanguageService.formatSongCount(album.songIds.length),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                    ),
                  ),
                );
              },
              childCount: albums.length,
            ),
          ),
        ),
    ];
  }

  // -------------------------------------------------------------
  // Album Details Screen Navigation
  // -------------------------------------------------------------
  void _showAlbumDetailsSheet(BuildContext context, CustomAlbum album, AudioService audio) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlbumDetailsScreen(album: album),
      ),
    );
  }

  // -------------------------------------------------------------
  // Create Album Dialog
  // -------------------------------------------------------------
  void _showCreateAlbumDialog(BuildContext context, {int? initialSongId}) {
    final controller = TextEditingController();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: LanguageService().t('close'),
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
      pageBuilder: (dialogCtx, anim1, anim2) {
        return Directionality(
          textDirection: LanguageService().textDirection,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(dialogCtx).size.width * 0.86,
                constraints: const BoxConstraints(maxWidth: 360),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.65),
                      blurRadius: 36,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.12),
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
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      decoration: BoxDecoration(
                        color: (AppTheme.isDark ? const Color(0xFF121B16) : AppTheme.surface).withOpacity(0.92),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: AppTheme.isDark ? Colors.white.withOpacity(0.12) : AppTheme.cardBorder,
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header: 'X' button on the Trailing edge, Title centered
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () => Navigator.pop(dialogCtx),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppTheme.isDark ? Colors.white.withOpacity(0.06) : AppTheme.surfaceLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: AppTheme.textMuted,
                                    size: 20,
                                  ),
                                ),
                              ),
                              Text(
                                LanguageService().t('create_new_album'),
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 34), // Balances the X button
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Text Input: Only underline (no box outline)
                          TextField(
                            controller: controller,
                            autofocus: true,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            cursorColor: AppTheme.accentColor,
                            decoration: InputDecoration(
                              hintText: LanguageService().t('type_album_name'),
                              hintStyle: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 14.5,
                              ),
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppTheme.cardBorder, width: 1.5),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppTheme.cardBorder, width: 1.5),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppTheme.accentColor, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),

                          // Create Album Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentColor,
                                foregroundColor: AppTheme.accentColor.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () async {
                                final name = controller.text.trim();
                                if (name.isEmpty) return;
                                Navigator.pop(dialogCtx);
                                final newAlbum = await AlbumService().createAlbum(
                                  name,
                                  songIds: initialSongId != null ? [initialSongId] : null,
                                );
                                if (context.mounted) {
                                  AlbumDetailsScreen.showAddSongsSheet(context, newAlbum);
                                }
                              },
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.black,
                                size: 30,
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



  void _showSongListSheet(BuildContext context, String title, List<SongModel> songs) {
    showGlassBottomSheet(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: LanguageService().textDirection,
        child: GlassBottomSheet(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
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
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(LanguageService().t('play_all'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
              Expanded(
                child: ListView.builder(
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

  // -------------------------------------------------------------
  // Content: Artists (Real data grouped by song.artist)
  // -------------------------------------------------------------
  List<Widget> _buildArtistsSlivers(BuildContext context, AudioService audio) {
    final Map<String, List<SongModel>> artistMap = {};
    final editService = SongEditService();
    for (var s in audio.allSongs) {
      final displayArtist = editService.getDisplayArtist(s).trim();
      final isUnknown = displayArtist.isEmpty ||
          displayArtist.toLowerCase() == '<unknown>' ||
          displayArtist.toLowerCase() == 'unknown' ||
          displayArtist == LanguageService.tr('unknown_artist');

      final art = isUnknown ? LanguageService().t('unknown_artist') : displayArtist;
      artistMap.putIfAbsent(art, () => []).add(s);
    }
    final artists = artistMap.entries.toList();
    artists.sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Container(
                width: 3.5,
                height: 15,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                LanguageService().t('artists'),
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3), width: 1),
                ),
                child: Text(
                  '${artists.length}',
                  style: TextStyle(
                    color: AppTheme.accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      if (artists.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_off_rounded, size: 54, color: AppTheme.textMuted),
                const SizedBox(height: 12),
                Text(
                  LanguageService().t('no_artist_found'),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        )
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final entry = artists[index];
              final artistName = entry.key;
            final artistSongs = entry.value;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder, width: 1),
              ),
              child: ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person_rounded, color: AppTheme.accentColor, size: 24),
                ),
                title: Text(
                  artistName,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  LanguageService.formatSongCount(artistSongs.length),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.play_circle_outline_rounded, color: AppTheme.accentColor, size: 28),
                  onPressed: () async {
                    await audio.playSong(artistSongs.first, playlist: artistSongs);
                    if (context.mounted) {
                      NowPlayingSheet.show(context);
                    }
                  },
                ),
                onTap: () {
                  _showSongListSheet(context, artistName, artistSongs);
                },
              ),
            );
          },
          childCount: artists.length,
        ),
      ),
    ];
  }

  // -------------------------------------------------------------
  // Content: Playlists (Flat Design Cards)
  // -------------------------------------------------------------
  List<Widget> _buildPlaylistsSlivers(BuildContext context, AudioService audio) {
    final favSongs = audio.allSongs.where((s) => audio.favoriteIds.contains(s.id)).toList();

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              _buildFlatPlaylistTile(
                icon: Icons.favorite_rounded,
                iconColor: const Color(0xFFFF5252),
                title: LanguageService().t('favorites_title'),
                subtitle: LanguageService().t('saved_songs_count').replaceAll('{count}', '${favSongs.length}'),
                onTap: () {
                  setState(() {
                    _selectedCategory = 'favorites';
                  });
                },
              ),
              const SizedBox(height: 8),
              _buildFlatPlaylistTile(
                icon: Icons.library_music_rounded,
                iconColor: AppTheme.primaryGreen,
                title: LanguageService().t('phone_library'),
                subtitle: LanguageService().t('phone_library_sub').replaceAll('{count}', '${audio.allSongs.length}'),
                onTap: () {
                  setState(() {
                    _selectedCategory = 'all';
                  });
                },
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildFlatPlaylistTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
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
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14.5, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        trailing: Icon(
          LanguageService().isArabic
              ? Icons.arrow_forward_ios_rounded
              : Icons.arrow_back_ios_new_rounded,
          color: AppTheme.textMuted,
          size: 14,
        ),
        onTap: onTap,
      ),
    );
  }

  // -------------------------------------------------------------
  // Content: Favorites
  // -------------------------------------------------------------
  List<Widget> _buildFavoritesSlivers(BuildContext context, AudioService audio) {
    final favSongs = audio.allSongs.where((s) => audio.favoriteIds.contains(s.id)).toList();

    if (favSongs.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.cardBorder, width: 1),
                  ),
                  child: const Icon(Icons.favorite_border_rounded, color: Color(0xFFFF5252), size: 40),
                ),
                const SizedBox(height: 14),
                Text(
                  LanguageService().t('no_favorites_title'),
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  LanguageService().t('no_favorites_hint'),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 15,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5252),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    LanguageService().t('favorites_title'),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161E26),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF222C38), width: 1),
                    ),
                    child: Text(
                      '${favSongs.length}',
                      style: const TextStyle(
                        color: Color(0xFFFF5252),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  await audio.playSong(favSongs.first, playlist: favSongs);
                  if (context.mounted) {
                    NowPlayingSheet.show(context);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 17),
                      const SizedBox(width: 4),
                      Text(
                        LanguageService().t('play_all'),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return SongTile(song: favSongs[index], playlist: favSongs);
          },
          childCount: favSongs.length,
        ),
      ),
    ];
  }

  Widget _buildEmptyState(BuildContext context, AudioService audio) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.accentColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.music_off_rounded,
                color: AppTheme.accentColor,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              LanguageService().t('no_songs_found'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              LanguageService().t('permission_needed'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: AppTheme.accentColor.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: Text(
                LanguageService().t('search'),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                final granted = await audio.checkAndRequestPermissions();
                if (!granted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'يرجى منح إذن الوصول إلى الموسيقى من إعدادات الهاتف لعرض أغانيك.',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.redAccent,
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

