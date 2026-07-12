import 'player.dart';

enum NineBallStatus { setup, inProgress, finished }

/// 1 dòng log thao tác trong trận Pool — ai được cộng/trừ ván, lúc nào, tỷ số
/// sau đó. Mục đích: minh bạch khi sửa nhầm (vd bấm nhầm bên thắng → −1 bên đó
/// rồi +1 bên kia) để khỏi cãi nhau.
class NineBallLogEntry {
  NineBallLogEntry({
    required this.at,
    required this.playerName,
    required this.delta,
    required List<int> winsAfter,
  }) : winsAfter = List.unmodifiable(winsAfter);

  /// Thời điểm thao tác.
  final DateTime at;

  /// Tên người chơi bị tác động.
  final String playerName;

  /// +1 = thắng 1 ván; −1 = sửa giảm 1 ván.
  final int delta;

  /// Tỷ số 2 bên ngay sau thao tác (chạy theo trận).
  final List<int> winsAfter;

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'playerName': playerName,
    'delta': delta,
    'winsAfter': winsAfter,
  };

  factory NineBallLogEntry.fromJson(Map<String, dynamic> json) =>
      NineBallLogEntry(
        at: DateTime.parse(json['at'] as String),
        playerName: json['playerName'] as String,
        delta: json['delta'] as int,
        winsAfter: (json['winsAfter'] as List<dynamic>).cast<int>(),
      );
}

class NineBallSnapshot {
  NineBallSnapshot({
    required List<Player> players,
    required List<int> rackWins,
    required this.raceTarget,
    required this.breakerIndex,
    required this.currentRack,
    required this.status,
    List<String> rackWinnerNames = const [],
    this.variantLabel,
    this.shotClockSeconds = 0,
    this.id = '',
    this.startedAt,
    List<NineBallLogEntry> log = const [],
  }) : players = List.unmodifiable(players),
       rackWins = List.unmodifiable(rackWins),
       rackWinnerNames = List.unmodifiable(rackWinnerNames),
       log = List.unmodifiable(log);

  final List<Player> players;
  final List<int> rackWins;
  final int raceTarget;
  final int breakerIndex;
  final int currentRack;
  final NineBallStatus status;

  /// Log thao tác +1/−1 theo thời gian (xem [NineBallLogEntry]).
  final List<NineBallLogEntry> log;

  /// Id trận (sinh ở engine lúc startGame) — giữ trong snapshot để undo không
  /// làm lạc id (kéo theo mất liên kết với active list).
  final String id;

  /// Thời điểm bắt đầu trận — hiển thị ở list các trận đang chơi.
  final DateTime? startedAt;

  /// Tên người thắng từng rack theo thứ tự (rack 1 = phần tử 0, ...). Snapshot
  /// giữ luôn để undo khôi phục đúng.
  final List<String> rackWinnerNames;

  /// Biến thể Pool ("8-Ball"/"9-Ball"/"10-Ball"/tuỳ ý) — set lúc startGame,
  /// không đổi trong trận. Snapshot giữ để undo không lạc.
  final String? variantLabel;

