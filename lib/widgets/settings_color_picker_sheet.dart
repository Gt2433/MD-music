import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_repository.dart';

class LuxuryColorItem {
  final Color color;
  final String nameAr;
  final String nameEn;
  final String hex;
  final String categoryAr;
  final String categoryEn;

  const LuxuryColorItem({
    required this.color,
    required this.nameAr,
    required this.nameEn,
    required this.hex,
    required this.categoryAr,
    required this.categoryEn,
  });
}

class SettingsColorPickerSheet extends StatefulWidget {
  const SettingsColorPickerSheet({super.key});

  @override
  State<SettingsColorPickerSheet> createState() => _SettingsColorPickerSheetState();
}

class _SettingsColorPickerSheetState extends State<SettingsColorPickerSheet>
    with SingleTickerProviderStateMixin {
  late Color _previewColor;
  late AnimationController _pulseController;

  int _selectedTab = 0; // 0 = Luxury Palettes, 1 = Custom Spectrum

  // Custom HSV components
  double _hue = 150.0;
  double _saturation = 1.0;
  double _value = 0.9;

  // Mini live player preview state
  bool _isPlaying = true;
  bool _isLiked = true;
  double _progress = 0.45;

  static const List<LuxuryColorItem> _luxuryPalettes = [
    // 1. Royal Jewels (الذهب والمجوهرات الملكية)
    LuxuryColorItem(
      color: Color(0xFFFFD700),
      nameAr: 'ذهب ملكي عيار 24',
      nameEn: '24K Royal Gold',
      hex: '#FFD700',
      categoryAr: 'مجوهرات ملكية',
      categoryEn: 'Royal Jewels',
    ),
    LuxuryColorItem(
      color: Color(0xFF00E676),
      nameAr: 'زمرد إمبراطوري',
      nameEn: 'Imperial Emerald',
      hex: '#00E676',
      categoryAr: 'مجوهرات ملكية',
      categoryEn: 'Royal Jewels',
    ),
    LuxuryColorItem(
      color: Color(0xFFFF1744),
      nameAr: 'ياقوت قرمزي',
      nameEn: 'Burmese Ruby',
      hex: '#FF1744',
      categoryAr: 'مجوهرات ملكية',
      categoryEn: 'Royal Jewels',
    ),
    LuxuryColorItem(
      color: Color(0xFFA855F7),
      nameAr: 'أميثيست مخملي',
      nameEn: 'Velvet Amethyst',
      hex: '#A855F7',
      categoryAr: 'مجوهرات ملكية',
      categoryEn: 'Royal Jewels',
    ),
    LuxuryColorItem(
      color: Color(0xFF00B4D8),
      nameAr: 'زفير سماوي',
      nameEn: 'Celestial Sapphire',
      hex: '#00B4D8',
      categoryAr: 'مجوهرات ملكية',
      categoryEn: 'Royal Jewels',
    ),

    // 2. Cyber & Neon (نيون وسايبربانك)
    LuxuryColorItem(
      color: Color(0xFF00F5D4),
      nameAr: 'نيون سايبربانك',
      nameEn: 'Cyberpunk Cyan',
      hex: '#00F5D4',
      categoryAr: 'نيون وسايبر',
      categoryEn: 'Cyber Neon',
    ),
    LuxuryColorItem(
      color: Color(0xFFFF007F),
      nameAr: 'طوكيو ليزر',
      nameEn: 'Tokyo Laser Pink',
      hex: '#FF007F',
      categoryAr: 'نيون وسايبر',
      categoryEn: 'Cyber Neon',
    ),
    LuxuryColorItem(
      color: Color(0xFF7C3AED),
      nameAr: 'بنفسجي كهربائي',
      nameEn: 'Electric Violet',
      hex: '#7C3AED',
      categoryAr: 'نيون وسايبر',
      categoryEn: 'Cyber Neon',
    ),
    LuxuryColorItem(
      color: Color(0xFF06D6A0),
      nameAr: 'شفق قطبي',
      nameEn: 'Aurora Borealis',
      hex: '#06D6A0',
      categoryAr: 'نيون وسايبر',
      categoryEn: 'Cyber Neon',
    ),
    LuxuryColorItem(
      color: Color(0xFF2563EB),
      nameAr: 'أزرق كوبالت فائق',
      nameEn: 'Ultra Cobalt',
      hex: '#2563EB',
      categoryAr: 'نيون وسايبر',
      categoryEn: 'Cyber Neon',
    ),

    // 3. Sunset & Essence (الغروب والشفق)
    LuxuryColorItem(
      color: Color(0xFFFF5722),
      nameAr: 'شروق الماغما',
      nameEn: 'Magma Sunset',
      hex: '#FF5722',
      categoryAr: 'شفق وغروب',
      categoryEn: 'Sunset Essence',
    ),
    LuxuryColorItem(
      color: Color(0xFFF43F5E),
      nameAr: 'وردي الذهب',
      nameEn: 'Rose Gold',
      hex: '#F43F5E',
      categoryAr: 'شفق وغروب',
      categoryEn: 'Sunset Essence',
    ),
    LuxuryColorItem(
      color: Color(0xFF14B8A6),
      nameAr: 'أكوا المالديف',
      nameEn: 'Maldives Breeze',
      hex: '#14B8A6',
      categoryAr: 'شفق وغروب',
      categoryEn: 'Sunset Essence',
    ),
    LuxuryColorItem(
      color: Color(0xFF84CC16),
      nameAr: 'ليموني طازج',
      nameEn: 'Lime Spark',
      hex: '#84CC16',
      categoryAr: 'شفق وغروب',
      categoryEn: 'Sunset Essence',
    ),
    LuxuryColorItem(
      color: Color(0xFFF59E0B),
      nameAr: 'كهرمان تيسلا',
      nameEn: 'Tesla Amber',
      hex: '#F59E0B',
      categoryAr: 'شفق وغروب',
      categoryEn: 'Sunset Essence',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _previewColor = SettingsRepository().accentColor;
    final hsv = HSVColor.fromColor(_previewColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value.clamp(0.4, 1.0);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _contrastColor(Color bg) {
    return bg.computeLuminance() > 0.45 ? Colors.black : Colors.white;
  }

  void _updateFromHsv() {
    final newColor = HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
    setState(() {
      _previewColor = newColor;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final accent = _previewColor;
    final buttonTextColor = _contrastColor(accent);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C1017) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: accent.withValues(alpha: 0.35), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.25 : 0.15),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            children: [
              // 1. Top Drag Handle & Title Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: accent.withValues(alpha: 0.4), width: 1),
                          ),
                          child: Icon(Icons.palette_rounded, color: accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isRtl ? 'الثيمات' : 'Themes',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          color: isDark ? Colors.white60 : Colors.black54,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Interactive Glass Live Preview Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: _buildLuxuryLivePreviewCard(isDark: isDark, isRtl: isRtl),
              ),

              // 3. Tab Bar (Palettes vs Custom Spectrum)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161C26) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF242E3D) : const Color(0xFFCBD5E1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTabButton(
                          title: isRtl ? 'الألوان' : 'Palettes',
                          icon: Icons.auto_awesome_rounded,
                          index: 0,
                          accent: accent,
                          isDark: isDark,
                        ),
                      ),
                      Expanded(
                        child: _buildTabButton(
                          title: isRtl ? 'تخصيص' : 'Custom',
                          icon: Icons.tune_rounded,
                          index: 1,
                          accent: accent,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Scrollable Content Area
              Expanded(
                child: _selectedTab == 0
                    ? _buildLuxuryPalettesList(isDark: isDark, isRtl: isRtl)
                    : _buildCustomSpectrumStudio(isDark: isDark, isRtl: isRtl),
              ),

              // 5. Bottom Action Bar (Apply / Cancel)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0C1017) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0xFF1E2633) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : Colors.black87,
                          side: BorderSide(
                            color: isDark ? const Color(0xFF2E3A4B) : const Color(0xFFCBD5E1),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          isRtl ? 'إلغاء' : 'Cancel',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: buttonTextColor,
                          elevation: 8,
                          shadowColor: accent.withValues(alpha: 0.55),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: Icon(Icons.check_rounded, color: buttonTextColor, size: 20),
                        label: Text(
                          isRtl ? 'تطبيق' : 'Apply',
                          style: TextStyle(
                            color: buttonTextColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          SettingsRepository().setAccentColor(_previewColor);
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: _previewColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: _previewColor.withValues(alpha: 0.7),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    isRtl ? 'تم تطبيق المظهر اللوني الجديد بنجاح ✨' : 'Theme color applied ✨',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF161F2E),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
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
    required bool isDark,
  }) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTab = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
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
                  ? _contrastColor(accent)
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? _contrastColor(accent)
                    : (isDark ? Colors.white70 : Colors.black87),
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Live Audio Player Card with Real Aura & Equalizer
  Widget _buildLuxuryLivePreviewCard({required bool isDark, required bool isRtl}) {
    final accent = _previewColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131822) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.2 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Vinyl Album Art with Shimmer Ring
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.6),
                          const Color(0xFF1E293B),
                          Colors.black,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.music_note_rounded, color: accent, size: 24),
                  ),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Title & Artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MD Music',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isRtl ? 'معاينة المظهر' : 'Theme Preview',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Animated Pulsating Equalizer Bars
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final v = _pulseController.value;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildEqualizerBar(6 + 14 * v, accent),
                      const SizedBox(width: 2.5),
                      _buildEqualizerBar(16 - 10 * v, accent),
                      const SizedBox(width: 2.5),
                      _buildEqualizerBar(8 + 12 * (1 - v), accent),
                      const SizedBox(width: 2.5),
                      _buildEqualizerBar(4 + 16 * v, accent),
                    ],
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Progress Bar with Glowing Slider Thumb
          Row(
            children: [
              Text(
                '01:45',
                style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10.5),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3.5,
                    activeTrackColor: accent,
                    inactiveTrackColor: isDark ? const Color(0xFF222C3A) : const Color(0xFFE2E8F0),
                    thumbColor: accent,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayColor: accent.withValues(alpha: 0.2),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: _progress,
                    onChanged: (val) {
                      setState(() => _progress = val);
                    },
                  ),
                ),
              ),
              Text(
                '03:50',
                style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10.5),
              ),
            ],
          ),

          // Interactive Mini Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  _isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                  color: _isLiked ? const Color(0xFFFF5252) : (isDark ? Colors.white54 : Colors.black45),
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _isLiked = !_isLiked);
                },
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.skip_previous_rounded, color: isDark ? Colors.white70 : Colors.black87, size: 22),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () {
                      setState(() => _isPlaying = !_isPlaying);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: _contrastColor(accent),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Icon(Icons.skip_next_rounded, color: isDark ? Colors.white70 : Colors.black87, size: 22),
                ],
              ),
              IconButton(
                icon: Icon(Icons.shuffle_rounded, color: accent, size: 20),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEqualizerBar(double height, Color color) {
    return Container(
      width: 3.5,
      height: height.clamp(4.0, 22.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // 4. Tab 0: Curated Luxury Palettes
  Widget _buildLuxuryPalettesList({required bool isDark, required bool isRtl}) {
    // Group into categories
    final royalJewels = _luxuryPalettes.where((p) => p.categoryEn == 'Royal Jewels').toList();
    final cyberNeon = _luxuryPalettes.where((p) => p.categoryEn == 'Cyber Neon').toList();
    final sunsetEssence = _luxuryPalettes.where((p) => p.categoryEn == 'Sunset Essence').toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: [
        _buildPaletteSection(
          title: isRtl ? 'ألوان راقية' : 'Classics',
          items: royalJewels,
          isDark: isDark,
          isRtl: isRtl,
        ),
        const SizedBox(height: 18),
        _buildPaletteSection(
          title: isRtl ? 'نيون حيوي' : 'Neon',
          items: cyberNeon,
          isDark: isDark,
          isRtl: isRtl,
        ),
        const SizedBox(height: 18),
        _buildPaletteSection(
          title: isRtl ? 'درجات طبيعية' : 'Natural',
          items: sunsetEssence,
          isDark: isDark,
          isRtl: isRtl,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPaletteSection({
    required String title,
    required List<LuxuryColorItem> items,
    required bool isDark,
    required bool isRtl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3.5,
              height: 14,
              decoration: BoxDecoration(
                color: _previewColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) {
            final isSelected = item.color.value == _previewColor.value;
            return _buildJewelCard(item: item, isSelected: isSelected, isDark: isDark, isRtl: isRtl);
          }).toList(),
        ),
      ],
    );
  }

  // Jewel Capsule Card with Specular Sheen
  Widget _buildJewelCard({
    required LuxuryColorItem item,
    required bool isSelected,
    required bool isDark,
    required bool isRtl,
  }) {
    final textColor = _contrastColor(item.color);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _previewColor = item.color;
          final hsv = HSVColor.fromColor(item.color);
          _hue = hsv.hue;
          _saturation = hsv.saturation;
          _value = hsv.value;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 165,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141923) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? item.color
                : (isDark ? const Color(0xFF242E3D) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: item.color.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Gem Circle with Specular Highlight
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.3),
                  radius: 0.8,
                  colors: [
                    Color.lerp(item.color, Colors.white, 0.45)!,
                    item.color,
                    Color.lerp(item.color, Colors.black, 0.3)!,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: item.color.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isSelected
                  ? Icon(Icons.check_rounded, color: textColor, size: 18)
                  : null,
            ),
            const SizedBox(width: 10),

            // Name Only (No redundant hex codes)
            Expanded(
              child: Text(
                isRtl ? item.nameAr : item.nameEn,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5. Tab 1: Interactive Custom Spectrum Studio (شريط طيف لوني حر)
  Widget _buildCustomSpectrumStudio({required bool isDark, required bool isRtl}) {
    final accent = _previewColor;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        // Clean Color Swatch (No Hex or RGB clutter)
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.3),
                radius: 0.85,
                colors: [
                  Color.lerp(accent, Colors.white, 0.45)!,
                  accent,
                  Color.lerp(accent, Colors.black, 0.35)!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.5),
                  blurRadius: 22,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 22),

        // 1. Rainbow Hue Slider - Forced LTR so left = 0° (Red), center-right = 240° (Blue)
        Text(
          isRtl ? 'اللون' : 'Hue',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF0000), // 0° Red
                  Color(0xFFFFFF00), // 60° Yellow
                  Color(0xFF00FF00), // 120° Green
                  Color(0xFF00FFFF), // 180° Cyan
                  Color(0xFF0000FF), // 240° Blue
                  Color(0xFFFF00FF), // 300° Magenta
                  Color(0xFFFF0000), // 360° Red
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 38,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12, elevation: 4),
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

        // 2. Saturation Slider - Forced LTR
        Text(
          isRtl ? 'التشبع' : 'Saturation',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor(),
                ],
              ),
            ),
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 38,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12, elevation: 4),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: _saturation,
                min: 0.2,
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

        // 3. Brightness Slider - Forced LTR
        Text(
          isRtl ? 'السطوع' : 'Brightness',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1E293B),
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
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12, elevation: 4),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: _value,
                min: 0.4,
                max: 1.0,
                onChanged: (val) {
                  _value = val;
                  _updateFromHsv();
                },
              ),
            ),
          ),
        ),

        const SizedBox(height: 28),
        ],
      ),
    );
  }
}
