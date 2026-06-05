enum MatchStage { roundRobin, group, knockout }

/// 1 cặp trận trong lịch thi đấu của giải.
///
/// [isPlayed] = đã nhập tỷ số chưa (set true khi user bấm "Lưu" ở dialog
/// nhập tỷ số; có thể 0-0 nếu match thực sự kết thúc 0-0).
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
}
