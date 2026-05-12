import 'ball_config.dart';
import 'player.dart';
import 'turn_state.dart';

enum GameStatus { modeSelection, setup, inProgress, finished }

class GameSnapshot {
  GameSnapshot({
    required List<Player> players,
    required List<BallConfig> ballConfigs,
    required this.turnState,
    required this.status,
    this.roundNumber = 1,
    this.lastScorerIndex,
    this.lastVictimIndex,
    this.scoreEventCount = 0,
  }) : players = List.unmodifiable(players),
       ballConfigs = List.unmodifiable(ballConfigs);

  final List<Player> players;
  final List<BallConfig> ballConfigs;
  final TurnState turnState;
  final GameStatus status;
  final int roundNumber;
  final int? lastScorerIndex;
  final int? lastVictimIndex;

  /// Số lượng [ScoreEvent] tại thời điểm chụp snapshot. Khi undo, `scoreEvents`
  /// được cắt về con số này → lượt ghi điểm vừa bị undo cũng biến mất khỏi log
  /// lịch sử (không còn append-only).
  final int scoreEventCount;
}
