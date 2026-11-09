import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/language_service.dart';
import '../services/song_edit_service.dart';
import '../theme/app_theme.dart';
import '../widgets/artist_selector_sheet.dart';
import '../widgets/query_artwork_or_fallback.dart';
import '../widgets/glass_dialog.dart';

class EditSongScreen extends StatefulWidget {
  final SongModel song;

  const EditSongScreen({super.key, required this.song});

  @override
  State<EditSongScreen> createState() => _EditSongScreenState();
}

class _EditSongScreenState extends State<EditSongScreen> {
  final SongEditService _editService = SongEditService();
  late TextEditingController _titleController;
  late TextEditingController _artistController;

  String? _selectedArtworkPath;
  bool _isArtworkCleared = false;
  bool _isSaving = false;
  bool _isReverting = false;

  @override
  void initState() {
    super.initState();
    final editInfo = _editService.getEditInfo(widget.song.id);

    final initialTitle = editInfo?.title.isNotEmpty == true
        ? editInfo!.title
        : widget.song.title;
    final rawArtist = editInfo?.artist.isNotEmpty == true
        ? editInfo!.artist
        : (widget.song.artist ?? '');
    final isUnknown = rawArtist.trim().toLowerCase() == '<unknown>' ||
        rawArtist.trim().toLowerCase() == 'unknown' ||
        rawArtist.trim() == LanguageService.tr('unknown_artist');

    final initialArtist = isUnknown ? '' : rawArtist;

    _titleController = TextEditingController(text: initialTitle);
    _artistController = TextEditingController(text: initialArtist);

    final existingCustomArt = _editService.getCustomArtworkPath(widget.song.id);
    _selectedArtworkPath = (existingCustomArt != null && File(existingCustomArt).existsSync())
        ? existingCustomArt
        : null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  Future<void> _openArtistSelector() async {
    final selected = await ArtistSelectorSheet.show(
      context,
      currentArtist: _artistController.text,
      songTitle: _titleController.text,
    );
    if (selected != null && selected.isNotEmpty) {
      setState(() {
        _artistController.text = selected;
      });
    }
  }

  Future<void> _pickArtworkFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (picked == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final ext = picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
      final newArtworkFile = File('${appDir.path}/song_art_${widget.song.id}_${DateTime.now().millisecondsSinceEpoch}.$ext');

      await File(picked.path).copy(newArtworkFile.path);

      if (mounted) {
        setState(() {
          _selectedArtworkPath = newArtworkFile.path;
          _isArtworkCleared = false;
        });
      }
    } catch (e) {
      debugPrint('Error picking song artwork: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageService().t('pick_image_error')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _removeCustomArtwork() {
    setState(() {
      _selectedArtworkPath = null;
      _isArtworkCleared = true;
    });
  }

  Future<void> _saveChanges() async {
    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService().t('enter_song_title')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await _editService.saveSongEdits(
      song: widget.song,
      newTitle: title,
      newArtist: artist,
      newArtworkPath: _selectedArtworkPath,
      clearCustomArtwork: _isArtworkCleared,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageService().t('save_edits_success')),
            backgroundColor: AppTheme.accentColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageService().t('save_edits_error')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _revertToOriginal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: Directionality.of(context),
        child: GlassDialog(
          title: Row(
            children: [
              Icon(Icons.restore_rounded, color: AppTheme.accentColor),
              const SizedBox(width: 10),
              Text(
                LanguageService().t('revert_dialog_title'),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 17),
              ),
            ],
          ),
          content: Text(
            LanguageService().t('revert_dialog_desc'),
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(LanguageService().t('cancel'), style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(LanguageService().t('revert_confirm_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _isReverting = true);

    final ok = await _editService.revertToOriginal(widget.song);

    if (mounted) {
      setState(() {
        _isReverting = false;
        if (ok) {
          _selectedArtworkPath = null;
          _isArtworkCleared = false;
        }
      });
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageService().t('revert_success')),
            backgroundColor: AppTheme.accentColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageService().t('revert_error')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        AppTheme.themeModeNotifier,
        AppTheme.accentColorNotifier,
        AppTheme.amoledBlackNotifier,
        LanguageService().currentLanguage,
      ]),
      builder: (context, _) {
        final isEdited = _editService.isSongEditedOrTrimmed(widget.song.id) ||
            _selectedArtworkPath != null ||
            _isArtworkCleared;

        return Directionality(
          textDirection: Directionality.of(context),
          child: Scaffold(
            backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              LanguageService().isArabic
                  ? Icons.arrow_forward_rounded
                  : Icons.arrow_back_rounded,
              color: AppTheme.textPrimary,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            LanguageService().t('edit'),
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accentColor,
                  backgroundColor: AppTheme.accentColor.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: _isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentColor),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  LanguageService().t('save'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _isSaving ? null : _saveChanges,
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Cover Artwork Preview & Edit
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _pickArtworkFromGallery,
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: 146,
                        height: 146,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Main Artwork Card
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: AppTheme.cardColor,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: _selectedArtworkPath != null
                                        ? AppTheme.accentColor.withValues(alpha: 0.8)
                                        : AppTheme.cardBorder,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_selectedArtworkPath != null ? AppTheme.accentColor : Colors.black).withOpacity(0.25),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: _buildArtworkWidget(),
                                ),
                              ),
                            ),
                            // Modern Floating Pencil Icon in Bottom-Right Corner
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickArtworkFromGallery,
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.background,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.edit_rounded,
                                    size: 19,
                                    color: AppTheme.accentColor.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedArtworkPath != null || (!_isArtworkCleared && _editService.getCustomArtworkPath(widget.song.id) != null)) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFF5252),
                          backgroundColor: const Color(0xFFFF5252).withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 17),
                        label: Text(
                          LanguageService().t('remove_custom_cover'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _removeCustomArtwork,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // 2. Song Title & Artist TextFields
              _buildSectionTitle(LanguageService().t('basic_info'), Icons.edit_note_rounded),
              const SizedBox(height: 14),

              // Song Title Field
              _buildInputField(
                controller: _titleController,
                label: LanguageService().t('song_title_label'),
                hint: LanguageService().t('song_title_hint'),
                icon: Icons.music_note_rounded,
              ),
              const SizedBox(height: 16),

              // Artist Name Field (Editable directly by typing or choosing via dropdown)
              _buildInputField(
                controller: _artistController,
                label: LanguageService().t('artist_name_label'),
                hint: LanguageService().t('artist_name_hint'),
                icon: Icons.person_rounded,
                suffix: IconButton(
                  icon: Icon(Icons.arrow_drop_down_circle_rounded, color: AppTheme.accentColor, size: 22),
                  tooltip: LanguageService().t('select_artist_title'),
                  onPressed: _openArtistSelector,
                ),
              ),

              const SizedBox(height: 32),

              // 3. Save Button
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: AppTheme.accentColor.computeLuminance() > 0.4 ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black),
                        )
                      : const Icon(Icons.save_rounded, size: 22),
                  label: Text(
                    _isSaving ? LanguageService().t('saving') : LanguageService().t('save_edits'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: _isSaving ? null : _saveChanges,
                ),
              ),

              // 4. Revert to Original Button (Only if edited before)
              if (isEdited) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF5252),
                      side: BorderSide(
                        color: AppTheme.isDark ? const Color(0xFF452226) : const Color(0xFFFFCDD2),
                        width: 1.2,
                      ),
                      backgroundColor: AppTheme.isDark
                          ? const Color(0xFF261214).withOpacity(0.4)
                          : const Color(0xFFFFEBEE).withOpacity(0.6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _isReverting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF5252)),
                          )
                        : const Icon(Icons.restore_rounded, size: 20),
                    label: Text(
                      LanguageService().t('revert_to_original'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: _isReverting ? null : _revertToOriginal,
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildArtworkWidget() {
    if (_selectedArtworkPath != null && File(_selectedArtworkPath!).existsSync()) {
      return Image.file(
        File(_selectedArtworkPath!),
        width: 140,
        height: 140,
        fit: BoxFit.cover,
      );
    }

    if (_isArtworkCleared) {
      return QueryArtworkWidget(
        id: widget.song.id,
        type: ArtworkType.AUDIO,
        artworkWidth: 140,
        artworkHeight: 140,
        artworkFit: BoxFit.cover,
        artworkBorder: BorderRadius.zero,
        artworkQuality: FilterQuality.high,
        keepOldArtwork: false,
        quality: 100,
        format: ArtworkFormat.JPEG,
        size: 1000,
        nullArtworkWidget: Container(
          width: 140,
          height: 140,
          color: AppTheme.isDark ? const Color(0xFF222834) : const Color(0xFFE2E8F0),
          child: Icon(Icons.music_note_rounded, size: 50, color: AppTheme.textSecondary.withOpacity(0.4)),
        ),
      );
    }

    return QueryArtworkOrFallback(
      id: widget.song.id,
      size: 140,
      borderRadius: 0,
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.accentColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    VoidCallback? onTap,
    Widget? suffix,
    bool readOnly = false,
  }) {
    final scaffoldBg = AppTheme.background;
    final isScaffoldLight = scaffoldBg.computeLuminance() > 0.35;
    final isThemeLight = Theme.of(context).brightness == Brightness.light;
    final isLight = isScaffoldLight || isThemeLight || !AppTheme.isDark;

    final fieldBg = isLight ? Colors.white : const Color(0xFF141A23);
    final fieldBorder = isLight ? const Color(0xFFCBD5E1) : const Color(0xFF263242);
    final textColor = isLight ? const Color(0xFF0F172A) : Colors.white;
    final labelColor = isLight ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final hintColor = isLight ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: fieldBorder, width: 1.2),
            boxShadow: isLight
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            cursorColor: AppTheme.accentColor,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: hintColor, fontSize: 13.5),
              prefixIcon: Icon(icon, color: AppTheme.accentColor, size: 20),
              suffixIcon: suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            ),
          ),
        ),
      ],
    );
  }
}
