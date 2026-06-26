import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/nine_ball_engine.dart';
import '../models/match_result.dart';
import '../models/nine_ball_state.dart';
import 'active_pools_controller.dart';
import 'game_controller.dart';
import 'match_history_controller.dart';
import 'pool_session_controller.dart';

final nineBallEngineProvider =
    Provider<NineBallEngine>((ref) => const NineBallEngine());

final nineBallControllerProvider =
    NotifierProvider<NineBallController, NineBallState>(
  NineBallController.new,
);

/// State của trận Pool **đang chơi** (1 trong N trận trong active list).
/// Auto-sync về [activePoolsControllerProvider] mỗi lần đổi. Mirror
/// LeagueController: user switch giữa các trận không mất tỷ số.
class NineBallController extends Notifier<NineBallState> {
  NineBallEngine get _engine => ref.read(nineBallEngineProvider);

  @override
  NineBallState build() {
    listenSelf((_, next) {
      // Sync về active list: inProgress thì upsert, ngược lại (finished /
      // initial) remove khỏi list để invariant "list chỉ chứa inProgress".
      final pools = ref.read(activePoolsControllerProvider.notifier);
      if (next.status == NineBallStatus.inProgress) {
        pools.upsert(next);
      } else if (next.id.isNotEmpty) {
        pools.remove(next.id);
      }
    });
    // Restore: session có currentId → load trận từ active list seed.
    final session = ref.read(poolSessionSeedProvider);
    final currentId = session?.currentId;
    if (currentId != null && currentId.isNotEmpty) {
      final seedList = ref.read(activePoolsSeedProvider) ?? const [];
      for (final m in seedList) {
        if (m.id == currentId) return m;
      }
      // Session trỏ tới trận không còn trong active list (kill app ở
      // ResultScreen sau finish, hoặc data hỏng). Defer goToList ra
      // microtask — KHÔNG mutate provider khác trong build.
      Future.microtask(() {
        ref.read(poolSessionControllerProvider.notifier).goToList();
      });
    }
    return NineBallState.initial();
  }

  /// Khởi tạo trận mới. Engine throw nếu validation fail → state không update
  /// → các dòng dưới không chạy. Sau start, openCurrent(id) để session nhớ
  /// trận này.
  void startGame(
    List<String> names,
    int raceTarget, {
    String? variantLabel,
    int shotClockSeconds = 0,
  }) {
    state = _engine.startGame(
      names,
      raceTarget,
      variantLabel: variantLabel,
      shotClockSeconds: shotClockSeconds,
    );
    // Lưu tên vào pool dùng chung → Setup screen lần sau gợi ý.
    unawaited(ref.read(playerNameHistoryProvider.notifier).addAll(names));
    // Persist variant + shot clock để Setup mở lần sau auto-select.
    ref
        .read(lastSetupProvider.notifier)
        .setPoolConfig(variantLabel ?? '9-Ball', shotClockSeconds);
    ref.read(poolSessionControllerProvider.notifier).openCurrent(state.id);
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

  /// Mở 1 trận đang chơi có sẵn từ list — copy vào state để screen chơi tiếp.
  /// Short-circuit nếu đã ở trận đó để tránh mutation thừa.
  void openMatch(NineBallState match) {
    if (state.id.isNotEmpty && state.id == match.id) {
      ref.read(poolSessionControllerProvider.notifier).openCurrent(match.id);
      return;
    }
    state = match;
    ref.read(poolSessionControllerProvider.notifier).openCurrent(match.id);
  }

  /// Bắt đầu setup trận mới (clear state, vào màn Setup).
  void createNew() {
    state = NineBallState.initial();
    ref.read(poolSessionControllerProvider.notifier).openNewSetup();
  }

  /// Quay về NineBallListScreen — KHÔNG xoá khỏi active list (trận vẫn ở đó
  /// để resume sau).
  void backToList() {
    state = NineBallState.initial();
    ref.read(poolSessionControllerProvider.notifier).goToList();
  }

  /// Huỷ trận hiện tại — xoá khỏi active list, quay về list.
  void cancelMatch() {
    final id = state.id;
    state = NineBallState.initial();
    ref.read(activePoolsControllerProvider.notifier).remove(id);
    ref.read(poolSessionControllerProvider.notifier).goToList();
  }

  /// Thoát hẳn Pool mode → Mode Selection. Active list giữ nguyên.
  void exitToModeSelection() {
    state = NineBallState.initial();
    ref.read(poolSessionControllerProvider.notifier).goToList();
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
    // Biến thể (8/9/10-Ball / tuỳ ý) chọn ở Setup → fallback "Pool".
    final modeLabel = state.variantLabel ?? 'Pool';
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
