import '../models/ball_config.dart';
import '../models/game_snapshot.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/score_event.dart';
import '../models/turn_state.dart';
import '../services/player_avatar_pool.dart';

class GameEngine {
  const GameEngine();

  GameState startGame(
    List<String> rawNames,
    List<BallConfig> ballConfigs,
  ) {
    final names = rawNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    final uniqueNames = names.map((name) => name.toLowerCase()).toSet();

    if (names.length < 2) {
      throw ArgumentError('Cần ít nhất 2 người chơi.');
    }

    if (uniqueNames.length != names.length) {
      throw ArgumentError('Tên người chơi phải khác nhau.');
    }

    if (ballConfigs.isEmpty) {
      throw ArgumentError('Cần ít nhất 1 loại bi.');
    }

    final avatars = PlayerAvatarPool.randomUnique(names.length);
    final players = <Player>[
      for (var i = 0; i < names.length; i++)
        Player(
          id: 'player_${i + 1}_${_slug(names[i])}',
          name: names[i],
          score: 0,
          avatar: avatars[i],
        ),
    ];

    return GameState(
      players: players,
      ballConfigs: ballConfigs,
      turnState: TurnState(),
      status: GameStatus.inProgress,
      roundNumber: 1,
    );
  }

  /// Thêm 1 người chơi vào trận đang diễn ra. Điểm = 0, avatar random
  /// không trùng. Append vào cuối list — không đụng điểm/lịch sử/ván của ai.
  /// Throw [ArgumentError] nếu tên rỗng hoặc trùng (case-insensitive).
  GameState addPlayer(GameState state, String rawName) {
    if (state.status != GameStatus.inProgress) return state;

    final name = rawName.trim();
    if (name.isEmpty) {
      throw ArgumentError('Tên người chơi không được để trống.');
    }
    final lower = name.toLowerCase();
    if (state.players.any((p) => p.name.toLowerCase() == lower)) {
      throw ArgumentError('Đã có người chơi tên này.');
    }

    final usedAvatars = {for (final p in state.players) p.avatar};
    final newPlayer = Player(
      id: 'player_${state.players.length + 1}_${_slug(name)}',
      name: name,
      score: 0,
      avatar: PlayerAvatarPool.pickOne(usedAvatars),
    );

    return state.copyWith(
      players: [...state.players, newPlayer],
      history: _recordHistory(state),
    );
  }

  GameState selectShooter(GameState state, int index) {
    if (!_isPlaying(state) || !_validIndex(state, index)) {
      return state;
    }

    return state.copyWith(
      turnState: state.turnState.copyWith(shooterIndex: () => index),
      history: _recordHistory(state),
    );
  }

  GameState addBall(GameState state, BallConfig ball) {
    if (!_isPlaying(state)) {
      return state;
    }

    return state.copyWith(
      turnState: state.turnState.copyWith(
        pocketedBalls: [...state.turnState.pocketedBalls, ball],
      ),
      history: _recordHistory(state),
    );
  }

  GameState removeBallAt(GameState state, int index) {
    if (!_isPlaying(state)) {
      return state;
    }
    final balls = [...state.turnState.pocketedBalls];
    if (index < 0 || index >= balls.length) {
      return state;
    }
    balls.removeAt(index);

    return state.copyWith(
      turnState: state.turnState.copyWith(pocketedBalls: balls),
      history: _recordHistory(state),
    );
  }

  GameState clearDraft(GameState state) {
    if (!_isPlaying(state)) {
      return state;
    }

    return state.copyWith(
      turnState: TurnState(),
      history: _recordHistory(state),
    );
  }

  /// Vào chế độ "Chấm sành điệu":
  /// - `pocketedBalls` = tất cả bi đã cấu hình
  /// - `chamMode` = true (hệ số ×2)
  ///
  /// Sau khi gọi, [applyScore] sẽ dùng tổng điểm của TẤT CẢ bi × 2.
  /// Yêu cầu đã có shooter.
  GameState enterCham(GameState state) {
    if (!_isPlaying(state)) return state;
    if (state.turnState.shooterIndex == null) return state;
    if (state.ballConfigs.isEmpty) return state;

    return state.copyWith(
      turnState: state.turnState.copyWith(
        pocketedBalls: state.ballConfigs,
        chamMode: true,
      ),
      history: _recordHistory(state),
    );
  }

