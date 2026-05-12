import 'package:flutter/material.dart';

import 'ball_assets.dart';

/// Render bi billiards — ưu tiên ảnh thật trong `assets/ball/` nếu có
/// ([hasBallImage]), không thì tự vẽ (gradient + sọc + số). Dùng cho icon
/// mode card / header. Không tap, không hiển thị +điểm.
class BallIcon extends StatelessWidget {
  const BallIcon({super.key, required this.number, this.size = 52});

  final int number;
  final double size;

  static const Map<int, Color> _standardColors = {
    1: Color(0xFFE8C442),
    2: Color(0xFF1F4FB0),
    3: Color(0xFFC0392B),
    4: Color(0xFF5E2A7E),
    5: Color(0xFFE67E22),
    6: Color(0xFF1E7D3C),
    7: Color(0xFF7A4C28),
    8: Color(0xFF1A1A1A),
    9: Color(0xFFE8C442),
    10: Color(0xFF1F4FB0),
    11: Color(0xFFC0392B),
    12: Color(0xFF5E2A7E),
    13: Color(0xFFE67E22),
    14: Color(0xFF1E7D3C),
    15: Color(0xFF7A4C28),
  };

  static const List<Color> _fallback = [
    Color(0xFFC0392B),
    Color(0xFF27AE60),
    Color(0xFFD4AC0D),
    Color(0xFF2E86C1),
  ];

  bool get _isStriped => number >= 9 && number <= 15;

  Color get _primary =>
      _standardColors[number] ?? _fallback[number.abs() % _fallback.length];

  @override
  Widget build(BuildContext context) {
    final primary = _primary;
    final shadowColor = hasBallImage(number)
        ? Colors.black.withAlpha(45)
        : primary.withAlpha(60);
    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipOval(
          child: hasBallImage(number)
              // Ảnh chụp có lề quanh ball → zoom trong ClipOval để cắt bỏ lề
              // mờ, chỉ còn lõi ball → viền sạch. Mức zoom tuỳ ảnh ([ballImageZoom]).
              ? Transform.scale(
                  scale: ballImageZoom(number),
                  child: Image.asset(
                    ballAssetPath(number),
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    // Decode ở ~5× kích thước logic (dư cho mọi DPI + zoom)
                    // thay vì decode full 1024px rồi downscale → sắc nét, ít RAM.
                    cacheWidth: (size * 5).round(),
                    filterQuality: FilterQuality.medium,
                    // Asset lỗi / chưa load (test env) → fallback bi tự vẽ.
                    errorBuilder: (_, _, _) => _buildDrawn(),
                  ),
                )
              : _buildDrawn(),
        ),
      ),
    );
  }

  Widget _buildDrawn() {
    final primary = _primary;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (_isStriped)
          _StripedBody(color: primary, size: size)
        else
          _SolidBody(color: primary),
        const _Gloss(),
        Text(
          '$number',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.42,
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
      ],
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
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.4),
                radius: 0.9,
                colors: [Color(0xFFFFFFFF), Color(0xFFE6E6E6)],
              ),
            ),
          ),
        ),
        Align(
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
