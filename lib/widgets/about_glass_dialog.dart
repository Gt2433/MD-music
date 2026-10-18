import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/language_service.dart';

/// Shows a rich glassmorphic About modal dialog featuring the app icon,
/// name, version, developer info (Mohammed Bahayou), and official social links.
Future<void> showAboutGlassDialog(
  BuildContext context, {
  String versionName = '1.0.0',
  int versionCode = 1,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'AboutDialog',
    barrierColor: Colors.black.withOpacity(0.55),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, anim1, anim2) {
      return AboutGlassDialog(
        versionName: versionName,
        versionCode: versionCode,
      );
    },
    transitionBuilder: (ctx, anim, secondaryAnim, child) {
      final curvedValue = Curves.easeOutCubic.transform(anim.value);
      return Transform.scale(
        scale: 0.92 + (curvedValue * 0.08),
        child: Opacity(
          opacity: anim.value.clamp(0.0, 1.0),
          child: child,
        ),
      );
    },
  );
}

class AboutGlassDialog extends StatelessWidget {
  final String versionName;
  final int versionCode;

  const AboutGlassDialog({
    super.key,
    this.versionName = '1.0.0',
    this.versionCode = 1,
  });

  static const String _tiktokUrl =
      'https://www.tiktok.com/@mbd_dev1?is_from_webapp=1&sender_device=pc';
  static const String _instagramUrl =
      'https://www.instagram.com/moh_bah_dev/';
  static const String _whatsappUrl =
      'https://wa.me/213655603829';

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Failed to open $url: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppTheme.accentColor;

    // Glass styling tokens
    final glassBg = isDark
        ? const Color(0xFF14171F).withOpacity(0.78)
        : Colors.white.withOpacity(0.85);

    final glassBorder = isDark
        ? Colors.white.withOpacity(0.14)
        : Colors.black.withOpacity(0.08);

    final dividerColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: glassBg,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: glassBorder, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(isDark ? 0.22 : 0.15),
                      blurRadius: 36,
                      spreadRadius: 2,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Row: Close button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: accentColor.withOpacity(0.25),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 14,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  LanguageService.tr('about'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: AppTheme.textSecondary,
                            splashRadius: 20,
                            tooltip: LanguageService.tr('close'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // App Logo with glowing border
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.35),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: accentColor.withOpacity(0.55),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stack) => Container(
                              color: AppTheme.surface,
                              child: Icon(
                                Icons.music_note_rounded,
                                color: accentColor,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // App Name
                      Text(
                        'MD Music',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Tagline
                      Text(
                        LanguageService.tr('offline_music_tagline'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Version Badge (Clickable to copy)
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(
                              text: 'MD Music v$versionName ($versionCode)'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text(LanguageService.tr('version_copied')),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.12)
                                  : Colors.black.withOpacity(0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_outlined,
                                size: 14,
                                color: accentColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'v$versionName (Build $versionCode)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Divider
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Divider(color: dividerColor, height: 1),
                      ),

                      // Developer Section Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.04)
                              : Colors.black.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.05),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.code_rounded,
                                  size: 16,
                                  color: accentColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  LanguageService.tr('developer_title'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              LanguageService().isArabic
                                  ? 'محمد باحيو'
                                  : 'Mohammed Bahayou',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (LanguageService().isArabic) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Mohammed Bahayou',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Social Media Section Label
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          LanguageService.tr('social_media'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Row of Social Media Buttons (WhatsApp, Instagram, TikTok)
                      Directionality(
                        textDirection: LanguageService().textDirection,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // 1. WhatsApp
                            _buildSocialButton(
                              context: context,
                              title: 'WhatsApp',
                              iconAsset: 'assets/images/icon_whatsapp.png',
                              glowColor: const Color(0xFF25D366),
                              onTap: () => _launch(_whatsappUrl),
                            ),

                            // 2. Instagram
                            _buildSocialButton(
                              context: context,
                              title: 'Instagram',
                              iconAsset: 'assets/images/icon_instagram.png',
                              glowColor: const Color(0xFFE1306C),
                              onTap: () => _launch(_instagramUrl),
                            ),

                            // 3. TikTok
                            _buildSocialButton(
                              context: context,
                              title: 'TikTok',
                              iconAsset: 'assets/images/icon_tiktok.png',
                              glowColor: const Color(0xFF00F2FE),
                              onTap: () => _launch(_tiktokUrl),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Copyright
                      Text(
                        LanguageService.tr('copyright'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required BuildContext context,
    required String title,
    required String iconAsset,
    required Color glowColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            splashColor: glowColor.withOpacity(0.25),
            highlightColor: glowColor.withOpacity(0.15),
            child: Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E222D).withOpacity(0.85)
                    : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: glowColor.withOpacity(0.4),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withOpacity(0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Image.asset(
                iconAsset,
                fit: BoxFit.contain,
                errorBuilder: (_, error, stack) => Icon(
                  Icons.open_in_browser_rounded,
                  color: glowColor,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
