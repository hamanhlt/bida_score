import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/league_engine.dart';
import '../models/league_state.dart';
import '../services/active_leagues_storage.dart';
import 'active_leagues_controller.dart';
import 'game_controller.dart';
import 'league_history_controller.dart';
import 'league_session_controller.dart';

final leagueEngineProvider = Provider<LeagueEngine>(
  (_) => const LeagueEngine(),
);

/// State của giải đấu **đang được edit** (1 trong N giải trong active
/// list). Auto-sync về [activeLeaguesControllerProvider] mỗi lần đổi.
///
/// Khi user mở giải khác → `openLeague(other)` thay state.
/// Khi user tạo mới → `createNew()` reset về initial.
/// Khi user về list → `backToList()` clear viewMode (state cũ vẫn còn ở
/// active list, không mất).
final leagueControllerProvider =
    NotifierProvider<LeagueController, LeagueState>(LeagueController.new);

class LeagueController extends Notifier<LeagueState> {
  LeagueEngine get _engine => ref.read(leagueEngineProvider);

  @override
  LeagueState build() {
    listenSelf((_, next) {
      // Auto-sync về active list: chỉ inProgress mới được lưu (engine
      // upsert tự guard, controller này không cần check lại).
      if (next.status == LeagueStatus.inProgress) {
        ref.read(activeLeaguesControllerProvider.notifier).upsert(next);
      }
    });
    // Restore: nếu session có currentId → load giải từ active list seed.
    final session = ref.read(leagueSessionSeedProvider);
    final currentId = session?.currentId;
    if (currentId != null && currentId.isNotEmpty) {
      final seedList = ref.read(activeLeaguesSeedProvider) ?? const [];
      for (final l in seedList) {
        if (l.id == currentId) {
          // Re-sort theo logic engine hiện tại (tiebreaker có thể đổi
          // giữa các phiên bản app — state trên đĩa giữ thứ tự cũ).
          return _engine.recalculate(l);
        }
      }
      // Session trỏ tới giải không còn trong active list (vd user kill
      // app ở LeagueResultScreen sau finish, hoặc data hỏng). Defer
      // goToList() ra microtask — KHÔNG được mutate provider khác trong
      // build. Frame tiếp theo _AppShell sẽ render LeagueListScreen.
      Future.microtask(() {
        ref.read(leagueSessionControllerProvider.notifier).goToList();
      });
    }
    return LeagueState.initial();
  }

  /// Khởi tạo giải mới. Engine throw [ArgumentError] nếu names không hợp
  /// lệ → caller bắt. Sau start, openCurrent(id) để session ghi nhớ giải
  /// mới này.
  void startTournament(
    List<String> names, {
    String tournamentName = '',
    int? groupSize,
    List<List<String>>? manualGroups,
  }) {
    state = _engine.startTournament(
      names,
      tournamentName: tournamentName,
      groupSize: groupSize,
      manualGroups: manualGroups,
    );
    ref.read(leagueSessionControllerProvider.notifier).openCurrent(state.id);
  }

  /// Đổi tên giải đang chơi. Tên trống không hợp lệ để tránh list/history
  /// hiển thị nhãn mơ hồ.
  void renameTournament(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Tên giải không được để trống.');
    }
    if (state.status != LeagueStatus.inProgress) return;
    state = state.copyWith(name: trimmed);
  }

  /// Cập nhật tỷ số 1 trận → engine recalculate leaderboard từ đầu →
  /// listenSelf upsert vào active list.
  void updateScore(String fixtureId, int score1, int score2) {
    state = _engine.updateScore(state, fixtureId, score1, score2);
  }

  /// Người chơi xác nhận khoá vòng bảng và tạo nhánh knockout.
  void startKnockout() {
    state = _engine.startKnockout(state);
  }

  /// Xoá tỷ số 1 trận (về not-played).
  void clearScore(String fixtureId) {
    state = _engine.clearScore(state, fixtureId);
  }

  /// Mở 1 giải đang chơi có sẵn từ list — copy vào state để screen edit
  /// được. Session lưu id để mở lại sau kill app.
  ///
  /// Short-circuit nếu đã đang ở giải đó — tránh phát ra mutation thừa
  /// (kéo theo upsert + disk write redundant).
  void openLeague(LeagueState league) {
    if (state.id.isNotEmpty && state.id == league.id) {
      ref.read(leagueSessionControllerProvider.notifier).openCurrent(league.id);
      return;
    }
    state = league;
    ref.read(leagueSessionControllerProvider.notifier).openCurrent(league.id);
  }

  /// Bắt đầu setup giải mới (clear state, vào màn Setup).
  void createNew() {
    state = LeagueState.initial();
    ref.read(leagueSessionControllerProvider.notifier).openNewSetup();
  }

  /// Quay về LeagueListScreen — KHÔNG xoá khỏi active list (giải vẫn ở
  /// đó để user resume sau).
  void backToList() {
    state = LeagueState.initial();
    ref.read(leagueSessionControllerProvider.notifier).goToList();
  }

  /// Chốt giải hiện tại. Crash-safety: remove khỏi active list TRƯỚC khi
  /// await history (đảo so với phiên bản cũ) — nếu crash giữa hai bước,
  /// user mất bản snapshot trên ResultScreen NHƯNG không tạo duplicate
  /// editable trong active list. Try/catch revert nếu history fail.
  Future<void> finishTournament() async {
    if (state.status != LeagueStatus.inProgress) return;
    final preFinishState = state;
    final leagueId = state.id;
    final finished = _engine.finishTournament(state);
    state = finished;
    if (finished.status != LeagueStatus.finished) return;
    try {
      // 1. Xoá khỏi active list ngay (state local là source of truth cho
      //    ResultScreen; active list invariant = chỉ inProgress).
      ref.read(activeLeaguesControllerProvider.notifier).remove(leagueId);
      // 2. Ghi history (await). Dùng snapshot `finished` thay vì state
      //    getter — đảm bảo concurrent mutation (nếu có) không leak vào.
      await ref
          .read(leagueHistoryControllerProvider.notifier)
          .addResult(finished);
      // 3. Flush active list xuống đĩa rõ ràng — listenSelf đã schedule
      //    fire-and-forget save, await ở đây để chắc chắn đĩa khớp trước
      //    khi user có thể kill app.
      await ActiveLeaguesStorage.saveAll(
        ref.read(activeLeaguesControllerProvider),
      );
    } catch (_) {
      // Restore: state về inProgress, active list re-add. Caller sẽ thấy
      // exception và có thể show SnackBar / retry.
      state = preFinishState;
      ref.read(activeLeaguesControllerProvider.notifier).upsert(preFinishState);
      rethrow;
    }
  }

  /// Huỷ giải hiện tại — xoá khỏi active list, quay về list view.
  /// Guard: chỉ chạy khi đang inProgress, tránh huỷ nhầm finished/setup.
  void cancelTournament() {
    if (state.status != LeagueStatus.inProgress) return;
    final leagueId = state.id;
    state = LeagueState.initial();
    ref.read(activeLeaguesControllerProvider.notifier).remove(leagueId);
    ref.read(leagueSessionControllerProvider.notifier).goToList();
  }

  /// Thoát hẳn League mode → Mode Selection. Active list giữ nguyên.
  void exitToModeSelection() {
    state = LeagueState.initial();
    ref.read(leagueSessionControllerProvider.notifier).goToList();
    ref.read(gameControllerProvider.notifier).resetGame();
  }
}
