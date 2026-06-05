import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/league_session.dart';

/// Persist [LeagueSessionData] (viewMode + currentId) qua kill app, để
/// user mở lại landing đúng màn (list hoặc giải cụ thể).
class LeagueSessionStorage {
  LeagueSessionStorage._();

  static const _storageKey = 'league_session_v1';

  /// Đọc session đã lưu. Data hỏng → fallback initial (list view).
  static Future<LeagueSessionData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return LeagueSessionData.initial();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return LeagueSessionData.fromJson(map);
    } catch (_) {
      await clear();
      return LeagueSessionData.initial();
    }
  }

  static Future<void> save(LeagueSessionData session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(session.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
