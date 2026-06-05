import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/league_state.dart';

/// Lưu danh sách các giải đấu đang chơi (status = inProgress). Cho phép
/// user mở nhiều giải song song, mỗi giải có id riêng, switch giữa chúng
/// mà không mất tỷ số.
///
/// Migration từ `active_league_v1` (single-state, ngắn ngủi ở phiên trước)
/// → `active_leagues_v1` (list). Migration chạy 1 lần ở `loadAll`.
class ActiveLeaguesStorage {
  ActiveLeaguesStorage._();

  static const _storageKey = 'active_leagues_v1';
  static const _legacySingleKey = 'active_league_v1';

  /// Đọc list giải đang chơi. Per-entry try/catch — 1 entry hỏng không
  /// wipe toàn list (defensive: model fromJson throw FormatException trên
  /// status lạ, không nên kéo theo mất giải khác). Top-level JSON hỏng
  /// thì clear (corrupt blob, không recover được).
  static Future<List<LeagueState>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      List<dynamic> decoded;
      try {
        decoded = jsonDecode(raw) as List<dynamic>;
      } catch (_) {
        await clear();
        return const [];
      }
      final survivors = <LeagueState>[];
      for (final e in decoded) {
        try {
          final st = LeagueState.fromJson(e as Map<String, dynamic>);
          if (st.status == LeagueStatus.inProgress) survivors.add(st);
        } catch (_) {
          // skip entry hỏng, giữ phần còn lại.
        }
      }
      // Migration đã xong → dọn legacy key (idempotent, đảm bảo không
      // sót lại từ build trước hoặc tampering).
      if (prefs.containsKey(_legacySingleKey)) {
        await prefs.remove(_legacySingleKey);
      }
      return List.unmodifiable(survivors);
    }
    // Migration từ key cũ — chạy 1 lần.
    final legacy = prefs.getString(_legacySingleKey);
    if (legacy != null && legacy.isNotEmpty) {
      try {
        final map = jsonDecode(legacy) as Map<String, dynamic>;
        final st = LeagueState.fromJson(map);
        await prefs.remove(_legacySingleKey);
        if (st.status == LeagueStatus.inProgress) {
          final list = [st];
          await saveAll(list);
          return list;
        }
      } catch (_) {
        await prefs.remove(_legacySingleKey);
      }
    }
    return const [];
  }

  /// Lưu list. Lọc chỉ giữ inProgress; nếu rỗng → remove key (đỡ tốn slot).
  static Future<void> saveAll(List<LeagueState> list) async {
    final prefs = await SharedPreferences.getInstance();
    final inProgress = list
        .where((s) => s.status == LeagueStatus.inProgress)
        .toList(growable: false);
    if (inProgress.isEmpty) {
      await prefs.remove(_storageKey);
      return;
    }
    final raw = jsonEncode(inProgress.map((s) => s.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
