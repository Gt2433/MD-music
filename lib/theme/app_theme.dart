import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_repository.dart';

class AppTheme {
  // Theme Mode State
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static final ValueNotifier<Color> accentColorNotifier =
      ValueNotifier<Color>(const Color(0xFF00E676));

  static final ValueNotifier<bool> amoledBlackNotifier =
      ValueNotifier<bool>(false);

  // Background Customization State
  static final ValueNotifier<String> bgTypeNotifier =
      ValueNotifier<String>('default'); // 'default' | 'color' | 'image'
  static final ValueNotifier<Color> customBgColorNotifier =
      ValueNotifier<Color>(const Color(0xFF0C1015));
  static final ValueNotifier<String?> customBgImageNotifier =
      ValueNotifier<String?>(null);
  static final ValueNotifier<double> customBgBlurNotifier =
      ValueNotifier<double>(0.0);
  static final ValueNotifier<double> customBgOpacityNotifier =
      ValueNotifier<double>(1.0);
  static final ValueNotifier<String> playerThemeNotifier =
      ValueNotifier<String>('default'); // 'default' | 'vinyl' | 'waves'
  static final ValueNotifier<String> landscapeColorModeNotifier =
      ValueNotifier<String>('artwork'); // 'app' | 'artwork'

  static bool get isDark {
    // 1. Explicit user selection of dark or light mode takes absolute priority
    if (themeModeNotifier.value == ThemeMode.dark) {
      return true;
    }
    if (themeModeNotifier.value == ThemeMode.light) {
      return false;
    }
    // 2. In system mode, respect custom background color or image
    if (bgTypeNotifier.value == 'color') {
      final lum = customBgColorNotifier.value.computeLuminance();
      return lum < 0.32;
    }
    if (bgTypeNotifier.value == 'image') {
      return true;
    }
    // 3. Fallback to platform brightness
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark;
  }

  static void init() {
    final repo = SettingsRepository();
    _applyFromRepo(repo);
    repo.onSettingChanged.listen((_) => _applyFromRepo(repo));
  }

  static void _applyFromRepo(SettingsRepository repo) {
    switch (repo.themeMode) {
      case 'dark':
        themeModeNotifier.value = ThemeMode.dark;
        break;
      case 'light':
        themeModeNotifier.value = ThemeMode.light;
        break;
      case 'system':
      default:
        themeModeNotifier.value = ThemeMode.system;
        break;
    }
    accentColorNotifier.value = repo.accentColor;
    amoledBlackNotifier.value = repo.amoledBlack;
    bgTypeNotifier.value = repo.bgType;
    customBgColorNotifier.value = repo.customBgColor;
    customBgImageNotifier.value = repo.customBgImagePath;
    customBgBlurNotifier.value = repo.customBgBlur;
    customBgOpacityNotifier.value = repo.customBgOpacity;
    playerThemeNotifier.value = repo.playerTheme;
    landscapeColorModeNotifier.value = repo.landscapeColorMode;
    updateSystemUIOverlay();
  }

  static void updateSystemUIOverlay() {
    final dark = isDark;
    final amoled = amoledBlackNotifier.value;
    final bgType = bgTypeNotifier.value;

    Color navColor;
    if (bgType == 'color') {
      navColor = customBgColorNotifier.value;
    } else if (bgType == 'image') {
      navColor = const Color(0xFF0C1015);
    } else {
      navColor = dark
          ? (amoled ? Colors.black : const Color(0xFF121720))
          : Colors.white;
    }

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: navColor,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  static Future<void> setThemeMode(String mode) async {
    await SettingsRepository().setThemeMode(mode);
    // Forcibly clear custom background so dark/light mode takes over unconditionally
    bgTypeNotifier.value = 'default';
    customBgImageNotifier.value = null;
    switch (mode) {
      case 'dark':
        themeModeNotifier.value = ThemeMode.dark;
        break;
      case 'light':
        themeModeNotifier.value = ThemeMode.light;
        break;
      case 'system':
      default:
        themeModeNotifier.value = ThemeMode.system;
        break;
    }
    updateSystemUIOverlay();
  }

  static Future<void> setLandscapeColorMode(String mode) async {
    await SettingsRepository().setLandscapeColorMode(mode);
    landscapeColorModeNotifier.value = mode;
  }

  // Dynamic Active Theme Colors (auto-switches for all screens)
  static Color get background {
    if (bgTypeNotifier.value == 'image') {
      return Colors.transparent;
    }
    if (bgTypeNotifier.value == 'color') {
      return customBgColorNotifier.value;
    }
    return isDark
        ? (amoledBlackNotifier.value ? Colors.black : darkBackground)
        : lightBackground;
  }

  static Color get surface {
    if (bgTypeNotifier.value == 'image') {
      return const Color(0xFF141A23).withOpacity(0.88);
    }
    if (bgTypeNotifier.value == 'color') {
      final base = customBgColorNotifier.value;
      final dark = isDark;
      return Color.alphaBlend(
        dark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.04),
        base,
      );
    }
    return isDark
        ? (amoledBlackNotifier.value ? const Color(0xFF080808) : darkSurface)
        : lightSurface;
  }

