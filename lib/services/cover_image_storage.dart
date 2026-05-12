import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Lưu ảnh bìa (banner) tuỳ chỉnh do user chọn — base64 trong SharedPreferences.
///
/// Ảnh được [ImagePicker] resize (maxWidth ~1280, quality ~80) trước khi truyền
/// vào đây nên blob giữ ở mức vài chục–trăm KB, OK với SharedPreferences.
/// Null/không có → màn chính dùng banner mặc định `assets/banner.jpg`.
class CoverImageStorage {
  CoverImageStorage._();

  static const _storageKey = 'cover_image_v1';

  /// Đọc bytes ảnh bìa tuỳ chỉnh. Null nếu chưa set hoặc data hỏng.
  static Future<Uint8List?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      await clear();
      return null;
    }
  }

  /// Lưu bytes ảnh bìa.
  static Future<void> save(Uint8List bytes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, base64Encode(bytes));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
