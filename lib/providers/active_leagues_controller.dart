import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/league_state.dart';
import '../services/active_leagues_storage.dart';

/// Seed cho [activeLeaguesControllerProvider] — preload list giải đang
/// chơi từ disk, override ở `main.dart`.
final activeLeaguesSeedProvider = Provider<List<LeagueState>?>((_) => null);

/// Quản lý list giải đấu đang chơi. Auto-persist mỗi lần list thay đổi.
/// LeagueController (giải đang edit) sync về đây qua listenSelf.
final activeLeaguesControllerProvider =
    NotifierProvider<ActiveLeaguesController, List<LeagueState>>(
      ActiveLeaguesController.new,
    );

class ActiveLeaguesController extends Notifier<List<LeagueState>> {
  @override
  List<LeagueState> build() {
    listenSelf((_, next) {
      unawaited(ActiveLeaguesStorage.saveAll(next));
    });
    return ref.read(activeLeaguesSeedProvider) ?? const <LeagueState>[];
  }

  /// Insert mới (đầu list, mới nhất trước) hoặc update tại chỗ theo id.
  /// Guard: bỏ qua league có id rỗng (state khởi tạo chưa start) hoặc
  /// status != inProgress (không hợp lệ để lưu vào active list).
  void upsert(LeagueState league) {
    if (league.id.isEmpty) return;
    if (league.status != LeagueStatus.inProgress) {
      // Status đổi (vd finished) → caller phải gọi remove(id) thay vì
      // upsert. Defensive: không infect list với non-inProgress entry.
      return;
    }
    final idx = state.indexWhere((l) => l.id == league.id);
    if (idx < 0) {
      state = [league, ...state];
    } else {
      final next = [...state];
      next[idx] = league;
      state = next;
    }
  }

  /// Xoá league theo id. No-op nếu không tìm thấy.
  void remove(String id) {
    if (id.isEmpty) return;
    final next = state.where((l) => l.id != id).toList(growable: false);
    if (next.length == state.length) return;
    state = next;
  }

  /// Lookup nhanh — không track dependency. Dùng cho seed / restore.
  LeagueState? findById(String id) {
    for (final l in state) {
      if (l.id == id) return l;
    }
    return null;
  }
}
