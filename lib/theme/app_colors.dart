import 'package:flutter/material.dart';

/// Bảng màu dùng chung toàn app.
///
/// Dùng semantic naming thay vì hex số để các file khác tái sử dụng
/// nhất quán và dễ đổi tone.
abstract final class AppColors {
  // Thương hiệu
  static const primary = Color(0xFF146356);
  static const primaryDark = Color(0xFF0E3E36);
  static const accent = Color(0xFFF2B544);

  // Vai trò trong lượt chơi
  static const shooter = Color(0xFF2E9E6F);
  static const victim = Color(0xFFCC5C4F);

  // Chữ
  static const textDark = Color(0xFF16322C);
  static const textBody = Color(0xFF4A6057);
  static const textSubtle = Color(0xFF5F726A);

  // Nền + viền
  static const border = Color(0xFFE1E7E2);
  static const scaffoldBg = Color(0xFFF5F0E6);
  static const surface = Color(0xFFFFFBF4);

  // Tín hiệu
  static const negativeSoft = Color(0xFFE88A7D);

  // Hạng (huy chương)
  static const trophyGold = accent;
  static const trophySilver = Color(0xFF7AA3C8);
  static const trophyBronze = Color(0xFFB97A56);

  /// Màu chữ/icon dễ đọc trên một màu nền cụ thể.
  ///
  /// Nền tối → chữ trắng, nền sáng → chữ tối. Dùng helper này cho các chip,
  /// pill, card custom hoặc container tự set background thay vì hardcode màu
  /// chữ theo cảm tính.
  static Color readableOn(
    Color background, {
    Color darkText = textDark,
    Color lightText = Colors.white,
  }) {
    return background.computeLuminance() < 0.5 ? lightText : darkText;
  }
}
