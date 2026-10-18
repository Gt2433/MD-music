import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/language_service.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppTheme.accentColorNotifier,
      builder: (context, accentColor, _) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              LanguageService.tr('privacy_policy'),
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shield_outlined, color: accentColor, size: 36),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    LanguageService.tr('offline_guarantee_title'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    LanguageService.tr('offline_guarantee_subtitle'),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                _buildPolicyCard(
                  accentColor,
                  Icons.signal_cellular_connected_no_internet_4_bar_rounded,
                  LanguageService.tr('policy_item1_title'),
                  LanguageService.tr('policy_item1_desc'),
                ),
                const SizedBox(height: 12),
                _buildPolicyCard(
                  accentColor,
                  Icons.person_off_outlined,
                  LanguageService.tr('policy_item2_title'),
                  LanguageService.tr('policy_item2_desc'),
                ),
                const SizedBox(height: 12),
                _buildPolicyCard(
                  accentColor,
                  Icons.folder_shared_outlined,
                  LanguageService.tr('policy_item3_title'),
                  LanguageService.tr('policy_item3_desc'),
                ),
                const SizedBox(height: 12),
                _buildPolicyCard(
                  accentColor,
                  Icons.lock_outline_rounded,
                  LanguageService.tr('policy_item4_title'),
                  LanguageService.tr('policy_item4_desc'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPolicyCard(Color accentColor, IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
