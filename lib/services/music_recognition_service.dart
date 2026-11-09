import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/recognized_track.dart';
import 'audio_service.dart';
import 'language_service.dart';

enum RecognitionState {
  idle,
  listening,
  analyzing,
  success,
  notFound,
  error,
}

class MusicRecognitionService extends ChangeNotifier {
  static final MusicRecognitionService _instance =
      MusicRecognitionService._internal();
  factory MusicRecognitionService() => _instance;
  MusicRecognitionService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 25),
  ));

  RecognitionState _state = RecognitionState.idle;
  RecognitionState get state => _state;

  RecognizedTrack? _currentResult;
  RecognizedTrack? get currentResult => _currentResult;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  double _amplitude = 0.0;
  double get amplitude => _amplitude;

  int _countdownSeconds = 5;
  int get countdownSeconds => _countdownSeconds;

  List<RecognizedTrack> _history = [];
  List<RecognizedTrack> get history => List.unmodifiable(_history);

  Timer? _recordTimer;
  Timer? _amplitudeTimer;
  String _userApiKey = '';

  String get userApiKey => _userApiKey;

  Future<void> init() async {
    await _loadHistory();
    await _loadApiKey();
    // Pre-warm SSL connection to eliminate DNS & handshake latency
    try {
      _dio.head('https://api.audd.io/').catchError((_) => Response(
            requestOptions: RequestOptions(path: ''),
          ));
    } catch (_) {}
  }

  /// Sets custom AudD API Key for unlimited recognition
  Future<void> setApiKey(String key) async {
    _userApiKey = key.trim();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/audd_api_key.txt');
    await file.writeAsString(_userApiKey);
    notifyListeners();
  }

  Future<void> _loadApiKey() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/audd_api_key.txt');
      if (await file.exists()) {
        _userApiKey = (await file.readAsString()).trim();
      }
    } catch (_) {}
  }

  /// Starts listening to ambient audio for ultra-fast recognition (~2.7s)
  Future<void> startRecognition() async {
    if (_state == RecognitionState.listening ||
        _state == RecognitionState.analyzing) {
      return;
    }

    // 1. Request microphone permission
    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      _state = RecognitionState.error;
      _errorMessage = LanguageService().t('mic_permission_needed');
      notifyListeners();
      return;
    }

    // Pause audio playback if currently playing in MD Music
    try {
      if (AudioService().player.playing) {
        await AudioService().player.pause();
      }
    } catch (_) {}

    _state = RecognitionState.listening;
    _currentResult = null;
    _errorMessage = null;
    _amplitude = 0.0;
    notifyListeners();

    try {
      final dir = await getTemporaryDirectory();
      final recordPath =
          '${dir.path}/music_rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Studio-grade 44.1kHz mono recording for exact acoustic fingerprint matching (~3.8s)
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: recordPath,
      );

      // Fast amplitude polling (60ms) for ultra-fluid ripple visualizer
      _amplitudeTimer =
          Timer.periodic(const Duration(milliseconds: 60), (t) async {
        if (_state != RecognitionState.listening &&
            _state != RecognitionState.analyzing) {
          t.cancel();
          return;
        }
        try {
          final amp = await _recorder.getAmplitude();
          final normalized = ((amp.current + 50) / 50).clamp(0.06, 1.0);
          _amplitude = normalized;
          notifyListeners();
        } catch (_) {}
      });

      // Balanced high-accuracy recognition window (3.8 seconds)
      _recordTimer = Timer(const Duration(milliseconds: 3800), () async {
        await _finishRecordingAndIdentify(recordPath);
      });
    } catch (e) {
      _cleanupTimers();
      _state = RecognitionState.error;
      _errorMessage = LanguageService()
          .t('music_rec_record_error')
          .replaceAll('{error}', e.toString());
      notifyListeners();
    }
  }

  /// Cancels active recognition
  Future<void> cancelRecognition() async {
    _cleanupTimers();
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {}
    _state = RecognitionState.idle;
    notifyListeners();
  }

  /// Resets state back to idle
  void reset() {
    _cleanupTimers();
    _state = RecognitionState.idle;
    _currentResult = null;
    _errorMessage = null;
    _amplitude = 0.0;
    notifyListeners();
  }

  void _cleanupTimers() {
    _recordTimer?.cancel();
    _recordTimer = null;
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
  }

  Future<void> _finishRecordingAndIdentify(String audioPath) async {
    _cleanupTimers();
    try {
      final path = await _recorder.stop();
      final file = File(path ?? audioPath);
      if (!await file.exists() || await file.length() < 1000) {
        _state = RecognitionState.error;
        _errorMessage = LanguageService().t('music_rec_no_audio');
        notifyListeners();
        return;
      }

      _state = RecognitionState.analyzing;
      _amplitude = 0.35;
      notifyListeners();

      final apiToken = _userApiKey.isNotEmpty ? _userApiKey : 'test';

      final formData = FormData.fromMap({
        'api_token': apiToken,
        'return': 'spotify,youtube,apple_music',
        'file': await MultipartFile.fromFile(
          file.path,
          filename: 'snippet.m4a',
        ),
      });

      final response = await _dio.post(
        'https://api.audd.io/',
        data: formData,
      );

      // Clean up temp audio file
      try {
        await file.delete();
      } catch (_) {}

      final data = response.data;
      debugPrint('[MusicRecognition] AudD API response: $data');

      if (data is Map) {
        if (data['status'] == 'success' && data['result'] != null) {
          final resultData = data['result'] as Map<String, dynamic>;
          final track = RecognizedTrack.fromAudD(resultData);
          _currentResult = track;
          _state = RecognitionState.success;
          await _addToHistory(track);
        } else if (data['error'] != null) {
          final errorObj = data['error'];
          final code = errorObj is Map ? errorObj['error_code'] : null;
          final msg = errorObj is Map
              ? (errorObj['error_message'] ?? '')
              : errorObj.toString();
          debugPrint('[MusicRecognition] AudD Error: code=$code, msg=$msg');

          final msgStr = msg.toString().toLowerCase();
          if (code == 900 ||
              msgStr.contains('trial') ||
              msgStr.contains('limit was reached') ||
              msgStr.contains('authorization failed')) {
            _state = RecognitionState.error;
            _errorMessage = LanguageService().t('music_rec_quota_exceeded');
          } else {
            _state = RecognitionState.error;
            _errorMessage = LanguageService()
                .t('music_rec_server_error')
                .replaceAll('{error}', msg.toString());
          }
        } else {
          // Status success but result is null (no matching song in database)
          _state = RecognitionState.notFound;
        }
      } else {
        _state = RecognitionState.notFound;
      }
    } catch (e, stack) {
      debugPrint('[MusicRecognition] Exception: $e\n$stack');
      _state = RecognitionState.error;
      _errorMessage = LanguageService().t('music_rec_offline_error');
    } finally {
      notifyListeners();
    }
  }

  /// Opens the identified track directly in YouTube
  Future<void> openInYouTube(RecognizedTrack track) async {
    final uri = Uri.parse(track.effectiveYouTubeUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  /// Opens the identified track directly in Spotify
  Future<void> openInSpotify(RecognizedTrack track) async {
    final uri = Uri.parse(track.effectiveSpotifyUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  /// Plays a local matching song inside MD Music
  Future<void> playLocalMatch(SongModel song) async {
    await AudioService().playSong(song);
  }

  // -------------------------------------------------------------
  // History Persistence
  // -------------------------------------------------------------
  Future<void> _loadHistory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/recognition_history.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List list = jsonDecode(content);
        _history = list
            .map((item) => RecognizedTrack.fromJson(item as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/recognition_history.json');
      final list = _history.map((t) => t.toJson()).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _addToHistory(RecognizedTrack track) async {
    // Avoid duplicate at top
    _history.removeWhere((t) =>
        t.title.toLowerCase() == track.title.toLowerCase() &&
        t.artist.toLowerCase() == track.artist.toLowerCase());
    _history.insert(0, track);
    if (_history.length > 50) {
      _history = _history.sublist(0, 50);
    }
    await _saveHistory();
  }

  Future<void> deleteHistoryItem(int index) async {
    if (index >= 0 && index < _history.length) {
      _history.removeAt(index);
      await _saveHistory();
      notifyListeners();
    }
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }

  @override
  void dispose() {
    _cleanupTimers();
    _recorder.dispose();
    super.dispose();
  }
}
