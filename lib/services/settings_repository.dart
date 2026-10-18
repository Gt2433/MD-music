import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Single source of truth for application settings.
/// Exposes live observables (ValueNotifiers & Streams) and persists state atomically.
class SettingsRepository extends ChangeNotifier {
  static final SettingsRepository _instance = SettingsRepository._internal();
  factory SettingsRepository() => _instance;
  SettingsRepository._internal();

  static const String _settingsFileName = 'app_settings_v1.json';
  static const int currentSchemaVersion = 2;

  // -------------------------------------------------------------
  // Predefined Accent Colors Palette (Curated & High Contrast)
  // -------------------------------------------------------------
  static const List<Color> accentColorPalette = [
    Color(0xFF00E676), // Emerald Green (Default)
    Color(0xFF00E5FF), // Neon Cyan
    Color(0xFF2979FF), // Electric Blue
    Color(0xFFFF9100), // Sunset Orange
    Color(0xFFD500F9), // Royal Purple
    Color(0xFFFF1744), // Crimson Red
    Color(0xFFFF4081), // Neon Pink
    Color(0xFFFFD600), // Amber Gold
    Color(0xFF1DE9B6), // Mint Teal
    Color(0xFF76FF03), // Lime Green
  ];

  // -------------------------------------------------------------
  // Keys Definition
  // -------------------------------------------------------------
  static const String keySchemaVersion = 'schema_version';
  static const String keyLanguage = 'language';
  static const String keyThemeMode = 'theme_mode';
  static const String keyAccentColor = 'accent_color';
  static const String keyAmoledBlack = 'amoled_black';
  static const String keyBgType = 'bg_type'; // 'default' | 'color' | 'image'
  static const String keyCustomBgColor = 'custom_bg_color';
  static const String keyCustomBgImagePath = 'custom_bg_image_path';
  static const String keyCustomBgRawImagePath = 'custom_bg_raw_image_path';
  static const String keyCustomBgBlur = 'custom_bg_blur';
  static const String keyCustomBgOpacity = 'custom_bg_opacity';
  static const String keyPlayerTheme = 'player_theme'; // 'default' | 'vinyl'
  static const String keyLandscapeColorMode = 'landscape_color_mode'; // 'app' | 'artwork'
  static const String keyAudioEffect = 'audio_effect'; // 'none' | 'deep_echo'

  // -------------------------------------------------------------
  // Defaults Definition
  // -------------------------------------------------------------
  static const String defaultLanguage = 'system'; // 'system' | 'ar' | 'en'
  static const String defaultThemeMode = 'system'; // 'system' | 'light' | 'dark'
  static const int defaultAccentColorValue = 0xFF00E676;
  static const bool defaultAmoledBlack = false;
  static const String defaultBgType = 'default';
  static const int defaultCustomBgColorValue = 0xFF0C1015;
  static const double defaultCustomBgBlur = 0.0;
  static const double defaultCustomBgOpacity = 1.0;
  static const String defaultPlayerTheme = 'default';
  static const String defaultLandscapeColorMode = 'artwork';
  static const String defaultAudioEffect = 'none';

  // -------------------------------------------------------------
  // In-Memory Cached State
  // -------------------------------------------------------------
  Map<String, dynamic> _data = {};
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Live Streams / Notifiers
  final StreamController<String> _settingChangesController =
      StreamController<String>.broadcast();
  Stream<String> get onSettingChanged => _settingChangesController.stream;

