import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/language_service.dart';
import '../theme/app_theme.dart';

class AudioWaveformTrimmer extends StatefulWidget {
  final List<double> waveform;
  final double totalDurationSec;
  final double startSec;
  final double endSec;
  final double currentPreviewSec;
  final bool isPlayingPreview;
  final Function(double start, double end) onTrimChanged;
  final VoidCallback onTogglePreview;

  const AudioWaveformTrimmer({
    super.key,
    required this.waveform,
    required this.totalDurationSec,
    required this.startSec,
    required this.endSec,
    required this.currentPreviewSec,
    required this.isPlayingPreview,
    required this.onTrimChanged,
    required this.onTogglePreview,
  });

  @override
  State<AudioWaveformTrimmer> createState() => _AudioWaveformTrimmerState();
}

class _AudioWaveformTrimmerState extends State<AudioWaveformTrimmer> {
  // Dragging state: 0 = none, 1 = start handle, 2 = end handle, 3 = selection body
  int _activeDrag = 0;
  double _dragStartX = 0;
  double _initialStartSec = 0;
  double _initialEndSec = 0;

  String _formatTime(double sec) {
    final s = sec.clamp(0.0, widget.totalDurationSec).round();
    final m = s ~/ 60;
    final rem = s % 60;
    return '${m.toString().padLeft(2, '0')}:${rem.toString().padLeft(2, '0')}';
  }

  void _fineTuneStart(double delta) {
    HapticFeedback.selectionClick();
    final newStart = (widget.startSec + delta).clamp(0.0, widget.endSec - 1.0);
    widget.onTrimChanged(newStart, widget.endSec);
  }

  void _fineTuneEnd(double delta) {
    HapticFeedback.selectionClick();
    final newEnd = (widget.endSec + delta).clamp(widget.startSec + 1.0, widget.totalDurationSec);
    widget.onTrimChanged(widget.startSec, newEnd);
  }

