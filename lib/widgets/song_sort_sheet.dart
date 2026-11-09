import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../services/language_service.dart';
import '../theme/app_theme.dart';
import 'glass_dialog.dart';

class SongSortSheet extends StatelessWidget {
  const SongSortSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showGlassBottomSheet(
      context: context,
      builder: (ctx) => const SongSortSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audio = AudioService();
    final currentOrder = audio.currentSortOrder;

    final sortOptions = <_SortOptionItem>[
      _SortOptionItem(
        order: SongSortOrder.dateAddedDesc,
        titleKey: 'sort_date_added_desc',
        icon: Icons.schedule_rounded,
      ),
      _SortOptionItem(
        order: SongSortOrder.dateAddedAsc,
        titleKey: 'sort_date_added_asc',
        icon: Icons.history_rounded,
      ),
      _SortOptionItem(
        order: SongSortOrder.titleAsc,
        titleKey: 'sort_title_asc',
        icon: Icons.sort_by_alpha_rounded,
      ),
      _SortOptionItem(
        order: SongSortOrder.titleDesc,
        titleKey: 'sort_title_desc',
        icon: Icons.sort_by_alpha_rounded,
      ),
      _SortOptionItem(
        order: SongSortOrder.artistAsc,
        titleKey: 'sort_artist_asc',
        icon: Icons.person_outline_rounded,
      ),
      _SortOptionItem(
        order: SongSortOrder.sizeDesc,
        titleKey: 'sort_size_desc',
        icon: Icons.storage_rounded,
      ),
      _SortOptionItem(
        order: SongSortOrder.sizeAsc,
        titleKey: 'sort_size_asc',
        icon: Icons.sd_storage_rounded,
      ),
      _SortOptionItem(
        order: SongSortOrder.durationDesc,
        titleKey: 'sort_duration_desc',
        icon: Icons.timer_outlined,
      ),
      _SortOptionItem(
        order: SongSortOrder.durationAsc,
        titleKey: 'sort_duration_asc',
        icon: Icons.timer_outlined,
      ),
    ];

    return Directionality(
      textDirection: LanguageService().textDirection,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        decoration: BoxDecoration(
          color: AppTheme.isDark ? const Color(0xFF10141D) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag pill
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.swap_vert_rounded,
                        color: AppTheme.accentColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LanguageService().t('sort_songs'),
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            LanguageService().t('sort_by'),
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Colors.white10),

              // Options List
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: sortOptions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = sortOptions[index];
                    final isSelected = item.order == currentOrder;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          await audio.setSortOrder(item.order);
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.accentColor.withValues(alpha: 0.12)
                                : (AppTheme.isDark ? const Color(0xFF161B26) : const Color(0xFFF4F6F9)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.accentColor.withValues(alpha: 0.45)
                                  : Colors.white.withValues(alpha: 0.05),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.accentColor.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  item.icon,
                                  size: 18,
                                  color: isSelected ? AppTheme.accentColor : AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  LanguageService().t(item.titleKey),
                                  style: TextStyle(
                                    color: isSelected ? AppTheme.accentColor : AppTheme.textPrimary,
                                    fontSize: 14.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.accentColor,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.black,
                                    size: 15,
                                  ),
                                )
                              else
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white24,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortOptionItem {
  final SongSortOrder order;
  final String titleKey;
  final IconData icon;

  const _SortOptionItem({
    required this.order,
    required this.titleKey,
    required this.icon,
  });
}
