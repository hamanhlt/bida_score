import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/last_setup.dart';

/// Lưu/đọc setup gần nhất (tên người chơi + cấu hình bi) qua
/// SharedPreferences để auto-fill Setup screen khi user mở app sau.
class SetupPersistence {
  SetupPersistence._();

  static const _storageKey = 'last_setup_v1';

  /// Đọc setup đã lưu. Trả null nếu chưa lưu hoặc dữ liệu hỏng.
  static Future<LastSetup?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return LastSetup.fromJson(map);
    } catch (_) {
      await clear();
      return null;
    }
  }

  static Future<void> save(LastSetup setup) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(setup.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
