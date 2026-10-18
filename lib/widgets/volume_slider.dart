import 'package:flutter/material.dart';

/// سلايدر مستوى الصوت العمودي
/// القيمة بين 0.0 و 1.0
class VolumeSlider extends StatelessWidget {
  const VolumeSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.length = 130, // طول السلايدر
    this.thickness = 15, // عرض السلايدر
    this.borderRadius = 5, // نصف قطر الحواف
    this.backgroundColor = const Color(0x52525252), // خلفية المسار
    this.levelColor = const Color(0xFF92FF77), // لون التعبئة
    this.iconSize = 30, // حجم الأيقونة
    this.iconBottomOffset = 18, // إزاحة الأيقونة من الأسفل
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double length;
  final double thickness;
  final double borderRadius;
  final Color backgroundColor;
  final Color levelColor;
  final double iconSize;
  final double iconBottomOffset;

  void _update(double dy) {
    final v = (1 - dy / length).clamp(0.0, 1.0);
    onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => _update(d.localPosition.dy),
      onVerticalDragStart: (d) => _update(d.localPosition.dy),
      onVerticalDragUpdate: (d) => _update(d.localPosition.dy),
      child: SizedBox(
        width: thickness,
        height: length,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // المسار + المستوى
            ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(color: backgroundColor),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: thickness,
                      height: length * clampedValue,
                      color: levelColor,
                    ),
                  ),
                ],
              ),
            ),

            // أيقونة الصوت الثابتة
            Positioned(
              bottom: iconBottomOffset,
              left: (thickness - iconSize) / 2,
              child: IgnorePointer(
                child: Icon(
                  Icons.volume_up_rounded,
                  size: iconSize,
                  color: backgroundColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
