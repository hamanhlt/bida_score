/// Kết quả cuối cùng của 1 trận đấu — lưu vào lịch sử khi user bấm
/// "Kết thúc trận".
class MatchResult {
  const MatchResult({
    required this.finishedAt,
    required this.modeLabel,
    required this.roundsPlayed,
    required this.players,
  });

  final DateTime finishedAt;
  final String modeLabel;
  final int roundsPlayed;
  final List<MatchPlayerResult> players;

  Map<String, dynamic> toJson() => {
    'finishedAt': finishedAt.toIso8601String(),
    'modeLabel': modeLabel,
    'roundsPlayed': roundsPlayed,
    'players': players.map((p) => p.toJson()).toList(),
  };

  factory MatchResult.fromJson(Map<String, dynamic> json) => MatchResult(
    finishedAt: DateTime.parse(json['finishedAt'] as String),
    modeLabel: json['modeLabel'] as String,
    roundsPlayed: json['roundsPlayed'] as int,
    players: (json['players'] as List<dynamic>)
        .map((e) => MatchPlayerResult.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class MatchPlayerResult {
  const MatchPlayerResult({required this.name, required this.score});

  final String name;
  final int score;

  Map<String, dynamic> toJson() => {'name': name, 'score': score};

  factory MatchPlayerResult.fromJson(Map<String, dynamic> json) =>
      MatchPlayerResult(
        name: json['name'] as String,
        score: json['score'] as int,
      );
}
