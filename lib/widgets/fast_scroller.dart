import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// ماسك النزول والصعود السريع في القوائم الطويلة.
/// يتم وضعه تلقائياً في الجهة المعاكسة لصور الأغاني (الجهة اليسرى في الواجهة العربية).
class FastScroller extends StatefulWidget {
  final Widget child;
  final ScrollController controller;
  final bool? isLeft; // إن كانت null، يتم تحديدها تلقائياً عكس جهة الصور

  const FastScroller({
    super.key,
    required this.child,
    required this.controller,
    this.isLeft,
  });

  @override
  State<FastScroller> createState() => _FastScrollerState();
}

class _FastScrollerState extends State<FastScroller> {
  double _scrollProgress = 0.0;
  bool _isDragging = false;
  bool _isVisible = false;
  Timer? _fadeTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !widget.controller.hasClients) return;
    final maxScroll = widget.controller.position.maxScrollExtent;
    if (maxScroll <= 120) {
      if (_isVisible) setState(() => _isVisible = false);
      return;
    }

    final progress = (widget.controller.offset / maxScroll).clamp(0.0, 1.0);
    setState(() {
      _scrollProgress = progress;
      _isVisible = true;
    });

    if (!_isDragging) {
      _resetFadeTimer();
    }
  }

  void _resetFadeTimer() {
    _fadeTimer?.cancel();
    _fadeTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted && !_isDragging) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  void _handleDrag(double localY, double trackHeight) {
    if (!widget.controller.hasClients) return;
    final maxScroll = widget.controller.position.maxScrollExtent;
    if (maxScroll <= 0 || trackHeight <= 0) return;

    final fraction = (localY / trackHeight).clamp(0.0, 1.0);
    setState(() {
      _scrollProgress = fraction;
    });

    widget.controller.jumpTo(fraction * maxScroll);
  }

  void _onDragUpdate(DragUpdateDetails details, double trackHeight, double topMargin, double thumbHeight) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localY = box.globalToLocal(details.globalPosition).dy - topMargin - (thumbHeight / 2);
    _handleDrag(localY, trackHeight);
  }

  void _onDragStart(DragStartDetails details, double trackHeight, double topMargin, double thumbHeight) {
    setState(() {
      _isDragging = true;
      _isVisible = true;
    });
    _fadeTimer?.cancel();
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localY = box.globalToLocal(details.globalPosition).dy - topMargin - (thumbHeight / 2);
    _handleDrag(localY, trackHeight);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        const thumbHeight = 56.0;
        const thumbWidth = 28.0;
        const topMargin = 12.0;
        const bottomMargin = 96.0; // تجنب تغطية المشغل المصغر
        final trackHeight = (availableHeight - topMargin - bottomMargin - thumbHeight).clamp(50.0, 5000.0);
        final thumbTop = topMargin + (_scrollProgress * trackHeight);

        // في الواجهة العربية (RTL) الصور تكون على اليمين، لذا نضع الماسك في اليسار (عكس الصور)
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        final placeOnLeft = widget.isLeft ?? isRtl;

        return Stack(
          children: [
            widget.child,

            // ماسك النقل السريع - يتبع حركة الإصبع بدقة 1:1 بدون قفز
            if (widget.controller.hasClients &&
                widget.controller.position.maxScrollExtent > 150)
              Positioned(
                top: thumbTop,
                left: placeOnLeft ? 2 : null,
                right: placeOnLeft ? null : 2,
                child: AnimatedOpacity(
                  opacity: _isDragging ? 1.0 : (_isVisible ? 0.90 : 0.35),
                  duration: const Duration(milliseconds: 200),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (details) => _onDragStart(details, trackHeight, topMargin, thumbHeight),
                    onVerticalDragUpdate: (details) => _onDragUpdate(details, trackHeight, topMargin, thumbHeight),
                    onVerticalDragEnd: (details) {
                      setState(() => _isDragging = false);
                      _resetFadeTimer();
                    },
                    onVerticalDragCancel: () {
                      setState(() => _isDragging = false);
                      _resetFadeTimer();
                    },
                    child: Padding(
                      // منطقة لمس واسعة (Hit Target) حتى يسهل إمساكها بالإصبع
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Container(
                        width: thumbWidth,
                        height: thumbHeight,
                        decoration: BoxDecoration(
                          color: _isDragging
                              ? AppTheme.accentColor.withValues(alpha: 0.20)
                              : AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _isDragging
                                ? AppTheme.accentColor
                                : AppTheme.cardBorder,
                            width: _isDragging ? 1.8 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isDragging ? AppTheme.accentColor : Colors.black)
                                  .withValues(alpha: _isDragging ? 0.35 : 0.25),
                              blurRadius: _isDragging ? 10 : 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.keyboard_arrow_up_rounded,
                                size: 14,
                                color: _isDragging ? AppTheme.accentColor : AppTheme.textPrimary,
                              ),
                              Container(
                                width: 12,
                                height: 2,
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                decoration: BoxDecoration(
                                  color: _isDragging ? AppTheme.accentColor : AppTheme.textMuted,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 14,
                                color: _isDragging ? AppTheme.accentColor : AppTheme.textPrimary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
