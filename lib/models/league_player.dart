/// 1 người chơi trong giải đấu vòng tròn (Chế độ giải đấu).
///
/// Khác `Player` của Bắn đền (id, name, score, avatar) — `LeaguePlayer` lưu
/// stats theo thể thức league: số điểm trận (Thắng = +1), số trận đã đấu,
/// tổng điểm ghi được / bị thủng. [goalDifference] derive — không lưu.
class LeaguePlayer {
  const LeaguePlayer({
    required this.id,
    required this.name,
    this.points = 0,
    this.matchesPlayed = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
  });

  final String id;
  final String name;
  final int points;
  final int matchesPlayed;
  final int goalsFor;
  final int goalsAgainst;

  int get goalDifference => goalsFor - goalsAgainst;

  LeaguePlayer copyWith({
    String? id,
    String? name,
    int? points,
    int? matchesPlayed,
    int? goalsFor,
    int? goalsAgainst,
  }) {
    return LeaguePlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      points: points ?? this.points,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      goalsFor: goalsFor ?? this.goalsFor,
      goalsAgainst: goalsAgainst ?? this.goalsAgainst,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'points': points,
    'matchesPlayed': matchesPlayed,
    'goalsFor': goalsFor,
    'goalsAgainst': goalsAgainst,
  };

  factory LeaguePlayer.fromJson(Map<String, dynamic> json) => LeaguePlayer(
    id: json['id'] as String,
    name: json['name'] as String,
    points: json['points'] as int? ?? 0,
    matchesPlayed: json['matchesPlayed'] as int? ?? 0,
    goalsFor: json['goalsFor'] as int? ?? 0,
    goalsAgainst: json['goalsAgainst'] as int? ?? 0,
  );
}
