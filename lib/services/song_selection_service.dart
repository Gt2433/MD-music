import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';

class SongSelectionService extends ChangeNotifier {
  static final SongSelectionService _instance = SongSelectionService._internal();
  factory SongSelectionService() => _instance;
  SongSelectionService._internal();

  final Map<int, SongModel> _selectedSongs = {};

  bool get isSelectionMode => _selectedSongs.isNotEmpty;
  int get selectedCount => _selectedSongs.length;
  List<SongModel> get selectedSongs => _selectedSongs.values.toList();
  List<int> get selectedIds => _selectedSongs.keys.toList();

  bool isSelected(int songId) => _selectedSongs.containsKey(songId);

  /// Returns 1-based sequential order of selection, or 0 if not selected.
  int getSelectionOrder(int songId) {
    final keys = _selectedSongs.keys.toList();
    final idx = keys.indexOf(songId);
    return idx >= 0 ? idx + 1 : 0;
  }

  void startSelection(SongModel song) {
    if (!_selectedSongs.containsKey(song.id)) {
      _selectedSongs[song.id] = song;
      notifyListeners();
    }
  }

  void toggleSelection(SongModel song) {
    if (_selectedSongs.containsKey(song.id)) {
      _selectedSongs.remove(song.id);
    } else {
      _selectedSongs[song.id] = song;
    }
    notifyListeners();
  }

  bool areAllSelected(List<SongModel> songs) {
    if (songs.isEmpty) return false;
    return songs.every((s) => _selectedSongs.containsKey(s.id));
  }

  void selectAll(List<SongModel> songs) {
    for (final song in songs) {
      _selectedSongs[song.id] = song;
    }
    notifyListeners();
  }

  void toggleSelectAll(List<SongModel> songs) {
    if (areAllSelected(songs)) {
      clearSelection();
    } else {
      selectAll(songs);
    }
  }

  void clearSelection() {
    if (_selectedSongs.isNotEmpty) {
      _selectedSongs.clear();
      notifyListeners();
    }
  }
}
