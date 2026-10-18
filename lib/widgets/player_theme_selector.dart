import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/language_service.dart';
import '../services/settings_repository.dart';
import '../theme/app_theme.dart';

/// Shows a sleek bottom sheet to choose the Now Playing screen theme style
void showPlayerThemeSelector(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const PlayerThemeSelectorSheet(),
  );
}

class PlayerThemeSelectorSheet extends StatefulWidget {
  const PlayerThemeSelectorSheet({super.key});

  @override
  State<PlayerThemeSelectorSheet> createState() =>
      _PlayerThemeSelectorSheetState();
}

class _PlayerThemeSelectorSheetState extends State<PlayerThemeSelectorSheet> {
  late String _selectedTheme;

  @override
  void initState() {
    super.initState();
    _selectedTheme = SettingsRepository().playerTheme;
    if (_selectedTheme == 'waves') {
      _selectedTheme = 'default';
      SettingsRepository().setPlayerTheme('default');
      AppTheme.playerThemeNotifier.value = 'default';
    }
  }

  void _selectTheme(String theme) async {
    HapticFeedback.mediumImpact();
    setState(() => _selectedTheme = theme);
    await SettingsRepository().setPlayerTheme(theme);
    AppTheme.playerThemeNotifier.value = theme;

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark;
    final accent = AppTheme.accentColor;

    return Directionality(
      textDirection: LanguageService().textDirection,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF080D16).withOpacity(0.48)
                  : Colors.white.withOpacity(0.58),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.18)
                    : Colors.black.withOpacity(0.10),
                width: 1.2,
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.style_rounded,
                            color: accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LanguageService.tr('select_player_theme'),
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textPrimary,
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              LanguageService.tr('player_theme_desc'),
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white60
                                    : AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: isDark ? Colors.white60 : Colors.black45),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Theme 1: Default (Classic Album Art)
                  _buildThemeOptionTile(
                    keyName: 'default',
                    icon: Icons.crop_square_rounded,
                    title: LanguageService.tr('player_theme_default'),
                    description:
                        LanguageService.tr('player_theme_default_desc'),
                    accent: accent,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 10),

                  // Theme 2: Vinyl Disc
                  _buildThemeOptionTile(
                    keyName: 'vinyl',
                    icon: Icons.album_rounded,
                    title: LanguageService.tr('player_theme_vinyl'),
                    description: LanguageService.tr('player_theme_vinyl_desc'),
                    accent: accent,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOptionTile({
    required String keyName,
    required IconData icon,
    required String title,
    required String description,
    required Color accent,
    required bool isDark,
  }) {
    final isSelected = _selectedTheme == keyName;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _selectTheme(keyName),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withOpacity(0.12)
                : (isDark ? const Color(0xFF161F2C) : AppTheme.surfaceLight),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? accent
                  : (isDark ? const Color(0xFF243042) : AppTheme.cardBorder),
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accent.withOpacity(0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent
                      : (isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.06)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? Colors.black
                      : (isDark ? Colors.white : AppTheme.textPrimary),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected
                            ? accent
                            : (isDark ? Colors.white : AppTheme.textPrimary),
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        color: isDark ? Colors.white60 : AppTheme.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isSelected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.black, size: 16),
                )
              else
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black26,
                      width: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
