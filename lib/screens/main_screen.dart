import 'package:flutter/material.dart';
import '../services/app_preferences.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../services/song_selection_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bulk_selection_action_bar.dart';
import '../widgets/global_app_background.dart';
import '../widgets/mini_player.dart';
import 'home_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    // Guarantee that onboarding is permanently marked as completed
    AppPreferences.setOnboardingCompleted();
  }

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
        SongSelectionService(),
      ]),
      builder: (context, _) {
        final currentLang = LanguageService().activeLanguageCode;
        final isDark = AppTheme.isDark;
        final accent = AppTheme.accentColor.value;
        final amoled = AppTheme.amoledBlackNotifier.value;
        final bgType = AppTheme.bgTypeNotifier.value;
        final customColor = AppTheme.customBgColorNotifier.value.value;
        final customImage = AppTheme.customBgImageNotifier.value ?? '';
        final selection = SongSelectionService();

        return PopScope(
          canPop: !selection.isSelectionMode,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (selection.isSelectionMode) {
              selection.clearSelection();
            }
          },
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Stack(
              children: [
                // Persistent background layer (color or image with blur & opacity)
                const Positioned.fill(
                  child: GlobalAppBackground(),
                ),

                // Main Content (Rebuilds instantly when language, theme, accent, AMOLED, or background changes)
                HomeScreen(
                  key: ValueKey('home_${currentLang}_${isDark}_${accent}_${amoled}_${bgType}_${customColor}_$customImage'),
                ),

                // Docked MiniPlayer at the bottom extending edge-to-edge
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: MiniPlayer(),
                ),

                // Floating Bulk Selection Action Bar
                AnimatedBuilder(
                  animation: AudioService(),
                  builder: (context, _) {
                    final hasSong = AudioService().currentSong != null;
                    return BulkSelectionActionBar(
                      bottomOffset: hasSong ? 86 : 18,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
