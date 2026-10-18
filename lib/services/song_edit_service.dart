import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'audio_service.dart';
import 'language_service.dart';

class SongEditInfo {
  final int songId;
  String title;
  String artist;
  String? customArtPath;
  int trimStartMs;
  int? trimEndMs;
  bool isTrimmed;
  String? originalBackupPath;

  SongEditInfo({
    required this.songId,
    required this.title,
    required this.artist,
    this.customArtPath,
    this.trimStartMs = 0,
    this.trimEndMs,
    this.isTrimmed = false,
    this.originalBackupPath,
  });

  Map<String, dynamic> toJson() => {
        'songId': songId,
        'title': title,
        'artist': artist,
        'customArtPath': customArtPath,
        'trimStartMs': trimStartMs,
        'trimEndMs': trimEndMs,
        'isTrimmed': isTrimmed,
        'originalBackupPath': originalBackupPath,
      };

  factory SongEditInfo.fromJson(Map<String, dynamic> json) => SongEditInfo(
        songId: json['songId'] as int,
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String? ?? '',
        customArtPath: json['customArtPath'] as String?,
        trimStartMs: json['trimStartMs'] as int? ?? 0,
        trimEndMs: json['trimEndMs'] as int?,
        isTrimmed: json['isTrimmed'] as bool? ?? false,
        originalBackupPath: json['originalBackupPath'] as String?,
      );
}

class SongEditService extends ChangeNotifier {
  static final SongEditService _instance = SongEditService._internal();
  factory SongEditService() => _instance;
  SongEditService._internal() {
    _loadEdits();
  }

  static const MethodChannel _platformChannel = MethodChannel('com.mbd.music/artwork');
  final Map<int, SongEditInfo> _edits = {};
  final Set<String> _customArtists = {};

  Map<int, SongEditInfo> get edits => _edits;
  Set<String> get customArtists => _customArtists;

