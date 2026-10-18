import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/audio_service.dart';

class NowPlayingArtwork extends StatefulWidget {
  final int songId;
  final double size;

  const NowPlayingArtwork({
    super.key,
    required this.songId,
    this.size = 320,
  });

  @override
  State<NowPlayingArtwork> createState() => _NowPlayingArtworkState();
}

class _NowPlayingArtworkState extends State<NowPlayingArtwork> {
  Uint8List? _bytes;
  bool _loaded = false;
  int? _currentId;

  @override
  void initState() {
    super.initState();
    _loadArtwork();
  }

  @override
  void didUpdateWidget(covariant NowPlayingArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.songId != widget.songId) {
      _loadArtwork();
    }
  }

  Future<void> _loadArtwork() async {
    final id = widget.songId;
    _currentId = id;
    final bytes = await AudioService().getSongArtworkBytes(id);
    if (mounted && _currentId == id) {
      setState(() {
        _bytes = bytes;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // 1. Wide Ambient Glow Halo (Spreads 360° broadly with vibrant artwork colors)
        Transform.scale(
          scale: 1.15,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 54, sigmaY: 54),
            child: Opacity(
              opacity: 0.92,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: _buildGlowContent(),
                ),
              ),
            ),
          ),
        ),

        // 2. Focused Radiant Bloom (Intense colored light directly hugging the card)
        Positioned(
          top: 18,
          child: Transform.scale(
            scale: 1.08,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Opacity(
                opacity: 0.95,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _buildGlowContent(),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 3. Crisp Edge Aura (Highlights borders with glowing saturation)
        Transform.scale(
          scale: 1.03,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Opacity(
              opacity: 0.85,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: _buildGlowContent(),
                ),
              ),
            ),
          ),
        ),

        // 4. Foreground sharp album artwork card
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: const Color(0xFF222834),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.40),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Container(
              color: const Color(0xFF222834),
              child: _buildArtworkContent(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlowContent() {
    if (_bytes != null && _bytes!.isNotEmpty) {
      return Image.memory(
        _bytes!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
      );
    }
    return Image.asset(
      'assets/images/app_icon.png',
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
    );
  }

  Widget _buildArtworkContent() {
    if (_bytes != null && _bytes!.isNotEmpty) {
      return Image.memory(
        _bytes!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
    }

    if (_loaded && _bytes == null) {
      // Fallback: MD Music app icon with 50% opacity
      return Opacity(
        opacity: 0.5,
        child: Image.asset(
          'assets/images/app_icon.png',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      );
    }

    // While loading first time, show placeholder with 50% opacity app icon
    return Container(
      width: widget.size,
      height: widget.size,
      color: const Color(0xFF161C22),
      child: Center(
        child: Opacity(
          opacity: 0.5,
          child: Image.asset(
            'assets/images/app_icon.png',
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
