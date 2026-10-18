import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/language_service.dart';
import 'glass_dialog.dart';
export 'settings_color_picker_sheet.dart';

/// Reusable Section Container for Settings
class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.accentColorNotifier,
      builder: (context, accentColor, _) {
        return Padding(
          padding: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: accentColor,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.cardBorder.withOpacity(0.4),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(AppTheme.isDark ? 0.2 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      for (int i = 0; i < children.length; i++) ...[
                        children[i],
                        if (i < children.length - 1)
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 56,
                            endIndent: 16,
                            color: AppTheme.dividerColor.withOpacity(0.5),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Reusable Switch Tile with Semantics & 48dp Touch Target
class SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveEnabled = enabled && onChanged != null;
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.accentColorNotifier,
      builder: (context, accentColor, _) {
        return Semantics(
          label: '$title, ${value ? "enabled" : "disabled"}',
          toggled: value,
          enabled: effectiveEnabled,
          button: true,
          child: Opacity(
            opacity: effectiveEnabled ? 1.0 : 0.45,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: effectiveEnabled ? () => onChanged!(!value) : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            icon,
                            size: 20,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.3,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: value,
                          onChanged: effectiveEnabled ? onChanged : null,
                          activeColor: accentColor,
                          activeTrackColor: accentColor.withOpacity(0.35),
                          inactiveThumbColor: AppTheme.textSecondary,
                          inactiveTrackColor: AppTheme.surfaceLight,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Reusable Navigation Tile with Trailing Value & Mirrored Chevron
class SettingsNavigationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? valueText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  const SettingsNavigationTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.valueText,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.accentColorNotifier,
      builder: (context, accentColor, _) {
        return Semantics(
          label: '$title, ${valueText ?? ""}',
          enabled: enabled,
          button: true,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.45,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled ? onTap : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            icon,
                            size: 20,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.3,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (valueText != null)
                          Text(
                            valueText!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        if (trailing != null)
                          trailing!
                        else ...[
                          const SizedBox(width: 4),
                          Icon(
                            isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                            size: 20,
                            color: AppTheme.textMuted,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Reusable Slider Tile with Semantics & Live Label
class SettingsSliderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const SettingsSliderTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.accentColorNotifier,
      builder: (context, accentColor, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: accentColor,
                  inactiveTrackColor: AppTheme.surfaceLight,
                  thumbColor: accentColor,
                  overlayColor: accentColor.withOpacity(0.15),
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Radio Selection Dialog (Generic Material 3)
class SettingsRadioDialog<T> extends StatelessWidget {
  final String title;
  final List<SettingsRadioOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onSelected;

  const SettingsRadioDialog({
    super.key,
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.accentColorNotifier,
      builder: (context, accentColor, _) {
        return GlassDialog(
          title: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((opt) {
              final isSelected = opt.value == selectedValue;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? accentColor.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: RadioListTile<T>(
                  value: opt.value,
                  groupValue: selectedValue,
                  activeColor: accentColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  title: Text(
                    opt.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? accentColor : AppTheme.textPrimary,
                    ),
                  ),
                  subtitle: opt.subtitle != null
                      ? Text(
                          opt.subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        )
                      : null,
                  onChanged: (val) {
                    if (val != null) {
                      onSelected(val);
                      Navigator.of(context).pop();
                    }
                  },
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                LanguageService.tr('cancel'),
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class SettingsRadioOption<T> {
  final String title;
  final String? subtitle;
  final T value;

  const SettingsRadioOption({
    required this.title,
    this.subtitle,
    required this.value,
  });
}

