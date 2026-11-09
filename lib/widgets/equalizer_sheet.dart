import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/equalizer_service.dart';
import '../services/language_service.dart';
import '../theme/app_theme.dart';
import 'glass_dialog.dart';

class EqualizerSheet extends StatefulWidget {
  const EqualizerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showGlassBottomSheet(
      context: context,
      builder: (_) => const EqualizerSheet(),
    );
  }

  @override
  State<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends State<EqualizerSheet> {
  final EqualizerService _eq = EqualizerService();

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor;

    return Directionality(
      textDirection: LanguageService().textDirection,
      child: GlassBottomSheet(
        child: AnimatedBuilder(
          animation: _eq,
          builder: (context, _) {
            final isEnabled = _eq.enabled;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.dividerColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  // Header with Master Switch
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: accent.withOpacity(0.4)),
                        ),
                        child: Icon(Icons.equalizer_rounded, color: accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LanguageService().t('equalizer_pro_title'),
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              LanguageService().t('equalizer_pro_desc'),
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: isEnabled,
                        activeColor: accent,
                        onChanged: (val) {
                          HapticFeedback.lightImpact();
                          _eq.setEnabled(val);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Presets Carousel
                  Opacity(
                    opacity: isEnabled ? 1.0 : 0.45,
                    child: IgnorePointer(
                      ignoring: !isEnabled,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                LanguageService().t('equalizer_presets_label'),
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_eq.currentPresetId == 'custom')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    LanguageService().t('equalizer_custom'),
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: _eq.presets.map((preset) {
                                final isSelected = _eq.currentPresetId == preset.id;
                                final label = preset.displayName;

                                return Padding(
                                  padding: const EdgeInsets.only(left: 6, right: 6),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        _eq.setPreset(preset.id);
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? accent
                                              : AppTheme.surfaceLight.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected
                                                ? accent
                                                : AppTheme.cardBorder.withOpacity(0.4),
                                            width: 1.1,
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
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            color: isSelected
                                                ? (accent.computeLuminance() > 0.4 ? Colors.black : Colors.white)
                                                : AppTheme.textPrimary,
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Bass Boost Card
                  Opacity(
                    opacity: isEnabled ? 1.0 : 0.45,
                    child: IgnorePointer(
                      ignoring: !isEnabled,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.cardBorder.withOpacity(0.45)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.speaker_rounded, color: accent, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      LanguageService().t('equalizer_bass_boost'),
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: accent.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${((_eq.bassBoost / 1000.0) * 100).toInt()}%',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: accent,
                                inactiveTrackColor: AppTheme.cardBorder.withOpacity(0.5),
                                thumbColor: accent,
                                overlayColor: accent.withOpacity(0.15),
                                trackHeight: 3.5,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                              ),
                              child: Slider(
                                value: _eq.bassBoost.toDouble().clamp(0.0, 1000.0),
                                min: 0.0,
                                max: 1000.0,
                                divisions: 20,
                                onChanged: (val) {
                                  _eq.setBassBoost(val.round());
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 5 Vertical Equalizer Sliders Card
                  Opacity(
                    opacity: isEnabled ? 1.0 : 0.45,
                    child: IgnorePointer(
                      ignoring: !isEnabled,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.cardBorder.withOpacity(0.4)),
                        ),
                        child: Column(
                          children: [
                            // Decibel Range Legend
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '+${_eq.maxDb.toInt()}dB',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                                  ),
                                  Text(
                                    '0dB (Flat)',
                                    style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.6), fontSize: 10),
                                  ),
                                  Text(
                                    '${_eq.minDb.toInt()}dB',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Sliders Row
                            SizedBox(
                              height: 160,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: List.generate(_eq.bands.length, (idx) {
                                  final gain = _eq.bands[idx];
                                  final freq = idx < _eq.frequencies.length
                                      ? _eq.frequencies[idx]
                                      : 1000;
                                  final freqLabel = _eq.formatFreq(freq);

                                  return Column(
                                    children: [
                                      // Gain value badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: gain != 0.0
                                              ? accent.withOpacity(0.18)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${gain > 0 ? '+' : ''}${gain.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            color: gain != 0.0 ? accent : AppTheme.textSecondary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),

                                      // Vertical Slider
                                      Expanded(
                                        child: RotatedBox(
                                          quarterTurns: -1,
                                          child: SliderTheme(
                                            data: SliderTheme.of(context).copyWith(
                                              activeTrackColor: accent,
                                              inactiveTrackColor: AppTheme.cardBorder.withOpacity(0.4),
                                              thumbColor: accent,
                                              overlayColor: accent.withOpacity(0.15),
                                              trackHeight: 3.5,
                                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                            ),
                                            child: Slider(
                                              value: gain.clamp(_eq.minDb, _eq.maxDb),
                                              min: _eq.minDb,
                                              max: _eq.maxDb,
                                              divisions: 20,
                                              onChanged: (val) {
                                                _eq.setBandGain(idx, val);
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),

                                      // Frequency Label
                                      Text(
                                        freqLabel,
                                        style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Reset to Flat button
                  TextButton.icon(
                    onPressed: isEnabled
                        ? () {
                            HapticFeedback.lightImpact();
                            _eq.resetToFlat();
                          }
                        : null,
                    icon: Icon(Icons.restart_alt_rounded, color: AppTheme.textSecondary, size: 18),
                    label: Text(
                      LanguageService().t('equalizer_reset_flat'),
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

