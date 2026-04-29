import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lưu danh sách các tên người chơi đã từng nhập (LRU, mới nhất đầu list).
/// Dùng để gợi ý ở Setup screen — user khỏi gõ lại từ đầu.
class PlayerNameHistoryStorage {
  PlayerNameHistoryStorage._();

  static const _storageKey = 'player_name_history_v1';

  /// Tối đa giữ 50 tên — đủ cho 1 nhóm chơi ổn định, không phồng disk.
  static const _maxLength = 50;

  /// Đọc list. Trả [] nếu chưa lưu hoặc data hỏng.
  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<String>();
    } catch (_) {
      await clear();
      return const [];
    }
  }

  /// Cập nhật list bằng cách prepend [newNames] (đã trim, dedupe case-insensitive),
  /// cắt còn [_maxLength] phần tử. Trả về list cuối để caller cập nhật state.
  static Future<List<String>> addAll(
    List<String> currentList,
    List<String> newNames,
  ) async {
    final result = <String>[...currentList];
    for (final raw in newNames.reversed) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      // Bỏ entry cũ trùng (case-insensitive) trước khi prepend.
      result.removeWhere((n) => n.toLowerCase() == name.toLowerCase());
      result.insert(0, name);
    }
    final capped = result.length > _maxLength
        ? result.sublist(0, _maxLength)
        : result;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(capped));
    return capped;
  }

  /// Xóa 1 tên khỏi list (case-insensitive). Trả list mới.
  static Future<List<String>> remove(
    List<String> currentList,
    String name,
  ) async {
    final lower = name.toLowerCase();
    final filtered = currentList
        .where((n) => n.toLowerCase() != lower)
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(filtered));
    return filtered;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
