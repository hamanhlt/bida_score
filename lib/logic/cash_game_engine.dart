import '../models/cash_game_state.dart';

/// Engine pure cho chế độ Chơi điểm. Input state → output state, throw
/// [ArgumentError] khi validation fail. Không Riverpod, không I/O.
class CashGameEngine {
  const CashGameEngine();

  static const _maxMoney = 100000000; // 100 triệu / đơn vị — chặn nhập lố.

  /// Khởi tạo trận. Throw [ArgumentError] nếu tên không hợp lệ hoặc mức
  /// tiền âm / vượt cap.
  CashGameState startGame(
    List<String> rawNames, {
    required int moneyPerRack,
    required int moneyPerBall,
  }) {
    final names = rawNames
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    if (names.length != 2) {
      throw ArgumentError('Chơi điểm cần đúng 2 người chơi.');
    }
    if (names[0].toLowerCase() == names[1].toLowerCase()) {
      throw ArgumentError('Tên người chơi phải khác nhau.');
    }
    if (moneyPerRack < 0 || moneyPerBall < 0) {
      throw ArgumentError('Mức tiền phải ≥ 0.');
    }
    if (moneyPerRack > _maxMoney || moneyPerBall > _maxMoney) {
      throw ArgumentError('Mức tiền quá lớn.');
    }

    return CashGameState(
      playerNames: names,
      rackWins: List.filled(names.length, 0),
      balls: List.filled(names.length, 0),
      rackResults: const [],
      settledOffsets: List.filled(names.length, 0),
      settledRackWins: List.filled(names.length, 0),
      moneyPerRack: moneyPerRack,
      moneyPerBall: moneyPerBall,
      status: CashGameStatus.inProgress,
      startedAt: DateTime.now(),
    );
  }

  /// +1 ván thắng cho người [index]. Điểm số này cộng dồn toàn trận.
  CashGameState addRackWin(CashGameState state, int index) {
    if (!_validIndex(state, index)) return state;
    if (state.status != CashGameStatus.inProgress) return state;
    final next = [...state.rackWins];
    next[index] = next[index] + 1;
    return state.copyWith(rackWins: next, history: _push(state));
  }

  /// −1 ván thắng (sửa nhầm). Floor 0.
  CashGameState decrementRackWin(CashGameState state, int index) {
    if (!_validIndex(state, index)) return state;
    if (state.status != CashGameStatus.inProgress) return state;
    if (state.rackWins[index] <= 0) return state;
    final next = [...state.rackWins];
    next[index] = next[index] - 1;
    return state.copyWith(rackWins: next, history: _push(state));
  }

  /// +1 lỗ 10 cho người [index].
  CashGameState addBall(CashGameState state, int index) {
    if (!_validIndex(state, index)) return state;
    if (state.status != CashGameStatus.inProgress) return state;
    final next = [...state.balls];
    next[index] = next[index] + 1;
    return state.copyWith(balls: next, history: _push(state));
  }

  /// −1 bi (sửa nhầm). Floor 0.
  CashGameState removeBall(CashGameState state, int index) {
    if (!_validIndex(state, index)) return state;
    if (state.status != CashGameStatus.inProgress) return state;
    if (state.balls[index] <= 0) return state;
    final next = [...state.balls];
    next[index] = next[index] - 1;
    return state.copyWith(balls: next, history: _push(state));
  }

  /// Chốt lỗ 10 ván hiện tại rồi mở bộ đếm lỗ 10 mới.
  CashGameState settleRack(CashGameState state) {
    if (state.status != CashGameStatus.inProgress) return state;
    if (!state.canSettleRack) return state;
    return _settleAndNet(state, pushHistory: true);
  }

  CashGameState finishGame(CashGameState state) {
    if (state.status != CashGameStatus.inProgress) return state;
    final settled = state.canSettleRack
        ? _settleAndNet(state, pushHistory: false)
        : state;
    return settled.copyWith(status: CashGameStatus.finished);
  }

  CashGameState undo(CashGameState state) {
    if (state.history.isEmpty) return state;
    final prev = state.history.last;
    final remaining = state.history.sublist(0, state.history.length - 1);
    return CashGameState.fromSnapshot(
      prev,
      playerNames: state.playerNames,
      moneyPerRack: state.moneyPerRack,
      moneyPerBall: state.moneyPerBall,
      startedAt: state.startedAt,
      history: remaining,
    );
  }

  CashGameState resetGame() => CashGameState.initial();

  bool _validIndex(CashGameState state, int index) =>
      index >= 0 && index < state.playerNames.length;

  CashGameState _settleAndNet(
    CashGameState state, {
    required bool pushHistory,
  }) {
    var next = state.currentRackHasScore || state.currentRackWinsChanged
        ? _settleCurrentRack(state)
        : state;
    final amount = next.settlementAmount;
    if (amount > 0) {
      next = next.copyWith(
        settledOffsets: [
          for (var i = 0; i < next.playerNames.length; i++)
            (i < next.settledOffsets.length ? next.settledOffsets[i] : 0) +
                amount,
        ],
      );
    }
    next = next.copyWith(settledRackWins: next.rackWins);
    return pushHistory ? next.copyWith(history: _push(state)) : next;
  }

  CashGameState _settleCurrentRack(CashGameState state) {
    final result = CashGameRackResult(
      rackNumber: state.currentRackNumber,
      balls: state.balls,
      money: [
        for (var i = 0; i < state.playerNames.length; i++)
          state.currentMoneyOf(i),
      ],
    );
    return state.copyWith(
      balls: List.filled(state.playerNames.length, 0),
      rackResults: [...state.rackResults, result],
    );
  }

  List<CashGameSnapshot> _push(CashGameState state) => [
    ...state.history,
    state.toSnapshot(),
  ];
}