  // -------------------------------------------------------------
  // Initialization & Migration
  // -------------------------------------------------------------
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final file = await _getSettingsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          _data = jsonDecode(content) as Map<String, dynamic>;
        }
      }
      _migrateIfNeeded();
    } catch (e) {
      debugPrint('Error initializing SettingsRepository: $e');
      _data = {};
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  void _migrateIfNeeded() {
    final version = _data[keySchemaVersion] as int? ?? 0;
    if (version < currentSchemaVersion) {
      _data[keySchemaVersion] = currentSchemaVersion;
      _persistToFile();
    }
  }

  Future<File> _getSettingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_settingsFileName');
  }

  Future<void> _persistToFile() async {
    try {
      final file = await _getSettingsFile();
      final content = const JsonEncoder.withIndent('  ').convert(_data);
      await file.writeAsString(content, flush: true);
    } catch (e) {
      debugPrint('Error persisting settings: $e');
    }
  }

  void _notify(String key) {
    _settingChangesController.add(key);
    notifyListeners();
    _persistToFile();
  }

  // -------------------------------------------------------------
  // Getters & Setters
  // -------------------------------------------------------------

  // 1. Language ('system' | 'ar' | 'en' | 'fr')
  String get language => _data[keyLanguage] as String? ?? defaultLanguage;
  Future<void> setLanguage(String value) async {
    if (['system', 'ar', 'en', 'fr'].contains(value) && language != value) {
      _data[keyLanguage] = value;
      _notify(keyLanguage);
    }
  }

  // 2. Theme Mode ('system' | 'light' | 'dark')
  String get themeMode => _data[keyThemeMode] as String? ?? defaultThemeMode;
  Future<void> setThemeMode(String value) async {
    if (['system', 'light', 'dark'].contains(value)) {
      final bool modeChanged = themeMode != value;
      final bool hasCustomBg = bgType != defaultBgType || customBgImagePath != null;
      if (modeChanged || hasCustomBg) {
        _data[keyThemeMode] = value;
        // Forcibly reset any custom background/theme so dark or light mode takes full control
        _data[keyBgType] = defaultBgType;
        _data[keyCustomBgImagePath] = null;
        _notify(keyThemeMode);
        _notify(keyBgType);
      }
    }
  }

  // 3. Accent Color
  Color get accentColor {
    final val = _data[keyAccentColor] as int? ?? defaultAccentColorValue;
    return Color(val);
  }

  Future<void> setAccentColor(Color color) async {
    if (accentColor.value != color.value) {
      _data[keyAccentColor] = color.value;
      _notify(keyAccentColor);
    }
  }

  // 4. AMOLED Pure Black
  bool get amoledBlack => _data[keyAmoledBlack] as bool? ?? defaultAmoledBlack;
  Future<void> setAmoledBlack(bool value) async {
    if (amoledBlack != value) {
      _data[keyAmoledBlack] = value;
      _notify(keyAmoledBlack);
    }
  }

  // 5. Background Type ('default' | 'color' | 'image')
  String get bgType => _data[keyBgType] as String? ?? defaultBgType;
  Future<void> setBgType(String value) async {
    if (['default', 'color', 'image'].contains(value) && bgType != value) {
      _data[keyBgType] = value;
      _notify(keyBgType);
    }
  }

  // 6. Custom Background Color
  Color get customBgColor {
    final val = _data[keyCustomBgColor] as int? ?? defaultCustomBgColorValue;
    return Color(val);
  }

  Future<void> setCustomBgColor(Color color) async {
    _data[keyCustomBgColor] = color.value;
    _data[keyBgType] = 'color';
    _notify(keyCustomBgColor);
  }

  // 7. Custom Background Image Path
  String? get customBgImagePath => _data[keyCustomBgImagePath] as String?;
  String? get customBgRawImagePath => _data[keyCustomBgRawImagePath] as String?;

  // 8. Custom Background Blur (0.0 to 30.0)
  double get customBgBlur =>
      (_data[keyCustomBgBlur] as num?)?.toDouble() ?? defaultCustomBgBlur;
  Future<void> setCustomBgBlur(double value) async {
    final clamped = value.clamp(0.0, 30.0);
    if ((customBgBlur - clamped).abs() > 0.01) {
      _data[keyCustomBgBlur] = clamped;
      _notify(keyCustomBgBlur);
    }
  }

  // 9. Custom Background Opacity (0.1 to 1.0)
  double get customBgOpacity =>
      (_data[keyCustomBgOpacity] as num?)?.toDouble() ?? defaultCustomBgOpacity;
  Future<void> setCustomBgOpacity(double value) async {
    final clamped = value.clamp(0.1, 1.0);
    if ((customBgOpacity - clamped).abs() > 0.01) {
      _data[keyCustomBgOpacity] = clamped;
      _notify(keyCustomBgOpacity);
    }
  }

  // 10. Save Full Custom Background Image Configuration
  Future<void> setCustomBgImage({
    required String imagePath,
    String? rawImagePath,
    double? blur,
    double? opacity,
  }) async {
    _data[keyBgType] = 'image';
    _data[keyCustomBgImagePath] = imagePath;
    if (rawImagePath != null) {
      _data[keyCustomBgRawImagePath] = rawImagePath;
    }
    if (blur != null) {
      _data[keyCustomBgBlur] = blur.clamp(0.0, 30.0);
    }
    if (opacity != null) {
      _data[keyCustomBgOpacity] = opacity.clamp(0.1, 1.0);
    }
    _notify(keyCustomBgImagePath);
  }

  // 11. Clear Custom Background (Restore default theme background)
  Future<void> clearCustomBg() async {
    _data[keyBgType] = 'default';
    _notify(keyBgType);
  }

  // 12. Player Theme ('default' | 'vinyl')
  String get playerTheme {
    final t = _data[keyPlayerTheme] as String? ?? defaultPlayerTheme;
    if (t == 'waves') return 'default';
    return t;
  }

  Future<void> setPlayerTheme(String value) async {
    if (['default', 'vinyl'].contains(value) && playerTheme != value) {
      _data[keyPlayerTheme] = value;
      _notify(keyPlayerTheme);
    }
  }

  // 13. Landscape Display Color Mode ('app' | 'artwork')
  String get landscapeColorMode =>
      _data[keyLandscapeColorMode] as String? ?? defaultLandscapeColorMode;

  Future<void> setLandscapeColorMode(String value) async {
    if (['app', 'artwork'].contains(value) && landscapeColorMode != value) {
      _data[keyLandscapeColorMode] = value;
      _notify(keyLandscapeColorMode);
    }
  }

  // 14. Audio Effect ('none' | 'deep_echo')
  String get audioEffect =>
      _data[keyAudioEffect] as String? ?? defaultAudioEffect;

  Future<void> setAudioEffect(String value) async {
    if (audioEffect != value) {
      _data[keyAudioEffect] = value;
      _notify(keyAudioEffect);
    }
  }

  // -------------------------------------------------------------
  // Reset All Settings to Default (Safe: Keeps playlists & songs)
  // -------------------------------------------------------------
  Future<void> resetAllSettings() async {
    _data = {
      keySchemaVersion: currentSchemaVersion,
      keyLanguage: defaultLanguage,
      keyThemeMode: defaultThemeMode,
      keyAccentColor: defaultAccentColorValue,
      keyAmoledBlack: defaultAmoledBlack,
      keyBgType: defaultBgType,
      keyCustomBgColor: defaultCustomBgColorValue,
      keyCustomBgBlur: defaultCustomBgBlur,
      keyCustomBgOpacity: defaultCustomBgOpacity,
      keyPlayerTheme: defaultPlayerTheme,
      keyLandscapeColorMode: defaultLandscapeColorMode,
      keyAudioEffect: defaultAudioEffect,
    };
    await _persistToFile();
    _settingChangesController.add('reset');
    notifyListeners();
  }
}
