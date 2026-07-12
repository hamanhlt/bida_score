import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/nine_ball_state.dart';

/// Lưu danh sách các trận Pool đang chơi (status = inProgress). Cho phép user
/// chơi nhiều trận song song, mỗi trận id riêng, switch qua lại không mất
/// tỷ số. Mirror [ActiveLeaguesStorage].
///
/// Migration từ key cũ `active_pool_state_v1` (single-state, phiên trước) →
/// `active_pools_v1` (list). Chạy 1 lần ở `loadAll`.
class ActivePoolsStorage {
  ActivePoolsStorage._();

  static const _storageKey = 'active_pools_v1';
  static const _legacySingleKey = 'active_pool_state_v1';

  /// Đọc list trận đang chơi. Per-entry try/catch — 1 entry hỏng không wipe
  /// toàn list. Top-level JSON hỏng thì clear.
  static Future<List<NineBallState>> loadAll() async {
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
      final survivors = <NineBallState>[];
      for (final e in decoded) {
        try {
          final st = NineBallState.fromJson(e as Map<String, dynamic>);
          if (st.status == NineBallStatus.inProgress) survivors.add(st);
        } catch (_) {
          // skip entry hỏng, giữ phần còn lại.
        }
      }
      if (prefs.containsKey(_legacySingleKey)) {
        await prefs.remove(_legacySingleKey);
      }
      return List.unmodifiable(survivors);
    }
    // Migration từ key cũ (single in-progress match) — chạy 1 lần.
    final legacy = prefs.getString(_legacySingleKey);
    if (legacy != null && legacy.isNotEmpty) {
      try {
        final map = jsonDecode(legacy) as Map<String, dynamic>;
        final st = NineBallState.fromJson(map);
        await prefs.remove(_legacySingleKey);
        if (st.status == NineBallStatus.inProgress && st.id.isNotEmpty) {
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

  /// Lưu list. Lọc chỉ giữ inProgress (và id hợp lệ); rỗng → remove key.
  static Future<void> saveAll(List<NineBallState> list) async {
    final prefs = await SharedPreferences.getInstance();
    final inProgress = list
        .where((s) => s.status == NineBallStatus.inProgress && s.id.isNotEmpty)
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
