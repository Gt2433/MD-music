import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

class CustomAlbum {
  final String id;
  String name;
  final List<int> songIds;
  final DateTime createdAt;
  String? customArtworkPath;

  CustomAlbum({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
    this.customArtworkPath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'songIds': songIds,
    'createdAt': createdAt.toIso8601String(),
    'customArtworkPath': customArtworkPath,
  };

  factory CustomAlbum.fromJson(Map<String, dynamic> json) {
    return CustomAlbum(
      id: json['id'] as String,
      name: json['name'] as String,
      songIds: (json['songIds'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      customArtworkPath: json['customArtworkPath'] as String?,
    );
  }
}

class AlbumService extends ChangeNotifier {
  static final AlbumService _instance = AlbumService._internal();
  factory AlbumService() => _instance;
  AlbumService._internal();

  final List<CustomAlbum> _albums = [];
  bool _initialized = false;

  List<CustomAlbum> get albums => List.unmodifiable(_albums);

  Future<void> init() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/custom_albums.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final dynamic decoded = jsonDecode(content);
        if (decoded is List) {
          _albums.clear();
          for (var item in decoded) {
            if (item is Map<String, dynamic>) {
              _albums.add(CustomAlbum.fromJson(item));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading custom albums: $e');
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/custom_albums.json');
      final data = jsonEncode(_albums.map((a) => a.toJson()).toList());
      await file.writeAsString(data);
    } catch (e) {
      debugPrint('Error saving custom albums: $e');
    }
    notifyListeners();
  }

  Future<CustomAlbum> createAlbum(String name, {List<int>? songIds}) async {
    final album = CustomAlbum(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'ألبوم جديد' : name.trim(),
      songIds: songIds != null ? List.from(songIds) : [],
      createdAt: DateTime.now(),
    );
    _albums.insert(0, album);
    await _save();
    return album;
  }

  Future<void> deleteAlbum(String albumId) async {
    _albums.removeWhere((a) => a.id == albumId);
    await _save();
  }

  Future<void> renameAlbum(String albumId, String newName) async {
    final idx = _albums.indexWhere((a) => a.id == albumId);
    if (idx != -1 && newName.trim().isNotEmpty) {
      _albums[idx].name = newName.trim();
      await _save();
    }
  }

  Future<void> addSongsToAlbum(String albumId, List<int> ids) async {
    final idx = _albums.indexWhere((a) => a.id == albumId);
    if (idx != -1) {
      for (final id in ids) {
        if (!_albums[idx].songIds.contains(id)) {
          _albums[idx].songIds.add(id);
        }
      }
      await _save();
    }
  }

  Future<void> addSongToAlbum(String albumId, int songId) async {
    await addSongsToAlbum(albumId, [songId]);
  }

  Future<void> removeSongFromAlbum(String albumId, int songId) async {
    final idx = _albums.indexWhere((a) => a.id == albumId);
    if (idx != -1) {
      _albums[idx].songIds.remove(songId);
      await _save();
    }
  }

  List<SongModel> getSongsForAlbum(String albumId, List<SongModel> allSongs) {
    final idx = _albums.indexWhere((a) => a.id == albumId);
    if (idx == -1) return [];
    final songMap = {for (final s in allSongs) s.id: s};
    final List<SongModel> result = [];
    for (final id in _albums[idx].songIds) {
      final s = songMap[id];
      if (s != null) result.add(s);
    }
    return result;
  }

  bool isSongInAlbum(String albumId, int songId) {
    final idx = _albums.indexWhere((a) => a.id == albumId);
    if (idx == -1) return false;
    return _albums[idx].songIds.contains(songId);
  }

  Future<bool> toggleSongInAlbum(String albumId, int songId) async {
    final idx = _albums.indexWhere((a) => a.id == albumId);
    if (idx != -1) {
      final exists = _albums[idx].songIds.contains(songId);
      if (exists) {
        _albums[idx].songIds.remove(songId);
      } else {
        _albums[idx].songIds.add(songId);
      }
      await _save();
      return !exists;
    }
    return false;
  }

  Future<void> setAlbumSongs(String albumId, List<int> songIds) async {
    final idx = _albums.indexWhere((a) => a.id == albumId);
    if (idx != -1) {
      _albums[idx].songIds.clear();
      _albums[idx].songIds.addAll(songIds);
      await _save();
    }
  }

  Future<void> setAlbumArtwork(String albumId, String? imagePath) async {
    final idx = _albums.indexWhere((a) => a.id == albumId);
    if (idx != -1) {
      _albums[idx].customArtworkPath = imagePath;
      await _save();
    }
  }

  Future<void> reorderAlbumSongs(String albumId, int oldIndex, int newIndex) async {
    final idx = _albums.indexWhere((a) => a.id == albumId);
    if (idx != -1) {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      if (oldIndex >= 0 && oldIndex < _albums[idx].songIds.length &&
          newIndex >= 0 && newIndex < _albums[idx].songIds.length) {
        final item = _albums[idx].songIds.removeAt(oldIndex);
        _albums[idx].songIds.insert(newIndex, item);
        await _save();
      }
    }
  }
}
