import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_snapshot.dart';
import '../models/game_state.dart';

/// Lưu/đọc GameState hiện tại qua SharedPreferences để khôi phục khi
/// app bị kill (user vuốt khỏi recent / hệ thống thu hồi memory).
///
/// **Không** lưu `history` (undo stack) — sau restart user không cần undo
/// về thao tác trước khi tắt app.
class GamePersistence {
  GamePersistence._();

  static const _storageKey = 'active_game_state_v1';

  /// Đọc state đã lưu (nếu có). Trả null nếu chưa lưu hoặc dữ liệu hỏng.
  static Future<GameState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return GameState.fromJson(map);
    } catch (_) {
      // Data hỏng (đổi schema / corrupt): bỏ qua.
      await clear();
      return null;
    }
  }

  /// Lưu state. Nếu `status` là mode-selection (chưa vào game) hoặc
  /// finished, xoá bản lưu — không cần khôi phục những trạng thái đó.
  static Future<void> save(GameState state) async {
    if (state.status == GameStatus.modeSelection ||
        state.status == GameStatus.finished) {
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
