import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md_music/services/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsRepository Defaults & State Tests', () {
    late SettingsRepository repo;

    setUp(() {
      repo = SettingsRepository();
    });

    test('Initial defaults match specifications', () {
      expect(repo.language, equals('system'));
      expect(repo.themeMode, equals('system'));
      expect(repo.accentColor.value, equals(0xFF00E676));
      expect(repo.amoledBlack, isFalse);
    });

    test('Mutations update getters correctly', () async {
      await repo.setLanguage('ar');
      expect(repo.language, equals('ar'));

      await repo.setThemeMode('dark');
      expect(repo.themeMode, equals('dark'));

      await repo.setAmoledBlack(true);
      expect(repo.amoledBlack, isTrue);

      await repo.setAccentColor(const Color(0xFF2979FF));
      expect(repo.accentColor, equals(const Color(0xFF2979FF)));
    });

    test('Reset restores all defaults cleanly', () async {
      await repo.setLanguage('en');
      await repo.setThemeMode('light');
      await repo.setAmoledBlack(true);
      await repo.setAccentColor(const Color(0xFFFF5252));

      await repo.resetAllSettings();

      expect(repo.language, equals('system'));
      expect(repo.themeMode, equals('system'));
      expect(repo.accentColor.value, equals(0xFF00E676));
      expect(repo.amoledBlack, isFalse);
    });
  });
}
