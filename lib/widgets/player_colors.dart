import 'package:flutter/material.dart';

/// Bảng màu gán cho từng người chơi trong list trận của giải đấu.
/// Giúp user scan ai-vs-ai nhanh hơn — mỗi tên xuất hiện đều cùng 1 màu.
const List<Color> kPlayerPalette = <Color>[
  Color(0xFF2962E0), // xanh dương
  Color(0xFFD93838), // đỏ
  Color(0xFF1B998B), // teal
  Color(0xFFBF7A02), // gold đậm (đọc tốt trên nền trắng)
  Color(0xFF7A3CB8), // tím
  Color(0xFFD56300), // cam
  Color(0xFF455A64), // xám slate
  Color(0xFF1A8D5F), // xanh lá
  Color(0xFFB23A48), // đỏ tía
  Color(0xFF5D4037), // nâu
  Color(0xFF00838F), // cyan đậm
  Color(0xFF6D4C92), // tím xám
  Color(0xFF8E24AA), // magenta
  Color(0xFF388E3C), // xanh lá đậm
  Color(0xFF1565C0), // navy
  Color(0xFFC2185B), // hồng đậm
];

/// Gán màu cho từng `playerId`. Sort id để đảm bảo cùng giải → cùng map
/// kể cả khi list players re-sort theo ranking sau mỗi updateScore.
Map<String, Color> assignPlayerColors(Iterable<String> playerIds) {
  final sorted = playerIds.toList()..sort();
  final map = <String, Color>{};
  for (var i = 0; i < sorted.length; i++) {
    map[sorted[i]] = kPlayerPalette[i % kPlayerPalette.length];
  }
  return map;
}
