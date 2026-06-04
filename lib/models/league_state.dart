import 'league_player.dart';
import 'match_fixture.dart';

enum LeagueStatus { setup, inProgress, finished }

/// State của giải đấu vòng tròn — immutable, copyWith.
///
/// In-memory trong suốt quá trình đang chơi ([LeagueStatus.inProgress]).
/// Khi user bấm "Kết thúc giải" → status chuyển `finished` + persist vào
/// LeagueHistory (qua `LeagueHistoryStorage`).
///
/// [players] luôn sort theo thứ hạng (Points DESC → GoalDifference DESC →
/// GoalsFor DESC) sau mỗi lần recalculate — UI render trực tiếp.
class LeagueState {
  LeagueState({
    this.status = LeagueStatus.setup,
    List<LeaguePlayer> players = const [],
    List<MatchFixture> fixtures = const [],
    this.startedAt,
    this.finishedAt,
  }) : players = List.unmodifiable(players),
       fixtures = List.unmodifiable(fixtures);

  factory LeagueState.initial() => LeagueState();

  final LeagueStatus status;
  final List<LeaguePlayer> players;
  final List<MatchFixture> fixtures;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  bool get isFinished => status == LeagueStatus.finished;

  int get matchesTotal => fixtures.length;
  int get matchesPlayed => fixtures.where((f) => f.isPlayed).length;

  LeagueState copyWith({
    LeagueStatus? status,
    List<LeaguePlayer>? players,
    List<MatchFixture>? fixtures,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    return LeagueState(
      status: status ?? this.status,
      players: players ?? this.players,
      fixtures: fixtures ?? this.fixtures,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'players': players.map((p) => p.toJson()).toList(),
    'fixtures': fixtures.map((f) => f.toJson()).toList(),
    'startedAt': startedAt?.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
  };

  factory LeagueState.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String?;
    // Missing field (legacy/empty save) → default setup.
    // Field present nhưng giá trị lạ → throw, KHÔNG silently coerce
    // (tránh user mất dữ liệu in-progress khi tương lai rename enum).
    final LeagueStatus status;
    if (statusName == null) {
      status = LeagueStatus.setup;
    } else {
      status = LeagueStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => throw FormatException(
          'LeagueState.fromJson: unknown status "$statusName".',
        ),
      );
    }
    return LeagueState(
      status: status,
      players: (json['players'] as List<dynamic>? ?? const [])
          .map((e) => LeaguePlayer.fromJson(e as Map<String, dynamic>))
          .toList(),
      fixtures: (json['fixtures'] as List<dynamic>? ?? const [])
          .map((e) => MatchFixture.fromJson(e as Map<String, dynamic>))
          .toList(),
      startedAt: _parseDate(json['startedAt']),
      finishedAt: _parseDate(json['finishedAt']),
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw);
  }
}
