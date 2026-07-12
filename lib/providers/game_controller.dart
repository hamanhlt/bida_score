import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/game_engine.dart';
import '../models/ball_config.dart';
import '../models/game_mode.dart';
import '../models/game_snapshot.dart';
import '../models/game_state.dart';
import '../models/last_setup.dart';
import '../models/match_result.dart';
import '../services/ball_config_history_storage.dart';
import '../services/game_persistence.dart';
import '../services/player_name_history_storage.dart';
import '../services/setup_persistence.dart';
import 'match_history_controller.dart';

final gameEngineProvider = Provider<GameEngine>((ref) => const GameEngine());

/// State ban đầu được preload ở `main.dart` từ SharedPreferences.
/// Null nghĩa là chưa có bản lưu → dùng [GameState.initial].
final initialGameStateProvider = Provider<GameState?>((_) => null);

/// Seed cho [lastSetupProvider] — override ở `main.dart` sau khi load
/// từ SharedPreferences. Notifier dùng để khởi tạo state ban đầu.
final lastSetupSeedProvider = Provider<LastSetup?>((_) => null);

/// Setup (tên + bi) lần Bắt đầu gần nhất.
///
/// Cold start: load từ disk thông qua [lastSetupSeedProvider].
/// Trong session: GameController.startGame gọi `.set(...)` để cập nhật
/// state in-memory + ghi disk → Setup screen mount lần sau đọc được giá
/// trị mới ngay.
final lastSetupProvider = NotifierProvider<LastSetupNotifier, LastSetup?>(
  LastSetupNotifier.new,
);

class LastSetupNotifier extends Notifier<LastSetup?> {
  @override
  LastSetup? build() => ref.read(lastSetupSeedProvider);

  /// Cập nhật state in-memory + persist ra disk (fire-and-forget).
  void set(LastSetup setup) {
    state = setup;
    unawaited(SetupPersistence.save(setup));
  }

  /// Update Bắn đền setup (names + ballConfigs) — preserve variantLabel +
  /// shotClockSeconds.
  void setPenalty(List<String> names, List<BallConfig> configs) {
    final next = LastSetup(
      playerNames: names,
      ballConfigs: configs,
      variantLabel: state?.variantLabel,
      shotClockSeconds: state?.shotClockSeconds ?? 0,
    );
    state = next;
    unawaited(SetupPersistence.save(next));
  }

  /// Update Pool config (variant + shot clock) — preserve Bắn đền names +
  /// ballConfigs.
  void setPoolConfig(String variantLabel, int shotClockSeconds) {
    final next = LastSetup(
      playerNames: state?.playerNames ?? const [],
      ballConfigs: state?.ballConfigs ?? const [],
      variantLabel: variantLabel,
      shotClockSeconds: shotClockSeconds,
    );
    state = next;
    unawaited(SetupPersistence.save(next));
  }
}

/// Seed cho [playerNameHistoryProvider] — override ở `main.dart`.
final playerNameHistorySeedProvider = Provider<List<String>>((_) => const []);

/// Lịch sử các tên người chơi đã từng nhập (LRU, mới nhất đầu list).
/// Setup screen dùng để gợi ý qua popup menu cuối mỗi field tên.
final playerNameHistoryProvider =
    NotifierProvider<PlayerNameHistoryNotifier, List<String>>(
  PlayerNameHistoryNotifier.new,
);

class PlayerNameHistoryNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => ref.read(playerNameHistorySeedProvider);

  /// Thêm `names` vào đầu list (dedupe case-insensitive, cap 50) + ghi disk.
  Future<void> addAll(List<String> names) async {
    final updated = await PlayerNameHistoryStorage.addAll(state, names);
    state = updated;
  }

  /// Xóa 1 tên khỏi list + ghi disk.
  Future<void> remove(String name) async {
    final updated = await PlayerNameHistoryStorage.remove(state, name);
    state = updated;
  }
}

/// Seed cho [ballConfigHistoryProvider] — override ở `main.dart`.
final ballConfigHistorySeedProvider =
    Provider<List<BallConfig>>((_) => const []);

/// Lịch sử các cấu hình bi (số bi + điểm) đã từng nhập (LRU, mới nhất đầu).
/// Setup screen gợi ý popup ở mỗi row "Danh sách bi" → user khỏi gõ lại.
final ballConfigHistoryProvider =
    NotifierProvider<BallConfigHistoryNotifier, List<BallConfig>>(
  BallConfigHistoryNotifier.new,
);

class BallConfigHistoryNotifier extends Notifier<List<BallConfig>> {
  @override
  List<BallConfig> build() => ref.read(ballConfigHistorySeedProvider);

  /// Thêm `configs` vào đầu list (dedupe — `BallConfig.==` override, cap 20).
  Future<void> addAll(List<BallConfig> configs) async {
    final updated = await BallConfigHistoryStorage.addAll(state, configs);
    state = updated;
  }

  /// Xoá 1 cấu hình bi khỏi list + ghi disk.
  Future<void> remove(BallConfig config) async {
    final updated = await BallConfigHistoryStorage.remove(state, config);
    state = updated;
  }
}

final gameControllerProvider = NotifierProvider<GameController, GameState>(
  GameController.new,
);

class GameController extends Notifier<GameState> {
  GameEngine get _engine => ref.read(gameEngineProvider);

  @override
  GameState build() {
    // Auto-save mỗi khi state đổi (fire-and-forget để không block UI).
    listenSelf((previous, next) {
      unawaited(GamePersistence.save(next));
    });

    final preloaded = ref.read(initialGameStateProvider);
    return preloaded ?? GameState.initial();
  }

