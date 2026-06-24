import '../models/nine_ball_state.dart';
import '../models/player.dart';

class NineBallEngine {
  const NineBallEngine();

  NineBallState startGame(
    List<String> rawNames,
    int raceTarget, {
    String? variantLabel,
    int shotClockSeconds = 0,
  }) {
    final names = rawNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    if (names.length != 2) {
      throw ArgumentError('Pool cần đúng 2 người chơi.');
    }

    final uniqueNames = names.map((n) => n.toLowerCase()).toSet();
    if (uniqueNames.length != names.length) {
      throw ArgumentError('Tên người chơi phải khác nhau.');
    }

    final players = <Player>[
      for (var i = 0; i < names.length; i++)
        Player(
          id: 'player_${i + 1}_${_slug(names[i])}',
          name: names[i],
          score: 0,
        ),
    ];

    return NineBallState(
      players: players,
      rackWins: List.filled(players.length, 0),
      raceTarget: raceTarget,
      breakerIndex: 0,
      currentRack: 1,
      status: NineBallStatus.inProgress,
      variantLabel: variantLabel,
      shotClockSeconds: shotClockSeconds,
    );
  }

  /// Ghi nhận người thắng rack. Winner breaks rack tiếp.
  NineBallState winRack(NineBallState state, int winnerIndex) {
    if (state.status != NineBallStatus.inProgress) return state;
    if (winnerIndex < 0 || winnerIndex >= state.players.length) return state;

    final newWins = [...state.rackWins];
    newWins[winnerIndex] = newWins[winnerIndex] + 1;

    final newPlayers = [...state.players];
    newPlayers[winnerIndex] = newPlayers[winnerIndex].copyWith(
      score: newWins[winnerIndex],
    );

    var nextState = state.copyWith(
      players: newPlayers,
      rackWins: newWins,
      breakerIndex: winnerIndex,
      currentRack: state.currentRack + 1,
      rackWinnerNames: [
        ...state.rackWinnerNames,
        state.players[winnerIndex].name,
      ],
      history: _recordHistory(state),
    );

    // Kiểm tra đã đạt race target chưa
    if (newWins[winnerIndex] >= state.raceTarget) {
      nextState = nextState.copyWith(status: NineBallStatus.finished);
    }

    return nextState;
  }

  /// Trừ 1 rack win của 1 người. Không đổi breaker, không đổi currentRack —
  /// đây là sửa lỗi nhập nhầm chứ không phải "unwin" turn. Floor 0.
  /// Nếu trận đã finished mà điểm rớt xuống dưới raceTarget → revert inProgress.
  NineBallState decrementWin(NineBallState state, int playerIndex) {
    if (playerIndex < 0 || playerIndex >= state.players.length) return state;
    if (state.rackWins[playerIndex] <= 0) return state;

    final newWins = [...state.rackWins];
    newWins[playerIndex] = newWins[playerIndex] - 1;

    final newPlayers = [...state.players];
    newPlayers[playerIndex] = newPlayers[playerIndex].copyWith(
      score: newWins[playerIndex],
    );

    var status = state.status;
    if (status == NineBallStatus.finished &&
        newWins[playerIndex] < state.raceTarget) {
      status = NineBallStatus.inProgress;
    }

    // Gỡ rack thắng gần nhất của người này khỏi log play-by-play.
    final newWinnerNames = [...state.rackWinnerNames];
    final removeAt = newWinnerNames.lastIndexOf(state.players[playerIndex].name);
    if (removeAt >= 0) newWinnerNames.removeAt(removeAt);

    return state.copyWith(
      players: newPlayers,
      rackWins: newWins,
      status: status,
      rackWinnerNames: newWinnerNames,
      history: _recordHistory(state),
    );
  }

  NineBallState finishGame(NineBallState state) {
    if (state.status != NineBallStatus.inProgress) return state;
    return state.copyWith(status: NineBallStatus.finished);
  }

  NineBallState undo(NineBallState state) {
    if (state.history.isEmpty) return state;

    final prev = state.history.last;
    final remaining = state.history.sublist(0, state.history.length - 1);
    return NineBallState.fromSnapshot(prev, history: remaining);
  }

  NineBallState resetGame() => NineBallState.initial();

  List<NineBallSnapshot> _recordHistory(NineBallState state) {
    return [...state.history, state.toSnapshot()];
  }

  String _slug(String input) {
    final cleaned = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return cleaned.replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
