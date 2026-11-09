import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/language_service.dart';
import '../services/settings_repository.dart';
import '../widgets/settings_tiles.dart';
import '../widgets/settings_color_picker_sheet.dart';
import '../widgets/custom_background_color_sheet.dart';
import '../widgets/player_theme_selector.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/font_size_selector_sheet.dart';
import 'custom_background_editor_screen.dart';

class ThemesSettingsScreen extends StatefulWidget {
  const ThemesSettingsScreen({super.key});

  @override
  State<ThemesSettingsScreen> createState() => _ThemesSettingsScreenState();
}

class _ThemesSettingsScreenState extends State<ThemesSettingsScreen> {
  final SettingsRepository _repo = SettingsRepository();
  final PageController _pageController = PageController(viewportFraction: 0.76);
  int _currentMockupPage = 0;

  // Preset accent colors matching the reference design
  static const List<Color> _presetColors = [
    Color(0xFFFF7043), // Vibrant Orange
    Color(0xFFE040FB), // Neon Magenta / Pink
    Color(0xFF00E676), // Emerald Green
    Color(0xFF2979FF), // Vivid Electric Blue
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
                  leading: Icon(Icons.tune_rounded, color: AppTheme.accentColor),
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

  void _showAdvancedOptionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isDark = AppTheme.isDark;
          final accent = AppTheme.accentColor;

          return Directionality(
            textDirection: LanguageService().textDirection,
            child: GlassBottomSheet(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4.5,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.dividerColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.palette_rounded, color: accent, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            LanguageService().t('advanced_theme_options'),
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // 1. Full Color Picker
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        tileColor: AppTheme.cardColor,
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                        title: Text(LanguageService.tr('accent_color'), style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                        subtitle: Text(LanguageService.tr('accent_color_desc'), style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () {
                          Navigator.pop(ctx);
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (_) => const SettingsColorPickerSheet(),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      // 2. AMOLED Black Switch
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        tileColor: AppTheme.cardColor,
                        leading: const Icon(Icons.dark_mode_rounded),
                        title: Text(LanguageService.tr('amoled_black'), style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          isDark ? LanguageService.tr('amoled_black_desc') : LanguageService.tr('amoled_dark_only'),
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        trailing: Switch(
                          value: _repo.amoledBlack,
                          activeColor: accent,
                          onChanged: isDark
                              ? (val) async {
                                  await _repo.setAmoledBlack(val);
                                  AppTheme.amoledBlackNotifier.value = val;
                                  setSheetState(() {});
                                  if (mounted) setState(() {});
                                }
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // 3. Song Artwork Shape (Rounded vs Circles)
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        tileColor: AppTheme.cardColor,
                        leading: Icon(
                          _repo.artworkShape == 'circle' ? Icons.lens_rounded : Icons.crop_square_rounded,
                          color: accent,
                        ),
                        title: Text(
                          LanguageService().t('song_artwork_shape'),
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          _repo.artworkShape == 'circle'
                              ? LanguageService().t('artwork_shape_circles_desc')
                              : LanguageService().t('artwork_shape_squares_desc'),
                          style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        trailing: Switch(
                          value: _repo.artworkShape == 'circle',
                          activeColor: accent,
                          onChanged: (val) async {
                            final newShape = val ? 'circle' : 'rounded';
                            await _repo.setArtworkShape(newShape);
                            AppTheme.artworkShapeNotifier.value = newShape;
                            setSheetState(() {});
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      // 4. Player Theme (Classic / Vinyl)
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        tileColor: AppTheme.cardColor,
                        subtitle: Text(
                          _repo.playerTheme == 'turntable'
                              ? 'Turntable 🎛️'
                              : (_repo.playerTheme == 'vinyl'
                                  ? 'Vinyl Sleeve 💿'
                                  : 'Classic'),
                          style: TextStyle(color: accent, fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          showPlayerThemeSelector(context);
                        },
                      ),
                      const SizedBox(height: 10),
                      // 4. Custom Background Color
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        tileColor: AppTheme.cardColor,
                        leading: const Icon(Icons.format_paint_rounded),
                        title: Text(LanguageService.tr('custom_bg_color'), style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () {
                          Navigator.pop(ctx);
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (_) => const CustomBackgroundColorSheet(),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      // 5. Font Size Level
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        tileColor: AppTheme.cardColor,
                        leading: Icon(Icons.format_size_rounded, color: accent),
                        title: Text(LanguageService.tr('font_size'), style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          LanguageService.tr('font_size_desc'),
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: accent.withOpacity(0.4), width: 1),
                              ),
                              child: Text(
                                '${(_repo.fontScale * 100).round()}%',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          FontSizeSelectorSheet.show(context);
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDensityButton({
    required String key,
    required IconData icon,
    required String label,
    required Color accent,
    required String currentDensity,
    required bool isArabic,
  }) {
    final isSelected = currentDensity == key;
    final fgColor = isSelected
        ? (accent.computeLuminance() > 0.4 ? Colors.black : Colors.white)
        : Colors.white70;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        await _repo.setListDensity(key);
        AppTheme.listDensityNotifier.value = key;
        if (mounted) setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 12 : 9, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accent : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fgColor),
            if (isSelected) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: fgColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildArtworkShapeButton({
    required Color accent,
    required String artworkShape,
    required bool isArabic,
  }) {
    final isCircle = artworkShape == 'circle';
    final fgColor = isCircle
        ? (accent.computeLuminance() > 0.4 ? Colors.black : Colors.white)
        : Colors.white70;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final newShape = isCircle ? 'rounded' : 'circle';
        await _repo.setArtworkShape(newShape);
        AppTheme.artworkShapeNotifier.value = newShape;
        if (mounted) setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: isCircle ? accent : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCircle ? Icons.lens_rounded : Icons.crop_square_rounded,
              size: 16,
              color: fgColor,
            ),
            const SizedBox(width: 4),
            Text(
              isCircle
                  ? LanguageService().t('artwork_shape_circles')
                  : LanguageService().t('artwork_shape_rounded'),
              style: TextStyle(
                color: fgColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
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
        AppTheme.playerThemeNotifier,
        AppTheme.listDensityNotifier,
        AppTheme.artworkShapeNotifier,
        AppTheme.fontScaleNotifier,
        LanguageService().currentLanguage,
      ]),
      builder: (context, _) {
        final isDark = AppTheme.isDark;
        final accent = AppTheme.accentColor;
        final currentThemeMode = _repo.themeMode;
        final listDensity = _repo.listDensity;
        final artworkShape = _repo.artworkShape;
        final isArabic = LanguageService().isArabic;

        return Directionality(
          textDirection: LanguageService().textDirection,
          child: Scaffold(
            backgroundColor: const Color(0xFF0C1015), // Deep sleek background matching Lark Player
            body: SafeArea(
              child: Column(
                children: [
                  // -----------------------------------------------------------
                  // 1. Top Bar (Title + Density & View Mode Controls + Shape)
                  // -----------------------------------------------------------
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        // Back Icon and Title
                        IconButton(
                          icon: Icon(
                            isArabic ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          LanguageService().t('theme'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),

                        // Density switchers: [صغير] [عادي] [مربعات]
                        _buildDensityButton(
                          key: 'compact',
                          icon: Icons.format_list_bulleted_rounded,
                          label: LanguageService().t('density_small'),
                          accent: accent,
                          currentDensity: listDensity,
                          isArabic: isArabic,
                        ),
                        const SizedBox(width: 6),
                        _buildDensityButton(
                          key: 'normal',
                          icon: Icons.view_headline_rounded,
                          label: LanguageService().t('density_normal'),
                          accent: accent,
                          currentDensity: listDensity,
                          isArabic: isArabic,
                        ),
                        const SizedBox(width: 6),
                        _buildDensityButton(
                          key: 'grid',
                          icon: Icons.grid_view_rounded,
                          label: LanguageService().t('density_grid'),
                          accent: accent,
                          currentDensity: listDensity,
                          isArabic: isArabic,
                        ),
                        const SizedBox(width: 6),
                        _buildArtworkShapeButton(
                          accent: accent,
                          artworkShape: artworkShape,
                          isArabic: isArabic,
                        ),
                      ],
                    ),
                  ),

                  // -----------------------------------------------------------
                  // 2. Central Live Smartphone Mockup Carousel
                  // -----------------------------------------------------------
                  Expanded(
                    child: Center(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: 3,
                        onPageChanged: (index) {
                          setState(() => _currentMockupPage = index);
                        },
                        itemBuilder: (context, index) {
                          return _buildPhoneMockupCard(index, accent, isDark);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Carousel Indicator Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final isActive = index == _currentMockupPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive ? accent : Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 12),

                  // -----------------------------------------------------------
                  // 3. Bottom Control Dock (Theme Mode Pill + Quick Colors & Actions)
                  // -----------------------------------------------------------
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 3.1 Theme Mode Pill: [النظام ◐ | نهاري ☀️ | ليلي 🌙]
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2530),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              // System Mode (النظام)
                              Expanded(
                                child: _buildThemeModeSegment(
                                  mode: 'system',
                                  label: LanguageService().t('theme_system'),
                                  icon: Icons.brightness_auto_rounded,
                                  currentMode: currentThemeMode,
                                  accentColor: accent,
                                ),
                              ),
                              // Light Mode (نهاري)
                              Expanded(
                                child: _buildThemeModeSegment(
                                  mode: 'light',
                                  label: LanguageService().t('theme_light'),
                                  icon: Icons.wb_sunny_rounded,
                                  currentMode: currentThemeMode,
                                  accentColor: accent,
                                ),
                              ),
                              // Dark Mode (ليلي)
                              Expanded(
                                child: _buildThemeModeSegment(
                                  mode: 'dark',
                                  label: LanguageService().t('theme_dark'),
                                  icon: Icons.nightlight_round,
                                  currentMode: currentThemeMode,
                                  accentColor: accent,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // 3.2 Quick Accent Colors Row & Action Buttons
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 4 Preset Colors (Orange, Magenta, Green, Blue)
                              ..._presetColors.map((color) {
                                final isSelected = accent.value == color.value;
                                return GestureDetector(
                                  onTap: () async {
                                    await _repo.setAccentColor(color);
                                    AppTheme.accentColorNotifier.value = color;
                                    setState(() {});
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 5),
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(color: Colors.white, width: 3)
                                          : null,
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withOpacity(isSelected ? 0.6 : 0.25),
                                          blurRadius: isSelected ? 12 : 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check_rounded,
                                            size: 20,
                                            color: color.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                                          )
                                        : null,
                                  ),
                                );
                              }),

                              // Vertical divider
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 7),
                                width: 1.5,
                                height: 26,
                                color: Colors.white.withOpacity(0.2),
                              ),

                              // Expand / More Colors Chevron Button: ( ∨ )
                              GestureDetector(
                                onTap: _showAdvancedOptionsSheet,
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E2530),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.8),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 6),

                              // Custom Background / Wallpaper Button: ( 🖼+ )
                              GestureDetector(
                                onTap: _handleGalleryBackgroundTap,
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E2530),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.25),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.add_photo_alternate_rounded,
                                    color: accent,
                                    size: 20,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 6),

                              // Font Size Level Button: ( A / format_size )
                              GestureDetector(
                                onTap: () => FontSizeSelectorSheet.show(context),
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E2530),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.25),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.format_size_rounded,
                                    color: accent,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // Theme Mode Segment Button
  // -------------------------------------------------------------
  Widget _buildThemeModeSegment({
    required String mode,
    required String label,
    required IconData icon,
    required String currentMode,
    required Color accentColor,
  }) {
    final isSelected = currentMode == mode;
    return GestureDetector(
      onTap: () async {
        await AppTheme.setThemeMode(mode);
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? (accentColor.computeLuminance() > 0.4 ? Colors.black : Colors.white)
                  : Colors.white60,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (accentColor.computeLuminance() > 0.4 ? Colors.black : Colors.white)
                    : Colors.white70,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Mockup Phone Device Card
  // -------------------------------------------------------------
  Widget _buildPhoneMockupCard(int pageIndex, Color accent, bool isDark) {
    final frameBg = isDark ? const Color(0xFF10141D) : const Color(0xFFF5F7FB);
    final cardBg = isDark ? const Color(0xFF181F2C) : Colors.white;
    final textPrim = isDark ? Colors.white : Colors.black87;
    final textSec = isDark ? Colors.white54 : Colors.black45;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 310, maxHeight: 520),
        decoration: BoxDecoration(
          color: frameBg,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.65),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: accent.withOpacity(0.15),
              blurRadius: 32,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Column(
            children: [
              // Phone Notch / Speaker Slot
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Mockup Screen Content based on Slide
              Expanded(
                child: pageIndex == 0
                    ? _buildMockupSongsScreen(accent, isDark, frameBg, cardBg, textPrim, textSec, _repo.listDensity, _repo.artworkShape)
                    : pageIndex == 1
                        ? _buildMockupArtistsScreen(accent, isDark, frameBg, cardBg, textPrim, textSec)
                        : _buildMockupAlbumScreen(accent, isDark, frameBg, cardBg, textPrim, textSec),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Screen 1: Songs List Preview (Lark Player style)
  // -------------------------------------------------------------
  Widget _buildMockupSongsScreen(
    Color accent,
    bool isDark,
    Color frameBg,
    Color cardBg,
    Color textPrim,
    Color textSec,
    String listDensity,
    String artworkShape,
  ) {
    final isCircle = artworkShape == 'circle';
    final sampleSongs = [
      {'title': 'Midnight City Echoes', 'artist': 'The Lumineers', 'art': 0},
      {'title': 'Golden Hour Dreams', 'artist': 'Nova Sky', 'art': 1},
      {'title': 'Whispers In The Mist', 'artist': 'Aurora Lane', 'art': 2},
      {'title': 'Chasing The Horizon', 'artist': 'Oliver Vance', 'art': 3},
      {'title': 'Lost In The Rhythm', 'artist': 'Maya Lin', 'art': 4},
      {'title': 'Starlight Symphony', 'artist': 'Daniel Stone', 'art': 5},
    ];

    return Column(
      children: [
        // Top App Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: Row(
            children: [
              Text(
                'MD Music',
                style: TextStyle(
                  color: textPrim,
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Icon(Icons.search_rounded, size: 19, color: textSec),
            ],
          ),
        ),

        // Filter Pills Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _buildMockupPill(LanguageService().t('videos'), false, accent, textSec),
              const SizedBox(width: 6),
              _buildMockupPill(LanguageService().t('songs'), true, accent, textPrim),
              const SizedBox(width: 6),
              _buildMockupPill(LanguageService().t('playlists'), false, accent, textSec),
              const SizedBox(width: 6),
              _buildMockupPill(LanguageService().t('folders'), false, accent, textSec),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Song Items List (Adapts live to Grid / Compact / Normal density)
        Expanded(
          child: listDensity == 'grid'
              ? GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: 4,
                  itemBuilder: (context, i) {
                    final song = sampleSongs[i];
                    return Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cardBg.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: _getArtworkColor(song['art'] as int),
                                borderRadius: BorderRadius.circular(isCircle ? 999 : 8),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white.withOpacity(0.9),
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            song['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textPrim,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            song['artist'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textSec,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sampleSongs.length,
                  itemBuilder: (context, i) {
                    final song = sampleSongs[i];
                    final isCompact = listDensity == 'compact';
                    final thumbSize = isCompact ? 32.0 : 42.0;
                    final vPadding = isCompact ? 2.5 : 5.0;
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: vPadding),
                      child: Row(
                        children: [
                          // Artwork Thumbnail
                          Container(
                            width: thumbSize,
                            height: thumbSize,
                            decoration: BoxDecoration(
                              color: _getArtworkColor(song['art'] as int),
                              borderRadius: BorderRadius.circular(isCircle ? (thumbSize / 2) : (isCompact ? 8 : 10)),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.music_note_rounded,
                                color: Colors.white.withOpacity(0.85),
                                size: isCompact ? 16 : 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Title and Artist
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song['title'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textPrim,
                                    fontSize: isCompact ? 11.5 : 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  song['artist'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textSec,
                                    fontSize: isCompact ? 9.5 : 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.shuffle_rounded,
                            size: 16,
                            color: i == 4 ? accent : textSec.withOpacity(0.5),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Mini Player Bar at bottom of mockup
        Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B2230) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(isDark ? 0.08 : 0.4),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(isCircle ? 15 : 8),
                ),
                child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Solar Eclipse',
                      style: TextStyle(color: textPrim, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Elena Ray',
                      style: TextStyle(color: textSec, fontSize: 9.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.play_arrow_rounded, color: accent, size: 22),
              const SizedBox(width: 6),
              Icon(Icons.fast_forward_rounded, color: textPrim, size: 18),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Screen 2: Artists List Preview
  // -------------------------------------------------------------
  Widget _buildMockupArtistsScreen(
    Color accent,
    bool isDark,
    Color frameBg,
    Color cardBg,
    Color textPrim,
    Color textSec,
  ) {
    final sampleArtists = [
      {'name': 'Nattan', 'count': '8', 'art': 0},
      {'name': 'Zé Felipe', 'count': '6', 'art': 1},
      {'name': 'MC Cabelinho', 'count': '20', 'art': 2},
      {'name': 'Dj Chris', 'count': '32', 'art': 3},
      {'name': 'Zé Neto & Cristiano', 'count': '5', 'art': 4},
      {'name': 'Mari Fernandez', 'count': '32', 'art': 5},
      {'name': 'Jorge & Mateus', 'count': '32', 'art': 6},
    ];

    return Column(
      children: [
        // Top App Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: Row(
            children: [
              Text(
                'MD Music',
                style: TextStyle(
                  color: textPrim,
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Icon(Icons.search_rounded, size: 19, color: textSec),
            ],
          ),
        ),

        // Filter Pills Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _buildMockupPill(LanguageService().t('playlists'), false, accent, textSec),
              const SizedBox(width: 6),
              _buildMockupPill(LanguageService().t('folders'), false, accent, textSec),
              const SizedBox(width: 6),
              _buildMockupPill(LanguageService().t('artists'), true, accent, textPrim),
              const SizedBox(width: 6),
              _buildMockupPill(LanguageService().t('albums'), false, accent, textSec),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Artist Items
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sampleArtists.length,
            itemBuilder: (context, i) {
              final artist = sampleArtists[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    // Circular Avatar with vibrant color
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _getArtworkColor(artist['art'] as int),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.2),
                      ),
                      child: Center(
                        child: Text(
                          (artist['name'] as String).substring(0, 1),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        artist['name'] as String,
                        style: TextStyle(
                          color: textPrim,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      artist['count'] as String,
                      style: TextStyle(
                        color: textSec,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Screen 3: Album & Player Screen Preview
  // -------------------------------------------------------------
  Widget _buildMockupAlbumScreen(
    Color accent,
    bool isDark,
    Color frameBg,
    Color cardBg,
    Color textPrim,
    Color textSec,
  ) {
    return Column(
      children: [
        // Top row inside album
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back_rounded, size: 16, color: textPrim),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.more_vert_rounded, size: 16, color: textPrim),
              ),
            ],
          ),
        ),

        // Big Hero Artwork Cover
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withOpacity(0.9), accent.withOpacity(0.5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.4),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.album_rounded, size: 54, color: Colors.white),
          ),
        ),

        const SizedBox(height: 10),

        Text(
          'Recently played',
          style: TextStyle(
            color: textPrim,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '32 songs',
          style: TextStyle(color: textSec, fontSize: 11),
        ),

        const SizedBox(height: 10),

        // Action Buttons: [ ▶ Play ] and [ 🔀 Shuffle ]
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withOpacity(0.5), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, color: accent, size: 16),
                  const SizedBox(width: 4),
                  Text('Play', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shuffle_rounded, color: textSec, size: 15),
                  const SizedBox(width: 4),
                  Text('Shuffle', style: TextStyle(color: textPrim, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Small song list teaser
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildMockupTrackMini('Midnight City Echoes', 'The Lumineers', textPrim, textSec),
              _buildMockupTrackMini('Golden Hour Dreams', 'Nova Sky', textPrim, textSec),
              _buildMockupTrackMini('Whispers In The Mist', 'Aurora Lane', textPrim, textSec),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMockupTrackMini(String title, String artist, Color textPrim, Color textSec) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.music_note_rounded, size: 14, color: Colors.white70),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, style: TextStyle(color: textPrim, fontSize: 10.5, fontWeight: FontWeight.w600)),
                Text(artist, maxLines: 1, style: TextStyle(color: textSec, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockupPill(String title, bool isSelected, Color accent, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? accent : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: isSelected
              ? (accent.computeLuminance() > 0.4 ? Colors.black : Colors.white)
              : Colors.white60,
          fontSize: 10.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Color _getArtworkColor(int index) {
    const colors = [
      Color(0xFFE91E63),
      Color(0xFFFF9800),
      Color(0xFF00BCD4),
      Color(0xFF4CAF50),
      Color(0xFF9C27B0),
      Color(0xFF3F51B5),
      Color(0xFFFF5722),
    ];
    return colors[index % colors.length];
  }
}
