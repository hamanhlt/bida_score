import 'nine_ball_state.dart';
import 'score_event.dart';

/// Kết quả cuối cùng của 1 trận đấu — lưu vào lịch sử khi user bấm
/// "Kết thúc trận" (hoặc trận race-to-X tự kết thúc khi đạt race target).
///
/// Tuỳ mode, 1 trong 2 list chi tiết được điền (cái còn lại rỗng):
/// - [events]: Bắn đền — toàn bộ lượt ghi điểm (per-ván / per-lượt).
/// - [rackWinners]: race-to-X (9/8/10-Ball) — tên người thắng từng rack
///   theo thứ tự → MatchDetailScreen hiện play-by-play.
/// Cả hai rỗng = trận cũ lưu trước khi thêm field.
///
/// [poolLog]: race-to-X — log thao tác +1/−1 kèm thời gian (xem
/// [NineBallLogEntry]). Có từ phiên sau khi thêm log; trận Pool cũ rỗng → màn
/// chi tiết fallback về [rackWinners].
class MatchResult {
  const MatchResult({
    required this.finishedAt,
    required this.modeLabel,
    required this.roundsPlayed,
    required this.players,
    this.events = const [],
    this.rackWinners = const [],
    this.poolLog = const [],
  });

  final DateTime finishedAt;
  final String modeLabel;
  final int roundsPlayed;
  final List<MatchPlayerResult> players;
  final List<ScoreEvent> events;
  final List<String> rackWinners;
  final List<NineBallLogEntry> poolLog;

  Map<String, dynamic> toJson() => {
    'finishedAt': finishedAt.toIso8601String(),
    'modeLabel': modeLabel,
    'roundsPlayed': roundsPlayed,
    'players': players.map((p) => p.toJson()).toList(),
    'events': events.map((e) => e.toJson()).toList(),
    'rackWinners': rackWinners,
    'poolLog': poolLog.map((e) => e.toJson()).toList(),
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
    poolLog: (json['poolLog'] as List<dynamic>? ?? const [])
        .map((e) => NineBallLogEntry.fromJson(e as Map<String, dynamic>))
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