  Future<File> _getStorageFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/song_edits.json');
  }

  Future<void> _loadEdits() async {
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);
        data.forEach((key, val) {
          if (key == 'custom_artists') {
            final list = (val as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
            _customArtists.addAll(list);
          } else {
            final id = int.tryParse(key);
            if (id != null) {
              _edits[id] = SongEditInfo.fromJson(Map<String, dynamic>.from(val));
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading song edits: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> _saveEdits() async {
    try {
      final file = await _getStorageFile();
      final Map<String, dynamic> data = {};
      _edits.forEach((id, edit) {
        data[id.toString()] = edit.toJson();
      });
      data['custom_artists'] = _customArtists.toList();
      await file.writeAsString(jsonEncode(data));
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving song edits: $e');
    }
  }

  Future<void> addCustomArtist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _customArtists.add(trimmed);
    await _saveEdits();
    notifyListeners();
  }

  Future<List<double>> getAudioWaveform(SongModel song, {int samples = 100}) async {
    try {
      final pathOrUri = (song.data.isNotEmpty && File(song.data).existsSync())
          ? song.data
          : (song.uri ?? song.data);

      final res = await _platformChannel.invokeMethod<List<dynamic>>('extractWaveform', {
        'path': pathOrUri,
        'samples': samples,
      });

      if (res != null && res.isNotEmpty) {
        final list = res.map((e) => (e as num).toDouble()).toList();
        if (list.length >= samples && list.any((v) => v > 0.15)) {
          return list;
        }
      }
    } catch (e) {
      debugPrint('Error getting waveform from native: $e');
    }

    return _generateRealisticWaveform(song, samples);
  }

  List<double> _generateRealisticWaveform(SongModel song, int samples) {
    final seed = (song.id * 37 + (song.duration ?? 180000)).abs();
    final list = <double>[];
    for (int i = 0; i < samples; i++) {
      final t = i / samples.toDouble();
      final harmonic1 = 0.5 * (1 + math.sin(t * math.pi * 3));
      final harmonic2 = 0.3 * (1 + math.sin(t * math.pi * 9 + (seed % 7)));
      final harmonic3 = 0.2 * (1 + math.cos(t * math.pi * 17 + (seed % 11)));
      final noise = (((seed * (i + 19)) % 100) / 100.0) * 0.22;
      final val = 0.1 + (harmonic1 * 0.38) + (harmonic2 * 0.25) + (harmonic3 * 0.15) + noise;
      list.add(val.clamp(0.1, 1.0));
    }
    return list;
  }

  SongEditInfo? getEditInfo(int songId) => _edits[songId];

  String getDisplayTitle(SongModel song) {
    return _edits[song.id]?.title.isNotEmpty == true ? _edits[song.id]!.title : song.title;
  }

  String getDisplayArtist(SongModel song) {
    return _edits[song.id]?.artist.isNotEmpty == true
        ? _edits[song.id]!.artist
        : (song.artist ?? LanguageService.tr('unknown_artist'));
  }

  String? getCustomArtworkPath(int songId) {
    return _edits[songId]?.customArtPath;
  }

  bool isSongEditedOrTrimmed(int songId) {
    final info = _edits[songId];
    if (info == null) return false;
    return info.isTrimmed ||
        info.customArtPath != null ||
        info.title.isNotEmpty ||
        info.artist.isNotEmpty;
  }

  Future<bool> saveSongEdits({
    required SongModel song,
    required String newTitle,
    required String newArtist,
    String? newArtworkPath,
    int startMs = 0,
    int endMs = 0,
    bool applyTrim = false,
  }) async {
    try {
      final info = _edits[song.id] ??
          SongEditInfo(
            songId: song.id,
            title: song.title,
            artist: song.artist ?? '',
          );

      info.title = newTitle.trim().isNotEmpty ? newTitle.trim() : song.title;
      info.artist = newArtist.trim().isNotEmpty ? newArtist.trim() : (song.artist ?? '');

      if (newArtworkPath != null && newArtworkPath.isNotEmpty) {
        info.customArtPath = newArtworkPath;
        try {
          final artFile = File(newArtworkPath);
          if (await artFile.exists()) {
            final bytes = await artFile.readAsBytes();
            AudioService().updateArtworkCache(song.id, bytes);
          }
        } catch (_) {}
      }

      if (applyTrim) {
        info.trimStartMs = startMs;
        info.trimEndMs = endMs;
        info.isTrimmed = true;

        // Perform actual trimming
        final srcFile = File(song.data);
        if (await srcFile.exists()) {
          final tempDir = await getTemporaryDirectory();
          final ext = song.data.split('.').last;
          final backupPath = '${tempDir.path}/backup_${song.id}.$ext';
          final backupFile = File(backupPath);
          if (!await backupFile.exists()) {
            await srcFile.copy(backupPath);
            info.originalBackupPath = backupPath;
          }

          final trimmedTempPath = '${tempDir.path}/trimmed_${song.id}.$ext';
          final trimmed = await _platformChannel.invokeMethod<bool>('trimAudio', {
            'src': backupPath,
            'dst': trimmedTempPath,
            'startMs': startMs,
            'endMs': endMs,
          });

          if (trimmed == true && await File(trimmedTempPath).exists()) {
            await File(trimmedTempPath).copy(song.data);
          }
        }
      }

      _edits[song.id] = info;
      await _saveEdits();
      await AudioService().loadSongs();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving song edits: $e');
      return false;
    }
  }

  Future<bool> revertToOriginal(SongModel song) async {
    try {
      final info = _edits[song.id];
      if (info != null) {
        // Restore original audio file if backup exists
        if (info.originalBackupPath != null) {
          final backupFile = File(info.originalBackupPath!);
          if (await backupFile.exists()) {
            await backupFile.copy(song.data);
          }
        }
        _edits.remove(song.id);
        AudioService().updateArtworkCache(song.id, null);
        await _saveEdits();
        await AudioService().loadSongs();
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error reverting song: $e');
    }
    return false;
  }

  Future<String> setAsRingtone(String filePath) async {
    try {
      final res = await _platformChannel.invokeMethod<String>('setAsRingtone', {'path': filePath});
      return res ?? 'error';
    } catch (e) {
      debugPrint('Error setting ringtone: $e');
      return 'error: $e';
    }
  }

  Future<bool> moveToTrash(SongModel song) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final trashDir = Directory('${docDir.path}/trash');
      if (!await trashDir.exists()) {
        await trashDir.create(recursive: true);
      }

      final file = File(song.data);
      if (await file.exists()) {
        final filename = song.data.split('/').last.split('\\').last;
        final targetPath = '${trashDir.path}/${song.id}_$filename';
        await file.rename(targetPath);
      }

      // If playing this song, stop or next
      final audio = AudioService();
      if (audio.currentSong?.id == song.id) {
        await audio.player.stop();
      }

      audio.allSongs.removeWhere((s) => s.id == song.id);
      audio.currentPlaylist.removeWhere((s) => s.id == song.id);
      _edits.remove(song.id);
      await _saveEdits();
      await audio.loadSongs();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error moving to trash: $e');
      return false;
    }
  }

  Future<bool> deletePermanently(SongModel song) async {
    _edits.remove(song.id);
    await _saveEdits();
    final ok = await AudioService().deleteSong(song);
    notifyListeners();
    return ok;
  }

  Future<int> deleteMultiplePermanently(List<SongModel> songs) async {
    for (final song in songs) {
      _edits.remove(song.id);
    }
    await _saveEdits();
    final count = await AudioService().deleteMultipleSongs(songs);
    notifyListeners();
    return count;
  }
}
