enum MatchStage { roundRobin, group, knockout }

/// Nhánh bracket trong chế độ đấu nhánh kép (double elimination).
/// - [winners]: nhánh thắng.
/// - [losers]: nhánh thua.
/// - [grandFinal]: Trận chung kết tổng (WB winner vs LB winner).
/// - [none]: Fixture không thuộc bracket nào (vd vòng tròn, vòng bảng).
enum BracketSide { none, winners, losers, grandFinal }

/// 1 cặp trận trong lịch thi đấu của giải.
///
/// [isPlayed] = đã nhập tỷ số chưa (set true khi user bấm "Lưu" ở dialog
/// nhập tỷ số; có thể 0-0 nếu match thực sự kết thúc 0-0).
///
/// **Source linkage (double-elim)**: khi 1 slot player chưa biết tại thời
/// điểm sinh bracket (vd "player1 của trận này = winner trận X"), engine
/// để player1Id rỗng và set `sourceWinnerOfP1Id = X`. Khi trận X kết thúc,
/// engine fill player1Id từ winner. Tương tự cho loser slot.
class MatchFixture {
  const MatchFixture({
    required this.id,
    required this.player1Id,
    required this.player2Id,
    this.score1 = 0,
    this.score2 = 0,
    this.isPlayed = false,
    this.stage = MatchStage.roundRobin,
    this.groupId,
    this.roundIndex = 0,
    this.roundName = '',
    this.bracketSide = BracketSide.none,
    this.sourceWinnerOfP1Id,
    this.sourceLoserOfP1Id,
    this.sourceWinnerOfP2Id,
    this.sourceLoserOfP2Id,
  });

  final String id;
  final String player1Id;
  final String player2Id;
  final int score1;
  final int score2;
  final bool isPlayed;
  final MatchStage stage;
  final String? groupId;
  final int roundIndex;
  final String roundName;
  final BracketSide bracketSide;
  final String? sourceWinnerOfP1Id;
  final String? sourceLoserOfP1Id;
  final String? sourceWinnerOfP2Id;
  final String? sourceLoserOfP2Id;

  /// True khi cả 2 slot player đã có ID thật (không phải placeholder).
  bool get isReady => player1Id.isNotEmpty && player2Id.isNotEmpty;

  MatchFixture copyWith({
    String? id,
    String? player1Id,
    String? player2Id,
    int? score1,
    int? score2,
    bool? isPlayed,
    MatchStage? stage,
    String? groupId,
    int? roundIndex,
    String? roundName,
    BracketSide? bracketSide,
    String? sourceWinnerOfP1Id,
    String? sourceLoserOfP1Id,
    String? sourceWinnerOfP2Id,
    String? sourceLoserOfP2Id,
  }) {
    return MatchFixture(
      id: id ?? this.id,
      player1Id: player1Id ?? this.player1Id,
      player2Id: player2Id ?? this.player2Id,
      score1: score1 ?? this.score1,
      score2: score2 ?? this.score2,
      isPlayed: isPlayed ?? this.isPlayed,
      stage: stage ?? this.stage,
      groupId: groupId ?? this.groupId,
      roundIndex: roundIndex ?? this.roundIndex,
      roundName: roundName ?? this.roundName,
      bracketSide: bracketSide ?? this.bracketSide,
      sourceWinnerOfP1Id: sourceWinnerOfP1Id ?? this.sourceWinnerOfP1Id,
      sourceLoserOfP1Id: sourceLoserOfP1Id ?? this.sourceLoserOfP1Id,
      sourceWinnerOfP2Id: sourceWinnerOfP2Id ?? this.sourceWinnerOfP2Id,
      sourceLoserOfP2Id: sourceLoserOfP2Id ?? this.sourceLoserOfP2Id,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'player1Id': player1Id,
    'player2Id': player2Id,
    'score1': score1,
    'score2': score2,
    'isPlayed': isPlayed,
    'stage': stage.name,
    'groupId': groupId,
    'roundIndex': roundIndex,
    'roundName': roundName,
    'bracketSide': bracketSide.name,
    'sourceWinnerOfP1Id': sourceWinnerOfP1Id,
    'sourceLoserOfP1Id': sourceLoserOfP1Id,
    'sourceWinnerOfP2Id': sourceWinnerOfP2Id,
    'sourceLoserOfP2Id': sourceLoserOfP2Id,
  };

  factory MatchFixture.fromJson(Map<String, dynamic> json) => MatchFixture(
    id: json['id'] as String,
    player1Id: json['player1Id'] as String,
    player2Id: json['player2Id'] as String,
    score1: json['score1'] as int? ?? 0,
    score2: json['score2'] as int? ?? 0,
    isPlayed: json['isPlayed'] as bool? ?? false,
    stage: _parseStage(json['stage']),
    groupId: json['groupId'] as String?,
    roundIndex: json['roundIndex'] as int? ?? 0,
    roundName: json['roundName'] as String? ?? '',
    bracketSide: _parseBracket(json['bracketSide']),
    sourceWinnerOfP1Id: json['sourceWinnerOfP1Id'] as String?,
    sourceLoserOfP1Id: json['sourceLoserOfP1Id'] as String?,
    sourceWinnerOfP2Id: json['sourceWinnerOfP2Id'] as String?,
    sourceLoserOfP2Id: json['sourceLoserOfP2Id'] as String?,
  );

  static MatchStage _parseStage(Object? raw) {
    if (raw == null) return MatchStage.roundRobin;
    final name = raw as String;
    return MatchStage.values.firstWhere(
      (s) => s.name == name,
      orElse: () => throw FormatException(
        'MatchFixture.fromJson: unknown stage "$name".',
      ),
    );
  }

  static BracketSide _parseBracket(Object? raw) {
    if (raw == null) return BracketSide.none;
    final name = raw as String;
    return BracketSide.values.firstWhere(
      (s) => s.name == name,
      orElse: () => BracketSide.none,
    );
  }
}
