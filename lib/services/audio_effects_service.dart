import 'package:flutter/material.dart';
import 'audio_service.dart';
import 'language_service.dart';
import 'settings_repository.dart';

class AudioEffectItem {
  final String id;
  final String titleAr;
  final String titleEn;
  final String descAr;
  final String descEn;
  final IconData icon;

  const AudioEffectItem({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.descAr,
    required this.descEn,
    required this.icon,
  });

  String get title => LanguageService().isArabic ? titleAr : titleEn;
  String get description => LanguageService().isArabic ? descAr : descEn;
}

class AudioEffectsService extends ChangeNotifier {
  static final AudioEffectsService _instance = AudioEffectsService._internal();
  factory AudioEffectsService() => _instance;
  AudioEffectsService._internal();

  static const String effectNone = 'none';
  static const String effectDeepEcho = 'deep_echo';

  /// Registry of available effects. Easily extensible for future additions!
  final List<AudioEffectItem> availableEffects = const [
    AudioEffectItem(
      id: effectNone,
      titleAr: 'بدون مؤثرات',
      titleEn: 'Original (Off)',
      descAr: 'الصوت الطبيعي الأصلي بدون أي تعديل',
      descEn: 'Natural original sound without processing',
      icon: Icons.music_note_rounded,
    ),
    AudioEffectItem(
      id: effectDeepEcho,
      titleAr: 'الصدى العميق',
      titleEn: 'Deep Echo',
      descAr: 'صوت عميق وغني مع صدى خفيف محيطي وتضخيم هادئ',
      descEn: 'Deep resonant bass & subtle atmospheric echo',
      icon: Icons.waves_rounded,
    ),
  ];

  String _activeEffect = effectNone;
  String get activeEffect => _activeEffect;

  bool get hasActiveEffect => _activeEffect != effectNone;

  String get activeEffectTitle {
    final effect = availableEffects.firstWhere(
      (e) => e.id == _activeEffect,
      orElse: () => availableEffects.first,
    );
    return effect.title;
  }

  void init() {
    final repo = SettingsRepository();
    _activeEffect = repo.audioEffect;
    AudioService().applyAudioEffect(_activeEffect);
  }

  Future<void> setEffect(String effectId) async {
    if (_activeEffect == effectId) return;
    _activeEffect = effectId;
    await SettingsRepository().setAudioEffect(effectId);
    await AudioService().applyAudioEffect(effectId);
    notifyListeners();
  }
}