  static Color get surfaceLight {
    if (bgTypeNotifier.value == 'image') {
      return const Color(0xFF1C2430).withOpacity(0.85);
    }
    if (bgTypeNotifier.value == 'color') {
      final base = customBgColorNotifier.value;
      final dark = isDark;
      return Color.alphaBlend(
        dark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
        base,
      );
    }
    return isDark
        ? (amoledBlackNotifier.value ? const Color(0xFF101010) : darkSurfaceLight)
        : lightSurfaceLight;
  }

  static Color get cardColor {
    if (bgTypeNotifier.value == 'image') {
      return const Color(0xFF161E28).withOpacity(0.84);
    }
    if (bgTypeNotifier.value == 'color') {
      final base = customBgColorNotifier.value;
      final dark = isDark;
      return Color.alphaBlend(
        dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        base,
      );
    }
    return isDark
        ? (amoledBlackNotifier.value ? const Color(0xFF0A0A0A) : darkCardColor)
        : lightCardColor;
  }

  static Color get cardBorder {
    if (bgTypeNotifier.value == 'image') {
      return const Color(0xFF2A3648).withOpacity(0.60);
    }
    if (bgTypeNotifier.value == 'color') {
      final base = customBgColorNotifier.value;
      final dark = isDark;
      return Color.alphaBlend(
        dark ? Colors.white.withOpacity(0.16) : Colors.black.withOpacity(0.12),
        base,
      );
    }
    return isDark
        ? (amoledBlackNotifier.value ? const Color(0xFF1F1F1F) : darkCardBorder)
        : lightCardBorder;
  }
  static Color get textPrimary {
    if (bgTypeNotifier.value == 'color') {
      final lum = customBgColorNotifier.value.computeLuminance();
      return lum < 0.32 ? Colors.white : const Color(0xFF0F172A);
    }
    if (bgTypeNotifier.value == 'image') {
      return Colors.white;
    }
    return isDark ? darkTextPrimary : lightTextPrimary;
  }

  static Color get textSecondary {
    if (bgTypeNotifier.value == 'color') {
      final lum = customBgColorNotifier.value.computeLuminance();
      return lum < 0.32
          ? Colors.white.withOpacity(0.85) // High-contrast crisp light silver-white on dark/grey
          : const Color(0xFF1E293B).withOpacity(0.85); // High-contrast deep dark charcoal on light/grey
    }
    if (bgTypeNotifier.value == 'image') {
      return Colors.white.withOpacity(0.85);
    }
    return isDark ? darkTextSecondary : lightTextSecondary;
  }

  static Color get textMuted {
    if (bgTypeNotifier.value == 'color') {
      final lum = customBgColorNotifier.value.computeLuminance();
      return lum < 0.32
          ? Colors.white.withOpacity(0.65)
          : const Color(0xFF334155).withOpacity(0.70);
    }
    if (bgTypeNotifier.value == 'image') {
      return Colors.white.withOpacity(0.65);
    }
    return isDark ? darkTextMuted : lightTextMuted;
  }

  static Color get dividerColor {
    if (bgTypeNotifier.value == 'color') {
      final dark = isDark;
      return dark
          ? Colors.white.withOpacity(0.12)
          : Colors.black.withOpacity(0.10);
    }
    return isDark ? darkDividerColor : lightDividerColor;
  }

