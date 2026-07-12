import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/nine_ball_state.dart';
import '../services/active_pools_storage.dart';

/// Seed cho [activePoolsControllerProvider] — preload list trận Pool đang
/// chơi từ disk, override ở `main.dart`.
final activePoolsSeedProvider = Provider<List<NineBallState>?>((_) => null);

/// Quản lý list trận Pool đang chơi. Auto-persist mỗi lần list thay đổi.
/// NineBallController (trận đang chơi) sync về đây qua listenSelf.
final activePoolsControllerProvider =
    NotifierProvider<ActivePoolsController, List<NineBallState>>(
      ActivePoolsController.new,
    );

class ActivePoolsController extends Notifier<List<NineBallState>> {
  @override
  List<NineBallState> build() {
    listenSelf((_, next) {
      unawaited(ActivePoolsStorage.saveAll(next));
    });
    return ref.read(activePoolsSeedProvider) ?? const <NineBallState>[];
  }

  /// Insert mới (đầu list, mới nhất trước) hoặc update tại chỗ theo id.
  /// Guard: bỏ qua trận id rỗng (chưa start) hoặc status != inProgress.
  void upsert(NineBallState match) {
    if (match.id.isEmpty) return;
    if (match.status != NineBallStatus.inProgress) return;
    final idx = state.indexWhere((m) => m.id == match.id);
    if (idx < 0) {
      state = [match, ...state];
    } else {
      final next = [...state];
      next[idx] = match;
      state = next;
    }
  }

  /// Xoá trận theo id. No-op nếu không tìm thấy.
  void remove(String id) {
    if (id.isEmpty) return;
    final next = state.where((m) => m.id != id).toList(growable: false);
    if (next.length == state.length) return;
    state = next;
  }

  /// Lookup nhanh — không track dependency. Dùng cho seed / restore.
  NineBallState? findById(String id) {
    for (final m in state) {
      if (m.id == id) return m;
    }
    return null;
  }
}
