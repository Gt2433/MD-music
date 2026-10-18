import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Displays a frosted glass dialog with smooth scaling & fading transition
/// Displays a frosted glass dialog with smooth scaling & fading transition
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'GlassDialog',
    barrierColor: barrierColor ?? Colors.black.withOpacity(0.28),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (ctx, anim1, anim2) => builder(ctx),
    transitionBuilder: (ctx, anim, secondaryAnim, child) {
      final curvedValue = Curves.easeOutCubic.transform(anim.value);
      return Transform.scale(
        scale: 0.93 + (curvedValue * 0.07),
        child: Opacity(
          opacity: anim.value.clamp(0.0, 1.0),
          child: child,
        ),
      );
    },
  );
}

/// Helper to show modal bottom sheet with soft barrier so glass blur is vividly visible
Future<T?> showGlassBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  Color? barrierColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: isScrollControlled,
    barrierColor: barrierColor ?? Colors.black.withOpacity(0.22),
    builder: builder,
  );
}

/// Luxury Frosted Glass Dialog (نافذة زجاجية شفافة ضبابية)
/// Features real-time BackdropFilter gaussian blur, translucent adaptive background,
/// glowing glass border, and soft elevation.
class GlassDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? actionsPadding;
  final EdgeInsets? insetPadding;
  final double maxWidth;
  final double borderRadius;
  final double blur;
  final Widget? child;

  const GlassDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.contentPadding,
    this.actionsPadding,
    this.insetPadding,
    this.maxWidth = 380,
    this.borderRadius = 26,
    this.blur = 30.0,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark;

    // Translucent glass tints (شفافة وضبابية بانسيابية عالية)
    final glassBg = isDark
        ? const Color(0xFF090E18).withOpacity(0.50)
        : Colors.white.withOpacity(0.60);

    final glassBorder = isDark
        ? Colors.white.withOpacity(0.18)
        : Colors.black.withOpacity(0.10);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: insetPadding ??
          const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              decoration: BoxDecoration(
                color: glassBg,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: glassBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: child ??
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (title != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
                          child: DefaultTextStyle(
                            style: TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                            child: title!,
                          ),
                        ),
                      if (content != null)
                        Flexible(
                          child: SingleChildScrollView(
                            padding: contentPadding ??
                                const EdgeInsets.fromLTRB(22, 0, 22, 18),
                            child: DefaultTextStyle(
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                                height: 1.45,
                              ),
                              child: content!,
                            ),
                          ),
                        ),
                      if (actions != null && actions!.isNotEmpty)
                        Padding(
                          padding: actionsPadding ??
                              const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: actions!,
                          ),
                        ),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted Glass Modal Bottom Sheet Container (نافذة سفلية زجاجية ضبابية)
class GlassBottomSheet extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const GlassBottomSheet({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.blur = 30.0,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark;

    final glassBg = isDark
        ? const Color(0xFF080D16).withOpacity(0.48)
        : Colors.white.withOpacity(0.58);

    final glassBorder = isDark
        ? Colors.white.withOpacity(0.18)
        : Colors.black.withOpacity(0.10);

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: glassBg,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(borderRadius)),
            border: Border.all(color: glassBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                blurRadius: 32,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Sub-container card for grouping options inside a GlassBottomSheet or GlassDialog
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark;
    final bg = isDark
        ? Colors.white.withOpacity(0.045)
        : Colors.black.withOpacity(0.025);
    final border = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.045);

    Widget content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border, width: 1),
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: content,
        ),
      );
    }

    return content;
  }
}
