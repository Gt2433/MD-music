import 'dart:io';
import 'package:flutter/material.dart';
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

  Future<void> _saveChanges() async {
    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال اسم الأغنية'),
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
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم حفظ التعديلات بنجاح ✨'),
            backgroundColor: AppTheme.accentColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء حفظ التعديلات'),
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
        textDirection: TextDirection.rtl,
        child: GlassDialog(
          title: Row(
            children: [
              Icon(Icons.restore_rounded, color: AppTheme.accentColor),
              const SizedBox(width: 10),
              Text(
                'استعادة البيانات الأصلية',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 17),
              ),
            ],
          ),
          content: Text(
            'هل أنت متأكد من إلغاء التعديلات واستعادة الاسم واسم الفنان الأصليين؟',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نعم، استعادة الأصلية', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _isReverting = true);

    final ok = await _editService.revertToOriginal(widget.song);

    if (mounted) {
      setState(() => _isReverting = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تمت استعادة البيانات الأصلية بنجاح 🔄'),
            backgroundColor: AppTheme.accentColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر استعادة البيانات الأصلية'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdited = _editService.isSongEditedOrTrimmed(widget.song.id);

    return Directionality(
      textDirection: Directionality.of(context),
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_forward_rounded, color: AppTheme.textPrimary),
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
              // 1. Cover Artwork Preview
              Center(
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _buildArtworkWidget(),
                  ),
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
                    _isSaving ? 'جارِ الحفظ...' : 'حفظ التعديلات',
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
                      side: const BorderSide(color: Color(0xFF452226), width: 1.2),
                      backgroundColor: const Color(0xFF261214).withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _isReverting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF5252)),
                          )
                        : const Icon(Icons.restore_rounded, size: 20),
                    label: const Text(
                      'إرجاع للبيانات الأصلية',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
  }

  Widget _buildArtworkWidget() {
    final customPath = _editService.getCustomArtworkPath(widget.song.id);
    if (customPath != null && File(customPath).existsSync()) {
      return Image.file(
        File(customPath),
        width: 130,
        height: 130,
        fit: BoxFit.cover,
      );
    }
    return QueryArtworkOrFallback(
      id: widget.song.id,
      size: 130,
      borderRadius: 20,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131922),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF202A36), width: 1),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14.5),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
              suffixIcon: suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
