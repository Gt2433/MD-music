import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/language_service.dart';
import '../services/settings_repository.dart';
import '../theme/app_theme.dart';
import 'glass_dialog.dart';

/// Interactive modal sheet allowing users to scale font size across the app
class FontSizeSelectorSheet extends StatefulWidget {
  const FontSizeSelectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FontSizeSelectorSheet(),
    );
  }

  @override
  State<FontSizeSelectorSheet> createState() => _FontSizeSelectorSheetState();
}

class _FontSizeSelectorSheetState extends State<FontSizeSelectorSheet> {
  final SettingsRepository _repo = SettingsRepository();
  late double _currentScale;

  // Preset scale values
  static const List<double> _presets = [0.85, 1.0, 1.15, 1.30];

  @override
  void initState() {
    super.initState();
    _currentScale = _repo.fontScale;
  }

  String _getScaleLabel(double scale, bool isArabic) {
    if (scale <= 0.88) {
      return LanguageService.tr('font_size_small');
    } else if (scale <= 1.05 && scale >= 0.95) {
      return LanguageService.tr('font_size_normal');
    } else if (scale <= 1.20) {
      return LanguageService.tr('font_size_large');
    } else {
      return LanguageService.tr('font_size_xlarge');
    }
  }

  Future<void> _updateScale(double newScale) async {
    final rounded = double.parse(newScale.toStringAsFixed(2));
    setState(() => _currentScale = rounded);
    await AppTheme.setFontScale(rounded);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark;
    final accent = AppTheme.accentColor;
    final isArabic = LanguageService().isArabic;
    final percent = (_currentScale * 100).round();
    final scaleLabel = _getScaleLabel(_currentScale, isArabic);

    return Directionality(
      textDirection: LanguageService().textDirection,
      child: GlassBottomSheet(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
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

                // Header with Title and Current Value Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.format_size_rounded, color: accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LanguageService.tr('font_size'),
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            LanguageService.tr('font_size_desc'),
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Percentage Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accent.withOpacity(0.4), width: 1),
                      ),
                      child: Text(
                        '$percent% • $scaleLabel',
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Quick Preset Chips: [صغير 85%] [افتراضي 100%] [كبير 115%] [كبير جداً 130%]
                Row(
                  children: _presets.map((preset) {
                    final isSelected = (_currentScale - preset).abs() < 0.04;
                    final label = _getScaleLabel(preset, isArabic);
                    final presetPercent = (preset * 100).round();

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _updateScale(preset);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent
                                  : (isDark ? const Color(0xFF1E2530) : Colors.black.withOpacity(0.04)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? accent
                                    : (isDark ? const Color(0xFF2B3645) : Colors.black.withOpacity(0.08)),
                                width: isSelected ? 1.5 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: accent.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? (accent.computeLuminance() > 0.4 ? Colors.black : Colors.white)
                                        : AppTheme.textPrimary,
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$presetPercent%',
                                  style: TextStyle(
                                    color: isSelected
                                        ? (accent.computeLuminance() > 0.4 ? Colors.black87 : Colors.white70)
                                        : AppTheme.textMuted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Interactive Slider
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141A23) : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? const Color(0xFF222C38) : Colors.black.withOpacity(0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Small "A" icon
                      Text(
                        'A',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: accent,
                            inactiveTrackColor: accent.withOpacity(0.2),
                            thumbColor: accent,
                            overlayColor: accent.withOpacity(0.18),
                            trackHeight: 4.5,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                          ),
                          child: Slider(
                            value: _currentScale,
                            min: 0.85,
                            max: 1.30,
                            divisions: 9,
                            onChanged: (val) {
                              HapticFeedback.selectionClick();
                              _updateScale(val);
                            },
                          ),
                        ),
                      ),
                      // Large "A" icon
                      Text(
                        'A',
                        style: TextStyle(
                          color: accent,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Live Preview Card (uses real-time MediaQuery scale)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161F2A) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? const Color(0xFF263242) : Colors.black.withOpacity(0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Preview Album Art
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accent.withOpacity(0.8), accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.music_note_rounded,
                          color: accent.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Preview Texts that inherit the dynamic scale
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LanguageService().t('font_size_live_preview'),
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              LanguageService().t('font_size_live_sub'),
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Reset to Default button if not 1.0
                if ((_currentScale - 1.0).abs() > 0.01)
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _updateScale(1.0);
                      },
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: Text(
                        LanguageService().t('font_size_reset_default'),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
