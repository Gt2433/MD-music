import 'dart:io';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../services/song_edit_service.dart';

class QueryArtworkOrFallback extends StatelessWidget {
  final int id;
  final ArtworkType type;
  final double size;
  final double borderRadius;
  final IconData fallbackIcon;
  final int? artworkRequestSize;

  const QueryArtworkOrFallback({
    super.key,
    required this.id,
    this.type = ArtworkType.AUDIO,
    this.size = 52,
    this.borderRadius = 12,
    this.fallbackIcon = Icons.music_note_rounded,
    this.artworkRequestSize,
  });

  @override
  Widget build(BuildContext context) {
    final customArt = SongEditService().getCustomArtworkPath(id);
    if (customArt != null && File(customArt).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.file(
          File(customArt),
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      );
    }

    final reqSize = artworkRequestSize ?? (size >= 100 ? 1000 : (size * 3).toInt().clamp(300, 800));

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: QueryArtworkWidget(
        id: id,
        type: type,
        artworkWidth: size,
        artworkHeight: size,
        artworkFit: BoxFit.cover,
        artworkBorder: BorderRadius.zero,
        artworkQuality: FilterQuality.high,
        keepOldArtwork: true,
        quality: 100,
        format: ArtworkFormat.JPEG,
        size: reqSize,
        nullArtworkWidget: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF222834),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Opacity(
              opacity: 0.5,
              child: Image.asset(
                'assets/images/app_icon.png',
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
