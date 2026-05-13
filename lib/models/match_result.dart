import 'score_event.dart';

/// Kết quả cuối cùng của 1 trận đấu — lưu vào lịch sử khi user bấm
/// "Kết thúc trận" (hoặc trận race-to-X tự kết thúc khi đạt race target).
///
/// Tuỳ mode, 1 trong 2 list chi tiết được điền (cái còn lại rỗng):
/// - [events]: Bắn đền — toàn bộ lượt ghi điểm (per-ván / per-lượt).
/// - [rackWinners]: race-to-X (9/8/10-Ball) — tên người thắng từng rack
///   theo thứ tự → MatchDetailScreen hiện play-by-play.
/// Cả hai rỗng = trận cũ lưu trước khi thêm field.
class MatchResult {
  const MatchResult({
    required this.finishedAt,
    required this.modeLabel,
    required this.roundsPlayed,
    required this.players,
    this.events = const [],
    this.rackWinners = const [],
  });

  final DateTime finishedAt;
  final String modeLabel;
  final int roundsPlayed;
  final List<MatchPlayerResult> players;
  final List<ScoreEvent> events;
  final List<String> rackWinners;

  Map<String, dynamic> toJson() => {
    'finishedAt': finishedAt.toIso8601String(),
    'modeLabel': modeLabel,
    'roundsPlayed': roundsPlayed,
    'players': players.map((p) => p.toJson()).toList(),
    'events': events.map((e) => e.toJson()).toList(),
    'rackWinners': rackWinners,
  };

  factory MatchResult.fromJson(Map<String, dynamic> json) => MatchResult(
    finishedAt: DateTime.parse(json['finishedAt'] as String),
    modeLabel: json['modeLabel'] as String,
    roundsPlayed: json['roundsPlayed'] as int,
    players: (json['players'] as List<dynamic>)
        .map((e) => MatchPlayerResult.fromJson(e as Map<String, dynamic>))
        .toList(),
    events: (json['events'] as List<dynamic>? ?? const [])
        .map((e) => ScoreEvent.fromJson(e as Map<String, dynamic>))
        .toList(),
    rackWinners:
        (json['rackWinners'] as List<dynamic>? ?? const []).cast<String>(),
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
