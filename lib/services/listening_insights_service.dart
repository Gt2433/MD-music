import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'audio_service.dart';
import 'language_service.dart';

class ListeningInsightsService extends ChangeNotifier {
  static final ListeningInsightsService _instance = ListeningInsightsService._internal();
  factory ListeningInsightsService() => _instance;
  ListeningInsightsService._internal();

  static const String _fileName = 'listening_insights_data_v1.json';

  int _totalListenSeconds = 0;
  Map<int, int> _songPlayCounts = {};
  Map<int, int> _songSeconds = {};
  Map<String, int> _artistPlayCounts = {};
  DateTime _firstListenDate = DateTime.now();

  // Active tracking state
  Timer? _tickerTimer;
  int? _currentTrackingSongId;
  int _currentSongElapsedSeconds = 0;
  bool _currentSongCountCredited = false;

  int get totalListenSeconds => _totalListenSeconds;
  Map<int, int> get songPlayCounts => Map.unmodifiable(_songPlayCounts);
  DateTime get firstListenDate => _firstListenDate;

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> init() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final Map<String, dynamic> data = jsonDecode(content);
          _totalListenSeconds = (data['totalListenSeconds'] as num?)?.toInt() ?? 0;

          if (data['songPlayCounts'] is Map) {
            final Map<String, dynamic> counts = data['songPlayCounts'];
            _songPlayCounts = counts.map((k, v) => MapEntry(int.parse(k), (v as num).toInt()));
          }

          if (data['songSeconds'] is Map) {
            final Map<String, dynamic> secs = data['songSeconds'];
            _songSeconds = secs.map((k, v) => MapEntry(int.parse(k), (v as num).toInt()));
          }

          if (data['artistPlayCounts'] is Map) {
            final Map<String, dynamic> artists = data['artistPlayCounts'];
            _artistPlayCounts = artists.map((k, v) => MapEntry(k, (v as num).toInt()));
          }

          if (data['firstListenDate'] != null) {
            _firstListenDate = DateTime.tryParse(data['firstListenDate']) ?? DateTime.now();
          }
        }
      }

      _startPlaybackTracking();
    } catch (e) {
      debugPrint('ListeningInsightsService init error: $e');
    }
  }

  void _startPlaybackTracking() {
    final audio = AudioService();

    // 1-second ticker while playing
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (audio.player.playing) {
        final song = audio.currentSong;
        if (song != null) {
          if (_currentTrackingSongId != song.id) {
            _currentTrackingSongId = song.id;
            _currentSongElapsedSeconds = 0;
            _currentSongCountCredited = false;
          }

          _totalListenSeconds++;
          _currentSongElapsedSeconds++;
          _songSeconds[song.id] = (_songSeconds[song.id] ?? 0) + 1;

          // After 20 seconds of continuous listen, credit 1 full play!
          if (!_currentSongCountCredited && _currentSongElapsedSeconds >= 20) {
            _currentSongCountCredited = true;
            _creditPlay(song);
          }

          // Save every 60 seconds
          if (_totalListenSeconds % 60 == 0) {
            _saveToFile();
          }
        }
      }
    });

    audio.player.currentIndexStream.listen((index) {
      _currentSongElapsedSeconds = 0;
      _currentSongCountCredited = false;
      _currentTrackingSongId = audio.currentSong?.id;
    });
  }

  void _creditPlay(SongModel song) {
    _songPlayCounts[song.id] = (_songPlayCounts[song.id] ?? 0) + 1;

    final artist = (song.artist ?? '').trim();
    if (artist.isNotEmpty && artist.toLowerCase() != '<unknown>') {
      _artistPlayCounts[artist] = (_artistPlayCounts[artist] ?? 0) + 1;
    }

    _saveToFile();
    notifyListeners();
  }

  List<SongModel> getTopSongs(List<SongModel> allSongs, {int limit = 10}) {
    final availableMap = {for (var s in allSongs) s.id: s};
    final sortedEntries = _songPlayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final result = <SongModel>[];
    for (final entry in sortedEntries) {
      final song = availableMap[entry.key];
      if (song != null) {
        result.add(song);
        if (result.length >= limit) break;
      }
    }
    return result;
  }

  List<MapEntry<String, int>> getTopArtists({int limit = 5}) {
    final sorted = _artistPlayCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  int getPlayCount(int songId) {
    return _songPlayCounts[songId] ?? 0;
  }

  String getFormattedTotalTime([bool? isArabic]) {
    final totalMins = _totalListenSeconds ~/ 60;
    final hours = totalMins ~/ 60;
    final mins = totalMins % 60;

    if (hours > 0) {
      return LanguageService()
          .t('insights_time_hours_mins')
          .replaceAll('{hours}', '$hours')
          .replaceAll('{mins}', '$mins');
    }
    return LanguageService()
        .t('insights_time_mins')
        .replaceAll('{mins}', '$mins');
  }

  Future<void> _saveToFile() async {
    try {
      final file = await _getFile();
      final data = {
        'totalListenSeconds': _totalListenSeconds,
        'songPlayCounts': _songPlayCounts.map((k, v) => MapEntry(k.toString(), v)),
        'songSeconds': _songSeconds.map((k, v) => MapEntry(k.toString(), v)),
        'artistPlayCounts': _artistPlayCounts,
        'firstListenDate': _firstListenDate.toIso8601String(),
      };
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('Error saving listening insights: $e');
    }
  }

  Future<void> resetStats() async {
    _totalListenSeconds = 0;
    _songPlayCounts.clear();
    _songSeconds.clear();
    _artistPlayCounts.clear();
    _firstListenDate = DateTime.now();
    await _saveToFile();
    notifyListeners();
  }
}
