import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/nine_ball_engine.dart';
import '../models/match_result.dart';
import '../models/nine_ball_state.dart';
import 'game_controller.dart';
import 'match_history_controller.dart';

final nineBallEngineProvider =
    Provider<NineBallEngine>((ref) => const NineBallEngine());

final nineBallControllerProvider =
    NotifierProvider<NineBallController, NineBallState>(
  NineBallController.new,
);

class NineBallController extends Notifier<NineBallState> {
  NineBallEngine get _engine => ref.read(nineBallEngineProvider);

  @override
  NineBallState build() => NineBallState.initial();

  void startGame(List<String> names, int raceTarget) {
    state = _engine.startGame(names, raceTarget);
    // Engine throw nếu validation fail → state không update → dòng dưới
    // không chạy. Lưu tên vào pool dùng chung → Setup screen lần sau gợi ý.
    unawaited(ref.read(playerNameHistoryProvider.notifier).addAll(names));
  }

  void winRack(int winnerIndex) {
    final wasInProgress = state.status == NineBallStatus.inProgress;
    state = _engine.winRack(state, winnerIndex);
    // winRack tự kết thúc trận khi ai đó đạt race target → ghi lịch sử ở đây.
    _recordHistoryIfFinished(wasInProgress);
  }

  void decrementWin(int playerIndex) {
    state = _engine.decrementWin(state, playerIndex);
  }

  void finishGame() {
    final wasInProgress = state.status == NineBallStatus.inProgress;
    state = _engine.finishGame(state);
    _recordHistoryIfFinished(wasInProgress);
  }

  void undo() {
    state = _engine.undo(state);
  }

  void resetGame() {
    state = _engine.resetGame();
    // Quay về mode selection
    ref.read(gameControllerProvider.notifier).resetGame();
  }

  /// Ghi kết quả vào lịch sử khi trận vừa chuyển inProgress → finished (qua bất
  /// kỳ đường nào: đạt race target trong [winRack], hoặc bấm "Kết thúc trận").
  /// Mode race-to-X không dùng `ScoreEvent` nên `events` rỗng; thay vào đó
  /// truyền `rackWinners` → MatchDetailScreen hiện play-by-play từng rack.
  void _recordHistoryIfFinished(bool wasInProgress) {
    if (!wasInProgress || state.status != NineBallStatus.finished) return;

    final ranked = [...state.players]
      ..sort((a, b) => b.score.compareTo(a.score));
    // Số rack đã đấu = số winner đã ghi (đã trừ các decrement nếu có).
    final racksPlayed = state.rackWinnerNames.length;
    final modeLabel =
        ref.read(gameControllerProvider).gameMode?.label ?? '9-Ball';
    final result = MatchResult(
      finishedAt: DateTime.now(),
      modeLabel: modeLabel,
      roundsPlayed: racksPlayed < 1 ? 1 : racksPlayed,
      players: [
        for (final p in ranked)
          MatchPlayerResult(name: p.name, score: p.score),
      ],
      rackWinners: state.rackWinnerNames,
    );
    ref.read(matchHistoryControllerProvider.notifier).addResult(result);
  }
}
