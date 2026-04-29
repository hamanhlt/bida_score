import 'package:flutter/material.dart';

class TableBackground extends StatelessWidget {
  const TableBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8F4EE), Color(0xFFF5F0E6), Color(0xFFF9F6EF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: _GlowCircle(
              size: 220,
              color: Color(0xFF146356).withAlpha(36),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -30,
            child: _GlowCircle(
              size: 160,
              color: Color(0xFFF2B544).withAlpha(46),
            ),
          ),
          Positioned(
            top: 120,
            left: -24,
            child: _GlowCircle(
              size: 84,
              color: Color(0xFFB03A2E).withAlpha(26),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
