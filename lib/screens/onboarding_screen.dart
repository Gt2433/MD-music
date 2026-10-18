import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_preferences.dart';
import '../services/language_service.dart';
import '../theme/app_theme.dart';
import 'main_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final String _tiktokUrl = 'https://www.tiktok.com/@mbd_dev1?is_from_webapp=1&sender_device=pc';
  final String _instagramUrl = 'https://www.instagram.com/moh_bah_dev/';
  final String _whatsappUrl = 'https://wa.me/213655603829';

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $url: $e');
    }
  }

  void _goToNext() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _finishOnboarding() async {
    await AppPreferences.setOnboardingCompleted();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: LanguageService().textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              // Top indicator & Skip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Page Indicator dots
                    Row(
                      children: List.generate(
                        2,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppTheme.primaryGreen
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    if (_currentPage == 0)
                      TextButton(
                        onPressed: _finishOnboarding,
                        child: Text(
                          LanguageService.tr('skip'),
                          style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 14),
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded, color: AppTheme.darkTextSecondary),
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                  ],
                ),
              ),

              // Page Views
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  children: [
                    _buildStepOne(),
                    _buildStepTwo(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Step 1: App Introduction & Logo
  // -------------------------------------------------------------
  Widget _buildStepOne() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          // App Logo
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                    blurRadius: 36,
                    spreadRadius: 4,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppTheme.surfaceLight,
                      child: Icon(Icons.music_note_rounded, color: AppTheme.primaryGreen, size: 70),
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            textDirection: TextDirection.ltr,
            children: [
              Text(
                'MD',
                style: TextStyle(
                  color: AppTheme.primaryGreen,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'MUSIC',
                style: TextStyle(
                  color: AppTheme.darkTextPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            LanguageService.tr('onboarding_subtitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.darkTextSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 24),

          // Definitions / Highlights
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.18)),
            ),
            child: Column(
              children: [
                _buildHighlightRow(
                  Icons.wifi_off_rounded,
                  LanguageService.tr('offline_feature_title'),
                  LanguageService.tr('offline_feature_desc'),
                ),
                const Divider(color: Colors.white10, height: 20),
                _buildHighlightRow(
                  Icons.library_music_rounded,
                  LanguageService.tr('auto_discovery_title'),
                  LanguageService.tr('auto_discovery_desc'),
                ),
                const Divider(color: Colors.white10, height: 20),
                _buildHighlightRow(
                  Icons.palette_outlined,
                  LanguageService.tr('design_feature_title'),
                  LanguageService.tr('design_feature_desc'),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Next Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.black,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _goToNext,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    LanguageService.tr('next'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    LanguageService().isArabic ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHighlightRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryGreen, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.darkTextPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Step 2: Partnership (MD Music x MBD) & Social Platforms
  // -------------------------------------------------------------
  Widget _buildStepTwo() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        children: [
          const SizedBox(height: 10),

          // Partnership Badge Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, color: AppTheme.primaryGreen, size: 16),
                const SizedBox(width: 6),
                Text(
                  LanguageService.tr('partnership_badge'),
                  style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Two Logos with Contract/Partnership symbol
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF161E24), Color(0xFF101418)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.primaryGreen.withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              children: [
                // Side by Side: icon.ico + CONTRACT SYMBOL + MBD.png
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // App Logo
                    Column(
                      children: [
                        Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'MD Music',
                          style: TextStyle(
                            color: AppTheme.darkTextPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    // Contract / Collaboration Symbol
                    Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppTheme.accentColor, AppTheme.accentColor.withValues(alpha: 0.7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.handshake_rounded,
                            color: Colors.black,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            LanguageService.tr('contract_partnership'),
                            style: TextStyle(
                              color: AppTheme.primaryGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // MBD Logo
                    Column(
                      children: [
                        Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'MBD Tech',
                          style: TextStyle(
                            color: AppTheme.darkTextPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),

                // "من مشاريع MBD" Label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryGreen, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        LanguageService.tr('mbd_project_label'),
                        style: const TextStyle(
                          color: AppTheme.darkTextPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Social Platforms Section Header
          Text(
            LanguageService.tr('connect_developer'),
            style: const TextStyle(
              color: AppTheme.darkTextSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 18),

          // Horizontal Row of 3 Icon Buttons
          Directionality(
            textDirection: LanguageService().textDirection,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. WhatsApp (Right)
                _buildSocialIconButton(
                  tooltip: 'WhatsApp',
                  accentColor: const Color(0xFF25D366),
                  icon: Image.asset(
                    'assets/images/icon_whatsapp.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                  ),
                  onTap: () => _launchUrl(_whatsappUrl),
                ),

                const SizedBox(width: 24),

                // 2. Instagram (Center)
                _buildSocialIconButton(
                  tooltip: 'Instagram',
                  accentColor: const Color(0xFFE1306C),
                  icon: Image.asset(
                    'assets/images/icon_instagram.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                  ),
                  onTap: () => _launchUrl(_instagramUrl),
                ),

                const SizedBox(width: 24),

                // 3. TikTok (Left)
                _buildSocialIconButton(
                  tooltip: 'TikTok',
                  accentColor: const Color(0xFF00F2FE),
                  icon: Image.asset(
                    'assets/images/icon_tiktok.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                  ),
                  onTap: () => _launchUrl(_tiktokUrl),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // Start Listening / Enter App Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.black,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _finishOnboarding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_circle_fill_rounded, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    LanguageService.tr('enter_app_start_listening'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSocialIconButton({
    required Widget icon,
    required Color accentColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          color: const Color(0xFF141920),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.22),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            splashColor: accentColor.withValues(alpha: 0.3),
            highlightColor: accentColor.withValues(alpha: 0.15),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}
