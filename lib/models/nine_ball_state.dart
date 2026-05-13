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
    List<String> rackWinnerNames = const [],
  }) : players = List.unmodifiable(players),
       rackWins = List.unmodifiable(rackWins),
       rackWinnerNames = List.unmodifiable(rackWinnerNames);

  final List<Player> players;
  final List<int> rackWins;
  final int raceTarget;
  final int breakerIndex;
  final int currentRack;
  final NineBallStatus status;

  /// Tên người thắng từng rack theo thứ tự (rack 1 = phần tử 0, ...). Snapshot
  /// giữ luôn để undo khôi phục đúng.
  final List<String> rackWinnerNames;
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
    List<String> rackWinnerNames = const [],
  }) : players = List.unmodifiable(players),
       rackWins = List.unmodifiable(
         rackWins.isEmpty && players.isNotEmpty
             ? List.filled(players.length, 0)
             : rackWins,
       ),
       history = List.unmodifiable(history),
       rackWinnerNames = List.unmodifiable(rackWinnerNames);

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
      rackWinnerNames: snapshot.rackWinnerNames,
    );
  }

  final List<Player> players;
  final List<int> rackWins;
  final int raceTarget;
  final int breakerIndex;
  final int currentRack;
  final NineBallStatus status;
  final List<NineBallSnapshot> history;

  /// Tên người thắng từng rack theo thứ tự (chronological). `length` luôn
  /// bằng tổng `rackWins`. Dùng cho MatchDetailScreen play-by-play.
  final List<String> rackWinnerNames;

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
      rackWinnerNames: rackWinnerNames,
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
    List<String>? rackWinnerNames,
  }) {
    return NineBallState(
      players: players ?? this.players,
      rackWins: rackWins ?? this.rackWins,
      raceTarget: raceTarget ?? this.raceTarget,
      breakerIndex: breakerIndex ?? this.breakerIndex,
      currentRack: currentRack ?? this.currentRack,
      status: status ?? this.status,
      history: history ?? this.history,
      rackWinnerNames: rackWinnerNames ?? this.rackWinnerNames,
    );
  }
}
