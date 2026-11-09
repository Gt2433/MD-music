import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import '../models/lyric_line.dart';
import 'song_edit_service.dart';

class LyricsService {
  static final LyricsService _instance = LyricsService._internal();
  factory LyricsService() => _instance;
  LyricsService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': 'MDMusicApp/2.0.0 (https://github.com/Gt2433/MD-music)',
      },
    ),
  );

  final Map<int, SongLyrics> _memoryCache = {};

  /// Retrieves lyrics for a song with multi-tier fallback:
  /// 1. Memory cache
  /// 2. Offline disk cache (`<appDocDir>/lyrics/<id>.json`)
  /// 3. Adjacent local file on disk (`<path>.lrc` or `<path>.txt`)
  /// 4. Online free LRCLIB API
  Future<SongLyrics?> getLyrics(
    SongModel song, {
    bool forceRefresh = false,
  }) async {
    final songId = song.id;

    // 1. Memory Cache
    if (!forceRefresh && _memoryCache.containsKey(songId)) {
      return _memoryCache[songId];
    }

    // 2. Local Disk Cache
    if (!forceRefresh) {
      final cached = await _loadFromDiskCache(songId);
      if (cached != null) {
        _memoryCache[songId] = cached;
        return cached;
      }
    }

    // 3. Adjacent .lrc or .txt file in same directory
    final localFileLyrics = await _checkAdjacentLocalFile(song);
    if (localFileLyrics != null) {
      _memoryCache[songId] = localFileLyrics;
      await _saveToDiskCache(localFileLyrics);
      return localFileLyrics;
    }

    // 4. Online LRCLIB API
    final onlineLyrics = await fetchOnlineLyrics(song);
    if (onlineLyrics != null) {
      _memoryCache[songId] = onlineLyrics;
      await _saveToDiskCache(onlineLyrics);
      return onlineLyrics;
    }

    return null;
  }

  /// Fetches lyrics from LRCLIB open API
  Future<SongLyrics?> fetchOnlineLyrics(SongModel song) async {
    final editService = SongEditService();
    final rawTitle = editService.getDisplayTitle(song);
    final rawArtist = editService.getDisplayArtist(song);

    final cleanTitle = _cleanSongTitle(rawTitle);
    final cleanArtist = _cleanArtistName(rawArtist);

    if (cleanTitle.isEmpty) return null;

    final durationSec = (song.duration != null && song.duration! > 0)
        ? (song.duration! / 1000).round()
        : null;

    try {
      // 1. Try exact match endpoint
      final Map<String, dynamic> queryParams = {
        'track_name': cleanTitle,
      };
      if (cleanArtist.isNotEmpty) {
        queryParams['artist_name'] = cleanArtist;
      }
      if (durationSec != null && durationSec > 10) {
        queryParams['duration'] = durationSec;
      }

      final response = await _dio.get(
        'https://lrclib.net/api/get',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final lyrics = _parseLrclibResponse(data, song.id, rawTitle, rawArtist);
        if (lyrics != null && lyrics.isNotEmpty) {
          return lyrics;
        }
      }
    } catch (_) {
      // Exact match failed, proceed to search fallback
    }

    // 2. Try search endpoint fallback
    try {
      final searchQuery = cleanArtist.isNotEmpty
          ? '$cleanTitle $cleanArtist'
          : cleanTitle;

      final searchResponse = await _dio.get(
        'https://lrclib.net/api/search',
        queryParameters: {'q': searchQuery},
      );

      if (searchResponse.statusCode == 200 && searchResponse.data is List) {
        final list = searchResponse.data as List;
        if (list.isNotEmpty && list.first is Map<String, dynamic>) {
          // Look for an entry with syncedLyrics first
          final bestMatch = list.firstWhere(
            (item) => (item['syncedLyrics'] as String?)?.isNotEmpty == true,
            orElse: () => list.first,
          ) as Map<String, dynamic>;

          final lyrics =
              _parseLrclibResponse(bestMatch, song.id, rawTitle, rawArtist);
          if (lyrics != null && lyrics.isNotEmpty) {
            return lyrics;
          }
        }
      }
    } catch (e) {
      debugPrint('LRCLIB search error: $e');
    }

    return null;
  }

  /// Searches LRCLIB with a custom query and returns list of candidate songs
  Future<List<Map<String, dynamic>>> searchOnlineCandidates(String query) async {
    try {
      final response = await _dio.get(
        'https://lrclib.net/api/search',
        queryParameters: {'q': query.trim()},
      );

      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    } catch (e) {
      debugPrint('Error searching online candidates: $e');
    }
    return [];
  }

  /// Applies a chosen online candidate to a song and caches it
  Future<SongLyrics?> applyOnlineCandidate(
    SongModel song,
    Map<String, dynamic> candidateData,
  ) async {
    final editService = SongEditService();
    final lyrics = _parseLrclibResponse(
      candidateData,
      song.id,
      editService.getDisplayTitle(song),
      editService.getDisplayArtist(song),
    );

    if (lyrics != null) {
      _memoryCache[song.id] = lyrics;
      await _saveToDiskCache(lyrics);
      return lyrics;
    }
    return null;
  }

  /// Manually saves user-edited lyrics (plain or LRC)
  Future<SongLyrics> saveManualLyrics(
    SongModel song,
    String text,
  ) async {
    final editService = SongEditService();
    final title = editService.getDisplayTitle(song);
    final artist = editService.getDisplayArtist(song);

    final bool isLrcFormat =
        RegExp(r'\[\d{1,2}:\d{2}').hasMatch(text);

    final SongLyrics lyrics;
    if (isLrcFormat) {
      lyrics = SongLyrics.fromLrc(
        songId: song.id,
        title: title,
        artist: artist,
        lrcContent: text,
        source: 'manual',
      );
    } else {
      lyrics = SongLyrics.fromPlain(
        songId: song.id,
        title: title,
        artist: artist,
        plainText: text,
        source: 'manual',
      );
    }

    _memoryCache[song.id] = lyrics;
    await _saveToDiskCache(lyrics);
    return lyrics;
  }

  /// Deletes cached lyrics for a song
  Future<void> deleteLyrics(int songId) async {
    _memoryCache.remove(songId);
    try {
      final file = await _getCacheFile(songId);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // Internal Helpers
  // -------------------------------------------------------------

  SongLyrics? _parseLrclibResponse(
    Map<String, dynamic> data,
    int songId,
    String defaultTitle,
    String defaultArtist,
  ) {
    final synced = data['syncedLyrics'] as String?;
    final plain = data['plainLyrics'] as String?;

    if (synced != null && synced.trim().isNotEmpty) {
      return SongLyrics.fromLrc(
        songId: songId,
        title: defaultTitle,
        artist: defaultArtist,
        lrcContent: synced,
        source: 'online_lrclib',
      );
    } else if (plain != null && plain.trim().isNotEmpty) {
      return SongLyrics.fromPlain(
        songId: songId,
        title: defaultTitle,
        artist: defaultArtist,
        plainText: plain,
        source: 'online_lrclib',
      );
    }
    return null;
  }

  Future<SongLyrics?> _checkAdjacentLocalFile(SongModel song) async {
    try {
      final songPath = song.data;
      if (songPath.isEmpty) return null;

      final lrcPath =
          songPath.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '.lrc');
      final lrcFile = File(lrcPath);
      if (await lrcFile.exists()) {
        final content = await lrcFile.readAsString();
        if (content.trim().isNotEmpty) {
          final editService = SongEditService();
          return SongLyrics.fromLrc(
            songId: song.id,
            title: editService.getDisplayTitle(song),
            artist: editService.getDisplayArtist(song),
            lrcContent: content,
            source: 'local_lrc',
          );
        }
      }

      final txtPath =
          songPath.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '.txt');
      final txtFile = File(txtPath);
      if (await txtFile.exists()) {
        final content = await txtFile.readAsString();
        if (content.trim().isNotEmpty) {
          final editService = SongEditService();
          return SongLyrics.fromPlain(
            songId: song.id,
            title: editService.getDisplayTitle(song),
            artist: editService.getDisplayArtist(song),
            plainText: content,
            source: 'local_txt',
          );
        }
      }
    } catch (_) {}
    return null;
  }

  Future<File> _getCacheFile(int songId) async {
    final dir = await getApplicationDocumentsDirectory();
    final lyricsDir = Directory('${dir.path}/lyrics');
    if (!await lyricsDir.exists()) {
      await lyricsDir.create(recursive: true);
    }
    return File('${lyricsDir.path}/$songId.json');
  }

  Future<SongLyrics?> _loadFromDiskCache(int songId) async {
    try {
      final file = await _getCacheFile(songId);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final Map<String, dynamic> json = jsonDecode(content);
          return SongLyrics.fromJson(json);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveToDiskCache(SongLyrics lyrics) async {
    try {
      final file = await _getCacheFile(lyrics.songId);
      await file.writeAsString(jsonEncode(lyrics.toJson()));
    } catch (_) {}
  }

  String _cleanSongTitle(String title) {
    var clean = title.trim();
    // Remove file extension if present
    clean = clean.replaceAll(RegExp(r'\.(mp3|m4a|flac|wav|aac|ogg)$', caseSensitive: false), '');
    // Remove unwanted typical music tags in brackets or parenthesis
    clean = clean.replaceAll(
        RegExp(
            r'\[(Official|Music|Video|Lyrics?|Audio|HD|4K|Remastered|Clip|Visualizer|Prod\..*?)\]',
            caseSensitive: false),
        '');
    clean = clean.replaceAll(
        RegExp(
            r'\((Official|Music|Video|Lyrics?|Audio|HD|4K|Remastered|Clip|Visualizer|320\s?kbps|Original.*?)\)',
            caseSensitive: false),
        '');
    // Remove trailing dashes or spaces
    clean = clean.replaceAll(RegExp(r'[\-_\|]+$'), '').trim();
    return clean;
  }

  String _cleanArtistName(String artist) {
    final a = artist.trim();
    if (a.isEmpty ||
        a.toLowerCase() == '<unknown>' ||
        a.toLowerCase() == 'unknown' ||
        a.toLowerCase() == 'unknown artist') {
      return '';
    }
    return a;
  }
}
