/// 1 cặp trận trong lịch thi đấu vòng tròn của giải.
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
  });

  final String id;
  final String player1Id;
  final String player2Id;
  final int score1;
  final int score2;
  final bool isPlayed;

  MatchFixture copyWith({
    String? id,
    String? player1Id,
    String? player2Id,
    int? score1,
    int? score2,
    bool? isPlayed,
  }) {
    return MatchFixture(
      id: id ?? this.id,
      player1Id: player1Id ?? this.player1Id,
      player2Id: player2Id ?? this.player2Id,
      score1: score1 ?? this.score1,
      score2: score2 ?? this.score2,
      isPlayed: isPlayed ?? this.isPlayed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'player1Id': player1Id,
    'player2Id': player2Id,
    'score1': score1,
    'score2': score2,
    'isPlayed': isPlayed,
  };

  factory MatchFixture.fromJson(Map<String, dynamic> json) => MatchFixture(
    id: json['id'] as String,
    player1Id: json['player1Id'] as String,
    player2Id: json['player2Id'] as String,
    score1: json['score1'] as int? ?? 0,
    score2: json['score2'] as int? ?? 0,
    isPlayed: json['isPlayed'] as bool? ?? false,
  );
}
