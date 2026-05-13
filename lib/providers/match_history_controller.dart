import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/match_result.dart';

/// Provider lịch sử các trận đã kết thúc. Persist qua `SharedPreferences`.
final matchHistoryControllerProvider =
    AsyncNotifierProvider<MatchHistoryController, List<MatchResult>>(
  MatchHistoryController.new,
);

class MatchHistoryController extends AsyncNotifier<List<MatchResult>> {
  static const _storageKey = 'match_history_v1';

  @override
  Future<List<MatchResult>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => MatchResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Dữ liệu hỏng thì coi như chưa có.
      return const [];
    }
  }

  /// Thêm 1 kết quả mới vào đầu danh sách (mới nhất trước).
  Future<void> addResult(MatchResult result) async {
    final current = state.valueOrNull ?? const <MatchResult>[];
    final updated = [result, ...current];
    state = AsyncData(updated);
    await _persist(updated);
  }

  /// Xoá toàn bộ lịch sử.
  Future<void> clearAll() async {
    state = const AsyncData([]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Xoá 1 trận theo identity ([MatchResult.finishedAt] là DateTime unique mỗi
  /// lần `addResult`). Dùng identity thay vì index vì màn lịch sử có thể đang
  /// lọc theo mode → index trong list lọc ≠ index trong list gốc.
  Future<void> removeMatch(MatchResult match) async {
    final current = state.valueOrNull ?? const <MatchResult>[];
    final updated =
        current.where((m) => m.finishedAt != match.finishedAt).toList();
    if (updated.length == current.length) return;
    state = AsyncData(updated);
    await _persist(updated);
  }

  Future<void> _persist(List<MatchResult> list) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(list.map((r) => r.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }
}
