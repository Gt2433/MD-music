import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/language_service.dart';
import '../services/sleep_timer_service.dart';
import '../theme/app_theme.dart';
import 'glass_dialog.dart';

class SleepTimerSheet extends StatefulWidget {
  const SleepTimerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showGlassBottomSheet(
      context: context,
      builder: (_) => const SleepTimerSheet(),
    );
  }

  @override
  State<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<SleepTimerSheet> {
  final SleepTimerService _service = SleepTimerService();
  int _selectedMinutes = 30;
  bool _stopAtEnd = false;
  bool _fadeOut = true;

  final List<int> _presetMinutes = const [15, 30, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    _stopAtEnd = _service.stopAtEndOfSong;
    _fadeOut = _service.fadeOut;
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor;

    return Directionality(
      textDirection: LanguageService().textDirection,
      child: GlassBottomSheet(
        child: AnimatedBuilder(
          animation: _service,
          builder: (context, _) {
            final isActive = _service.isActive;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle Bar
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

                  // Header Title & Icon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: accent.withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.bedtime_rounded,
                          color: accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LanguageService().t('smart_sleep_timer'),
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              LanguageService().t('smart_sleep_timer_sub'),
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Colors.greenAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                LanguageService().t('sleep_timer_active'),
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ACTIVE TIMER VIEW
                  if (isActive) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accent.withOpacity(0.35), width: 1.2),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.hourglass_bottom_rounded, color: accent, size: 36),
                          const SizedBox(height: 10),
                          Text(
                            _service.stopAtEndOfSong && _service.remaining == Duration.zero
                                ? LanguageService().t('sleep_timer_at_end')
                                : _service.formattedRemaining,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            LanguageService().t('sleep_timer_remaining'),
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Quick Add Minutes Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: accent.withOpacity(0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                            icon: Icon(Icons.add_rounded, color: accent, size: 18),
                            label: Text(
                              '+5 ${LanguageService().t('minutes_unit')}',
                              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _service.addMinutes(5);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: accent.withOpacity(0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                            icon: Icon(Icons.add_rounded, color: accent, size: 18),
                            label: Text(
                              '+15 ${LanguageService().t('minutes_unit')}',
                              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _service.addMinutes(15);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Cancel Timer Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.18),
                        foregroundColor: Colors.redAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: const Icon(Icons.cancel_rounded, size: 20),
                      label: Text(
                        LanguageService().t('cancel_timer'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        _service.cancelTimer();
                      },
                    ),
                  ] else ...[
                    // INACTIVE TIMER SETUP VIEW
                    // Preset Minutes Row
                    Text(
                      LanguageService().t('select_duration'),
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: _presetMinutes.map((min) {
                        final isSelected = !_stopAtEnd && _selectedMinutes == min;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.5),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _selectedMinutes = min;
                                    _stopAtEnd = false;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? accent
                                        : AppTheme.surfaceLight.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? accent : AppTheme.cardBorder.withOpacity(0.4),
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
                                  child: Center(
                                    child: Text(
                                      '$min ${LanguageService().t('minutes_unit_short')}',
                                      style: TextStyle(
                                        color: isSelected
                                            ? (accent.computeLuminance() > 0.4 ? Colors.black : Colors.white)
                                            : AppTheme.textPrimary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 18),

                    // Slider for Custom Time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          LanguageService().t('or_custom_duration'),
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: accent.withOpacity(0.35)),
                          ),
                          child: Text(
                            '$_selectedMinutes ${LanguageService().t('minutes_unit')}',
                            style: TextStyle(
                              color: accent,
                              fontSize: 12,
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
                        value: _selectedMinutes.toDouble().clamp(5.0, 120.0),
                        min: 5.0,
                        max: 120.0,
                        divisions: 23, // 5 min increments
                        onChanged: (val) {
                          setState(() {
                            _selectedMinutes = val.round();
                            _stopAtEnd = false;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Switch 1: Stop at end of track
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.cardBorder.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.skip_next_rounded, color: accent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  LanguageService().t('stop_at_end_of_track'),
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  LanguageService().t('stop_at_end_desc'),
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _stopAtEnd,
                            activeColor: accent,
                            onChanged: (val) {
                              setState(() {
                                _stopAtEnd = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Switch 2: Smooth Fade Out
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.cardBorder.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.volume_down_rounded, color: accent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  LanguageService().t('smooth_fade_out'),
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  LanguageService().t('smooth_fade_desc'),
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _fadeOut,
                            activeColor: accent,
                            onChanged: (val) {
                              setState(() {
                                _fadeOut = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Start Timer Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: accent.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                        elevation: 4,
                        shadowColor: accent.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: Text(
                        LanguageService().t('start_sleep_timer'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        _service.startTimer(
                          duration: _stopAtEnd ? Duration.zero : Duration(minutes: _selectedMinutes),
                          stopAtEndOfSong: _stopAtEnd,
                          fadeOut: _fadeOut,
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

