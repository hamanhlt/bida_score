import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Vòng quay bốc thăm — chia múi đều theo [names] (chỉ người CÒN LẠI chưa
/// bốc), mỗi múi 1 màu pastel + 1 emoji con vật. Có kim chỉ cố định ở đỉnh.
/// Khi [spinNonce] tăng, wheel quay nhiều vòng rồi dừng sao cho múi
/// [targetIndex] nằm dưới kim, xong gọi [onSpinEnd]. Người đã bốc bị parent
/// loại khỏi [names] → wheel co lại sau mỗi lượt.
///
/// Emoji con vật gán theo TÊN (ổn định khi danh sách co lại).
class DrawWheel extends StatefulWidget {
  const DrawWheel({
    super.key,
    required this.names,
    required this.spinNonce,
    required this.targetIndex,
    required this.onSpinEnd,
    this.size = 280,
  });

  final List<String> names;

  /// Tăng giá trị này để kích hoạt 1 lượt quay.
  final int spinNonce;

  /// Index múi (trong [names]) wheel sẽ dừng lại. Hợp lệ khi spinNonce > 0.
  final int targetIndex;

  /// Gọi khi animation quay dừng hẳn.
  final VoidCallback onSpinEnd;

  final double size;

  @override
  State<DrawWheel> createState() => _DrawWheelState();
}

class _DrawWheelState extends State<DrawWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  double _fromAngle = 0;
  double _toAngle = 0;

  /// Emoji con vật gán theo tên người — shuffle pool 1 lần/đời widget, gán
  /// dần khi gặp tên mới → mỗi người giữ 1 con cố định kể cả khi wheel co.
  late final List<String> _shuffledAnimals;
  final Map<String, String> _animalByName = {};
  int _animalCursor = 0;

  static const _animalPool = <String>[
    '🦁', '🐯', '🐘', '🦊', '🐨', '🐭', '🐿️', '🦒',
    '🐶', '🐱', '🐰', '🐻', '🐼', '🐵', '🐮', '🐷',
    '🦓', '🦌', '🐺', '🦝', '🐸', '🦄', '🐔', '🦉',
  ];

  String _animalFor(String name) {
    return _animalByName.putIfAbsent(name, () {
      final a = _shuffledAnimals[_animalCursor % _shuffledAnimals.length];
      _animalCursor++;
      return a;
    });
  }

  // Bảng màu pastel xoay vòng (giống mẫu wheel).
  static const _palette = <Color>[
    Color(0xFFF2867F), // đỏ san hô
    Color(0xFFF6A94B), // cam
    Color(0xFFF4D24E), // vàng
    Color(0xFF7FC96B), // xanh lá
    Color(0xFF5FC9B0), // teal
    Color(0xFF6FB7E8), // xanh dương
    Color(0xFFA89CE0), // tím
    Color(0xFFE99BD0), // hồng
  ];

  @override
  void initState() {
    super.initState();
    _shuffledAnimals = [..._animalPool]..shuffle(Random());
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onSpinEnd();
      }
    });
  }

  @override
  void didUpdateWidget(covariant DrawWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinNonce != oldWidget.spinNonce && widget.spinNonce > 0) {
      _spinTo(widget.targetIndex);
    }
  }

  void _spinTo(int index) {
    final n = widget.names.length;
    if (n == 0 || index < 0 || index >= n) return;
    final step = 2 * pi / n;
    // Tâm múi index (đo từ trục x, chiều kim đồng hồ vì y hướng xuống).
    final center = (index + 0.5) * step;
    // Kim ở đỉnh = hướng lên = -pi/2. Cần rotation R sao cho center + R = -pi/2.
    var target = -pi / 2 - center;
    // Quay ít nhất 4 vòng tới so với góc hiện tại (luôn tiến tới).
    const minTurns = 4;
    final base = _toAngle; // giữ liên tục từ lần quay trước
    while (target < base + minTurns * 2 * pi) {
      target += 2 * pi;
    }
    _fromAngle = base;
    _toAngle = target;
    _controller
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size + 16,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, _) {
          final angle =
              _fromAngle + (_toAngle - _fromAngle) * _curve.value;
          return CustomPaint(
            painter: _WheelPainter(
              names: widget.names,
              animals: [for (final n in widget.names) _animalFor(n)],
              rotation: angle,
              palette: _palette,
            ),
          );
        },
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.names,
    required this.animals,
    required this.rotation,
    required this.palette,
  });

  final List<String> names;
  final List<String> animals;
  final double rotation;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    const pointerH = 16.0;
    final radius = (size.width / 2);
    final center = Offset(radius, pointerH + radius);
    final n = names.length;

    if (n == 0) {
      final paint = Paint()..color = AppColors.border;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    final step = 2 * pi / n;
    final wedgePaint = Paint()..style = PaintingStyle.fill;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    for (var i = 0; i < n; i++) {
      wedgePaint.color = palette[i % palette.length];
      canvas.drawArc(rect, i * step, step, true, wedgePaint);
    }

    // Đường viền các múi (trắng) để tách rõ.
    final sep = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < n; i++) {
      final a = i * step;
      canvas.drawLine(
        center,
        center + Offset(cos(a), sin(a)) * radius,
        sep,
      );
    }
    canvas.drawCircle(center, radius, sep..strokeWidth = 3);

    // Nhãn (emoji con vật + tên) — vẽ thẳng đứng dù wheel đang xoay, bằng
    // cách counter-rotate -rotation tại tâm múi.
    for (var i = 0; i < n; i++) {
      final mid = (i + 0.5) * step;
      _paintLabel(
        canvas,
        center,
        radius,
        mid,
        i < animals.length ? animals[i] : '',
        names[i],
      );
    }
    canvas.restore();

    // Hub trung tâm.
    final hub = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.18, hub);
    canvas.drawCircle(
      center,
      radius * 0.18,
      Paint()
        ..color = AppColors.primaryDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Kim chỉ ở đỉnh (tam giác hướng xuống).
    final pointer = Path()
      ..moveTo(center.dx - 12, 0)
      ..lineTo(center.dx + 12, 0)
      ..lineTo(center.dx, pointerH + 6)
      ..close();
    canvas.drawPath(pointer, Paint()..color = AppColors.primaryDark);
  }

  void _paintLabel(
    Canvas canvas,
    Offset center,
    double radius,
    double midAngle,
    String animal,
    String name,
  ) {
    final display = name.trim().isEmpty
        ? '—'
        : (name.trim().length > 9
            ? '${name.trim().substring(0, 8)}…'
            : name.trim());

    final emojiTp = TextPainter(
      text: TextSpan(
        text: animal,
        style: const TextStyle(fontSize: 24, color: Colors.black),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final nameTp = TextPainter(
      text: TextSpan(
        text: display,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          shadows: [Shadow(color: Colors.black38, blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: radius * 0.66);

    // Vị trí tâm múi (toạ độ wheel chưa xoay) — đặt ở ~62% bán kính.
    final pos = center + Offset(cos(midAngle), sin(midAngle)) * radius * 0.62;
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    // Undo spin → emoji + chữ luôn thẳng đứng (giống ảnh mẫu).
    canvas.rotate(-rotation);
    emojiTp.paint(
      canvas,
      Offset(-emojiTp.width / 2, -emojiTp.height - 1),
    );
    nameTp.paint(canvas, Offset(-nameTp.width / 2, 1));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.rotation != rotation ||
      old.names != names ||
      old.animals != animals;
}
