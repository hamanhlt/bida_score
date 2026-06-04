import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/league_engine.dart';
import '../models/league_state.dart';
import 'game_controller.dart';
import 'league_history_controller.dart';

final leagueEngineProvider = Provider<LeagueEngine>(
  (_) => const LeagueEngine(),
);

/// State giải đấu hiện tại — in-memory ONLY (không persist sau kill app).
/// Đúng spec "Trong suốt quá trình giải đấu diễn ra, dữ liệu CHỈ quản lý
/// trên bộ nhớ tạm".
final leagueControllerProvider =
    NotifierProvider<LeagueController, LeagueState>(LeagueController.new);

class LeagueController extends Notifier<LeagueState> {
  LeagueEngine get _engine => ref.read(leagueEngineProvider);

  @override
  LeagueState build() => LeagueState.initial();

  /// Khởi tạo giải. Engine throw [ArgumentError] nếu names không hợp lệ
  /// (< 3 người, trùng) → caller bắt + hiện lỗi.
  void startTournament(List<String> names) {
    state = _engine.startTournament(names);
  }

  /// Cập nhật tỷ số 1 trận → engine tự recalculate leaderboard từ đầu →
  /// state mới được Riverpod publish → UI Tab Bảng xếp hạng tự rebuild.
  void updateScore(String fixtureId, int score1, int score2) {
    state = _engine.updateScore(state, fixtureId, score1, score2);
  }

  /// Xoá tỷ số 1 trận (về not-played).
  void clearScore(String fixtureId) {
    state = _engine.clearScore(state, fixtureId);
  }

  /// Chốt giải + persist vào LeagueHistory. Đây là điểm DUY NHẤT chạm
  /// disk trong lifecycle của 1 giải đấu (đúng spec).
  Future<void> finishTournament() async {
    final wasInProgress = state.status == LeagueStatus.inProgress;
    state = _engine.finishTournament(state);
    if (wasInProgress && state.status == LeagueStatus.finished) {
      await ref
          .read(leagueHistoryControllerProvider.notifier)
          .addResult(state);
    }
  }

  /// Reset về initial + quay lại Mode Selection.
  void resetTournament() {
    state = _engine.resetTournament();
    ref.read(gameControllerProvider.notifier).resetGame();
  }
}