  /// Áp điểm lượt hiện tại.
  ///
  /// - [victimIndices]: danh sách chỉ số người bị trừ (có thể 1 hoặc nhiều).
  /// - [multiplier]: hệ số nhân (1 = thường, 2 = chấm sành điệu).
  ///
  /// Mỗi victim mất `totalBi × multiplier`.
  /// Shooter được cộng `totalBi × multiplier × số_victim` (bảo toàn zero-sum).
  ///
  /// Ghi [ScoreEvent] vào log (append-only, undo không xoá), và reset draft.
  GameState applyScore(
    GameState state, {
    required List<int> victimIndices,
    int multiplier = 1,
  }) {
    if (!_isPlaying(state)) return state;

    final shooterIndex = state.turnState.shooterIndex;
    if (shooterIndex == null) return state;
    if (state.turnState.pocketedBalls.isEmpty) return state;
    if (victimIndices.isEmpty) return state;
    if (victimIndices.contains(shooterIndex)) return state;
    for (final v in victimIndices) {
      if (!_validIndex(state, v)) return state;
    }
    if (victimIndices.toSet().length != victimIndices.length) return state;

    final pointsPerVictim = state.turnState.totalPoints * multiplier;
    if (pointsPerVictim == 0) return state;

    final shooterGain = pointsPerVictim * victimIndices.length;

    final updatedPlayers = [...state.players];
    updatedPlayers[shooterIndex] = updatedPlayers[shooterIndex].copyWith(
      score: updatedPlayers[shooterIndex].score + shooterGain,
    );
    for (final vIdx in victimIndices) {
      updatedPlayers[vIdx] = updatedPlayers[vIdx].copyWith(
        score: updatedPlayers[vIdx].score - pointsPerVictim,
      );
    }

    final event = ScoreEvent(
      at: DateTime.now(),
      roundNumber: state.roundNumber,
      shooterId: state.players[shooterIndex].id,
      shooterName: state.players[shooterIndex].name,
      balls: state.turnState.pocketedBalls,
      multiplier: multiplier,
      victimIds: [for (final i in victimIndices) state.players[i].id],
      victimNames: [for (final i in victimIndices) state.players[i].name],
      pointsPerVictim: pointsPerVictim,
    );

    // Chỉ set lastVictimIndex khi đúng 1 victim — để endRound reorder chính xác.
    final int? singleVictim =
        victimIndices.length == 1 ? victimIndices.first : null;

    final nextState = state.copyWith(
      players: updatedPlayers,
      turnState: TurnState(),
      history: _recordHistory(state),
      scoreEvents: [...state.scoreEvents, event],
      lastScorerIndex: () => shooterIndex,
      lastVictimIndex: () => singleVictim,
    );

    return _ensureZeroBalance(nextState);
  }

  /// Kết thúc ván hiện tại, bắt đầu ván mới.
  GameState endRound(GameState state) {
    if (!_isPlaying(state) || state.players.isEmpty) {
      return state;
    }

    var players = [...state.players];

    if (state.lastScorerIndex != null && state.lastVictimIndex != null) {
      final scorerIdx = state.lastScorerIndex!;
      final victimIdx = state.lastVictimIndex!;
      final scorer = players[scorerIdx];
      final victim = players[victimIdx];

      final remaining = <Player>[];
      for (var i = 0; i < players.length; i++) {
        if (i != scorerIdx && i != victimIdx) {
          remaining.add(players[i]);
        }
      }

      players = [scorer, victim, ...remaining];
    }

    return state.copyWith(
      players: players,
      turnState: TurnState(),
      roundNumber: state.roundNumber + 1,
      lastScorerIndex: () => null,
      lastVictimIndex: () => null,
      history: _recordHistory(state),
    );
  }

  GameState finishGame(GameState state) {
    if (state.status != GameStatus.inProgress) {
      return state;
    }

    return state.copyWith(status: GameStatus.finished);
  }

  /// Hoàn tác action gần nhất. Nếu action đó là 1 lượt ghi điểm thì
  /// [ScoreEvent] tương ứng cũng bị gỡ khỏi log — undo không để lại "rác"
  /// trong lịch sử. (Cắt `scoreEvents` về `snapshot.scoreEventCount`.)
  GameState undo(GameState state) {
    if (state.history.isEmpty) {
      return state;
    }

    final previousSnapshot = state.history.last;
    final remainingHistory = state.history.sublist(0, state.history.length - 1);

    final keep = previousSnapshot.scoreEventCount;
    final trimmedEvents = keep < state.scoreEvents.length
        ? state.scoreEvents.sublist(0, keep)
        : state.scoreEvents;

    return GameState.fromSnapshot(
      previousSnapshot,
      history: remainingHistory,
      scoreEvents: trimmedEvents,
      gameMode: state.gameMode,
    );
  }

  GameState resetGame() => GameState.initial();

  List<GameSnapshot> _recordHistory(GameState state) {
    return [...state.history, state.toSnapshot()];
  }

  bool _isPlaying(GameState state) =>
      state.status == GameStatus.inProgress && state.players.length >= 2;

  bool _validIndex(GameState state, int index) =>
      index >= 0 && index < state.players.length;

  GameState _ensureZeroBalance(GameState state) {
    if (state.totalScore != 0) {
      throw StateError('The total score must remain zero.');
    }

    return state;
  }

  String _slug(String input) {
    final cleaned = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return cleaned.replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
