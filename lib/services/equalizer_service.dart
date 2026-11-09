import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'audio_service.dart';
import 'language_service.dart';

class EqualizerPreset {
  final String id;
  final String nameAr;
  final String nameEn;
  final List<double> bands; // 5 values in dB
  final int bassBoost; // 0 to 1000

  const EqualizerPreset({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.bands,
    this.bassBoost = 0,
  });

  String get displayName {
    if (id == 'flat') return LanguageService().t('preset_flat');
    if (id == 'bass_boost') return LanguageService().t('preset_bass_boost');
    if (id == 'pop') return LanguageService().t('preset_pop');
    if (id == 'rock') return LanguageService().t('preset_rock');
    if (id == 'vocal') return LanguageService().t('preset_vocal');
    if (id == 'dance') return LanguageService().t('preset_electronic');
    if (id == 'classical') return LanguageService().t('preset_classical');
    return LanguageService().isArabic ? nameAr : nameEn;
  }

  String get name => displayName;
}

class EqualizerService extends ChangeNotifier {
  static final EqualizerService _instance = EqualizerService._internal();
  factory EqualizerService() => _instance;
  EqualizerService._internal();

  static const MethodChannel _channel = MethodChannel('com.mbd.music/artwork');
  static const String _fileName = 'equalizer_settings_v1.json';

  bool _enabled = false;
  String _currentPresetId = 'flat';
  List<double> _bands = [0.0, 0.0, 0.0, 0.0, 0.0];
  int _bassBoost = 0; // 0 - 1000
  List<int> _frequencies = [60, 230, 910, 3600, 14000];
  double _minDb = -10.0;
  double _maxDb = 10.0;
  bool _isSupported = true;

  bool get enabled => _enabled;
  String get currentPresetId => _currentPresetId;
  List<double> get bands => List.unmodifiable(_bands);
  int get bassBoost => _bassBoost;
  List<int> get frequencies => _frequencies;
  double get minDb => _minDb;
  double get maxDb => _maxDb;
  bool get isSupported => _isSupported;

  final List<EqualizerPreset> presets = const [
    EqualizerPreset(
      id: 'flat',
      nameAr: 'طبيعي',
      nameEn: 'Flat',
      bands: [0.0, 0.0, 0.0, 0.0, 0.0],
      bassBoost: 0,
    ),
    EqualizerPreset(
      id: 'bass_boost',
      nameAr: 'تضخيم الباس',
      nameEn: 'Bass Boost',
      bands: [6.0, 4.0, 0.5, -0.5, 0.0],
      bassBoost: 650,
    ),
    EqualizerPreset(
      id: 'pop',
      nameAr: 'بوب',
      nameEn: 'Pop',
      bands: [-1.5, 2.0, 4.0, 2.5, -1.0],
      bassBoost: 180,
    ),
    EqualizerPreset(
      id: 'rock',
      nameAr: 'روك',
      nameEn: 'Rock',
      bands: [4.5, 2.5, -1.0, 2.5, 4.5],
      bassBoost: 320,
    ),
    EqualizerPreset(
      id: 'vocal',
      nameAr: 'صوت بشري',
      nameEn: 'Vocal',
      bands: [-2.0, 1.0, 4.5, 3.5, 1.5],
      bassBoost: 0,
    ),
    EqualizerPreset(
      id: 'dance',
      nameAr: 'إلكترونيك',
      nameEn: 'Electronic',
      bands: [5.5, 3.0, 0.0, 2.5, 4.0],
      bassBoost: 500,
    ),
    EqualizerPreset(
      id: 'classical',
      nameAr: 'كلاسيكي',
      nameEn: 'Classical',
      bands: [3.5, 2.0, -0.5, 2.5, 3.5],
      bassBoost: 80,
    ),
  ];

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
          _enabled = data['enabled'] == true;
          _currentPresetId = data['preset'] as String? ?? 'flat';
          _bassBoost = (data['bass'] as num?)?.toInt() ?? 0;

          if (data['bands'] is List) {
            final List<dynamic> list = data['bands'];
            _bands = list.map((e) => (e as num).toDouble()).toList();
          } else {
            _applyPresetValues(_currentPresetId);
          }
        }
      } else {
        _applyPresetValues(_currentPresetId);
      }

      // Listen to player session ID changes
      AudioService().player.androidAudioSessionIdStream.listen((sessionId) {
        if (sessionId != null && sessionId > 0) {
          attachToSession(sessionId);
        }
      });

      final currentId = AudioService().player.androidAudioSessionId;
      if (currentId != null && currentId > 0) {
        await attachToSession(currentId);
      }
    } catch (e) {
      debugPrint('Equalizer init error: $e');
    }
  }

  void _applyPresetValues(String presetId) {
    final preset = presets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => presets.first,
    );
    _bands = List<double>.from(preset.bands);
    _bassBoost = preset.bassBoost;
  }

  Future<void> attachToSession(int sessionId) async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('attachEqualizer', {
        'sessionId': sessionId,
        'enabled': _enabled,
        'bands': _bands,
        'bassBoost': _bassBoost,
      });

      if (res != null) {
        _isSupported = res['supported'] == true;
        if (res['minDb'] != null) _minDb = (res['minDb'] as num).toDouble();
        if (res['maxDb'] != null) _maxDb = (res['maxDb'] as num).toDouble();
        if (res['frequencies'] != null) {
          final List<dynamic> freqs = res['frequencies'];
          _frequencies = freqs.map((f) => (f as num).toInt()).toList();
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error attaching equalizer: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _sendBandsToNative();
    await _saveToFile();
    notifyListeners();
  }

  Future<void> setPreset(String presetId) async {
    _currentPresetId = presetId;
    _applyPresetValues(presetId);
    await _sendBandsToNative();
    await _saveToFile();
    notifyListeners();
  }

  Future<void> setBandGain(int bandIndex, double gainDb) async {
    if (bandIndex < 0 || bandIndex >= _bands.length) return;
    _bands[bandIndex] = double.parse(gainDb.clamp(_minDb, _maxDb).toStringAsFixed(1));
    _currentPresetId = 'custom';
    await _sendBandsToNative();
    await _saveToFile();
    notifyListeners();
  }

  Future<void> setBassBoost(int strength) async {
    _bassBoost = strength.clamp(0, 1000);
    _currentPresetId = 'custom';
    await _sendBandsToNative();
    await _saveToFile();
    notifyListeners();
  }

  Future<void> resetToFlat() async {
    await setPreset('flat');
  }

  Future<void> _sendBandsToNative() async {
    try {
      await _channel.invokeMethod('setEqualizerBands', {
        'enabled': _enabled,
        'bands': _bands,
        'bassBoost': _bassBoost,
      });
    } catch (e) {
      debugPrint('Error sending equalizer bands: $e');
    }
  }

  Future<void> _saveToFile() async {
    try {
      final file = await _getFile();
      final data = {
        'enabled': _enabled,
        'preset': _currentPresetId,
        'bands': _bands,
        'bass': _bassBoost,
      };
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('Error saving equalizer settings: $e');
    }
  }

  String formatFreq(int freqHz) {
    if (freqHz >= 1000) {
      final khz = freqHz / 1000.0;
      return khz == khz.roundToDouble()
          ? '${khz.toInt()}kHz'
          : '${khz.toStringAsFixed(1)}kHz';
    }
    return '${freqHz}Hz';
  }
}