  // Dark Theme Palette Constants (Guaranteed crisp light contrast, NEVER muddy grey)
  static const Color darkBackground = Color(0xFF0C1015);
  static const Color darkSurface = Color(0xFF141A23);
  static const Color darkSurfaceLight = Color(0xFF1C2430);
  static const Color darkCardColor = Color(0xFF161E28);
  static const Color darkCardBorder = Color(0xFF243040);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFF1F5F9); // Crisp bright silver-white
  static const Color darkTextMuted = Color(0xFFCBD5E1);     // Readable light silver
  static const Color darkDividerColor = Color(0xFF1E2836);
  static const Color errorColor = Color(0xFFFF5252);

  // Light Theme Palette Constants (Guaranteed deep dark contrast, NEVER muddy grey)
  static const Color lightBackground = Color(0xFFF4F6F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLight = Color(0xFFEDF2F7);
  static const Color lightCardColor = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF1E293B); // Deep crisp dark charcoal
  static const Color lightTextMuted = Color(0xFF334155);     // Clear dark slate
  static const Color lightDividerColor = Color(0xFFE2E8F0);

  // Fallback brand constant (used as default)
  static const Color defaultGreen = Color(0xFF00E676);
  static Color get primaryGreen => accentColorNotifier.value;
  static const Color accentTeal = Color(0xFF00B4D8);

  // Dynamic Accent Brand Color (binds live to Settings)
  static Color get accentColor => accentColorNotifier.value;

  // Aliases for compatibility
  static Color get dynamicBackground => background;
  static Color get dynamicSurface => surface;
  static Color get dynamicSurfaceLight => surfaceLight;
  static Color get dynamicCardColor => cardColor;
  static Color get dynamicCardBorder => cardBorder;
  static Color get dynamicTextPrimary => textPrimary;
  static Color get dynamicTextSecondary => textSecondary;
  static Color get dynamicTextMuted => textMuted;
  static Color get dynamicDivider => dividerColor;

  // Dark Theme Definition
  static ThemeData get darkTheme {
    final amoled = amoledBlackNotifier.value;
    final primary = accentColor;
    final bg = amoled ? Colors.black : darkBackground;
    final surf = amoled ? const Color(0xFF080808) : darkSurface;
    final card = amoled ? const Color(0xFF0A0A0A) : darkCardColor;
    final border = amoled ? const Color(0xFF1F1F1F) : darkCardBorder;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      primaryColor: primary,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: primary,
        surface: surf,
        onPrimary: Colors.black,
        onSurface: Colors.white,
        onSurfaceVariant: darkTextSecondary,
        outline: border,
        error: errorColor,
      ),
      fontFamily: 'Segoe UI',
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: const Color(0xFF131823).withOpacity(0.82),
        modalBackgroundColor: const Color(0xFF131823).withOpacity(0.82),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF131822).withOpacity(0.82),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.14), width: 1.2),
        ),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: darkTextSecondary,
          fontSize: 14,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: amoled ? Colors.black : const Color(0xFF121720),
        selectedItemColor: primary,
        unselectedItemColor: const Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
        inactiveTrackColor: Colors.white.withOpacity(0.15),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return const Color(0xFF94A3B8);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withOpacity(0.4);
          }
          return Colors.white.withOpacity(0.1);
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: darkDividerColor,
        thickness: 1,
      ),
    );
  }

  // Light Theme Definition
  static ThemeData get lightTheme {
    final primary = accentColor;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: primary,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: primary,
        surface: Colors.white,
        onPrimary: Colors.black,
        onSurface: lightTextPrimary,
        onSurfaceVariant: lightTextSecondary,
        outline: lightCardBorder,
        error: errorColor,
      ),
      fontFamily: 'Segoe UI',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 19,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightCardBorder, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white.withOpacity(0.84),
        modalBackgroundColor: Colors.white.withOpacity(0.84),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white.withOpacity(0.84),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.black.withOpacity(0.08), width: 1.2),
        ),
        titleTextStyle: const TextStyle(
          color: lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: lightTextSecondary,
          fontSize: 14,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: const Color(0xFF64748B),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        thumbColor: primary,
        inactiveTrackColor: Colors.black.withOpacity(0.1),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return const Color(0xFF94A3B8);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withOpacity(0.35);
          }
          return Colors.black.withOpacity(0.08);
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: lightDividerColor,
        thickness: 1,
      ),
    );
  }
}
