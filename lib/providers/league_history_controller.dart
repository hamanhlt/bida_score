import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/league_state.dart';
import '../services/league_history_storage.dart';

/// Lịch sử các giải đấu đã kết thúc — async load từ disk lần đầu, sau đó
/// in-memory + persist mỗi lần thay đổi.
final leagueHistoryControllerProvider =
    AsyncNotifierProvider<LeagueHistoryController, List<LeagueState>>(
  LeagueHistoryController.new,
);

class LeagueHistoryController extends AsyncNotifier<List<LeagueState>> {
  @override
  Future<List<LeagueState>> build() => LeagueHistoryStorage.load();

  /// Thêm giải mới vào đầu list (mới nhất trước) + ghi disk.
  ///
  /// **Phải `await future`** trước khi đọc `state.valueOrNull` — nếu user
  /// finish giải ngay sau khi mở app (build chưa resolve), `valueOrNull`
  /// là null → ta dùng `const []` → khi load resolve sau, Riverpod overwrite
  /// → giải mới biến mất. Race window hiếm nhưng có thật.
  Future<void> addResult(LeagueState league) async {
    final current = await future;
    final updated = [league, ...current];
    state = AsyncData(updated);
    await LeagueHistoryStorage.save(updated);
  }

  /// Xoá 1 giải theo `id` — identity ổn định do engine sinh ra (legacy
  /// payload fallback `_legacyId(startedAt)`). Tránh xoá nhầm hàng loạt
  /// khi nhiều entry chia sẻ finishedAt (clock coarse, hoặc null sau
  /// fromJson hỏng).
  Future<void> removeLeague(LeagueState league) async {
    final current = await future;
    final updated = current.where((s) {
      if (league.id.isNotEmpty && s.id.isNotEmpty) {
        return s.id != league.id;
      }
      // Cả hai id rỗng (data quá cũ) → fallback finishedAt.
      return s.finishedAt != league.finishedAt;
    }).toList();
    if (updated.length == current.length) return;
    state = AsyncData(updated);
    await LeagueHistoryStorage.save(updated);
  }

  /// Xoá toàn bộ lịch sử giải. Ghi disk trước rồi set state — nếu disk
  /// lỗi, UI vẫn cho thấy data cũ thay vì hiển thị empty "ảo".
  Future<void> clearAll() async {
    await LeagueHistoryStorage.clear();
    state = const AsyncData([]);
  }
}
