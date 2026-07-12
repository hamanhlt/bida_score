import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pool_session.dart';

/// Persist [PoolSessionData] (viewMode + currentId) qua kill app, để user mở
/// lại Pool đúng màn (list hoặc trận cụ thể). Mirror [LeagueSessionStorage].
class PoolSessionStorage {
  PoolSessionStorage._();

  static const _storageKey = 'pool_session_v1';

  /// Đọc session đã lưu. Data hỏng → fallback initial (list view).
  static Future<PoolSessionData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return PoolSessionData.initial();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return PoolSessionData.fromJson(map);
    } catch (_) {
      await clear();
      return PoolSessionData.initial();
    }
  }

  static Future<void> save(PoolSessionData session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(session.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
