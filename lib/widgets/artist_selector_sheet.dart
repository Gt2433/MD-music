import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../services/song_edit_service.dart';
import '../theme/app_theme.dart';

class ArtistItemInfo {
  final String name;
  final int songCount;
  final bool isSpecial;

  ArtistItemInfo({
    required this.name,
    required this.songCount,
    this.isSpecial = false,
  });
}

class ArtistSelectorSheet extends StatefulWidget {
  final String currentArtist;
  final String? songTitle;

  const ArtistSelectorSheet({
    super.key,
    required this.currentArtist,
    this.songTitle,
  });

  static Future<String?> show(
    BuildContext context, {
    required String currentArtist,
    String? songTitle,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (ctx) => ArtistSelectorSheet(
        currentArtist: currentArtist,
        songTitle: songTitle,
      ),
    );
  }

  @override
  State<ArtistSelectorSheet> createState() => _ArtistSelectorSheetState();
}

class _ArtistSelectorSheetState extends State<ArtistSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  final SongEditService _editService = SongEditService();
  final AudioService _audioService = AudioService();

  List<ArtistItemInfo> _allArtists = [];
  List<ArtistItemInfo> _filteredArtists = [];
  String _searchQuery = '';
  final List<String> _titleSuggestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _extractTitleSuggestions();
    _loadArtists();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _extractTitleSuggestions() {
    final title = widget.songTitle;
    if (title != null && title.isNotEmpty) {
      // Check "Artist - Title" or "Title - Artist"
      if (title.contains(' - ')) {
        final parts = title.split(' - ');
        for (final p in parts) {
          final candidate = p.trim();
          if (candidate.length >= 2 && candidate.length <= 40 && !_isUnknown(candidate) && !candidate.contains('/')) {
            if (!_titleSuggestions.contains(candidate)) {
              _titleSuggestions.add(candidate);
            }
          }
        }
      }
      // Check "Artist_Title"
      if (title.contains('_')) {
        final parts = title.split('_');
        for (final p in parts) {
          final candidate = p.trim();
          if (candidate.length >= 2 && candidate.length <= 40 && !_isUnknown(candidate)) {
            if (!_titleSuggestions.contains(candidate)) {
              _titleSuggestions.add(candidate);
            }
          }
        }
      }
    }
  }

  bool _isUnknown(String? name) {
    if (name == null) return true;
    final clean = name.trim().toLowerCase();
    return clean.isEmpty ||
        clean == '<unknown>' ||
        clean == 'unknown' ||
        clean == 'unknown artist' ||
        clean == 'فنان غير معروف' ||
        clean == 'غير معروف' ||
        clean == 'null' ||
        clean == 'artiste inconnu';
  }

  Future<void> _loadArtists() async {
    final Map<String, int> counts = {};

    // 0. Ensure songs are loaded
    if (_audioService.allSongs.isEmpty) {
      try {
        await _audioService.loadSongs();
      } catch (_) {}
    }

    // 1. Collect from all device songs in library
    for (final s in _audioService.allSongs) {
      final displayName = _editService.getDisplayArtist(s).trim();
      if (!_isUnknown(displayName)) {
        counts[displayName] = (counts[displayName] ?? 0) + 1;
      } else if (!_isUnknown(s.artist)) {
        counts[s.artist!.trim()] = (counts[s.artist!.trim()] ?? 0) + 1;
      }

      // Extract artist candidates from titles like "2Pac - Changes"
      final sTitle = s.title;
      if (sTitle.contains(' - ')) {
        final candidate = sTitle.split(' - ').first.trim();
        if (candidate.length >= 2 && candidate.length <= 40 && !_isUnknown(candidate) && !candidate.contains('/')) {
          counts[candidate] = (counts[candidate] ?? 0) + 1;
        }
      }
    }

    // 2. Query native MediaStore artists
    try {
      final mediaStoreArtists = await _audioService.audioQuery.queryArtists();
      for (final a in mediaStoreArtists) {
        final aName = a.artist.trim();
        if (!_isUnknown(aName)) {
          counts[aName] = (counts[aName] ?? 0) + (a.numberOfTracks ?? 1);
        }
      }
    } catch (e) {
      debugPrint('Error querying MediaStore artists: $e');
    }

    // 3. Add custom artists created by the user
    for (final customName in _editService.customArtists) {
      final trimmed = customName.trim();
      if (!_isUnknown(trimmed) && !counts.containsKey(trimmed)) {
        counts[trimmed] = 0;
      }
    }

    // 4. Ensure current artist is included if valid
    if (!_isUnknown(widget.currentArtist)) {
      counts.putIfAbsent(widget.currentArtist.trim(), () => 1);
    }

    // 5. Add title suggestions
    for (final sug in _titleSuggestions) {
      counts.putIfAbsent(sug, () => 1);
    }

    // 6. Curated popular artists fallback suggestions if library is sparse
    final defaultArtists = [
      'The Notorious B.I.G.',
      '2Pac',
      'Eminem',
      'Billie Eilish',
      'The Weeknd',
      'Drake',
      'Michael Jackson',
      'عمرو دياب',
      'شيرين',
      'فيروز',
      'الشاب خالد',
      'أم كلثوم',
      'Soolking',
      'ElGrandeToto',
      'تسجيل صوتي',
      'موسيقى متنوعة',
    ];
    for (final name in defaultArtists) {
      counts.putIfAbsent(name, () => 0);
    }

    final list = counts.entries
        .map((e) => ArtistItemInfo(name: e.key, songCount: e.value))
        .toList();

    // Sort: current artist first, then by songCount descending, then alphabetically
    final curr = widget.currentArtist.trim().toLowerCase();
    list.sort((a, b) {
      final aIsCurr = a.name.trim().toLowerCase() == curr;
      final bIsCurr = b.name.trim().toLowerCase() == curr;
      if (aIsCurr && !bIsCurr) return -1;
      if (!aIsCurr && bIsCurr) return 1;
      if (a.songCount != b.songCount) {
        return b.songCount.compareTo(a.songCount);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    if (mounted) {
      setState(() {
        _allArtists = list;
        _filteredArtists = list;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim();
    setState(() {
      _searchQuery = q;
      if (q.isEmpty) {
        _filteredArtists = _allArtists;
      } else {
        _filteredArtists = _allArtists
            .where((a) => a.name.toLowerCase().contains(q.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _createAndSelectNewArtist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    HapticFeedback.mediumImpact();
    await _editService.addCustomArtist(trimmed);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم اختيار الفنان: "$trimmed" ✨'),
          backgroundColor: AppTheme.accentColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final exactMatch = _allArtists.any((a) => a.name.toLowerCase() == _searchQuery.toLowerCase());
    final canCreateNew = _searchQuery.isNotEmpty && !exactMatch;

    final isDark = AppTheme.isDark;
    final glassBg = isDark
        ? const Color(0xFF080D16).withOpacity(0.50)
        : Colors.white.withOpacity(0.60);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: glassBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(color: accent.withOpacity(0.4), width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.65),
                blurRadius: 35,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
        top: false,
        child: Column(
          children: [
            // 1. Top Drag Handle
            Center(
              child: Container(
                width: 46,
                height: 5,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // 2. Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withOpacity(0.35), width: 1),
                    ),
                    child: Icon(Icons.person_search_rounded, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRtl ? 'اختيار أو إضافة اسم الفنان' : 'Select or Add Artist',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isRtl
                              ? 'اختر من القائمة أو اكتب اسماً جديداً مباشرة'
                              : 'Pick from list or type a new name directly',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 3. Search / Direct Type Input Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161E2B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _searchQuery.isNotEmpty ? accent : const Color(0xFF263242),
                    width: 1.2,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      _createAndSelectNewArtist(val);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: isRtl ? 'ابحث أو اكتب اسم فنان جديد...' : 'Search or type new artist name...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13.5),
                    prefixIcon: Icon(Icons.search_rounded, color: accent, size: 22),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.white70, size: 20),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            // 4. Instant Create Banner Card (if query doesn't match an existing artist)
            if (canCreateNew)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withOpacity(0.25),
                        accent.withOpacity(0.10),
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withOpacity(0.6), width: 1.3),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_add_alt_1_rounded,
                          color: accent.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isRtl ? 'تعيين كاسم فنان جديد:' : 'Set as new artist:',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '"$_searchQuery"',
                              style: TextStyle(color: accent, fontSize: 15, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: accent.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          elevation: 0,
                        ),
                        onPressed: () => _createAndSelectNewArtist(_searchQuery),
                        child: Text(
                          isRtl ? 'تأكيد واختيار' : 'Confirm',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 5. Title Suggestions (if available and not searching)
            if (_titleSuggestions.isNotEmpty && _searchQuery.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141C28),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: accent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isRtl ? 'مقترح من العنوان: ${_titleSuggestions.first}' : 'From title: ${_titleSuggestions.first}',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: accent,
                          backgroundColor: accent.withOpacity(0.16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: () => _createAndSelectNewArtist(_titleSuggestions.first),
                        child: Text(isRtl ? 'اختيار' : 'Use', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),

            // 6. Section Subtitle Bar
            Padding(
              padding: const EdgeInsets.only(left: 22, right: 22, top: 10, bottom: 6),
              child: Row(
                children: [
                  Text(
                    isRtl ? 'الفنانون المقترحون والمتاحون' : 'Available Artists',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_filteredArtists.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context, LanguageService.tr('unknown_artist'));
                    },
                    child: Text(
                      isRtl ? 'فنان غير معروف' : 'Unknown Artist',
                      style: TextStyle(
                        color: accent.withOpacity(0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 7. Artists List View
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: accent, strokeWidth: 2.5),
                    )
                  : _filteredArtists.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_search_rounded, color: Colors.white.withOpacity(0.3), size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  isRtl
                                      ? 'اكتب اسم الفنان في الحقل أعلاه واضغط على "تأكيد واختيار"'
                                      : 'Type artist name above and tap "Confirm"',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          itemCount: _filteredArtists.length,
                          separatorBuilder: (context, index) => Divider(
                            color: Colors.white.withOpacity(0.06),
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final item = _filteredArtists[index];
                            final isSelected = item.name.trim().toLowerCase() ==
                                widget.currentArtist.trim().toLowerCase();

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.pop(context, item.name);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? accent.withOpacity(0.14)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                    border: isSelected
                                        ? Border.all(color: accent.withOpacity(0.4), width: 1.2)
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: isSelected
                                            ? accent
                                            : const Color(0xFF222C3D),
                                        child: Text(
                                          item.name.isNotEmpty
                                              ? item.name.characters.first.toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: isSelected
                                                ? (accent.computeLuminance() > 0.4 ? Colors.black : Colors.white)
                                                : Colors.white,
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: TextStyle(
                                                color: isSelected ? accent : Colors.white,
                                                fontSize: 15,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item.songCount > 0
                                                  ? '${item.songCount} ${LanguageService().t('songs')}'
                                                  : (isRtl ? 'فنان مقترح' : 'Suggested artist'),
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.48),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: accent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.check_rounded,
                                            color: accent.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                                            size: 16,
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
      ),
        ),
      ),
    );
  }
}
