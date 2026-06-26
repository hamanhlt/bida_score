import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/nine_ball_state.dart';

/// Lưu/đọc NineBallState (Pool) đang chơi qua SharedPreferences để khôi phục
/// khi app bị kill — user chơi dở lần sau vào đánh tiếp.
///
/// **Không** lưu `history` (undo stack) — xem [NineBallState.toJson].
class NineBallPersistence {
  NineBallPersistence._();

  static const _storageKey = 'active_pool_state_v1';

  /// Đọc state đã lưu (nếu có). Trả null nếu chưa lưu hoặc dữ liệu hỏng.
  static Future<NineBallState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final state = NineBallState.fromJson(map);
      // Chỉ khôi phục trận đang chơi; setup/finished thì bỏ.
      if (state.status != NineBallStatus.inProgress) {
        await clear();
        return null;
      }
      return state;
    } catch (_) {
      // Data hỏng (đổi schema / corrupt): bỏ qua.
      await clear();
      return null;
    }
  }

  /// Lưu state. Chỉ giữ trận đang chơi — setup (chưa vào) hoặc finished
  /// (đã xong) thì xoá bản lưu.
  static Future<void> save(NineBallState state) async {
    if (state.status != NineBallStatus.inProgress) {
      await clear();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
