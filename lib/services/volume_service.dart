import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app_preferences.dart';
import 'audio_service.dart';

class VolumeService {
  static final VolumeService _instance = VolumeService._internal();
  factory VolumeService() => _instance;

  static const MethodChannel _channel = MethodChannel('com.mbd.music/volume');

  /// Custom stepped scale:
  /// From 0 to 5, increments/decrements by 1 (0, 1, 2, 3, 4, 5).
  /// Above 5, increments/decrements by 5 (5, 10, 15, ..., 100).
  static const List<int> validLevels = [
    0, 1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100
  ];

  final ValueNotifier<double> volume = ValueNotifier<double>(0.75); // 0.0 to 1.0 (corresponds to 0% to 100%)
  final ValueNotifier<bool> isVisible = ValueNotifier<bool>(false);

  Timer? _hideTimer;
  bool _initialized = false;
  double _lastNonZeroVolume = 0.50;

  VolumeService._internal();

  int get currentPercentage => (volume.value * 100).round();

  /// Calculates the next level when increasing volume:
  /// 0 -> 1 -> 2 -> 3 -> 4 -> 5 -> 10 -> 15 -> ... -> 100
  static int getNextStepUp(int current) {
    for (final lvl in validLevels) {
      if (lvl > current) return lvl;
    }
    return 100;
  }

  /// Calculates the next level when decreasing volume:
  /// 100 -> 95 -> ... -> 10 -> 5 -> 4 -> 3 -> 2 -> 1 -> 0
  static int getNextStepDown(int current) {
    for (int i = validLevels.length - 1; i >= 0; i--) {
      if (validLevels[i] < current) return validLevels[i];
    }
    return 0;
  }

  /// Snaps any continuous ratio to the nearest valid step
  static int snapToNearestLevel(int rawPercentage) {
    final clamped = rawPercentage.clamp(0, 100);
    int closest = validLevels.first;
    int minDiff = 1000;
    for (final lvl in validLevels) {
      final diff = (lvl - clamped).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = lvl;
      }
    }
    return closest;
  }

  /// Maps the percentage level to exact acoustic gain for the player:
  /// Level 1: Very weak / faint sound but audible ("هناك صوت ولكن ضعيف جدا")
  /// Level 2: A bit louder ("و2 اقوى شوي")
  /// Level 3: Louder ("3اقوى")
  /// Level 4: Louder ("4 اقوى")
  /// Level 5: Solid baseline ("والخامس")
  /// Above 5: Steps of 5 up to 1.0
  static double toAcousticGain(int percentage) {
    if (percentage <= 0) return 0.0;
    switch (percentage) {
      case 1:
        return 0.025; // Clearly audible when close, delicate and faint
      case 2:
        return 0.050; // Slightly stronger
      case 3:
        return 0.080; // Noticeably stronger
      case 4:
        return 0.115; // Moderate soft
      case 5:
        return 0.160; // Solid baseline, from here on scales in steps of 5
      default:
        return (0.160 + ((percentage - 5) / 95.0) * (1.0 - 0.160)).clamp(0.0, 1.0);
    }
  }

  void init() {
    if (_initialized) return;
    _initialized = true;

    // Load persisted volume if available
    AppPreferences.getSavedVolume().then((saved) {
      if (saved != null) {
        final snapped = snapToNearestLevel((saved * 100).round()) / 100.0;
        volume.value = snapped;
        final gain = toAcousticGain((snapped * 100).round());
        AudioService().player.setVolume(gain);
      }
    });

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'adjustVolume') {
        final args = call.arguments as Map?;
        final direction = args?['direction'] as String? ?? 'up';
        if (direction == 'up') {
          stepUp();
        } else {
          stepDown();
        }
      } else if (call.method == 'onVolumeChanged') {
        final args = call.arguments as Map?;
        final vol = (args?['volume'] as num?)?.toDouble();
        if (vol != null) {
          setVolume(vol);
        }
      }
    });

    _fetchCurrentVolume();
  }

  Future<void> _fetchCurrentVolume() async {
    try {
      final vol = await _channel.invokeMethod<double>('getVolume');
      if (vol != null) {
        final snapped = snapToNearestLevel((vol * 100).round()) / 100.0;
        volume.value = snapped;
        final gain = toAcousticGain((snapped * 100).round());
        AudioService().player.setVolume(gain);
      }
    } catch (_) {}
  }

  void stepUp() {
    final nextLevel = getNextStepUp(currentPercentage);
    setVolume(nextLevel / 100.0);
  }

  void stepDown() {
    final nextLevel = getNextStepDown(currentPercentage);
    setVolume(nextLevel / 100.0);
  }

  void toggleMute() {
    if (currentPercentage == 0) {
      setVolume(_lastNonZeroVolume > 0 ? _lastNonZeroVolume : 0.50);
    } else {
      setVolume(0.0);
    }
  }

  void showVolume(double vol) {
    volume.value = vol;
    isVisible.value = true;

    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 2600), () {
      isVisible.value = false;
    });
  }

  void dismiss() {
    _hideTimer?.cancel();
    isVisible.value = false;
  }

  Future<void> setVolume(double ratio, {bool showHud = true}) async {
    final rawPercentage = (ratio * 100).round();
    final snapped = snapToNearestLevel(rawPercentage);
    final normalized = snapped / 100.0;

    if (snapped > 0) {
      _lastNonZeroVolume = normalized;
    }

    if (showHud) {
      showVolume(normalized);
    } else {
      volume.value = normalized;
    }

    AppPreferences.setSavedVolume(normalized);

    final acousticGain = toAcousticGain(snapped);
    try {
      await AudioService().player.setVolume(acousticGain);
      await _channel.invokeMethod('setVolume', {'volume': normalized});
    } catch (_) {}
  }
}
