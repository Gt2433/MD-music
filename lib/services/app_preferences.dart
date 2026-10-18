import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AppPreferences {
  static const String _onboardingFileName = 'onboarding_completed.flag';

  /// Returns true if the user has already completed onboarding / login
  static Future<bool> isOnboardingCompleted() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_onboardingFileName');
      return await file.exists();
    } catch (e) {
      debugPrint('Error reading onboarding status: $e');
      return false;
    }
  }

  /// Marks the onboarding as completed and persists it permanently
  static Future<void> setOnboardingCompleted() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_onboardingFileName');
      await file.writeAsString('true');
    } catch (e) {
      debugPrint('Error saving onboarding status: $e');
    }
  }

  /// Resets the onboarding status (for testing or re-showing from settings)
  static Future<void> resetOnboarding() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_onboardingFileName');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error resetting onboarding: $e');
    }
  }

  static const String _volumeFileName = 'player_volume.dat';

  /// Returns the saved volume or null if not saved
  static Future<double?> getSavedVolume() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_volumeFileName');
      if (await file.exists()) {
        final text = await file.readAsString();
        final val = double.tryParse(text);
        if (val != null) {
          return val.clamp(0.0, 1.0);
        }
      }
    } catch (e) {
      debugPrint('Error reading saved volume: $e');
    }
    return null;
  }

  /// Saves the player volume permanently
  static Future<void> setSavedVolume(double volume) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_volumeFileName');
      await file.writeAsString(volume.toStringAsFixed(3));
    } catch (e) {
      debugPrint('Error saving volume: $e');
    }
  }

  static const String _themeFileName = 'app_theme_mode.dat';

  /// Returns true for dark, false for light, null if not set
  static Future<bool?> getSavedThemeMode() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_themeFileName');
      if (await file.exists()) {
        final text = (await file.readAsString()).trim();
        return text == 'dark';
      }
    } catch (e) {
      debugPrint('Error reading saved theme: $e');
    }
    return null;
  }

  /// Saves the theme mode permanently ('dark' or 'light')
  static Future<void> setSavedThemeMode(bool isDark) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_themeFileName');
      await file.writeAsString(isDark ? 'dark' : 'light');
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  static const String _languageFileName = 'app_language.dat';

  /// Returns saved language code ('ar', 'fr', 'en') or null
  static Future<String?> getSavedLanguage() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_languageFileName');
      if (await file.exists()) {
        final text = (await file.readAsString()).trim();
        if (text.isNotEmpty) return text;
      }
    } catch (e) {
      debugPrint('Error reading saved language: $e');
    }
    return null;
  }

  /// Saves the language code permanently
  static Future<void> setSavedLanguage(String lang) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_languageFileName');
      await file.writeAsString(lang);
    } catch (e) {
      debugPrint('Error saving language: $e');
    }
  }
}
