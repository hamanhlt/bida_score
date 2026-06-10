import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/cash_game_engine.dart';
import '../models/cash_config.dart';
import '../models/cash_game_state.dart';
import '../models/match_result.dart';
import '../services/cash_config_storage.dart';
import 'game_controller.dart';
import 'match_history_controller.dart';

final cashGameEngineProvider = Provider<CashGameEngine>(
  (_) => const CashGameEngine(),
);

/// Seed cho [cashConfigProvider] — preload mức tiền gần nhất ở `main.dart`.
final cashConfigSeedProvider = Provider<CashConfig?>((_) => null);

/// Mức tiền Chơi điểm gần nhất (auto-fill Setup). Cold start từ disk qua
/// seed; trong session `startGame` gọi `.set(...)` cập nhật + ghi disk.
final cashConfigProvider = NotifierProvider<CashConfigNotifier, CashConfig?>(
  CashConfigNotifier.new,
);

class CashConfigNotifier extends Notifier<CashConfig?> {
  @override
  CashConfig? build() => ref.read(cashConfigSeedProvider);

  void set(CashConfig config) {
    state = config;
    unawaited(CashConfigStorage.save(config));
  }
}

final cashGameControllerProvider =
    NotifierProvider<CashGameController, CashGameState>(CashGameController.new);

class CashGameController extends Notifier<CashGameState> {
  CashGameEngine get _engine => ref.read(cashGameEngineProvider);

  @override
  CashGameState build() => CashGameState.initial();

  void startGame(
    List<String> names, {
    required int moneyPerRack,
    required int moneyPerBall,
  }) {
    state = _engine.startGame(
      names,
      moneyPerRack: moneyPerRack,
      moneyPerBall: moneyPerBall,
    );
    // Engine throw nếu fail → state không update → dòng dưới không chạy.
    unawaited(ref.read(playerNameHistoryProvider.notifier).addAll(names));
    ref
        .read(cashConfigProvider.notifier)
        .set(
          CashConfig(moneyPerRack: moneyPerRack, moneyPerBall: moneyPerBall),
        );
  }

  void addRackWin(int index) => state = _engine.addRackWin(state, index);
  void decrementRackWin(int index) =>
      state = _engine.decrementRackWin(state, index);
  void addBall(int index) => state = _engine.addBall(state, index);
  void removeBall(int index) => state = _engine.removeBall(state, index);
  void settleRack() => state = _engine.settleRack(state);
  void undo() => state = _engine.undo(state);

  void finishGame() {
    final wasInProgress = state.status == CashGameStatus.inProgress;
    state = _engine.finishGame(state);
    if (wasInProgress && state.status == CashGameStatus.finished) {
      _recordHistory();
    }
  }

  void resetGame() {
    state = _engine.resetGame();
    ref.read(gameControllerProvider.notifier).resetGame();
  }

  /// Ghi MatchResult vào lịch sử — score = tổng tiền mỗi người (rank theo
  /// tiền). modeLabel 'Chơi điểm' để filter tab Lịch sử.
  void _recordHistory() {
    final indices = [for (var i = 0; i < state.playerNames.length; i++) i]
      ..sort((a, b) => state.moneyOf(b).compareTo(state.moneyOf(a)));
    final totalWins = state.rackWins.fold<int>(0, (s, v) => s + v);
    final totalRacks = totalWins > state.settledRackCount
        ? totalWins
        : state.settledRackCount;
    final result = MatchResult(
      finishedAt: DateTime.now(),
      modeLabel: 'Chơi điểm',
      roundsPlayed: totalRacks < 1 ? 1 : totalRacks,
      players: [
        for (final i in indices)
          MatchPlayerResult(
            name: state.playerNames[i],
            score: state.moneyOf(i),
          ),
      ],
    );
    ref.read(matchHistoryControllerProvider.notifier).addResult(result);
  }
}
