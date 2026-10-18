import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/language_service.dart';
import '../services/settings_repository.dart';
import '../widgets/settings_tiles.dart';
import '../widgets/about_glass_dialog.dart';
import '../widgets/custom_background_color_sheet.dart';
import '../widgets/player_theme_selector.dart';
import '../widgets/glass_dialog.dart';
import 'custom_background_editor_screen.dart';
import '../services/app_update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsRepository _repo = SettingsRepository();

  String _versionName = '1.0.0';
  int _versionCode = 1;

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
        setState(() {
          _versionName = info['versionName']?.toString() ?? '1.0.0';
          _versionCode = (info['versionCode'] as num?)?.toInt() ?? 1;
        });
      }
    } catch (_) {}
  }

  bool _isCheckingUpdate = false;

  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);

    final isArabic = LanguageService().isArabic;
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
              isArabic
                  ? 'جاري التحقق من وجود تحديثات...'
                  : 'Checking for updates...',
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
            isArabic
                ? 'أنت تستخدم أحدث إصدار بالفعل (v$_versionName)'
                : 'You are using the latest version (v$_versionName)',
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

  void _showThemeModeDialog() {
    final current = _repo.themeMode;
    showDialog(
      context: context,
      builder: (ctx) => SettingsRadioDialog<String>(
        title: LanguageService.tr('theme_mode'),
        selectedValue: current,
        options: [
          SettingsRadioOption<String>(
            title: LanguageService.tr('theme_system'),
            value: 'system',
          ),
          SettingsRadioOption<String>(
            title: LanguageService.tr('theme_light'),
            value: 'light',
          ),
          SettingsRadioOption<String>(
            title: LanguageService.tr('theme_dark'),
            value: 'dark',
          ),
        ],
        onSelected: (val) async {
          await _repo.setThemeMode(val);
          await AppTheme.setThemeMode(val);
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

  String _getThemeSubtitle() {
    switch (_repo.themeMode) {
      case 'light':
        return LanguageService.tr('theme_light');
      case 'dark':
        return LanguageService.tr('theme_dark');
      default:
        return LanguageService.tr('theme_system');
    }
  }

  String _getPlayerThemeSubtitle() {
    switch (_repo.playerTheme) {
      case 'vinyl':
        return LanguageService.tr('player_theme_vinyl');
      case 'default':
      default:
        return LanguageService.tr('player_theme_default');
    }
  }

  void _showCustomBackgroundColorSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const CustomBackgroundColorSheet(),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _handleGalleryBackgroundTap() async {
    final imagePath = _repo.customBgImagePath;
    final isImageActive = _repo.bgType == 'image' && imagePath != null;

    if (isImageActive) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => GlassBottomSheet(
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                ListTile(
                  leading:
                      Icon(Icons.tune_rounded, color: AppTheme.accentColor),
                  title: Text(
                    LanguageService.tr('edit_bg_image'),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    final rawPath = _repo.customBgRawImagePath ?? imagePath;
                    final targetFile = File(rawPath);
                    if (!targetFile.existsSync() && File(imagePath).existsSync()) {
                      // Fallback to cropped if raw not found
                      _openEditor(File(imagePath));
                    } else {
                      _openEditor(targetFile);
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.add_photo_alternate_rounded,
                      color: AppTheme.accentColor),
                  title: Text(
                    LanguageService.tr('custom_bg_image'),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickNewImageAndOpenEditor();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded,
                      color: AppTheme.errorColor),
                  title: Text(
                    LanguageService.tr('remove_custom_bg'),
                    style: TextStyle(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _repo.clearCustomBg();
                    AppTheme.bgTypeNotifier.value = 'default';
                    AppTheme.updateSystemUIOverlay();
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      );
    } else {
      await _pickNewImageAndOpenEditor();
    }
  }

  Future<void> _openEditor(File file) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomBackgroundEditorScreen(
          imageFile: file,
          initialBlur: _repo.customBgBlur,
          initialOpacity: _repo.customBgOpacity,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _pickNewImageAndOpenEditor() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (picked != null && mounted) {
        await _openEditor(File(picked.path));
      }
    } catch (e) {
      debugPrint('Error picking background image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageService.tr('pick_image_error')),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
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

            // SECTION 2: About (حول التطبيق)
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
    final effectiveDark = AppTheme.isDark;
    final accentColor = AppTheme.accentColor;

    return SettingsSection(
      title: LanguageService.tr('appearance'),
      children: [
        // 1.1 Language
        SettingsNavigationTile(
          icon: Icons.translate_rounded,
          title: LanguageService.tr('language'),
          subtitle: _getLanguageSubtitle(),
          onTap: _showLanguageDialog,
        ),
        // 1.2 Theme Mode
        SettingsNavigationTile(
          icon: Icons.brightness_medium_rounded,
          title: LanguageService.tr('theme_mode'),
          subtitle: _getThemeSubtitle(),
          onTap: _showThemeModeDialog,
        ),
        // 1.3 Accent Color
        SettingsNavigationTile(
          icon: Icons.palette_rounded,
          title: LanguageService.tr('accent_color'),
          subtitle: LanguageService.tr('accent_color_desc'),
          trailing: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withOpacity(0.8), width: 2),
            ),
          ),
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => const SettingsColorPickerSheet(),
            );
          },
        ),
        // 1.4 AMOLED Pure Black
        SettingsSwitchTile(
          icon: Icons.dark_mode_rounded,
          title: LanguageService.tr('amoled_black'),
          subtitle: effectiveDark
              ? LanguageService.tr('amoled_black_desc')
              : LanguageService.tr('amoled_dark_only'),
          value: _repo.amoledBlack,
          enabled: effectiveDark,
          onChanged: (val) async {
            await _repo.setAmoledBlack(val);
            AppTheme.amoledBlackNotifier.value = val;
            setState(() {});
          },
        ),
        // 1.5 Custom Background Color
        SettingsNavigationTile(
          icon: Icons.format_paint_rounded,
          title: LanguageService.tr('custom_bg_color'),
          subtitle: _repo.bgType == 'color'
              ? '#${_repo.customBgColor.value.toRadixString(16).substring(2).toUpperCase()}'
              : LanguageService.tr('custom_bg_color_desc'),
          trailing: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _repo.bgType == 'color'
                  ? _repo.customBgColor
                  : (_repo.themeMode == 'light'
                      ? AppTheme.lightBackground
                      : AppTheme.darkBackground),
              shape: BoxShape.circle,
              border: Border.all(
                color: _repo.bgType == 'color'
                    ? accentColor
                    : Colors.white.withOpacity(0.6),
                width: 2,
              ),
            ),
          ),
          onTap: _showCustomBackgroundColorSheet,
        ),
        // 1.6 Custom Gallery Background Image
        SettingsNavigationTile(
          icon: Icons.wallpaper_rounded,
          title: LanguageService.tr('custom_bg_image'),
          subtitle: _repo.bgType == 'image' && _repo.customBgImagePath != null
              ? LanguageService.tr('bg_image_active')
              : LanguageService.tr('custom_bg_image_desc'),
          trailing: _repo.bgType == 'image' &&
                  _repo.customBgImagePath != null &&
                  File(_repo.customBgImagePath!).existsSync()
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    File(_repo.customBgImagePath!),
                    width: 26,
                    height: 26,
                    fit: BoxFit.cover,
                  ),
                )
              : null,
          onTap: _handleGalleryBackgroundTap,
        ),
        // 1.7 Restore Default Background (Visible when custom color or image is active)
        if (_repo.bgType != 'default')
          SettingsNavigationTile(
            icon: Icons.restore_rounded,
            title: LanguageService.tr('remove_custom_bg'),
            subtitle: LanguageService.tr('remove_custom_bg_confirm'),
            onTap: () async {
              await _repo.clearCustomBg();
              AppTheme.bgTypeNotifier.value = 'default';
              AppTheme.updateSystemUIOverlay();
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(LanguageService.tr('custom_bg_removed')),
                    backgroundColor: AppTheme.surface,
                  ),
                );
              }
            },
          ),
        // 1.8 Player Theme (شكل واجهة المشغل)
        SettingsNavigationTile(
          icon: Icons.style_rounded,
          title: LanguageService.tr('player_theme'),
          subtitle: _getPlayerThemeSubtitle(),
          onTap: () {
            showPlayerThemeSelector(context);
          },
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Section 2: About
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
          title: LanguageService().isArabic
              ? 'التحقق من التحديثات'
              : 'Check for Updates',
          subtitle: LanguageService().isArabic
              ? 'البحث عن إصدارات جديدة عبر GitHub'
              : 'Check for new releases on GitHub',
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
