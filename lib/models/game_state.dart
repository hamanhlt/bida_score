import 'ball_config.dart';
import 'game_mode.dart';
import 'game_snapshot.dart';
import 'player.dart';
import 'score_event.dart';
import 'turn_state.dart';

class GameState {
  GameState({
    List<Player> players = const [],
    List<BallConfig> ballConfigs = const [],
    TurnState? turnState,
    List<GameSnapshot> history = const [],
    List<ScoreEvent> scoreEvents = const [],
    this.status = GameStatus.modeSelection,
    this.roundNumber = 1,
    this.lastScorerIndex,
    this.lastVictimIndex,
    this.gameMode,
  }) : players = List.unmodifiable(players),
       ballConfigs = List.unmodifiable(ballConfigs),
       turnState = turnState ?? TurnState(),
       history = List.unmodifiable(history),
       scoreEvents = List.unmodifiable(scoreEvents);

  factory GameState.initial() => GameState();

  /// Khôi phục từ snapshot. [scoreEvents] được truyền từ ngoài vì
  /// không nằm trong snapshot (append-only log, không bị undo xoá).
  factory GameState.fromSnapshot(
    GameSnapshot snapshot, {
    List<GameSnapshot> history = const [],
    List<ScoreEvent> scoreEvents = const [],
    GameMode? gameMode,
  }) {
    return GameState(
      players: snapshot.players,
      ballConfigs: snapshot.ballConfigs,
      turnState: snapshot.turnState,
      history: history,
      scoreEvents: scoreEvents,
      status: snapshot.status,
      roundNumber: snapshot.roundNumber,
      lastScorerIndex: snapshot.lastScorerIndex,
      lastVictimIndex: snapshot.lastVictimIndex,
      gameMode: gameMode,
    );
  }

  final List<Player> players;
  final List<BallConfig> ballConfigs;
  final TurnState turnState;
  final List<GameSnapshot> history;

  /// Lịch sử các lượt ghi điểm — append-only, không mất khi undo.
  final List<ScoreEvent> scoreEvents;

  final GameStatus status;
  final int roundNumber;
  final int? lastScorerIndex;
  final int? lastVictimIndex;
  final GameMode? gameMode;

  bool get hasActiveGame =>
      status != GameStatus.modeSelection &&
      status != GameStatus.setup &&
      players.isNotEmpty;

  bool get canUndo => history.isNotEmpty;

  int get totalScore => players.fold(0, (sum, player) => sum + player.score);

  GameSnapshot toSnapshot() {
    return GameSnapshot(
      players: players,
      ballConfigs: ballConfigs,
      turnState: turnState,
      status: status,
      roundNumber: roundNumber,
      lastScorerIndex: lastScorerIndex,
      lastVictimIndex: lastVictimIndex,
    );
  }

  /// Serialize cho persistence. Bỏ qua `history` (undo stack) — không cần
  /// giữ khi app bị kill/restart.
  Map<String, dynamic> toJson() => {
    'players': players.map((p) => p.toJson()).toList(),
    'ballConfigs': ballConfigs.map((b) => b.toJson()).toList(),
    'turnState': turnState.toJson(),
    'status': status.name,
    'roundNumber': roundNumber,
    'lastScorerIndex': lastScorerIndex,
    'lastVictimIndex': lastVictimIndex,
    'gameMode': gameMode?.name,
    'scoreEvents': scoreEvents.map((e) => e.toJson()).toList(),
  };

  factory GameState.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String;
    final status = GameStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => GameStatus.modeSelection,
    );
    final modeName = json['gameMode'] as String?;
    final gameMode = modeName == null
        ? null
        : GameMode.values.firstWhere(
            (m) => m.name == modeName,
            orElse: () => GameMode.penalty369,
          );
    return GameState(
      players: (json['players'] as List<dynamic>)
          .map((e) => Player.fromJson(e as Map<String, dynamic>))
          .toList(),
      ballConfigs: (json['ballConfigs'] as List<dynamic>)
          .map((e) => BallConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      turnState: TurnState.fromJson(
        json['turnState'] as Map<String, dynamic>,
      ),
      status: status,
      roundNumber: json['roundNumber'] as int? ?? 1,
      lastScorerIndex: json['lastScorerIndex'] as int?,
      lastVictimIndex: json['lastVictimIndex'] as int?,
      gameMode: gameMode,
      scoreEvents: (json['scoreEvents'] as List<dynamic>? ?? const [])
          .map((e) => ScoreEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  GameState copyWith({
    List<Player>? players,
    List<BallConfig>? ballConfigs,
    TurnState? turnState,
    List<GameSnapshot>? history,
    List<ScoreEvent>? scoreEvents,
    GameStatus? status,
    int? roundNumber,
    int? Function()? lastScorerIndex,
    int? Function()? lastVictimIndex,
    GameMode? gameMode,
  }) {
    return GameState(
      players: players ?? this.players,
      ballConfigs: ballConfigs ?? this.ballConfigs,
      turnState: turnState ?? this.turnState,
      history: history ?? this.history,
      scoreEvents: scoreEvents ?? this.scoreEvents,
      status: status ?? this.status,
      roundNumber: roundNumber ?? this.roundNumber,
      lastScorerIndex: lastScorerIndex != null
          ? lastScorerIndex()
          : this.lastScorerIndex,
      lastVictimIndex: lastVictimIndex != null
          ? lastVictimIndex()
          : this.lastVictimIndex,
      gameMode: gameMode ?? this.gameMode,
    );
  }
}
