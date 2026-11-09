import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/language_service.dart';
import '../services/settings_repository.dart';
import '../widgets/settings_tiles.dart';
import '../widgets/about_glass_dialog.dart';
import '../widgets/glass_dialog.dart';
import 'themes_settings_screen.dart';
import '../widgets/font_size_selector_sheet.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/listening_insights_sheet.dart';
import '../widgets/song_sort_sheet.dart';
import '../services/audio_service.dart';
import '../services/app_update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsRepository _repo = SettingsRepository();

  static const String appVersion = '2.0.0';
  static const int appBuildNumber = 3;

  String _versionName = appVersion;
  int _versionCode = appBuildNumber;

  static const MethodChannel _nativeChannel =
      MethodChannel('com.mbd.music/artwork');

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info =
          await _nativeChannel.invokeMapMethod<String, dynamic>('getPackageInfo');
      if (info != null && mounted) {
        final nativeVer = info['versionName']?.toString();
        if (nativeVer != null && nativeVer.isNotEmpty && nativeVer != '1.0.0') {
          setState(() {
            _versionName = nativeVer;
            _versionCode = (info['versionCode'] as num?)?.toInt() ?? appBuildNumber;
          });
        } else {
          setState(() {
            _versionName = appVersion;
            _versionCode = appBuildNumber;
          });
        }
      }
    } catch (_) {}
  }

  bool _isCheckingUpdate = false;

  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              LanguageService().t('checking_updates_msg'),
              style: TextStyle(color: AppTheme.textPrimary),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.surface,
      ),
    );

    final release = await AppUpdateService().checkForUpdate();
    if (!mounted) return;
    setState(() => _isCheckingUpdate = false);

    if (release != null) {
      AppUpdateService.showUpdateDialog(
        context,
        release,
        currentVersion: _versionName,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LanguageService().t('latest_version_msg').replaceAll('{version}', _versionName),
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          backgroundColor: AppTheme.surface,
        ),
      );
    }
  }

  void _showLanguageDialog() {
    final current = _repo.language;
    showDialog(
      context: context,
      builder: (ctx) => SettingsRadioDialog<String>(
        title: LanguageService.tr('language'),
        selectedValue: current,
        options: [
          SettingsRadioOption<String>(
            title: LanguageService.tr('language_system'),
            value: 'system',
          ),
          const SettingsRadioOption<String>(
            title: 'العربية (Arabic)',
            value: 'ar',
          ),
          const SettingsRadioOption<String>(
            title: 'English (الإنجليزية)',
            value: 'en',
          ),
          const SettingsRadioOption<String>(
            title: 'Français (الفرنسية)',
            value: 'fr',
          ),
        ],
        onSelected: (val) async {
          await _repo.setLanguage(val);
          await LanguageService().setLanguage(val);
          if (mounted) setState(() {});
        },
      ),
    );
  }


  void _confirmResetSettings() {
    showDialog(
      context: context,
      builder: (ctx) {
        return GlassDialog(
          title: Text(
            LanguageService.tr('reset_settings_title'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          content: Text(
            LanguageService.tr('reset_settings_desc'),
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                LanguageService.tr('cancel'),
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                await _repo.resetAllSettings();
                await LanguageService().setLanguage(_repo.language);
                await AppTheme.setThemeMode(_repo.themeMode);
                AppTheme.accentColorNotifier.value = _repo.accentColor;
                AppTheme.amoledBlackNotifier.value = _repo.amoledBlack;
                if (mounted) {
                  setState(() {});
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(LanguageService.tr('reset_settings_done')),
                      backgroundColor: AppTheme.surface,
                    ),
                  );
                }
              },
              child: Text(
                LanguageService.tr('reset'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getLanguageSubtitle() {
    switch (_repo.language) {
      case 'ar':
        return 'العربية';
      case 'en':
        return 'English';
      case 'fr':
        return 'Français';
      default:
        return LanguageService.tr('language_system');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          LanguageService.tr('settings'),
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SECTION 1: Appearance (المظهر)
            _buildAppearanceSection(),

            // SECTION 2: Audio & Smart Features (الصوت والمؤثرات)
            _buildAudioAndFeaturesSection(),

            // SECTION 3: About (حول التطبيق)
            _buildAboutSection(),

            // Reset All Settings Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Center(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: AppTheme.errorColor.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                  ),
                  onPressed: _confirmResetSettings,
                  icon: Icon(Icons.restore_rounded,
                      color: AppTheme.errorColor, size: 20),
                  label: Text(
                    LanguageService.tr('reset_all_settings'),
                    style: TextStyle(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Section 1: Appearance
  // -------------------------------------------------------------
  Widget _buildAppearanceSection() {
    final accentColor = AppTheme.accentColor;

    return SettingsSection(
      title: LanguageService.tr('appearance'),
      children: [
        // 1.1 Language (اللغة)
        SettingsNavigationTile(
          icon: Icons.translate_rounded,
          title: LanguageService.tr('language'),
          subtitle: _getLanguageSubtitle(),
          onTap: _showLanguageDialog,
        ),
        // 1.2 Themes (الثيمات)
        SettingsNavigationTile(
          icon: Icons.palette_rounded,
          title: LanguageService.tr('themes'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.45),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppTheme.textMuted,
              ),
            ],
          ),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ThemesSettingsScreen()),
            );
            if (mounted) setState(() {});
          },
        ),
        // 1.3 Font Size (حجم الخط)
        SettingsNavigationTile(
          icon: Icons.format_size_rounded,
          title: LanguageService.tr('font_size'),
          subtitle: '${(_repo.fontScale * 100).round()}% • ${LanguageService.tr('font_size_desc')}',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(_repo.fontScale * 100).round()}%',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppTheme.textMuted,
              ),
            ],
          ),
          onTap: () async {
            await FontSizeSelectorSheet.show(context);
            if (mounted) setState(() {});
          },
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Section 2: Audio & Smart Features
  // -------------------------------------------------------------
  Widget _buildAudioAndFeaturesSection() {
    return SettingsSection(
      title: LanguageService().t('audio_and_features'),
      children: [
        // Equalizer
        SettingsNavigationTile(
          icon: Icons.equalizer_rounded,
          title: LanguageService().t('equalizer_bass_title'),
          subtitle: LanguageService().t('equalizer_bass_desc'),
          onTap: () => EqualizerSheet.show(context),
        ),
        // Sleep Timer
        SettingsNavigationTile(
          icon: Icons.bedtime_rounded,
          title: LanguageService().t('smart_sleep_timer'),
          subtitle: LanguageService().t('smart_sleep_timer_sub'),
          onTap: () => SleepTimerSheet.show(context),
        ),
        // Listening Insights
        SettingsNavigationTile(
          icon: Icons.auto_graph_rounded,
          title: LanguageService().t('listening_insights_title'),
          subtitle: LanguageService().t('listening_insights_subtitle'),
          onTap: () => ListeningInsightsSheet.show(context),
        ),
        // Filter Short Audios (< 60 seconds)
        SettingsSwitchTile(
          icon: Icons.filter_alt_rounded,
          title: LanguageService().t('ignore_short_tracks'),
          subtitle: LanguageService().t('ignore_short_tracks_sub'),
          value: _repo.filterShortAudios,
          onChanged: (val) async {
            await _repo.setFilterShortAudios(val);
            if (mounted) setState(() {});
          },
        ),
        // Default Song Sorting
        SettingsNavigationTile(
          icon: Icons.swap_vert_rounded,
          title: LanguageService().t('default_song_sort'),
          subtitle: AudioService().currentSortLabel,
          onTap: () async {
            await SongSortSheet.show(context);
            if (mounted) setState(() {});
          },
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Section 3: About
  // -------------------------------------------------------------
  Widget _buildAboutSection() {
    final accentColor = AppTheme.accentColor;

    return SettingsSection(
      title: LanguageService.tr('about'),
      children: [
        // App Header Tile (Tap to open Glassmorphic Dialog)
        InkWell(
          onTap: () => showAboutGlassDialog(
            context,
            versionName: _versionName,
            versionCode: _versionCode,
          ),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stack) => Icon(
                        Icons.music_note_rounded,
                        color: accentColor,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MD Music',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v$_versionName • Mohammed Bahayou',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
        // Check for Updates Tile
        SettingsNavigationTile(
          icon: Icons.system_update_rounded,
          title: LanguageService().t('check_for_updates'),
          subtitle: LanguageService().t('check_for_updates_sub'),
          trailing: _isCheckingUpdate
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                )
              : null,
          onTap: _checkForUpdates,
        ),
        // Copyright
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Center(
            child: Text(
              LanguageService.tr('copyright'),
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
