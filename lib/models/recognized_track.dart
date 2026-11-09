import 'package:on_audio_query/on_audio_query.dart';
import '../services/audio_service.dart';
import '../services/song_edit_service.dart';

/// Model representing a song identified via Music Recognition
class RecognizedTrack {
  final String title;
  final String artist;
  final String? album;
  final String? releaseDate;
  final String? artworkUrl;
  final String? spotifyUrl;
  final String? youtubeUrl;
  final String? appleMusicUrl;
  final String? auddUrl;
  final DateTime timestamp;
  final Map<String, dynamic> rawJson;

  const RecognizedTrack({
    required this.title,
    required this.artist,
    this.album,
    this.releaseDate,
    this.artworkUrl,
    this.spotifyUrl,
    this.youtubeUrl,
    this.appleMusicUrl,
    this.auddUrl,
    required this.timestamp,
    this.rawJson = const {},
  });

  /// Checks if this identified song matches any local song on the user's device
  SongModel? findLocalMatch() {
    final allSongs = AudioService().allSongs;
    final editService = SongEditService();
    final cleanT = _normalize(title);
    final cleanA = _normalize(artist);

    if (cleanT.isEmpty) return null;

    for (final song in allSongs) {
      final localT = _normalize(editService.getDisplayTitle(song));
      final localA = _normalize(editService.getDisplayArtist(song));

      // Direct or substring match
      final titleMatch = localT == cleanT ||
          localT.contains(cleanT) ||
          cleanT.contains(localT);

      if (titleMatch) {
        if (cleanA.isEmpty ||
            localA.contains(cleanA) ||
            cleanA.contains(localA)) {
          return song;
        }
      }
    }
    return null;
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[\(\[\{].*?[\)\]\}]'), '') // remove brackets
        .replaceAll(RegExp(r'[^a-zA-Z0-9\u0621-\u064A\s]'), '') // keep arabic/english/numbers
        .trim();
  }

  /// Direct YouTube search fallback link
  String get effectiveYouTubeUrl {
    if (youtubeUrl != null && youtubeUrl!.isNotEmpty) {
      return youtubeUrl!;
    }
    final q = Uri.encodeComponent('$title $artist'.trim());
    return 'https://www.youtube.com/results?search_query=$q';
  }

  /// Direct Spotify search fallback link
  String get effectiveSpotifyUrl {
    if (spotifyUrl != null && spotifyUrl!.isNotEmpty) {
      return spotifyUrl!;
    }
    final q = Uri.encodeComponent('$title $artist'.trim());
    return 'https://open.spotify.com/search/$q';
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'artist': artist,
        'album': album,
        'releaseDate': releaseDate,
        'artworkUrl': artworkUrl,
        'spotifyUrl': spotifyUrl,
        'youtubeUrl': youtubeUrl,
        'appleMusicUrl': appleMusicUrl,
        'auddUrl': auddUrl,
        'timestamp': timestamp.toIso8601String(),
        'rawJson': rawJson,
      };

  factory RecognizedTrack.fromJson(Map<String, dynamic> json) {
    return RecognizedTrack(
      title: json['title'] as String? ?? 'Unknown Title',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      album: json['album'] as String?,
      releaseDate: json['releaseDate'] as String?,
      artworkUrl: json['artworkUrl'] as String?,
      spotifyUrl: json['spotifyUrl'] as String?,
      youtubeUrl: json['youtubeUrl'] as String?,
      appleMusicUrl: json['appleMusicUrl'] as String?,
      auddUrl: json['auddUrl'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      rawJson: json['rawJson'] is Map<String, dynamic>
          ? json['rawJson'] as Map<String, dynamic>
          : const {},
    );
  }

  /// Parses an AudD API JSON response
  factory RecognizedTrack.fromAudD(Map<String, dynamic> data) {
    String? artwork;
    String? spotifyUrl;
    String? youtubeUrl;
    String? appleUrl;

    // Check spotify block
    if (data['spotify'] is Map) {
      final sp = data['spotify'] as Map;
      if (sp['external_urls'] is Map) {
        spotifyUrl = sp['external_urls']['spotify'] as String?;
      }
      if (sp['album'] is Map && sp['album']['images'] is List) {
        final imgs = sp['album']['images'] as List;
        if (imgs.isNotEmpty && imgs[0] is Map) {
          artwork = imgs[0]['url'] as String?;
        }
      }
    }

    // Check youtube block
    if (data['youtube'] is Map) {
      final yt = data['youtube'] as Map;
      youtubeUrl = yt['link'] as String?;
      if (artwork == null && yt['image_url'] is String) {
        artwork = yt['image_url'] as String;
      }
    }

    // Check apple_music block
    if (data['apple_music'] is Map) {
      final ap = data['apple_music'] as Map;
      appleUrl = ap['url'] as String?;
      if (artwork == null && ap['artwork'] is Map) {
        final art = ap['artwork']['url'] as String?;
        if (art != null) {
          artwork = art.replaceAll('{w}', '500').replaceAll('{h}', '500');
        }
      }
    }

    return RecognizedTrack(
      title: data['title'] as String? ?? 'Unknown Title',
      artist: data['artist'] as String? ?? 'Unknown Artist',
      album: data['album'] as String?,
      releaseDate: data['release_date'] as String?,
      artworkUrl: artwork,
      spotifyUrl: spotifyUrl,
      youtubeUrl: youtubeUrl,
      appleMusicUrl: appleUrl,
      auddUrl: data['song_link'] as String?,
      timestamp: DateTime.now(),
      rawJson: data,
    );
  }
}
