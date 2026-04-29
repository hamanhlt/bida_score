import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Hiển thị điểm với 2 hiệu ứng:
/// - Số chính: tween mượt khi điểm thay đổi (count-up / count-down).
/// - Badge delta: khi điểm đổi, một badge "+N" hoặc "-N" bay lên rồi mờ dần.
class AnimatedScoreText extends StatefulWidget {
  const AnimatedScoreText({
    super.key,
    required this.score,
    this.style,
    this.tweenDuration = const Duration(milliseconds: 500),
    this.badgeDuration = const Duration(milliseconds: 900),
    this.badgeOffset = -24,
  });

  final int score;
  final TextStyle? style;
  final Duration tweenDuration;
  final Duration badgeDuration;

  /// Khoảng dịch theo trục Y (px) của badge khi bay lên. Dùng số âm để đi lên.
  final double badgeOffset;

  @override
  State<AnimatedScoreText> createState() => _AnimatedScoreTextState();
}

class _AnimatedScoreTextState extends State<AnimatedScoreText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slide;
  late final Animation<double> _fade;
  int? _delta;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.badgeDuration,
    );
    _slide = Tween<double>(begin: 0, end: widget.badgeOffset)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(_controller);
    _fade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 45),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant AnimatedScoreText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      setState(() => _delta = widget.score - oldWidget.score);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.style;
    final badgeSize = (baseStyle?.fontSize ?? 16) * 0.8;

    // RepaintBoundary isolates animation paint vào layer riêng — frame
    // animation không trigger repaint cha.
    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: widget.score),
            duration: widget.tweenDuration,
            curve: Curves.easeOutCubic,
            builder: (_, value, _) => Text(_format(value), style: baseStyle),
          ),
          if (_delta != null && _delta != 0)
            FadeTransition(
              opacity: _fade,
              child: AnimatedBuilder(
                animation: _slide,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, _slide.value),
                  child: child,
                ),
                child: Text(
                  _formatDelta(_delta!),
                  style: TextStyle(
                    color: _delta! > 0
                        ? AppColors.shooter
                        : AppColors.victim,
                    fontWeight: FontWeight.w900,
                    fontSize: badgeSize,
                    shadows: [
                      Shadow(
                        color: Colors.black.withAlpha(80),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _format(int s) => s > 0 ? '+$s' : '$s';
  String _formatDelta(int d) => d > 0 ? '+$d' : '$d';
}
