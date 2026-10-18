import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../services/language_service.dart';
import '../services/settings_repository.dart';
import '../theme/app_theme.dart';

class CustomBackgroundEditorScreen extends StatefulWidget {
  final File imageFile;
  final double? initialBlur;
  final double? initialOpacity;

  const CustomBackgroundEditorScreen({
    super.key,
    required this.imageFile,
    this.initialBlur,
    this.initialOpacity,
  });

  @override
  State<CustomBackgroundEditorScreen> createState() =>
      _CustomBackgroundEditorScreenState();
}

class _CustomBackgroundEditorScreenState
    extends State<CustomBackgroundEditorScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  final TransformationController _transController =
      TransformationController();

  late double _blur;
  late double _opacity;
  bool _showUiOverlay = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final repo = SettingsRepository();
    _blur = widget.initialBlur ?? repo.customBgBlur;
    _opacity = widget.initialOpacity ?? repo.customBgOpacity;
    if (_opacity <= 0.05) _opacity = 0.85;
  }

  @override
  void dispose() {
    _transController.dispose();
    super.dispose();
  }

  void _resetZoomAndPan() {
    HapticFeedback.lightImpact();
    _transController.value = Matrix4.identity();
    setState(() {});
  }

  Future<void> _saveAndApplyBackground() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      HapticFeedback.mediumImpact();

      // 1. Capture the zoomed & positioned viewport
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('Could not capture preview boundary');
      }

      final pixelRatio = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
      final ui.Image capturedImage = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData =
          await capturedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Could not convert image to bytes');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // 2. Save captured cropped image and copy original image to app documents
      final docsDir = await getApplicationDocumentsDirectory();
      final bgDir = Directory('${docsDir.path}/custom_bg');
      if (!await bgDir.exists()) {
        await bgDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final croppedFile = File('${bgDir.path}/bg_cropped_$timestamp.png');
      await croppedFile.writeAsBytes(pngBytes, flush: true);

      final originalFile = File('${bgDir.path}/bg_original_$timestamp.jpg');
      if (await widget.imageFile.exists()) {
        await widget.imageFile.copy(originalFile.path);
      }

      // 3. Persist to SettingsRepository
      final repo = SettingsRepository();
      await repo.setCustomBgImage(
        imagePath: croppedFile.path,
        rawImagePath: originalFile.path,
        blur: _blur,
        opacity: _opacity,
      );

      // 4. Update AppTheme immediately
      AppTheme.bgTypeNotifier.value = 'image';
      AppTheme.customBgImageNotifier.value = croppedFile.path;
      AppTheme.customBgBlurNotifier.value = _blur;
      AppTheme.customBgOpacityNotifier.value = _opacity;
      AppTheme.updateSystemUIOverlay();

      if (!mounted) return;

      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  LanguageService.tr('background_applied_success'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.accentColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    } catch (e) {
      debugPrint('Error saving background: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save background: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = LanguageService().isArabic;
    final accent = AppTheme.accentColor;
    final repo = SettingsRepository();
    final baseColor = repo.bgType == 'color'
        ? repo.customBgColor
        : (AppTheme.isDark ? AppTheme.darkBackground : AppTheme.lightBackground);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. The Framed Image RepaintBoundary for high-res capture
          Positioned.fill(
            child: RepaintBoundary(
              key: _boundaryKey,
              child: Container(
                color: baseColor,
                child: InteractiveViewer(
                  transformationController: _transController,
                  minScale: 0.6,
                  maxScale: 4.5,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  child: Image.file(
                    widget.imageFile,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(color: baseColor),
                  ),
                ),
              ),
            ),
          ),

          // 2. Hardware-accelerated Live Blur Filter
          if (_blur > 0.05)
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
                child: Container(color: Colors.transparent),
              ),
            ),

          // 3. Transparency Bleed-Through Layer (shows base color behind)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: baseColor.withOpacity(
                  (1.0 - _opacity.clamp(0.1, 1.0)).clamp(0.0, 0.95),
                ),
              ),
            ),
          ),

          // 4. Subtle Contrast Scrim for text clarity
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.35),
                      Colors.black.withOpacity(0.12),
                      Colors.black.withOpacity(0.35),
                      Colors.black.withOpacity(0.65),
                    ],
                    stops: const [0.0, 0.25, 0.70, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 5. Realistic App UI Mock Overlay (Toggled via eye icon)
          if (_showUiOverlay)
            Positioned.fill(
              child: IgnorePointer(
                child: _buildRealisticAppUiOverlay(accent, isRtl),
              ),
            ),

          // 6. Top Custom Navigation Header Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    // Back button
                    _buildGlassCircleButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        LanguageService.tr('bg_editor_title'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                                color: Colors.black87,
                                blurRadius: 10,
                                offset: Offset(0, 2))
                          ],
                        ),
                      ),
                    ),
                    // Reset zoom/pan button
                    _buildGlassCircleButton(
                      icon: Icons.center_focus_strong_rounded,
                      tooltip: 'إعادة ضبط التمركز',
                      onTap: _resetZoomAndPan,
                    ),
                    const SizedBox(width: 8),
                    // Eye button for toggling realistic UI overlay
                    _buildGlassCircleButton(
                      icon: _showUiOverlay
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      tooltip: LanguageService.tr('toggle_ui_preview'),
                      color: _showUiOverlay ? accent : Colors.white,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _showUiOverlay = !_showUiOverlay);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 7. Interactive framing gesture hint badge
          if (_showUiOverlay)
            Positioned(
              top: MediaQuery.of(context).padding.top + 58,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pinch_rounded,
                          color: accent.withOpacity(0.9), size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          LanguageService.tr('zoom_pan_hint'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 8. Bottom Controls Bottom Sheet (Blur & Opacity Sliders + Save Action)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildControlsPanel(accent, isRtl),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
    String? tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Realistic MPD Music UI Mock Overlay
  // -------------------------------------------------------------
  Widget _buildRealisticAppUiOverlay(Color accent, bool isRtl) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const SizedBox(height: 52), // Spacing below top action bar

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withOpacity(0.6)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.music_note_rounded, color: accent),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'MD MUSIC',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Icon(Icons.search_rounded,
                    color: Colors.white.withOpacity(0.9), size: 22),
                const SizedBox(width: 14),
                Icon(Icons.settings_rounded,
                    color: Colors.white.withOpacity(0.9), size: 22),
              ],
            ),
          ),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildMockCategoryChip(
                    isRtl ? 'الكل' : 'All', true, accent),
                _buildMockCategoryChip(
                    isRtl ? 'الأغاني' : 'Songs', false, accent),
                _buildMockCategoryChip(
                    isRtl ? 'الألبومات' : 'Albums', false, accent),
                _buildMockCategoryChip(
                    isRtl ? 'الفنانون' : 'Artists', false, accent),
                _buildMockCategoryChip(
                    isRtl ? 'المفضلة' : 'Favorites', false, accent),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // 2-3 Realistic Song Tiles
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildMockSongTile(
                  title: isRtl ? 'أغنية تجريبية للمعاينة' : 'Sample Track Preview',
                  artist: isRtl ? 'فنان تجريبي • ألبوم الموسيقى' : 'Sample Artist • Studio Album',
                  duration: '03:45',
                  accent: accent,
                  isCurrent: true,
                ),
                _buildMockSongTile(
                  title: isRtl ? 'لحن هادئ وسينمائي' : 'Cinematic Acoustic Melody',
                  artist: isRtl ? 'استوديو الصوتيات MPD' : 'MPD Audio Sessions',
                  duration: '04:12',
                  accent: accent,
                  isCurrent: false,
                ),
                _buildMockSongTile(
                  title: isRtl ? 'إيقاع نيون عصري' : 'Cyber Neon Horizon',
                  artist: isRtl ? 'موسيقى رائعة' : 'Electronic Waves',
                  duration: '02:58',
                  accent: accent,
                  isCurrent: false,
                ),
              ],
            ),
          ),

          // Docked Mini Player Mock
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 240),
            child: Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF141A23).withOpacity(0.88),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.album_rounded, color: accent, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRtl ? 'أغنية تجريبية للمعاينة' : 'Sample Track Preview',
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isRtl ? 'استماع مباشر • MPD Music' : 'Now Playing • MPD Music',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pause_rounded,
                        color: Colors.black, size: 22),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.skip_next_rounded,
                      color: Colors.white.withOpacity(0.85), size: 26),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockCategoryChip(String title, bool isSelected, Color accent) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7.5),
      decoration: BoxDecoration(
        color: isSelected
            ? accent
            : const Color(0xFF161E28).withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? accent : Colors.white.withOpacity(0.16),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white.withOpacity(0.9),
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildMockSongTile({
    required String title,
    required String artist,
    required String duration,
    required Color accent,
    required bool isCurrent,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent
            ? accent.withOpacity(0.12)
            : Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? accent.withOpacity(0.4)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCurrent ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
              color: isCurrent ? accent : Colors.white70,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  style: TextStyle(
                    color: isCurrent ? accent : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  artist,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            duration,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.more_vert_rounded,
              color: Colors.white.withOpacity(0.6), size: 18),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Bottom Controls Panel (Sliders for Blur & Opacity + Save Button)
  // -------------------------------------------------------------
  Widget _buildControlsPanel(Color accent, bool isRtl) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F151F).withOpacity(0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 1. Blur Slider Row
            Row(
              children: [
                Icon(Icons.blur_on_rounded, color: accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  LanguageService.tr('bg_blur_slider'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _blur <= 0.5
                        ? LanguageService.tr('bg_blur_none')
                        : '${(_blur / 30 * 100).toInt()}%',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  activeTrackColor: accent,
                  inactiveTrackColor: Colors.white.withOpacity(0.15),
                  thumbColor: Colors.white,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 10),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 18),
                ),
                child: Slider(
                  value: _blur,
                  min: 0.0,
                  max: 30.0,
                  onChanged: (val) {
                    setState(() => _blur = val);
                  },
                ),
              ),
            ),

            const SizedBox(height: 6),

            // 2. Opacity / Transparency Slider Row
            Row(
              children: [
                Icon(Icons.opacity_rounded, color: accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  LanguageService.tr('bg_opacity_slider'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${(_opacity * 100).toInt()}%',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  activeTrackColor: accent,
                  inactiveTrackColor: Colors.white.withOpacity(0.15),
                  thumbColor: Colors.white,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 10),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 18),
                ),
                child: Slider(
                  value: _opacity,
                  min: 0.1,
                  max: 1.0,
                  onChanged: (val) {
                    setState(() => _opacity = val);
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 3. Save & Apply Action Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  elevation: 8,
                  shadowColor: accent.withOpacity(0.55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isSaving ? null : _saveAndApplyBackground,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.check_rounded,
                        color: Colors.black, size: 22),
                label: Text(
                  _isSaving
                      ? LanguageService.tr('saving_background')
                      : LanguageService.tr('save_background'),
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
