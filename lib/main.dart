import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/album_service.dart';
import 'services/app_preferences.dart';
import 'services/audio_effects_service.dart';
import 'services/audio_service.dart';
import 'services/language_service.dart';
import 'services/settings_repository.dart';
import 'services/volume_service.dart';
import 'theme/app_theme.dart';
import 'widgets/global_app_background.dart';
import 'widgets/volume_hud.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 1. Initialize persistent Settings Repository first to eliminate any theme/language flash
  await SettingsRepository().init();
  AppTheme.init();
  LanguageService().init();
  AudioEffectsService().init();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.mbd.music.channel.audio',
    androidNotificationChannelName: 'MD Music Playback',
    androidNotificationOngoing: false,
    androidStopForegroundOnPause: false,
    androidNotificationIcon: 'mipmap/ic_launcher',
    androidShowNotificationBadge: true,
    notificationColor: AppTheme.accentColor,
  );

  // Synchronize system UI overlay brightness live
  AppTheme.updateSystemUIOverlay();

  // Request highest available display refresh rate (120Hz/90Hz)
  try {
    const MethodChannel('com.mbd.music/artwork')
        .invokeMethod('enableHighRefreshRate');
  } catch (_) {}

  // Initialize custom volume interception and service
  VolumeService().init();

  // Initialize custom albums storage
  await AlbumService().init();

  // Check if onboarding/intro has already been completed
  final bool isFirstLaunchDone = await AppPreferences.isOnboardingCompleted();

  runApp(MDMusicApp(
    initialScreen:
        isFirstLaunchDone ? const MainScreen() : const OnboardingScreen(),
  ));

  // Proactively check permission and load local library
  AudioService().checkAndRequestPermissions();
}

class MDMusicApp extends StatelessWidget {
  final Widget initialScreen;

  const MDMusicApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        AppTheme.themeModeNotifier,
        AppTheme.accentColorNotifier,
        AppTheme.amoledBlackNotifier,
        AppTheme.bgTypeNotifier,
        AppTheme.customBgColorNotifier,
        AppTheme.customBgImageNotifier,
        AppTheme.customBgBlurNotifier,
        AppTheme.customBgOpacityNotifier,
        LanguageService().currentLanguage,
      ]),
      builder: (context, _) {
        final effectiveThemeMode = AppTheme.themeModeNotifier.value != ThemeMode.system
            ? AppTheme.themeModeNotifier.value
            : (AppTheme.bgTypeNotifier.value == 'color'
                ? (AppTheme.isDark ? ThemeMode.dark : ThemeMode.light)
                : ThemeMode.system);
        final currentLocale = LanguageService().currentLocale;
        final textDir = LanguageService().textDirection;

        return MaterialApp(
          title: 'MD Music',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: effectiveThemeMode,
          locale: currentLocale,
          supportedLocales: const [
            Locale('ar'),
            Locale('en'),
            Locale('fr'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: initialScreen,
          builder: (context, child) {
            return Directionality(
              textDirection: textDir,
              child: Stack(
                children: [
                  const Positioned.fill(child: GlobalAppBackground()),
                  ?child,
                  const VolumeHud(),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
