import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/language_service.dart';
import '../services/settings_repository.dart';
import '../theme/app_theme.dart';

class CustomBackgroundColorItem {
  final Color color;
  final String nameAr;
  final String nameEn;
  final String hex;

  const CustomBackgroundColorItem({
    required this.color,
    required this.nameAr,
    required this.nameEn,
    required this.hex,
  });
}

class CustomBackgroundColorSheet extends StatefulWidget {
  const CustomBackgroundColorSheet({super.key});

  @override
  State<CustomBackgroundColorSheet> createState() =>
      _CustomBackgroundColorSheetState();
}

class _CustomBackgroundColorSheetState
    extends State<CustomBackgroundColorSheet> {
  late Color _selectedColor;
  int _selectedTab = 0; // 0 = Presets, 1 = Custom Spectrum

  // HSV components
  double _hue = 220.0;
  double _saturation = 0.5;
  double _value = 0.12;

  static const List<CustomBackgroundColorItem> _palettePresets = [
    // Deep Luxury Dark Themes
    CustomBackgroundColorItem(
      color: Color(0xFF0C1017),
      nameAr: 'كحلي ليلي كلاسيكي',
      nameEn: 'Classic Midnight',
      hex: '#0C1017',
    ),
    CustomBackgroundColorItem(
      color: Color(0xFF080C14),
      nameAr: 'أزرق المحيط العميق',
      nameEn: 'Deep Ocean Blue',
      hex: '#080C14',
    ),
    CustomBackgroundColorItem(
      color: Color(0xFF051C14),
      nameAr: 'زمردي ملكي داكن',
      nameEn: 'Imperial Emerald Dark',
      hex: '#051C14',
    ),
    CustomBackgroundColorItem(
      color: Color(0xFF160A22),
      nameAr: 'بنفسجي مخملي عميق',
      nameEn: 'Royal Velvet Purple',
      hex: '#160A22',
    ),
    CustomBackgroundColorItem(
      color: Color(0xFF1D090E),
      nameAr: 'خمري داكن فخم',
      nameEn: 'Luxury Dark Crimson',
      hex: '#1D090E',
    ),
    CustomBackgroundColorItem(
      color: Color(0xFF140F0B),
      nameAr: 'إسبريسو دافئ',
      nameEn: 'Warm Espresso',
      hex: '#140F0B',
    ),
    CustomBackgroundColorItem(
      color: Color(0xFF0F172A),
      nameAr: 'أردوازي فضائي',
      nameEn: 'Cosmic Slate',
      hex: '#0F172A',
    ),
    CustomBackgroundColorItem(
      color: Color(0xFF111827),
      nameAr: 'فحمي نيون هادئ',
      nameEn: 'Graphite Carbon',
      hex: '#111827',
    ),
    CustomBackgroundColorItem(
      color: Color(0xFF000000),
      nameAr: 'أسود فاحم (AMOLED)',
      nameEn: 'Pure OLED Black',
      hex: '#000000',
    ),

    // Aesthetic Modern Light Themes
    CustomBackgroundColorItem(
      color: Color(0xFFF4F6F9),
      nameAr: 'رمادي جليدي ناعم',
      nameEn: 'Soft Nordic Ice',
      hex: '#F4F6F9',
    ),
    CustomBackgroundColorItem(
      color: Color(0xFFFAF7F2),
      nameAr: 'عاجي دافئ فاخر',
      nameEn: 'Warm Ivory Sand',
      hex: '#FAF7F2',
    ),
    CustomBackgroundColorItem(
      color: Color(0xFFEFF6FF),
      nameAr: 'أزرق سماوي نقي',
      nameEn: 'Pure Sky Mist',
      hex: '#EFF6FF',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final repo = SettingsRepository();
    _selectedColor = repo.bgType == 'color'
        ? repo.customBgColor
        : (AppTheme.isDark ? AppTheme.darkBackground : AppTheme.lightBackground);

    final hsv = HSVColor.fromColor(_selectedColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  void _updateFromHsv() {
    setState(() {
      _selectedColor =
          HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
    });
  }

  void _applyColor() async {
    HapticFeedback.mediumImpact();
    final repo = SettingsRepository();
    await repo.setCustomBgColor(_selectedColor);
    AppTheme.bgTypeNotifier.value = 'color';
    AppTheme.customBgColorNotifier.value = _selectedColor;
    AppTheme.updateSystemUIOverlay();

    if (!mounted) return;
    Navigator.of(context).pop(true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _selectedColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                LanguageService.tr('bg_color_applied'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF141A23),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _restoreDefault() async {
    HapticFeedback.lightImpact();
    final repo = SettingsRepository();
    await repo.clearCustomBg();
    AppTheme.bgTypeNotifier.value = 'default';
    AppTheme.updateSystemUIOverlay();

    if (!mounted) return;
    Navigator.of(context).pop(true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LanguageService.tr('custom_bg_removed')),
        backgroundColor: const Color(0xFF141A23),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = LanguageService().isArabic;
    final accent = AppTheme.accentColor;
    final lum = _selectedColor.computeLuminance();
    final isColorDark = lum < 0.32;
    final previewTextColor = isColorDark ? Colors.white : const Color(0xFF0F172A);
    final previewSubColor =
        isColorDark ? Colors.white.withOpacity(0.85) : const Color(0xFF1E293B).withOpacity(0.85);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: BoxDecoration(
            color: const Color(0xFF080D16).withOpacity(0.50),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withOpacity(0.16), width: 1.2),
          ),
          child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.palette_rounded, color: accent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    LanguageService.tr('custom_color_picker_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _restoreDefault,
                  child: Text(
                    LanguageService.tr('restore_default_color'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Live Miniature App Preview Card
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isColorDark
                      ? Colors.white.withOpacity(0.18)
                      : Colors.black.withOpacity(0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accent, width: 1),
                        ),
                        child: Icon(Icons.music_note_rounded,
                            color: accent, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'MD MUSIC',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isColorDark
                              ? Colors.white.withOpacity(0.12)
                              : Colors.black.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#${_selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
                          style: TextStyle(
                            color: previewTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Mock song tile
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isColorDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isColorDark
                            ? Colors.white.withOpacity(0.12)
                            : Colors.black.withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.play_arrow_rounded,
                              color: accent, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isRtl
                                    ? 'تجربة وضوح النص والكتابة'
                                    : 'Text Contrast & Clarity',
                                style: TextStyle(
                                  color: previewTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isRtl
                                    ? 'النصوص واضحة وعالية التباين'
                                    : 'High legibility over background',
                                style: TextStyle(
                                  color: previewSubColor,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.favorite_rounded,
                            color: accent, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tabs (Presets vs Custom HSV)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF141B26),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      title: isRtl ? 'ألوان مختارة' : 'Curated Palettes',
                      icon: Icons.auto_awesome_rounded,
                      index: 0,
                      accent: accent,
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      title: isRtl ? 'طيف مخصص' : 'Custom Spectrum',
                      icon: Icons.tune_rounded,
                      index: 1,
                      accent: accent,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content Area
          Expanded(
            child: _selectedTab == 0
                ? _buildPresetsGrid(isRtl, accent)
                : _buildCustomSpectrum(isRtl, accent),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            decoration: BoxDecoration(
              color: const Color(0xFF0C1017),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(isRtl ? 'إلغاء' : 'Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      elevation: 6,
                      shadowColor: accent.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _applyColor,
                    icon: const Icon(Icons.check_rounded,
                        color: Colors.black, size: 20),
                    label: Text(
                      isRtl ? 'تطبيق اللون' : 'Apply Color',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
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
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required int index,
    required Color accent,
  }) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTab = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.black : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetsGrid(bool isRtl, Color accent) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      physics: const BouncingScrollPhysics(),
      itemCount: _palettePresets.length,
      itemBuilder: (context, index) {
        final item = _palettePresets[index];
        final isSelected = item.color.value == _selectedColor.value;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedColor = item.color;
              final hsv = HSVColor.fromColor(item.color);
              _hue = hsv.hue;
              _saturation = hsv.saturation;
              _value = hsv.value;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? accent.withOpacity(0.12)
                  : const Color(0xFF141B26),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? accent
                    : Colors.white.withOpacity(0.08),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRtl ? item.nameAr : item.nameEn,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.hex,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
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
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomSpectrum(bool isRtl, Color accent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Hue Spectrum
          Text(
            isRtl ? 'درجة اللون (Hue)' : 'Hue',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF0000),
                    Color(0xFFFFFF00),
                    Color(0xFF00FF00),
                    Color(0xFF00FFFF),
                    Color(0xFF0000FF),
                    Color(0xFFFF00FF),
                    Color(0xFFFF0000),
                  ],
                ),
              ),
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 38,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: Colors.white,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 12),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: _hue,
                  min: 0.0,
                  max: 360.0,
                  onChanged: (val) {
                    _hue = val;
                    _updateFromHsv();
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // 2. Saturation
          Text(
            isRtl ? 'التشبع (Saturation)' : 'Saturation',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade800,
                    HSVColor.fromAHSV(1.0, _hue, 1.0, _value).toColor(),
                  ],
                ),
              ),
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 38,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: Colors.white,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 12),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: _saturation,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) {
                    _saturation = val;
                    _updateFromHsv();
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // 3. Brightness / Value
          Text(
            isRtl ? 'السطوع (Brightness)' : 'Brightness',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    Colors.black,
                    HSVColor.fromAHSV(1.0, _hue, _saturation, 1.0).toColor(),
                  ],
                ),
              ),
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 38,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: Colors.white,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 12),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: _value,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) {
                    _value = val;
                    _updateFromHsv();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
