/// State cho chế độ "Chơi điểm" — 2 người, tính tiền theo ván thắng + lỗ 10.
/// Mức tiền cấu hình ở Setup.
///
/// Tiền 1 người = tổng ván thắng + lỗ 10 đã chốt + lỗ 10 đang nhập
/// sau khi trừ phần hiệu số đã chốt.
enum CashGameStatus { setup, inProgress, finished }

class CashGameRackResult {
  CashGameRackResult({
    required this.rackNumber,
    required List<int> balls,
    required List<int> money,
  }) : balls = List.unmodifiable(balls),
       money = List.unmodifiable(money);

  final int rackNumber;
  final List<int> balls;
  final List<int> money;
}

/// Snapshot cho undo — chỉ giữ phần thay đổi được.
class CashGameSnapshot {
  CashGameSnapshot({
    required List<int> rackWins,
    required List<int> balls,
    required List<CashGameRackResult> rackResults,
    required List<int> settledOffsets,
    required this.status,
  }) : rackWins = List.unmodifiable(rackWins),
       balls = List.unmodifiable(balls),
       rackResults = List.unmodifiable(rackResults),
       settledOffsets = List.unmodifiable(settledOffsets);

  final List<int> rackWins;
  final List<int> balls;
  final List<CashGameRackResult> rackResults;
  final List<int> settledOffsets;
  final CashGameStatus status;
}

class CashGameState {
  CashGameState({
    List<String> playerNames = const [],
    List<int> rackWins = const [],
    List<int> balls = const [],
    List<CashGameRackResult> rackResults = const [],
    List<int> settledOffsets = const [],
    this.moneyPerRack = 40000,
    this.moneyPerBall = 20000,
    this.status = CashGameStatus.setup,
    List<CashGameSnapshot> history = const [],
    this.startedAt,
  }) : playerNames = List.unmodifiable(playerNames),
       rackWins = List.unmodifiable(
         rackWins.isEmpty && playerNames.isNotEmpty
             ? List.filled(playerNames.length, 0)
             : rackWins,
       ),
       balls = List.unmodifiable(
         balls.isEmpty && playerNames.isNotEmpty
             ? List.filled(playerNames.length, 0)
             : balls,
       ),
       rackResults = List.unmodifiable(rackResults),
       settledOffsets = List.unmodifiable(
         settledOffsets.isEmpty && playerNames.isNotEmpty
             ? List.filled(playerNames.length, 0)
             : settledOffsets,
       ),
       history = List.unmodifiable(history);

  factory CashGameState.initial() => CashGameState();

  factory CashGameState.fromSnapshot(
    CashGameSnapshot snapshot, {
    required List<String> playerNames,
    required int moneyPerRack,
    required int moneyPerBall,
    DateTime? startedAt,
    List<CashGameSnapshot> history = const [],
  }) {
    return CashGameState(
      playerNames: playerNames,
      rackWins: snapshot.rackWins,
      balls: snapshot.balls,
      rackResults: snapshot.rackResults,
      settledOffsets: snapshot.settledOffsets,
      moneyPerRack: moneyPerRack,
      moneyPerBall: moneyPerBall,
      status: snapshot.status,
      startedAt: startedAt,
      history: history,
    );
  }

  final List<String> playerNames;

  /// [rackWins] là tổng ván thắng toàn trận. [balls] là lỗ 10 của ván đang
  /// nhập; khi bấm "Chốt ván", chỉ [balls] reset về 0.
  final List<int> rackWins;
  final List<int> balls;
  final List<CashGameRackResult> rackResults;
  final List<int> settledOffsets;
  final int moneyPerRack;
  final int moneyPerBall;
  final CashGameStatus status;
  final List<CashGameSnapshot> history;
  final DateTime? startedAt;

