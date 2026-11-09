import 'dart:async';
import 'package:flutter/material.dart';

/// A lightweight, high-performance entrance animation for list items.
/// Creates a smooth staggered cascade from top to bottom with FadeIn + subtle Slide.
/// Optimized to maintain 60/120 FPS without affecting scroll performance.
class StaggeredSongItem extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration duration;
  final Duration staggerDelay;
  final Offset slideOffset;
  final int maxAnimatedItems;

  const StaggeredSongItem({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 280),
    this.staggerDelay = const Duration(milliseconds: 32),
    this.slideOffset = const Offset(0.0, -0.12),
    this.maxAnimatedItems = 14,
  });

  @override
  State<StaggeredSongItem> createState() => _StaggeredSongItemState();
}

class _StaggeredSongItemState extends State<StaggeredSongItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    final bool shouldAnimate = widget.index < widget.maxAnimatedItems;

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: shouldAnimate ? 0.0 : 1.0,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.slideOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    if (shouldAnimate) {
      final delayMs = widget.index * widget.staggerDelay.inMilliseconds;
      if (delayMs <= 0) {
        _controller.forward();
      } else {
        _timer = Timer(Duration(milliseconds: delayMs), () {
          if (mounted) {
            _controller.forward();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If not animated (scrolled items beyond viewport threshold), return child directly
    if (widget.index >= widget.maxAnimatedItems) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
