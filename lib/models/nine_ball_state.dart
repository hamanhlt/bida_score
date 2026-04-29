import 'player.dart';

enum NineBallStatus { setup, inProgress, finished }

class NineBallSnapshot {
  NineBallSnapshot({
    required List<Player> players,
    required List<int> rackWins,
    required this.raceTarget,
    required this.breakerIndex,
    required this.currentRack,
    required this.status,
  }) : players = List.unmodifiable(players),
       rackWins = List.unmodifiable(rackWins);

  final List<Player> players;
  final List<int> rackWins;
  final int raceTarget;
  final int breakerIndex;
  final int currentRack;
  final NineBallStatus status;
}

class NineBallState {
  NineBallState({
    List<Player> players = const [],
    List<int> rackWins = const [],
    this.raceTarget = 5,
    this.breakerIndex = 0,
    this.currentRack = 1,
    this.status = NineBallStatus.setup,
    List<NineBallSnapshot> history = const [],
  }) : players = List.unmodifiable(players),
       rackWins = List.unmodifiable(
         rackWins.isEmpty && players.isNotEmpty
             ? List.filled(players.length, 0)
             : rackWins,
       ),
       history = List.unmodifiable(history);

  factory NineBallState.initial() => NineBallState();

  factory NineBallState.fromSnapshot(
    NineBallSnapshot snapshot, {
    List<NineBallSnapshot> history = const [],
  }) {
    return NineBallState(
      players: snapshot.players,
      rackWins: snapshot.rackWins,
      raceTarget: snapshot.raceTarget,
      breakerIndex: snapshot.breakerIndex,
      currentRack: snapshot.currentRack,
      status: snapshot.status,
      history: history,
    );
  }

  final List<Player> players;
  final List<int> rackWins;
  final int raceTarget;
  final int breakerIndex;
  final int currentRack;
  final NineBallStatus status;
  final List<NineBallSnapshot> history;

  bool get canUndo => history.isNotEmpty;

  Player get breaker => players[breakerIndex];

  /// Người thắng trận (đạt raceTarget), null nếu chưa có
  int? get matchWinnerIndex {
    for (var i = 0; i < rackWins.length; i++) {
      if (rackWins[i] >= raceTarget) return i;
    }
    return null;
  }

  NineBallSnapshot toSnapshot() {
    return NineBallSnapshot(
      players: players,
      rackWins: rackWins,
      raceTarget: raceTarget,
      breakerIndex: breakerIndex,
      currentRack: currentRack,
      status: status,
    );
  }

  NineBallState copyWith({
    List<Player>? players,
    List<int>? rackWins,
    int? raceTarget,
    int? breakerIndex,
    int? currentRack,
    NineBallStatus? status,
    List<NineBallSnapshot>? history,
  }) {
    return NineBallState(
      players: players ?? this.players,
      rackWins: rackWins ?? this.rackWins,
      raceTarget: raceTarget ?? this.raceTarget,
      breakerIndex: breakerIndex ?? this.breakerIndex,
      currentRack: currentRack ?? this.currentRack,
      status: status ?? this.status,
      history: history ?? this.history,
    );
  }
}
