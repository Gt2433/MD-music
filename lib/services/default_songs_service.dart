import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

class _DefaultSongEntry {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String assetAudio;
  final String assetCover;
  final String audioFileName;
  final String coverFileName;
  final int durationMs;
  final int fileSize;
  final int dateAdded;

  const _DefaultSongEntry({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.assetAudio,
    required this.assetCover,
    required this.audioFileName,
    required this.coverFileName,
    required this.durationMs,
    required this.fileSize,
    required this.dateAdded,
  });
}

class DefaultSongsService extends ChangeNotifier {
  static final DefaultSongsService _instance = DefaultSongsService._internal();
  factory DefaultSongsService() => _instance;
  DefaultSongsService._internal();

  static const List<_DefaultSongEntry> _entries = [
    _DefaultSongEntry(
      id: -1001,
      title: 'Apex Motion (Infinity)',
      artist: 'MD Music',
      album: 'MD Originals',
      assetAudio: 'assets/default_songs/apex_motion.mp3',
      assetCover: 'assets/default_songs/apex_motion.jpg',
      audioFileName: 'apex_motion.mp3',
      coverFileName: 'apex_motion.jpg',
      durationMs: 83000,
      fileSize: 1998536,
      dateAdded: 1710000003,
    ),
    _DefaultSongEntry(
      id: -1002,
      title: 'Carbon Geometry (Midnight Pulse)',
      artist: 'MD Music',
      album: 'MD Originals',
      assetAudio: 'assets/default_songs/carbon_geometry.mp3',
      assetCover: 'assets/default_songs/carbon_geometry.jpg',
      audioFileName: 'carbon_geometry.mp3',
      coverFileName: 'carbon_geometry.jpg',
      durationMs: 94000,
      fileSize: 2266866,
      dateAdded: 1710000002,
    ),
    _DefaultSongEntry(
      id: -1003,
      title: 'A Graceful Departure (Serenity)',
      artist: 'MD Music',
      album: 'MD Originals',
      assetAudio: 'assets/default_songs/graceful_departure.mp3',
      assetCover: 'assets/default_songs/graceful_departure.jpg',
      audioFileName: 'graceful_departure.mp3',
      coverFileName: 'graceful_departure.jpg',
      durationMs: 88000,
      fileSize: 2125805,
      dateAdded: 1710000001,
    ),
  ];

  final List<SongModel> _defaultSongs = [];
  final Map<int, String> _coverPaths = {};
  bool _isInitialized = false;

  List<SongModel> get defaultSongs => List.unmodifiable(_defaultSongs);
  bool get isInitialized => _isInitialized;

  String? getCoverPath(int songId) => _coverPaths[songId];
  bool isDefaultSong(int songId) => songId <= -1000;

  Future<void> init() async {
    if (_isInitialized && _defaultSongs.isNotEmpty) return;

    if (kIsWeb) {
      _defaultSongs.clear();
      _coverPaths.clear();
      for (final entry in _entries) {
        _coverPaths[entry.id] = entry.assetCover;
        final songMap = <dynamic, dynamic>{
          '_id': entry.id,
          '_data': entry.assetAudio,
          '_uri': entry.assetAudio,
          '_display_name': '${entry.title}.mp3',
          '_display_name_wo_ext': entry.title,
          '_size': entry.fileSize,
          'title': entry.title,
          'artist': entry.artist,
          'album': entry.album,
          'duration': entry.durationMs,
          'date_added': entry.dateAdded,
          'file_extension': 'mp3',
          'is_music': true,
        };
        _defaultSongs.add(SongModel(songMap));
      }
      _isInitialized = true;
      notifyListeners();
      return;
    }

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory('${docDir.path}/default_songs');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      _defaultSongs.clear();
      _coverPaths.clear();

      for (final entry in _entries) {
        final audioFile = File('${targetDir.path}/${entry.audioFileName}');
        final coverFile = File('${targetDir.path}/${entry.coverFileName}');

        // 1. Extract audio file from asset bundle if not on disk
        if (!await audioFile.exists() || (await audioFile.length()) == 0) {
          try {
            final byteData = await rootBundle.load(entry.assetAudio);
            await audioFile.writeAsBytes(
              byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
              flush: true,
            );
          } catch (e) {
            debugPrint('Error unpacking default audio ${entry.assetAudio}: $e');
          }
        }

        // 2. Extract cover image from asset bundle if not on disk
        if (!await coverFile.exists() || (await coverFile.length()) == 0) {
          try {
            final byteData = await rootBundle.load(entry.assetCover);
            await coverFile.writeAsBytes(
              byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
              flush: true,
            );
          } catch (e) {
            debugPrint('Error unpacking default cover ${entry.assetCover}: $e');
          }
        }

        if (await coverFile.exists()) {
          _coverPaths[entry.id] = coverFile.path;
        }

        final finalAudioPath = audioFile.path;
        final finalAudioUri = audioFile.uri.toString();
        final actualSize = (await audioFile.exists()) ? await audioFile.length() : entry.fileSize;

        final songMap = <dynamic, dynamic>{
          '_id': entry.id,
          '_data': finalAudioPath,
          '_uri': finalAudioUri,
          '_display_name': '${entry.title}.mp3',
          '_display_name_wo_ext': entry.title,
          '_size': actualSize,
          'title': entry.title,
          'artist': entry.artist,
          'album': entry.album,
          'duration': entry.durationMs,
          'date_added': entry.dateAdded,
          'file_extension': 'mp3',
          'is_music': true,
        };

        _defaultSongs.add(SongModel(songMap));
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing DefaultSongsService: $e');
    }
  }
}

