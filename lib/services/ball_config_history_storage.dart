import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ball_config.dart';

/// Lưu lịch sử các (số bi, điểm) đã từng nhập trong Setup screen — LRU, mới
/// nhất đầu list. Dùng để gợi ý popup ở mỗi row trong "Danh sách bi" — user
/// khỏi gõ lại số bi và điểm khi setup trận mới.
class BallConfigHistoryStorage {
  BallConfigHistoryStorage._();

  static const _storageKey = 'ball_config_history_v1';

  /// Tối đa giữ 20 cấu hình bi — đủ cho 1 nhóm chơi nhiều preset.
  static const _maxLength = 20;

  static Future<List<BallConfig>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => BallConfig.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      await clear();
      return const [];
    }
  }

  /// Prepend [newConfigs] vào list, dedupe (BallConfig đã override `==`),
  /// cắt còn [_maxLength]. Trả list mới cho caller cập nhật state.
  static Future<List<BallConfig>> addAll(
    List<BallConfig> currentList,
    List<BallConfig> newConfigs,
  ) async {
    final result = <BallConfig>[...currentList];
    for (final cfg in newConfigs.reversed) {
      result.removeWhere((c) => c == cfg);
      result.insert(0, cfg);
    }
    final capped = result.length > _maxLength
        ? result.sublist(0, _maxLength)
        : result;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(capped.map((c) => c.toJson()).toList()),
    );
    return capped;
  }

  /// Xoá 1 cấu hình bi cụ thể khỏi history.
  static Future<List<BallConfig>> remove(
    List<BallConfig> currentList,
    BallConfig config,
  ) async {
    final filtered = currentList.where((c) => c != config).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(filtered.map((c) => c.toJson()).toList()),
    );
    return filtered;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