  @override
  Widget build(BuildContext context) {
    final clipDuration = (widget.endSec - widget.startSec).clamp(0.0, widget.totalDurationSec);
    final accent = AppTheme.accentColor;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131922),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF222C3A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Time summary badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBadge(LanguageService().t('trim_start'), _formatTime(widget.startSec), accent),
              _buildBadge(LanguageService().t('clip_duration'), _formatTime(clipDuration), Colors.white, isBold: true),
              _buildBadge(LanguageService().t('trim_end'), _formatTime(widget.endSec), accent),
            ],
          ),

          const SizedBox(height: 18),

          // 2. Interactive Waveform Visualizer
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              const height = 96.0;

              return SizedBox(
                width: width,
                height: height,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final localX = details.localPosition.dx.clamp(0.0, width);

                    final startX = (widget.startSec / widget.totalDurationSec) * width;
                    final endX = (widget.endSec / widget.totalDurationSec) * width;

                    const hitRadius = 24.0;
                    if ((localX - startX).abs() <= hitRadius) {
                      _activeDrag = 1;
                    } else if ((localX - endX).abs() <= hitRadius) {
                      _activeDrag = 2;
                    } else if (localX > startX && localX < endX) {
                      _activeDrag = 3;
                    } else {
                      // Clicked outside, move nearest handle
                      if ((localX - startX).abs() < (localX - endX).abs()) {
                        _activeDrag = 1;
                      } else {
                        _activeDrag = 2;
                      }
                    }

                    _dragStartX = localX;
                    _initialStartSec = widget.startSec;
                    _initialEndSec = widget.endSec;
                    HapticFeedback.lightImpact();
                  },
                  onHorizontalDragUpdate: (details) {
                    final localX = details.localPosition.dx.clamp(0.0, width);
                    final deltaSec = ((localX - _dragStartX) / width) * widget.totalDurationSec;

                    if (_activeDrag == 1) {
                      // Dragging start
                      final newStart = (_initialStartSec + deltaSec).clamp(0.0, widget.endSec - 1.0);
                      widget.onTrimChanged(newStart, widget.endSec);
                    } else if (_activeDrag == 2) {
                      // Dragging end
                      final newEnd = (_initialEndSec + deltaSec).clamp(widget.startSec + 1.0, widget.totalDurationSec);
                      widget.onTrimChanged(widget.startSec, newEnd);
                    } else if (_activeDrag == 3) {
                      // Dragging entire window
                      final clipLen = _initialEndSec - _initialStartSec;
                      var newStart = _initialStartSec + deltaSec;
                      var newEnd = newStart + clipLen;

                      if (newStart < 0) {
                        newStart = 0;
                        newEnd = clipLen;
                      }
                      if (newEnd > widget.totalDurationSec) {
                        newEnd = widget.totalDurationSec;
                        newStart = newEnd - clipLen;
                      }
                      widget.onTrimChanged(newStart, newEnd);
                    }
                  },
                  onHorizontalDragEnd: (_) {
                    _activeDrag = 0;
                    HapticFeedback.selectionClick();
                  },
                  child: CustomPaint(
                    size: Size(width, height),
                    painter: _WaveformTrimmerPainter(
                      waveform: widget.waveform,
                      totalDurationSec: widget.totalDurationSec,
                      startSec: widget.startSec,
                      endSec: widget.endSec,
                      currentPreviewSec: widget.currentPreviewSec,
                      isPlayingPreview: widget.isPlayingPreview,
                      accentColor: accent,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          // Subtitle hint
          Center(
            child: Text(
              LanguageService().t('waveform_instructions'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 3. Fine-Tuning Controls (-1s, +1s)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Start fine-tune
              _buildFineTuneGroup(
                title: LanguageService().t('trim_start'),
                onMinus: () => _fineTuneStart(-1.0),
                onPlus: () => _fineTuneStart(1.0),
                accent: accent,
              ),

              // End fine-tune
              _buildFineTuneGroup(
                title: LanguageService().t('trim_end'),
                onMinus: () => _fineTuneEnd(-1.0),
                onPlus: () => _fineTuneEnd(1.0),
                accent: accent,
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 4. Preview Button
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: widget.isPlayingPreview
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isPlayingPreview ? const Color(0xFF263342) : accent,
                  foregroundColor: widget.isPlayingPreview
                      ? Colors.white
                      : (accent.computeLuminance() > 0.4 ? Colors.black : Colors.white),
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                icon: Icon(
                  widget.isPlayingPreview ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  size: 24,
                ),
                label: Text(
                  widget.isPlayingPreview
                      ? LanguageService().t('stop_preview')
                      : LanguageService().t('preview_trim'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: widget.onTogglePreview,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, String value, Color color, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13.5,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFineTuneGroup({
    required String title,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1B232F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2B3747), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onMinus,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                '-1s',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              title,
              style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPlus,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                '+1s',
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformTrimmerPainter extends CustomPainter {
  final List<double> waveform;
  final double totalDurationSec;
  final double startSec;
  final double endSec;
  final double currentPreviewSec;
  final bool isPlayingPreview;
  final Color accentColor;

  _WaveformTrimmerPainter({
    required this.waveform,
    required this.totalDurationSec,
    required this.startSec,
    required this.endSec,
    required this.currentPreviewSec,
    required this.isPlayingPreview,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final startRatio = totalDurationSec > 0 ? (startSec / totalDurationSec).clamp(0.0, 1.0) : 0.0;
    final endRatio = totalDurationSec > 0 ? (endSec / totalDurationSec).clamp(0.0, 1.0) : 1.0;

    final startX = startRatio * width;
    final endX = endRatio * width;

    // 1. Draw Active Selection Window Background
    final selectedRect = Rect.fromLTRB(startX, 0, endX, height);
    final selectedBgPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(selectedRect, const Radius.circular(8)), selectedBgPaint);

    // 2. Draw Waveform Bars
    final barCount = waveform.isNotEmpty ? waveform.length : 80;
    final barWidth = (width / barCount) * 0.65;
    final barGap = (width / barCount) * 0.35;

    final mutedPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final amp = i < waveform.length ? waveform[i] : 0.3;
      final x = i * (barWidth + barGap) + barWidth / 2;
      final barH = math.max(6.0, amp * (height - 18.0));
      final top = (height - barH) / 2;

      final isInside = x >= startX && x <= endX;

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - barWidth / 2, top, barWidth, barH),
        Radius.circular(barWidth / 2),
      );

      if (isInside) {
        final activePaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accentColor.withValues(alpha: 0.95),
              accentColor.withValues(alpha: 0.60),
            ],
          ).createShader(barRect.outerRect)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(barRect, activePaint);
      } else {
        canvas.drawRRect(barRect, mutedPaint);
      }
    }

    // 3. Draw Preview Playhead Needle
    if (isPlayingPreview && currentPreviewSec >= startSec && currentPreviewSec <= endSec) {
      final playRatio = totalDurationSec > 0 ? (currentPreviewSec / totalDurationSec).clamp(0.0, 1.0) : 0.0;
      final playX = playRatio * width;

      final playheadPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
      canvas.drawLine(Offset(playX, 4), Offset(playX, height - 4), playheadPaint);

      final knobPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(playX, 4), 3.5, knobPaint);
      canvas.drawCircle(Offset(playX, height - 4), 3.5, knobPaint);
    }

    // 4. Draw Start Handle (Left)
    _drawHandle(canvas, startX, height, isLeft: true);

    // 5. Draw End Handle (Right)
    _drawHandle(canvas, endX, height, isLeft: false);
  }

  void _drawHandle(Canvas canvas, double x, double height, {required bool isLeft}) {
    // Vertical line
    final linePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, 2), Offset(x, height - 2), linePaint);

    // Top & Bottom Handles
    final handlePaint = Paint()..color = accentColor;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Pill handle in the middle for easy grip
    final midRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, height / 2), width: 14, height: 28),
      const Radius.circular(7),
    );
    canvas.drawRRect(midRect, shadowPaint);
    canvas.drawRRect(midRect, handlePaint);

    // Pill grip icon lines
    final gripPaint = Paint()
      ..color = (accentColor.computeLuminance() > 0.4 ? Colors.black87 : Colors.white)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x - 2, height / 2 - 5), Offset(x - 2, height / 2 + 5), gripPaint);
    canvas.drawLine(Offset(x + 2, height / 2 - 5), Offset(x + 2, height / 2 + 5), gripPaint);

    // Top indicator arrow/dot
    canvas.drawCircle(Offset(x, 5), 4, handlePaint);
    canvas.drawCircle(Offset(x, height - 5), 4, handlePaint);
  }

  @override
  bool shouldRepaint(covariant _WaveformTrimmerPainter oldDelegate) {
    return oldDelegate.startSec != startSec ||
        oldDelegate.endSec != endSec ||
        oldDelegate.currentPreviewSec != currentPreviewSec ||
        oldDelegate.isPlayingPreview != isPlayingPreview ||
        oldDelegate.waveform != waveform;
  }
}
