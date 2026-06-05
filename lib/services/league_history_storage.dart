import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/league_state.dart';

/// Lưu lịch sử các giải đấu đã kết thúc — list `LeagueState` (status =
/// finished). Mới nhất đầu list. Persist qua SharedPreferences.
///
/// Khác với `ActiveLeaguesStorage` (lưu list giải đang chơi để resume):
/// file này chỉ chứa giải đã chốt. `finishTournament` → `addResult(state)`
/// append vào đây + xoá giải đó khỏi active list.
class LeagueHistoryStorage {
  LeagueHistoryStorage._();

  static const _storageKey = 'league_history_v1';

  /// Đọc list giải đã lưu. Trả [] nếu chưa có hoặc data hỏng.
  static Future<List<LeagueState>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => LeagueState.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      await clear();
      return const [];
    }
  }

  /// Persist toàn bộ list.
  static Future<void> save(List<LeagueState> list) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(list.map((s) => s.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