  bool get canUndo => history.isNotEmpty;
  bool get currentRackHasScore => balls.any((v) => v > 0);
  int get settledRackCount => rackResults.length;
  int get currentRackNumber => settledRackCount + 1;
  int get settlementAmount {
    if (playerNames.length < 2) return 0;
    final m0 = moneyOf(0);
    final m1 = moneyOf(1);
    return m0 < m1 ? m0 : m1;
  }

  bool get canSettleBalance => settlementAmount > 0;
  bool get canSettleRack => currentRackHasScore || canSettleBalance;

  /// Tiền lỗ 10 đang nhập của ván hiện tại.
  int currentMoneyOf(int index) {
    if (index < 0 || index >= playerNames.length) return 0;
    return balls[index] * moneyPerBall;
  }

  int settledMoneyOf(int index) {
    if (index < 0 || index >= playerNames.length) return 0;
    return rackResults.fold<int>(
      0,
      (sum, rack) => index < rack.money.length ? sum + rack.money[index] : sum,
    );
  }

  int totalRackWinsOf(int index) {
    if (index < 0 || index >= playerNames.length) return 0;
    return rackWins[index];
  }

  int totalBallsOf(int index) {
    if (index < 0 || index >= playerNames.length) return 0;
    return rackResults.fold<int>(
          0,
          (sum, rack) =>
              index < rack.balls.length ? sum + rack.balls[index] : sum,
        ) +
        balls[index];
  }

  int grossMoneyOf(int index) {
    if (index < 0 || index >= playerNames.length) return 0;
    return rackWins[index] * moneyPerRack +
        settledMoneyOf(index) +
        currentMoneyOf(index);
  }

  /// Tổng tiền của 1 người (index).
  int moneyOf(int index) {
    if (index < 0 || index >= playerNames.length) return 0;
    final offset = index < settledOffsets.length ? settledOffsets[index] : 0;
    final money = grossMoneyOf(index) - offset;
    return money < 0 ? 0 : money;
  }

  int moneyAfterSettleOf(int index) {
    if (index < 0 || index >= playerNames.length) return 0;
    final money = moneyOf(index) - settlementAmount;
    return money < 0 ? 0 : money;
  }

  /// Index người có tiền cao hơn; null nếu hoà tiền.
  int? get leaderIndex {
    if (playerNames.length < 2) return null;
    final m0 = moneyOf(0);
    final m1 = moneyOf(1);
    if (m0 == m1) return null;
    return m0 > m1 ? 0 : 1;
  }

  /// Chênh lệch tiền (luôn ≥ 0) — số tiền người thua phải trả người thắng.
  int get moneyDifference {
    if (playerNames.length < 2) return 0;
    return (moneyOf(0) - moneyOf(1)).abs();
  }

  CashGameSnapshot toSnapshot() {
    return CashGameSnapshot(
      rackWins: rackWins,
      balls: balls,
      rackResults: rackResults,
      settledOffsets: settledOffsets,
      status: status,
    );
  }

  CashGameState copyWith({
    List<String>? playerNames,
    List<int>? rackWins,
    List<int>? balls,
    List<CashGameRackResult>? rackResults,
    List<int>? settledOffsets,
    int? moneyPerRack,
    int? moneyPerBall,
    CashGameStatus? status,
    List<CashGameSnapshot>? history,
    DateTime? startedAt,
  }) {
    return CashGameState(
      playerNames: playerNames ?? this.playerNames,
      rackWins: rackWins ?? this.rackWins,
      balls: balls ?? this.balls,
      rackResults: rackResults ?? this.rackResults,
      settledOffsets: settledOffsets ?? this.settledOffsets,
      moneyPerRack: moneyPerRack ?? this.moneyPerRack,
      moneyPerBall: moneyPerBall ?? this.moneyPerBall,
      status: status ?? this.status,
      history: history ?? this.history,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

/// Format tiền VND có dấu chấm phân nhóm nghìn: 360000 → "360.000".
String formatVnd(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buf';
}