  /// Đồng hồ giây mỗi cú (shot clock). 0 = tắt.
  final int shotClockSeconds;
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
    this.variantLabel,
    this.shotClockSeconds = 0,
    this.id = '',
    this.startedAt,
    List<NineBallLogEntry> log = const [],
  }) : players = List.unmodifiable(players),
       rackWins = List.unmodifiable(
         rackWins.isEmpty && players.isNotEmpty
             ? List.filled(players.length, 0)
             : rackWins,
       ),
       history = List.unmodifiable(history),
       rackWinnerNames = List.unmodifiable(rackWinnerNames),
       log = List.unmodifiable(log);

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
      variantLabel: snapshot.variantLabel,
      shotClockSeconds: snapshot.shotClockSeconds,
      id: snapshot.id,
      startedAt: snapshot.startedAt,
      log: snapshot.log,
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

  /// Biến thể Pool đã chọn ở Setup ("8-Ball"/"9-Ball"/"10-Ball"/tuỳ ý) — set
  /// lúc startGame, không đổi trong trận. Dùng làm `modeLabel` khi ghi MatchResult.
  final String? variantLabel;

  /// Đồng hồ giây mỗi cú (shot clock). 0 = tắt. Set lúc startGame.
  final int shotClockSeconds;

  /// Id trận — sinh ở engine lúc startGame. '' nghĩa là chưa start (initial).
  /// Dùng làm identity trong active list + session (mirror League).
  final String id;

  /// Thời điểm bắt đầu trận — hiển thị "Bắt đầu dd/mm hh:mm" ở list.
  final DateTime? startedAt;

  /// Log thao tác +1/−1 theo thời gian (xem [NineBallLogEntry]). Giữ trong
  /// snapshot + persist để undo / kill app vẫn còn lịch sử minh bạch.
  final List<NineBallLogEntry> log;

  bool get canUndo => history.isNotEmpty;

  /// Nhãn hiển thị ở list/lịch sử: tên 2 người + biến thể.
  String get displayName {
    if (players.length < 2) return variantLabel ?? 'Pool';
    return '${players[0].name} vs ${players[1].name}';
  }

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
      variantLabel: variantLabel,
      shotClockSeconds: shotClockSeconds,
      id: id,
      startedAt: startedAt,
      log: log,
    );
  }

  /// JSON cho persistence (khôi phục trận đang chơi sau khi kill app).
  /// **Không** lưu `history` (undo stack) — sau restart không cần undo về
  /// thao tác trước khi tắt.
  Map<String, dynamic> toJson() => {
    'players': players.map((p) => p.toJson()).toList(),
    'rackWins': rackWins,
    'raceTarget': raceTarget,
    'breakerIndex': breakerIndex,
    'currentRack': currentRack,
    'status': status.name,
    'rackWinnerNames': rackWinnerNames,
    if (variantLabel != null) 'variantLabel': variantLabel,
    'shotClockSeconds': shotClockSeconds,
    'id': id,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    'log': log.map((e) => e.toJson()).toList(),
  };

  factory NineBallState.fromJson(Map<String, dynamic> json) => NineBallState(
    players: (json['players'] as List<dynamic>)
        .map((e) => Player.fromJson(e as Map<String, dynamic>))
        .toList(),
    rackWins: (json['rackWins'] as List<dynamic>).cast<int>(),
    raceTarget: json['raceTarget'] as int,
    breakerIndex: json['breakerIndex'] as int,
    currentRack: json['currentRack'] as int,
    status: NineBallStatus.values.byName(json['status'] as String),
    rackWinnerNames:
        (json['rackWinnerNames'] as List<dynamic>?)?.cast<String>() ??
        const [],
    variantLabel: json['variantLabel'] as String?,
    shotClockSeconds: json['shotClockSeconds'] as int? ?? 0,
    id: json['id'] as String? ?? '',
    startedAt: json['startedAt'] != null
        ? DateTime.tryParse(json['startedAt'] as String)
        : null,
    log:
        (json['log'] as List<dynamic>?)
            ?.map((e) => NineBallLogEntry.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );

  NineBallState copyWith({
    List<Player>? players,
    List<int>? rackWins,
    int? raceTarget,
    int? breakerIndex,
    int? currentRack,
    NineBallStatus? status,
    List<NineBallSnapshot>? history,
    List<String>? rackWinnerNames,
    String? variantLabel,
    int? shotClockSeconds,
    String? id,
    DateTime? startedAt,
    List<NineBallLogEntry>? log,
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
      variantLabel: variantLabel ?? this.variantLabel,
      shotClockSeconds: shotClockSeconds ?? this.shotClockSeconds,
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      log: log ?? this.log,
    );
  }
}
