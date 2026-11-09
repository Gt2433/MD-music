import 'dart:async';
import 'package:flutter/foundation.dart';
import 'audio_service.dart';
import 'language_service.dart';

class SleepTimerService extends ChangeNotifier {
  static final SleepTimerService _instance = SleepTimerService._internal();
  factory SleepTimerService() => _instance;
  SleepTimerService._internal() {
    _initSongListener();
  }

  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _stopAtEndOfSong = false;
  bool _fadeOut = true;
  double _preFadeVolume = 1.0;
  bool _isFadingOut = false;
  int? _initialSongId;

  // Getters
  bool get isActive => _countdownTimer != null || _stopAtEndOfSong;
  Duration get remaining => _remaining;
  Duration get totalDuration => _totalDuration;
  bool get stopAtEndOfSong => _stopAtEndOfSong;
  bool get fadeOut => _fadeOut;
  bool get isFadingOut => _isFadingOut;

  String get formattedRemaining {
    if (!isActive) return '';
    if (_stopAtEndOfSong && _countdownTimer == null) {
      return LanguageService().t('timer_end_of_song');
    }
    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _initSongListener() {
    final audio = AudioService();
    audio.player.currentIndexStream.listen((index) {
      if (!_stopAtEndOfSong) return;
      final currentSong = audio.currentSong;
      if (currentSong == null) return;

      if (_initialSongId == null) {
        _initialSongId = currentSong.id;
      } else if (_initialSongId != currentSong.id) {
        // Song has changed/finished, trigger sleep stop!
        _triggerSleepStop();
      }
    });

    audio.player.playerStateStream.listen((state) {
      if (!_stopAtEndOfSong) return;
      if (state.processingState.name == 'completed') {
        _triggerSleepStop();
      }
    });
  }

  void startTimer({
    required Duration duration,
    bool stopAtEndOfSong = false,
    bool fadeOut = true,
  }) {
    cancelTimer();
    _totalDuration = duration;
    _remaining = duration;
    _stopAtEndOfSong = stopAtEndOfSong;
    _fadeOut = fadeOut;
    _isFadingOut = false;
    _initialSongId = AudioService().currentSong?.id;

    if (duration > Duration.zero) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remaining.inSeconds <= 1) {
          _triggerSleepStop();
        } else {
          _remaining = _remaining - const Duration(seconds: 1);

          // Smooth volume fade out in last 30 seconds
          if (_fadeOut && _remaining.inSeconds <= 30) {
            _handleFadeOut(_remaining.inSeconds);
          }

          notifyListeners();
        }
      });
    }

    notifyListeners();
  }

  void setStopAtEndOfSong(bool value) {
    if (value) {
      _stopAtEndOfSong = true;
      _initialSongId = AudioService().currentSong?.id;
    } else {
      _stopAtEndOfSong = false;
      _initialSongId = null;
    }
    notifyListeners();
  }

  void setFadeOut(bool value) {
    _fadeOut = value;
    notifyListeners();
  }

  void addMinutes(int minutes) {
    if (!isActive) {
      startTimer(duration: Duration(minutes: minutes));
      return;
    }
    _remaining += Duration(minutes: minutes);
    _totalDuration += Duration(minutes: minutes);
    notifyListeners();
  }

  void _handleFadeOut(int secondsLeft) {
    final player = AudioService().player;
    if (!_isFadingOut) {
      _isFadingOut = true;
      _preFadeVolume = player.volume;
    }
    final fraction = (secondsLeft / 30.0).clamp(0.0, 1.0);
    player.setVolume(_preFadeVolume * fraction);
  }

  Future<void> _triggerSleepStop() async {
    final audio = AudioService();
    try {
      await audio.player.pause();
      if (_isFadingOut) {
        await audio.player.setVolume(_preFadeVolume);
      }
    } catch (e) {
      debugPrint('Sleep timer pause error: $e');
    }
    cancelTimer();
  }

  void cancelTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _remaining = Duration.zero;
    _totalDuration = Duration.zero;
    _stopAtEndOfSong = false;
    _initialSongId = null;

    if (_isFadingOut) {
      AudioService().player.setVolume(_preFadeVolume);
      _isFadingOut = false;
    }

    notifyListeners();
  }
}