  void selectMode(GameMode mode) {
    state = state.copyWith(gameMode: mode, status: GameStatus.setup);
  }

  void startGame(List<String> names, List<BallConfig> ballConfigs) {
    state = _engine.startGame(names, ballConfigs);
    // Engine throw nếu validation fail → state không update → set không chạy.
    // Cập nhật cả state in-memory (qua notifier) lẫn disk để Setup screen
    // mount lần sau (cùng app session) đọc được giá trị mới ngay.
    ref.read(lastSetupProvider.notifier).setPenalty(names, ballConfigs);
    // Lưu tên + cấu hình bi vào history pool — Setup screen lần sau gợi ý lại.
    unawaited(ref.read(playerNameHistoryProvider.notifier).addAll(names));
    unawaited(
      ref.read(ballConfigHistoryProvider.notifier).addAll(ballConfigs),
    );
  }

  /// Thêm người chơi giữa trận. Engine throw [ArgumentError] nếu tên rỗng/trùng
  /// → caller (UI) bắt + hiện lỗi. State không update nếu validation fail.
  void addPlayer(String name) {
    state = _engine.addPlayer(state, name);
  }

  void selectShooter(int index) {
    state = _engine.selectShooter(state, index);
  }

  void addBall(BallConfig ball) {
    state = _engine.addBall(state, ball);
  }

  void removeBallAt(int index) {
    state = _engine.removeBallAt(state, index);
  }

  void clearDraft() {
    state = _engine.clearDraft(state);
  }

  /// Áp điểm cho đúng 1 người bị trừ. Hệ số nhân lấy từ `turnState.chamMode`.
  void pickSingleVictim(int index) {
    state = _engine.applyScore(
      state,
      victimIndices: [index],
      multiplier: state.turnState.multiplier,
    );
  }

  /// Áp điểm cho tất cả người không-bắn. Hệ số nhân lấy từ `turnState.chamMode`.
  void applyToAllVictims() {
    final shooter = state.turnState.shooterIndex;
    if (shooter == null) return;
    final victims = <int>[
      for (var i = 0; i < state.players.length; i++)
        if (i != shooter) i,
    ];
    state = _engine.applyScore(
      state,
      victimIndices: victims,
      multiplier: state.turnState.multiplier,
    );
  }

  /// Áp điểm tổng quát: đặt `balls` + `multiplier` vào turn state rồi
  /// áp ngay cho danh sách `victimIndices`. Dùng cho flow popup ở Bước 2
  /// (tap 1 bi → popup chọn victim, hoặc Chấm đơn → popup chọn victim).
  /// Engine tự validate và ghi 1 entry `ScoreEvent` cùng 1 snapshot undo.
  /// Undo quay về bước chọn bi, không quay về draft trung gian có nút "Đền cả bàn".
  void applyBallsToVictims({
    required List<BallConfig> balls,
    required List<int> victimIndices,
    int multiplier = 1,
  }) {
    if (balls.isEmpty) return;
    final enriched = state.copyWith(
      turnState: state.turnState.copyWith(
        pocketedBalls: balls,
        chamMode: multiplier > 1,
      ),
    );
    state = _engine.applyScore(
      enriched,
      victimIndices: victimIndices,
      multiplier: multiplier,
      undoState: state,
    );
  }

  /// Chấm phá: fill tất cả bi + bật chấm ×2 + áp ngay cho tất cả người không-bắn.
  void chamPha() {
    final beforeShortcut = state;
    final afterEnter = _engine.enterCham(state);
    final shooter = afterEnter.turnState.shooterIndex;
    if (shooter == null) return;
    final victims = <int>[
      for (var i = 0; i < afterEnter.players.length; i++)
        if (i != shooter) i,
    ];
    state = _engine.applyScore(
      afterEnter,
      victimIndices: victims,
      multiplier: afterEnter.turnState.multiplier,
      undoState: beforeShortcut,
    );
  }

  void endRound() {
    state = _engine.endRound(state);
  }

  void finishGame() {
    final wasInProgress = state.status == GameStatus.inProgress;
    state = _engine.finishGame(state);

    // Chỉ ghi lịch sử khi thực sự chuyển từ inProgress → finished.
    if (wasInProgress && state.status == GameStatus.finished) {
      final ranked = [...state.players]
        ..sort((a, b) => b.score.compareTo(a.score));
      // Số ván "đã đấu" = ván cao nhất thực sự có ghi điểm — bỏ ván cuối
      // trống nếu user ấn "Hết ván" rồi "Kết thúc trận" mà chưa ghi gì.
      final maxScoredRound = state.scoreEvents.fold<int>(
        0,
        (m, e) => e.roundNumber > m ? e.roundNumber : m,
      );
      final roundsPlayed = maxScoredRound < 1 ? 1 : maxScoredRound;
      final result = MatchResult(
        finishedAt: DateTime.now(),
        modeLabel: state.gameMode?.label ?? 'Bắn đền',
        roundsPlayed: roundsPlayed,
        players: [
          for (final p in ranked)
            MatchPlayerResult(name: p.name, score: p.score),
        ],
        events: state.scoreEvents,
      );
      ref.read(matchHistoryControllerProvider.notifier).addResult(result);
    }
  }

  void undo() {
    state = _engine.undo(state);
  }

  void resetGame() {
    state = _engine.resetGame();
  }
}
