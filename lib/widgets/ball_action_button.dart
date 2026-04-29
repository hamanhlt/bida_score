import 'package:flutter/material.dart';

import '../models/ball_config.dart';

class BallActionButton extends StatefulWidget {
  const BallActionButton({
    super.key,
    required this.ball,
    this.size = 72,
    required this.onPressed,
  });

  final BallConfig ball;
  final double size;
  final VoidCallback onPressed;

  // Màu bi chuẩn billiards (1-8 trơn, 9-15 sọc cùng màu gốc).
  static const Map<int, Color> _standardColors = {
    1: Color(0xFFE8C442), // vàng
    2: Color(0xFF1F4FB0), // xanh dương đậm
    3: Color(0xFFC0392B), // đỏ
    4: Color(0xFF5E2A7E), // tím đậm
    5: Color(0xFFE67E22), // cam
    6: Color(0xFF1E7D3C), // xanh lá
    7: Color(0xFF7A4C28), // nâu
    8: Color(0xFF1A1A1A), // đen
    9: Color(0xFFE8C442),
    10: Color(0xFF1F4FB0),
    11: Color(0xFFC0392B),
    12: Color(0xFF5E2A7E),
    13: Color(0xFFE67E22),
    14: Color(0xFF1E7D3C),
    15: Color(0xFF7A4C28),
  };

  // Dự phòng cho số ngoài 1-15 do user tự cấu hình.
  static const List<Color> _fallbackPalette = [
    Color(0xFFC0392B),
    Color(0xFF27AE60),
    Color(0xFFD4AC0D),
    Color(0xFF2E86C1),
    Color(0xFF8E44AD),
    Color(0xFFE67E22),
    Color(0xFF1ABC9C),
    Color(0xFFB0362E),
  ];

  @override
  State<BallActionButton> createState() => _BallActionButtonState();
}

class _BallActionButtonState extends State<BallActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scale;

  bool get _isStriped =>
      widget.ball.number >= 9 && widget.ball.number <= 15;

  Color get _primaryColor =>
      BallActionButton._standardColors[widget.ball.number] ??
      BallActionButton._fallbackPalette[
          widget.ball.number.abs() % BallActionButton._fallbackPalette.length];

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOut,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) => _pressController.forward();
  void _handleTapUp(TapUpDetails _) => _pressController.reverse();
  void _handleTapCancel() => _pressController.reverse();

  @override
  Widget build(BuildContext context) {
    final primary = _primaryColor;
    final striped = _isStriped;
    final size = widget.size;

    // RepaintBoundary: mỗi bi cache vào layer riêng.
    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: 'Bi ${widget.ball.number}, cộng ${widget.ball.points} điểm',
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: widget.onPressed,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primary.withAlpha(60),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (striped)
                      _StripedBody(color: primary, size: size)
                    else
                      _SolidBody(color: primary),
                    const _Gloss(),
                    IgnorePointer(
                      child: _NumberLabel(
                        number: widget.ball.number,
                        points: widget.ball.points,
                        size: size,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SolidBody extends StatelessWidget {
  const _SolidBody({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 0.9,
          colors: [
            Color.lerp(color, Colors.white, 0.35)!,
            color,
            color.withAlpha(220),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _StripedBody extends StatelessWidget {
  const _StripedBody({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.4),
                radius: 0.9,
                colors: [Color(0xFFFFFFFF), Color(0xFFE6E6E6)],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: size,
            height: size * 0.68,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(color, Colors.white, 0.25)!,
                    color,
                    color.withAlpha(235),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Gloss extends StatelessWidget {
  const _Gloss();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.4, -0.5),
            radius: 0.55,
            colors: [
              Colors.white.withAlpha(70),
              Colors.white.withAlpha(0),
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _NumberLabel extends StatelessWidget {
  const _NumberLabel({
    required this.number,
    required this.points,
    required this.size,
  });

  final int number;
  final int points;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$number',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.38,
            height: 1.0,
            shadows: [
              Shadow(
                color: Colors.black.withAlpha(90),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '+$points',
          style: TextStyle(
            color: Colors.white.withAlpha(230),
            fontWeight: FontWeight.w800,
            fontSize: size * 0.16,
            height: 1.0,
            shadows: [
              Shadow(
                color: Colors.black.withAlpha(80),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
