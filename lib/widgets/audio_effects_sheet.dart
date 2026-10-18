import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_effects_service.dart';
import '../services/language_service.dart';
import '../theme/app_theme.dart';
import 'glass_dialog.dart';

void showAudioEffectsSheet(BuildContext context) {
  showGlassBottomSheet(
    context: context,
    builder: (ctx) => const AudioEffectsSheet(),
  );
}

class AudioEffectsSheet extends StatelessWidget {
  const AudioEffectsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final effectsService = AudioEffectsService();
    final accent = AppTheme.accentColor;
    final isArabic = LanguageService().isArabic;

    return Directionality(
      textDirection: LanguageService().textDirection,
      child: GlassBottomSheet(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: effectsService,
            builder: (context, _) {
              final activeId = effectsService.activeEffect;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Top Drag Handle
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

                  // 2. Sheet Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accent.withOpacity(0.4),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.25),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
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
                              isArabic ? 'المؤثرات الصوتية' : 'Audio Effects',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isArabic
                                  ? 'مؤثرات صوتية فورية لتجربة استماع سينمائية'
                                  : 'Real-time effects for a cinematic sound',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.close_rounded,
                            color: AppTheme.textSecondary, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 3. Effects Cards List
                  ...effectsService.availableEffects.map((effect) {
                    final isSelected = activeId == effect.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            effectsService.setEffect(effect.id);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent.withOpacity(0.14)
                                  : AppTheme.surfaceLight.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? accent.withOpacity(0.65)
                                    : AppTheme.cardBorder.withOpacity(0.5),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: accent.withOpacity(0.22),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                // Effect Icon
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? accent
                                        : AppTheme.cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? accent
                                          : AppTheme.cardBorder,
                                    ),
                                  ),
                                  child: Icon(
                                    effect.icon,
                                    color: isSelected
                                        ? (accent.computeLuminance() > 0.4
                                            ? Colors.black
                                            : Colors.white)
                                        : AppTheme.textSecondary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Title & Description
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            effect.title,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? accent
                                                  : AppTheme.textPrimary,
                                              fontSize: 14.5,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                            ),
                                          ),
                                          if (effect.id == AudioEffectsService.effectDeepEcho) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: accent.withOpacity(0.18),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isArabic ? 'رائج' : 'NEW',
                                                style: TextStyle(
                                                  color: accent,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        effect.description,
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 11.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 10),

                                // Radio Selection Indicator
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? accent
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? accent
                                          : AppTheme.textSecondary
                                              .withOpacity(0.4),
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: accent.computeLuminance() > 0.4
                                                  ? Colors.black
                                                  : Colors.white,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 6),

                  // 4. "More Effects Coming Soon" placeholder card
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.cardBorder.withOpacity(0.35),
                        style: BorderStyle.solid,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.hourglass_top_rounded,
                            color: Colors.amber,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isArabic
                                    ? 'المزيد من المؤثرات قريباً...'
                                    : 'More effects coming soon...',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isArabic
                                    ? 'Slowed + Reverb, 8D Spatial, Bass Boost...'
                                    : 'Slowed + Reverb, 8D Spatial, Bass Boost...',
                                style: TextStyle(
                                  color: AppTheme.textSecondary.withOpacity(0.8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
