import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';
import 'song_edit_service.dart';

class AudioService extends ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    _loadDeletedSongs();
    _initPlayer();
    _initAudioSession();
  }

  static final AndroidEqualizer _equalizer = AndroidEqualizer();
  static final AndroidLoudnessEnhancer _loudnessEnhancer = AndroidLoudnessEnhancer();
  static final AudioPipeline _pipeline = AudioPipeline(
    androidAudioEffects: [
      _equalizer,
      _loudnessEnhancer,
    ],
  );

  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _player = AudioPlayer(audioPipeline: _pipeline);

  OnAudioQuery get audioQuery => _audioQuery;
  AudioPlayer get player => _player;
  AndroidEqualizer get equalizer => _equalizer;
  AndroidLoudnessEnhancer get loudnessEnhancer => _loudnessEnhancer;

  List<SongModel> _allSongs = [];
  List<SongModel> _currentPlaylist = [];
  List<SongModel> _originalPlaylist = [];
  final List<SongModel> _recentlyPlayed = [];
  final Set<int> _favoriteIds = {};
  final Set<int> _deletedSongIds = {};
  ConcatenatingAudioSource? _playlistSource;

  bool _isSamePlaylistAs(List<SongModel> list) {
    if (_playlistSource == null || _player.audioSource == null) return false;
    if (_currentPlaylist.length != list.length) return false;
    for (int i = 0; i < list.length; i++) {
      if (_currentPlaylist[i].id != list[i].id) return false;
    }
    return true;
  }

  List<SongModel> get allSongs => _allSongs;
  List<SongModel> get currentPlaylist => _currentPlaylist;
  List<SongModel> get originalPlaylist => _originalPlaylist;
  List<SongModel> get recentlyPlayed => _recentlyPlayed;
  Set<int> get favoriteIds => _favoriteIds;
  Set<int> get deletedSongIds => _deletedSongIds;

  SongModel? _currentSong;
  SongModel? get currentSong => _currentSong;

  int _currentIndex = -1;
  int get currentIndex => _currentIndex;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasPermission = false;
  bool get hasPermission => _hasPermission;

  bool _isShuffle = false;
  bool get isShuffle => _isShuffle;

  LoopMode _loopMode = LoopMode.off;
  LoopMode get loopMode => _loopMode;

  bool _isTemporarySelectedQueue = false;
  bool get isTemporarySelectedQueue => _isTemporarySelectedQueue;

  double _playbackSpeed = 1.0;
  bool _linkPitchToSpeed = false;

  double get playbackSpeed => _playbackSpeed;
  bool get linkPitchToSpeed => _linkPitchToSpeed;

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = double.parse(speed.clamp(0.1, 3.0).toStringAsFixed(2));
    try {
      await _player.setSpeed(_playbackSpeed);
      await _applyPitch();
    } catch (e) {
      debugPrint('Error setting playback speed: $e');
    }
    notifyListeners();
  }

  Future<void> setLinkPitchToSpeed(bool link) async {
    _linkPitchToSpeed = link;
    await _applyPitch();
    notifyListeners();
  }

  String _currentEffect = 'none';
  String get currentEffect => _currentEffect;

  Future<void> applyAudioEffect(String effectId) async {
    _currentEffect = effectId;
    try {
      if (effectId == 'deep_echo') {
        // Deep Echo effect: deep baritone pitch (0.91)
        await _player.setPitch(0.91);

        if (Platform.isAndroid) {
          try {
            await _equalizer.setEnabled(true);
            final params = await _equalizer.parameters;
            for (final band in params.bands) {
              if (band.centerFrequency < 250) {
                // Boost deep bass (+7.0 dB)
                await band.setGain(7.0);
              } else if (band.centerFrequency < 1000) {
                // Warm lower mids (+2.0 dB)
                await band.setGain(2.0);
              } else if (band.centerFrequency > 4000) {
                // Cavernous high-frequency softness (-2.0 dB)
                await band.setGain(-2.0);
              } else {
                await band.setGain(0.0);
              }
            }
            await _loudnessEnhancer.setEnabled(true);
            await _loudnessEnhancer.setTargetGain(1.2);
          } catch (e) {
            debugPrint('Equalizer hardware effect not available: $e');
          }
        }
      } else {
        // 'none' - restore natural audio
        if (Platform.isAndroid) {
          try {
            await _equalizer.setEnabled(false);
            await _loudnessEnhancer.setEnabled(false);
          } catch (_) {}
        }
        await _applyPitch();
      }
    } catch (e) {
      debugPrint('Error applying audio effect: $e');
    }
    notifyListeners();
  }

  Future<void> _applyPitch() async {
    try {
      if (_currentEffect == 'deep_echo') {
        await _player.setPitch(0.91);
      } else {
        final targetPitch = _linkPitchToSpeed ? _playbackSpeed : 1.0;
        await _player.setPitch(targetPitch);
      }
    } catch (e) {
      debugPrint('Error setting pitch: $e');
    }
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      session.becomingNoisyEventStream.listen((_) {
        if (_player.playing) {
          _player.pause();
        }
      });
    } catch (e) {
      debugPrint('AudioSession init error: $e');
    }
  }

  Future<void> _saveLastPlaybackState(Duration pos) async {
    if (_currentSong != null) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/last_playback_state.json');
        await file.writeAsString(jsonEncode({
          'songId': _currentSong!.id,
          'positionMs': pos.inMilliseconds,
        }));
      } catch (_) {}
    }
  }

  void _recordRecentlyPlayed(SongModel song) {
    _recentlyPlayed.removeWhere((s) => s.id == song.id);
    _recentlyPlayed.insert(0, song);
    if (_recentlyPlayed.length > 15) {
      _recentlyPlayed.removeLast();
    }
  }

  void _initPlayer() {
    // Synchronize current song when player advances or switches tracks
    // Priority: verify via source MediaItem tag (unique song ID) to prevent any index drift
    _player.sequenceStateStream.listen((sequenceState) {
      final currentSource = sequenceState.currentSource;
      final tag = currentSource?.tag;
      if (tag is MediaItem) {
        final songId = int.tryParse(tag.id);
        if (songId != null) {
          final matchedIdx = _currentPlaylist.indexWhere((s) => s.id == songId);
          if (matchedIdx != -1) {
            _currentIndex = matchedIdx;
            _currentSong = _currentPlaylist[matchedIdx];
            _recordRecentlyPlayed(_currentSong!);
            notifyListeners();
            _syncActiveSongMediaItem(_currentSong!);
            return;
          }
        }
      }

      final index = sequenceState.currentIndex;
      if (index != null && index >= 0 && index < _currentPlaylist.length) {
        _currentIndex = index;
        _currentSong = _currentPlaylist[index];
        _recordRecentlyPlayed(_currentSong!);
        notifyListeners();
        _syncActiveSongMediaItem(_currentSong!);
      }
    });

    // Player state (playing, buffering, completed)
    _player.playerStateStream.listen((state) {
      notifyListeners();
      if (state.processingState == ProcessingState.completed) {
        _handleTrackCompleted();
      }
    });

    // Position listener for last playback state tracking
    _player.positionStream.listen((pos) {
      _saveLastPlaybackState(pos);
    });

    _player.durationStream.listen((_) {
      notifyListeners();
    });
  }

  Future<bool> checkAndRequestPermissions() async {
    bool permissionGranted = false;

    if (Platform.isAndroid) {
      // 1. Request POST_NOTIFICATIONS (Android 13+)
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        await Permission.notification.request();
      }

      // 2. Request Audio / Storage
      final audioStatus = await Permission.audio.status;
      if (audioStatus.isGranted) {
        permissionGranted = true;
      } else {
        final storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) {
          permissionGranted = true;
        } else {
          // Request audio permission first (Android 13+)
          final audioReq = await Permission.audio.request();
          if (audioReq.isGranted) {
            permissionGranted = true;
          } else {
            // Fallback for Android 12 and below
            final storageReq = await Permission.storage.request();
            if (storageReq.isGranted) {
              permissionGranted = true;
            }
          }
        }
      }

      // Also ensure on_audio_query's internal check passes
      final queryStatus = await _audioQuery.permissionsStatus();
      if (!queryStatus && !permissionGranted) {
        permissionGranted = await _audioQuery.permissionsRequest();
      }
    } else {
      permissionGranted = true;
    }

    _hasPermission = permissionGranted;
    notifyListeners();

    if (_hasPermission) {
      await loadSongs();
    }

    return _hasPermission;
  }

  List<SongModel> _filterSongs(List<SongModel> songs) {
    return songs.where((s) => !_deletedSongIds.contains(s.id)).toList();
  }

  Future<Map<String, int>> rescanLibrary() async {
    _isLoading = true;
    notifyListeners();
    try {
      final oldCount = _allSongs.length;
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.DATE_ADDED,
        orderType: OrderType.DESC_OR_GREATER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      _allSongs = _filterSongs(songs);
      final added = (_allSongs.length - oldCount).clamp(0, 999999);
      final removed = (oldCount - _allSongs.length).clamp(0, 999999);
      return {'total': _allSongs.length, 'added': added, 'removed': removed};
    } catch (e) {
      debugPrint('Error rescanning library: $e');
      return {'total': _allSongs.length, 'added': 0, 'removed': 0};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSongs() async {
    _isLoading = true;
    notifyListeners();

    try {
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.DATE_ADDED,
        orderType: OrderType.DESC_OR_GREATER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      _allSongs = _filterSongs(songs);
    } catch (e) {
      debugPrint('Error loading songs: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Uri? _fallbackArtworkUriCache;

  Future<Uri?> _getFallbackArtworkUri() async {
    if (_fallbackArtworkUriCache != null) return _fallbackArtworkUriCache;
    try {
      final tempDir = await getTemporaryDirectory();
      final fallbackFile = File('${tempDir.path}/app_icon_art.png');
      if (await fallbackFile.exists() && await fallbackFile.length() > 0) {
        _fallbackArtworkUriCache = Uri.file(fallbackFile.path);
        return _fallbackArtworkUriCache;
      }
      final byteData = await rootBundle.load('assets/images/app_icon.png');
      await fallbackFile.writeAsBytes(byteData.buffer.asUint8List());
      _fallbackArtworkUriCache = Uri.file(fallbackFile.path);
      return _fallbackArtworkUriCache;
    } catch (e) {
      debugPrint('Error getting fallback artwork URI: $e');
      return null;
    }
  }

  static const MethodChannel _artworkChannel = MethodChannel('com.mbd.music/artwork');
  final Map<int, Uint8List?> _artworkBytesCache = {};

  void updateArtworkCache(int songId, Uint8List? bytes) {
    if (bytes != null) {
      _artworkBytesCache[songId] = bytes;
    } else {
      _artworkBytesCache.remove(songId);
    }
    notifyListeners();
  }

  Future<Uint8List?> getSongArtworkBytes(int songId, {String? filePath}) async {
    if (_artworkBytesCache.containsKey(songId) && _artworkBytesCache[songId] != null) {
      return _artworkBytesCache[songId];
    }

    // 0. Check custom artwork edited via SongEditService
    final customArt = SongEditService().getCustomArtworkPath(songId);
    if (customArt != null && File(customArt).existsSync()) {
      try {
        final bytes = await File(customArt).readAsBytes();
        if (bytes.isNotEmpty) {
          _artworkBytesCache[songId] = bytes;
          return bytes;
        }
      } catch (_) {}
    }

    // 1. Try to extract original embedded artwork directly from audio file
    String? path = filePath;
    if (path == null) {
      for (final s in _allSongs) {
        if (s.id == songId) {
          path = s.data;
          break;
        }
      }
    }

    if (path != null && path.isNotEmpty) {
      try {
        final dynamic rawBytes = await _artworkChannel.invokeMethod('getEmbeddedArtwork', {'path': path});
        if (rawBytes != null) {
          final Uint8List embeddedBytes = rawBytes is Uint8List ? rawBytes : Uint8List.fromList(List<int>.from(rawBytes));
          if (embeddedBytes.isNotEmpty) {
            _artworkBytesCache[songId] = embeddedBytes;
            try {
              final tempDir = await getTemporaryDirectory();
              final artFile = File('${tempDir.path}/artwork_$songId.jpg');
              await artFile.writeAsBytes(embeddedBytes, flush: true);
            } catch (_) {}
            return embeddedBytes;
          }
        }
      } catch (e) {
        debugPrint('Error getting embedded artwork from file $path: $e');
      }
    }

    // 2. Query MediaStore for ArtworkType.AUDIO with sizes [500, 300, 200]
    for (final size in [500, 300, 200]) {
      try {
        final bytes = await _audioQuery.queryArtwork(
          songId,
          ArtworkType.AUDIO,
          format: ArtworkFormat.JPEG,
          size: size,
          quality: 95,
        );
        if (bytes != null && bytes.isNotEmpty) {
          _artworkBytesCache[songId] = bytes;
          try {
            final tempDir = await getTemporaryDirectory();
            final artFile = File('${tempDir.path}/artwork_$songId.jpg');
            await artFile.writeAsBytes(bytes, flush: true);
          } catch (_) {}
          return bytes;
        }
      } catch (e) {
        debugPrint('Error querying audio artwork for ID $songId at size $size: $e');
      }
    }

    // 3. Fallback: Query MediaStore for ArtworkType.ALBUM using song's albumId
    SongModel? matchedSong;
    for (final s in _allSongs) {
      if (s.id == songId) {
        matchedSong = s;
        break;
      }
    }
    if (matchedSong?.albumId != null) {
      for (final size in [500, 300, 200]) {
        try {
          final bytes = await _audioQuery.queryArtwork(
            matchedSong!.albumId!,
            ArtworkType.ALBUM,
            format: ArtworkFormat.JPEG,
            size: size,
            quality: 95,
          );
          if (bytes != null && bytes.isNotEmpty) {
            _artworkBytesCache[songId] = bytes;
            try {
              final tempDir = await getTemporaryDirectory();
              final artFile = File('${tempDir.path}/artwork_$songId.jpg');
              await artFile.writeAsBytes(bytes, flush: true);
            } catch (_) {}
            return bytes;
          }
        } catch (_) {}
      }
    }

    return null;
  }

  final Map<int, Uri> _songArtworkUriCache = {};

  Future<Uri?> _getSongArtworkUri(SongModel song) async {
    // 0. Check custom artwork edited via SongEditService
    final customArt = SongEditService().getCustomArtworkPath(song.id);
    if (customArt != null && File(customArt).existsSync()) {
      final uri = Uri.file(customArt);
      _songArtworkUriCache[song.id] = uri;
      return uri;
    }

    if (_songArtworkUriCache.containsKey(song.id)) {
      final cachedUri = _songArtworkUriCache[song.id];
      if (cachedUri != null && !cachedUri.path.contains('app_icon_art')) {
        return cachedUri;
      }
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final artFile = File('${tempDir.path}/artwork_${song.id}.jpg');
      if (await artFile.exists() && (await artFile.length()) > 200) {
        final uri = Uri.file(artFile.path);
        _songArtworkUriCache[song.id] = uri;
        return uri;
      }

      final bytes = await getSongArtworkBytes(song.id, filePath: song.data);
      if (bytes != null && bytes.isNotEmpty) {
        await artFile.writeAsBytes(bytes, flush: true);
        final uri = Uri.file(artFile.path);
        _songArtworkUriCache[song.id] = uri;
        return uri;
      }
    } catch (e) {
      debugPrint('Error getting artwork URI for song ${song.title}: $e');
    }

    final fallback = await _getFallbackArtworkUri();
    return fallback;
  }

  MediaItem createMediaItemForSong(SongModel song, {Uri? artUri}) {
    final String title = SongEditService().getDisplayTitle(song);
    final String artist = SongEditService().getDisplayArtist(song);
    final String album = (song.album != null && song.album!.trim().isNotEmpty)
        ? song.album!.trim()
        : 'MD Music';

    final extras = <String, dynamic>{};
    if (artUri != null && artUri.isScheme('file')) {
      extras['artCacheFile'] = artUri.toFilePath();
    }

    return MediaItem(
      id: '${song.id}',
      album: album,
      title: title,
      artist: artist,
      duration: Duration(milliseconds: song.duration ?? 0),
      artUri: artUri,
      extras: extras.isNotEmpty ? extras : null,
    );
  }

  Future<void> _syncActiveSongMediaItem(SongModel song) async {
    try {
      final artUri = await _getSongArtworkUri(song);
      if (_currentSong?.id == song.id) {
        final item = createMediaItemForSong(song, artUri: artUri);
        JustAudioBackground.setMediaItem(item);
      }
    } catch (e) {
      debugPrint('Error syncing active song media item: $e');
    }
  }

  AudioSource _createAudioSource(SongModel song, {Uri? artUri}) {
    final uri = (song.uri != null && song.uri!.isNotEmpty)
        ? Uri.parse(song.uri!)
        : Uri.file(song.data);

    return AudioSource.uri(
      uri,
      tag: createMediaItemForSong(song, artUri: artUri),
    );
  }

  Future<void> playWithShuffle(List<SongModel> playlist, {SongModel? initialSong}) async {
    if (playlist.isEmpty) return;
    _isShuffle = true;
    _originalPlaylist = List.from(playlist);

    final list = List<SongModel>.from(playlist);
    final chosen = initialSong ?? (List<SongModel>.from(list)..shuffle()).first;

    final remaining = list.where((s) => s.id != chosen.id).toList()..shuffle();
    final queue = [chosen, ...remaining];

    await playSong(chosen, playlist: queue, preserveShuffleOrder: true);
  }

  /// Plays ONLY the selected songs strictly in the sequential order they were selected
  /// in a temporary looping album/playlist. When all selected songs finish, it loops
  /// back to the first selected song and repeats continuously.
  Future<void> playSelectedSongsQueue(List<SongModel> selectedSongs) async {
    if (selectedSongs.isEmpty) return;

    _isTemporarySelectedQueue = true;

    // 1. Maintain exact sequential order chosen by the user
    final orderedList = List<SongModel>.from(selectedSongs);

    // 2. Disable shuffle to preserve exact 1-to-N selection order
    _isShuffle = false;

    // 3. Set loop mode to ALL so when queue reaches the end it wraps to the first selected song
    _loopMode = LoopMode.all;
    _player.setLoopMode(LoopMode.off);

    // 4. Update playlists to ONLY contain these selected songs
    _originalPlaylist = List.from(orderedList);
    _currentPlaylist = List.from(orderedList);
    _currentIndex = 0;

    // 5. Play from the first selected song
    await playSong(
      orderedList.first,
      playlist: orderedList,
      preserveShuffleOrder: true,
    );
  }

  Future<void> playSong(
    SongModel song, {
    List<SongModel>? playlist,
    bool preserveShuffleOrder = false,
  }) async {
    final list = playlist ?? (_allSongs.isNotEmpty ? _allSongs : [song]);

    if (!preserveShuffleOrder) {
      _isTemporarySelectedQueue = false;
      _originalPlaylist = List.from(list);
      if (_isShuffle && list.length > 1) {
        // Guaranteed non-repeating shuffle queue:
        // The clicked song plays first, all remaining songs are shuffled
        final remaining = list.where((s) => s.id != song.id).toList()..shuffle();
        _currentPlaylist = [song, ...remaining];
        _currentIndex = 0;
      } else {
        _currentPlaylist = List.from(list);
        final index = _currentPlaylist.indexWhere((s) => s.id == song.id);
        _currentIndex = index != -1 ? index : 0;
      }
    } else {
      _currentPlaylist = List.from(list);
      final index = _currentPlaylist.indexWhere((s) => s.id == song.id);
      _currentIndex = index != -1 ? index : 0;
    }

    final targetIndex = _currentIndex;
    _currentSong = _currentPlaylist[targetIndex];

    // Add to recently played (keep up to 15)
    _recentlyPlayed.removeWhere((s) => s.id == song.id);
    _recentlyPlayed.insert(0, song);
    if (_recentlyPlayed.length > 15) {
      _recentlyPlayed.removeLast();
    }

    notifyListeners();

    if (Platform.isAndroid) {
      try {
        final notifStatus = await Permission.notification.status;
        if (!notifStatus.isGranted) {
          await Permission.notification.request();
        }
      } catch (_) {}
    }

    try {
      final fallbackUri = await _getFallbackArtworkUri();
      final artUri = await _getSongArtworkUri(song);

      // Check if the current playlist is already active
      final isSamePlaylist = _isSamePlaylistAs(list) && !preserveShuffleOrder;

      if (isSamePlaylist && _player.audioSource != null) {
        await _player.seek(Duration.zero, index: targetIndex);
        if (_playbackSpeed != 1.0) {
          await _player.setSpeed(_playbackSpeed);
        }
        await _applyPitch();
        await _player.play();
        _syncActiveSongMediaItem(song);
      } else {
        final sources = <AudioSource>[];
        for (final s in _currentPlaylist) {
          final sArtUri = _songArtworkUriCache[s.id] ?? (s.id == song.id ? artUri : fallbackUri);
          sources.add(_createAudioSource(
            s,
            artUri: sArtUri,
          ));
        }

        final playlistSource = ConcatenatingAudioSource(children: sources);
        _playlistSource = playlistSource;
        await _player.setAudioSource(playlistSource, initialIndex: targetIndex);
        if (_playbackSpeed != 1.0) {
          await _player.setSpeed(_playbackSpeed);
        }
        await _applyPitch();
        await _player.play();
        _syncActiveSongMediaItem(song);
      }
    } catch (e) {
      debugPrint('Error playing song with playlist: $e');
      // Direct single-track fallback
      try {
        _playlistSource = null;
        final artUri = await _getSongArtworkUri(song);
        final singleSource = _createAudioSource(song, artUri: artUri);
        await _player.setAudioSource(singleSource);
        if (_playbackSpeed != 1.0) {
          await _player.setSpeed(_playbackSpeed);
        }
        await _applyPitch();
        await _player.play();
        _syncActiveSongMediaItem(song);
      } catch (e2) {
        debugPrint('Direct fallback error: $e2');
      }
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_currentSong != null) {
        await _player.play();
      } else if (_allSongs.isNotEmpty) {
        await playSong(_allSongs.first);
      }
    }
  }

  Future<void> _handleTrackCompleted() async {
    if (_loopMode == LoopMode.one) {
      await _player.seek(Duration.zero);
      await _player.play();
    } else if (_loopMode == LoopMode.all) {
      if (_isShuffle && _originalPlaylist.length > 1) {
        await _startNewShuffleCycle();
      } else if (_currentPlaylist.isNotEmpty) {
        await _player.seek(Duration.zero, index: 0);
        await _player.play();
      }
    } else {
      // LoopMode.off: All songs in the album / playlist have been played once!
      // Do not repeat any song; stop playback cleanly.
      await _player.pause();
      if (_currentPlaylist.isNotEmpty) {
        await _player.seek(Duration.zero, index: 0);
      }
    }
  }

  Future<void> _startNewShuffleCycle() async {
    if (_originalPlaylist.isEmpty) return;
    final lastSongId = _currentSong?.id;
    final newShuffled = List<SongModel>.from(_originalPlaylist)..shuffle();

    // Ensure the first song of the new cycle is not identical to the last song
    if (newShuffled.length > 1 && newShuffled.first.id == lastSongId) {
      final item = newShuffled.removeAt(0);
      newShuffled.add(item);
    }

    await playSong(newShuffled.first, playlist: newShuffled, preserveShuffleOrder: true);
  }

  Future<void> playNext() async {
    if (_currentPlaylist.isEmpty && _allSongs.isEmpty) return;

    if (_player.playing) {
      await _player.setVolume(0.3);
      await Future.delayed(const Duration(milliseconds: 150));
      await _player.setVolume(1.0);
    }

    if (_player.hasNext) {
      await _player.seekToNext();
      if (!_player.playing) {
        await _player.play();
      }
    } else {
      // Reached the end of the current queue (all songs played)
      if (_loopMode == LoopMode.all) {
        if (_isShuffle && _originalPlaylist.length > 1) {
          await _startNewShuffleCycle();
        } else if (_currentPlaylist.isNotEmpty) {
          await _player.seek(Duration.zero, index: 0);
          await _player.play();
        }
      } else {
        // LoopMode.off: Stopped after playing all songs
        if (_currentPlaylist.isNotEmpty) {
          await _player.seek(Duration.zero, index: 0);
        }
        await _player.pause();
      }
    }
  }

  Future<void> playPrevious() async {
    if (_currentPlaylist.isEmpty && _allSongs.isEmpty) return;

    if (_player.playing) {
      await _player.setVolume(0.3);
      await Future.delayed(const Duration(milliseconds: 150));
      await _player.setVolume(1.0);
    }

    // If played more than 3 seconds, restart current track
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }

    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else if (_currentPlaylist.isNotEmpty) {
      // Wrap to end
      await _player.seek(Duration.zero, index: _currentPlaylist.length - 1);
    }
    if (!_player.playing) {
      await _player.play();
    }
  }

  double _preMuteVolume = 1.0;
  bool _isMutedForScrubbing = false;

  Future<void> setScrubbingMuted(bool muted) async {
    try {
      if (muted && !_isMutedForScrubbing) {
        _isMutedForScrubbing = true;
        _preMuteVolume = _player.volume;
        await _player.setVolume(0.0);
      } else if (!muted && _isMutedForScrubbing) {
        _isMutedForScrubbing = false;
        await _player.setVolume(_preMuteVolume > 0 ? _preMuteVolume : 1.0);
      }
    } catch (e) {
      debugPrint('Error setting scrubbing mute: $e');
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> toggleShuffle() async {
    _isShuffle = !_isShuffle;

    if (_currentPlaylist.isEmpty) {
      notifyListeners();
      return;
    }

    final current = _currentSong;
    if (_isShuffle) {
      // Shuffle activated:
      // Keep current song at index 0, shuffle remaining songs from _originalPlaylist
      final baseList = _originalPlaylist.isNotEmpty ? _originalPlaylist : _currentPlaylist;
      _originalPlaylist = List.from(baseList);

      if (current != null && baseList.length > 1) {
        final remaining = baseList.where((s) => s.id != current.id).toList()..shuffle();
        final newQueue = [current, ...remaining];
        final currentPos = _player.position;
        final wasPlaying = _player.playing;

        _currentPlaylist = newQueue;
        _currentIndex = 0;
        await _loadActivePlaylist(
          initialIndex: 0,
          initialPosition: currentPos,
          autoPlay: wasPlaying,
        );
      }
    } else {
      // Shuffle deactivated:
      // Restore original playlist order and seek to current song
      if (_originalPlaylist.isNotEmpty && current != null) {
        final origIndex = _originalPlaylist.indexWhere((s) => s.id == current.id);
        final targetIndex = origIndex != -1 ? origIndex : 0;
        final currentPos = _player.position;
        final wasPlaying = _player.playing;

        _currentPlaylist = List.from(_originalPlaylist);
        _currentIndex = targetIndex;
        await _loadActivePlaylist(
          initialIndex: targetIndex,
          initialPosition: currentPos,
          autoPlay: wasPlaying,
        );
      }
    }

    notifyListeners();
  }

  Future<void> _loadActivePlaylist({
    required int initialIndex,
    Duration initialPosition = Duration.zero,
    bool autoPlay = true,
  }) async {
    try {
      final fallbackUri = await _getFallbackArtworkUri();
      final sources = <AudioSource>[];
      for (int i = 0; i < _currentPlaylist.length; i++) {
        final s = _currentPlaylist[i];
        final sArtUri = _songArtworkUriCache[s.id] ?? fallbackUri;
        sources.add(_createAudioSource(s, artUri: sArtUri));
      }

      final playlistSource = ConcatenatingAudioSource(children: sources);
      _playlistSource = playlistSource;
      await _player.setAudioSource(
        playlistSource,
        initialIndex: initialIndex,
        initialPosition: initialPosition,
      );

      if (_playbackSpeed != 1.0) {
        await _player.setSpeed(_playbackSpeed);
      }
      await _applyPitch();
      if (autoPlay) {
        await _player.play();
      }
    } catch (e) {
      debugPrint('Error reloading active playlist: $e');
    }
  }

  void toggleLoop() {
    if (_loopMode == LoopMode.off) {
      _loopMode = LoopMode.all;
    } else if (_loopMode == LoopMode.all) {
      _loopMode = LoopMode.one;
    } else {
      _loopMode = LoopMode.off;
    }

    // For single track loop, use player's native loop mode
    if (_loopMode == LoopMode.one) {
      _player.setLoopMode(LoopMode.one);
    } else {
      // Handled cleanly in queue logic to ensure non-repeating shuffle cycles
      _player.setLoopMode(LoopMode.off);
    }
    notifyListeners();
  }

  void toggleFavorite(int songId) {
    if (_favoriteIds.contains(songId)) {
      _favoriteIds.remove(songId);
    } else {
      _favoriteIds.add(songId);
    }
    notifyListeners();
  }

  bool isFavorite(int songId) {
    return _favoriteIds.contains(songId);
  }

  String formatDuration(int? milliseconds) {
    if (milliseconds == null || milliseconds <= 0) return '00:00';
    final totalSeconds = (milliseconds / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
    return '$minutesStr:$secondsStr';
  }

  Future<File> _getDeletedFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/deleted_songs.json');
  }

  Future<void> _loadDeletedSongs() async {
    try {
      final file = await _getDeletedFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> list = jsonDecode(content);
        for (var item in list) {
          if (item is int) {
            _deletedSongIds.add(item);
          } else if (item is num) {
            _deletedSongIds.add(item.toInt());
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading deleted songs: $e');
    }
  }

  Future<void> _saveDeletedSongs() async {
    try {
      final file = await _getDeletedFile();
      await file.writeAsString(jsonEncode(_deletedSongIds.toList()));
    } catch (e) {
      debugPrint('Error saving deleted songs: $e');
    }
  }

  Future<bool> deleteSong(SongModel song) async {
    try {
      // 1. Try native platform deletion (MediaStore & physical phone file)
      try {
        await _artworkChannel.invokeMethod<bool>('deleteAudio', {
          'path': song.data,
          'id': song.id,
        });
      } catch (e) {
        debugPrint('Native delete audio error: $e');
      }

      // 2. Direct file deletion fallback
      try {
        final file = File(song.data);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('File system delete skipped: $e');
      }

      final deletedIndexInCurrent = _currentPlaylist.indexWhere((s) => s.id == song.id);
      final isCurrentlyPlaying = _currentSong?.id == song.id;

      // 3. Mark as deleted permanently
      _deletedSongIds.add(song.id);
      await _saveDeletedSongs();

      // 4. Remove from all active lists
      _allSongs.removeWhere((s) => s.id == song.id);
      _currentPlaylist.removeWhere((s) => s.id == song.id);
      _originalPlaylist.removeWhere((s) => s.id == song.id);
      _recentlyPlayed.removeWhere((s) => s.id == song.id);
      _favoriteIds.remove(song.id);

      // Invalidate playlist source so subsequent playback builds a clean aligned queue
      _playlistSource = null;

      // 5. Handle player audio source synchronization
      if (_currentPlaylist.isEmpty) {
        _currentSong = null;
        _currentIndex = -1;
        await _player.stop();
      } else if (isCurrentlyPlaying) {
        await _player.stop();
        // Play the song that took over the deleted position, or first if at end
        final nextIndex = (deletedIndexInCurrent != -1 && deletedIndexInCurrent < _currentPlaylist.length)
            ? deletedIndexInCurrent
            : 0;
        final nextSong = _currentPlaylist[nextIndex];
        await playSong(nextSong, playlist: _currentPlaylist, preserveShuffleOrder: _isShuffle);
      } else {
        // If not playing, keep existing playback alive and update audio source
        if (_player.audioSource is ConcatenatingAudioSource && deletedIndexInCurrent != -1) {
          try {
            await (_player.audioSource as ConcatenatingAudioSource).removeAt(deletedIndexInCurrent);
          } catch (_) {}
        }
        if (_currentSong != null) {
          _currentIndex = _currentPlaylist.indexWhere((s) => s.id == _currentSong!.id);
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting song: $e');
      return false;
    }
  }

  Future<int> deleteMultipleSongs(List<SongModel> songs) async {
    int deleted = 0;
    for (final song in songs) {
      final success = await deleteSong(song);
      if (success) {
        deleted++;
      }
    }
    return deleted;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
