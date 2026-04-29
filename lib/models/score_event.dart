import 'ball_config.dart';

/// Bản ghi 1 lượt ghi điểm đã áp dụng — dùng cho lịch sử/tra cứu.
class ScoreEvent {
  ScoreEvent({
    required this.at,
    required this.roundNumber,
    required this.shooterId,
    required this.shooterName,
    required List<BallConfig> balls,
    required List<String> victimIds,
    required List<String> victimNames,
    required this.multiplier,
    required this.pointsPerVictim,
  }) : balls = List.unmodifiable(balls),
       victimIds = List.unmodifiable(victimIds),
       victimNames = List.unmodifiable(victimNames);

  final DateTime at;
  final int roundNumber;
  final String shooterId;
  final String shooterName;
  final List<BallConfig> balls;
  final int multiplier;
  final List<String> victimIds;
  final List<String> victimNames;

  /// Số điểm mỗi victim bị trừ = tổng_bi × multiplier.
  final int pointsPerVictim;

  /// Tổng shooter được cộng = pointsPerVictim × số_victim.
  int get shooterGain => pointsPerVictim * victimIds.length;

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'roundNumber': roundNumber,
    'shooterId': shooterId,
    'shooterName': shooterName,
    'balls': balls.map((b) => b.toJson()).toList(),
    'multiplier': multiplier,
    'victimIds': victimIds,
    'victimNames': victimNames,
    'pointsPerVictim': pointsPerVictim,
  };

  factory ScoreEvent.fromJson(Map<String, dynamic> json) => ScoreEvent(
    at: DateTime.parse(json['at'] as String),
    roundNumber: json['roundNumber'] as int,
    shooterId: json['shooterId'] as String,
    shooterName: json['shooterName'] as String,
    balls: (json['balls'] as List<dynamic>)
        .map((e) => BallConfig.fromJson(e as Map<String, dynamic>))
        .toList(),
    multiplier: json['multiplier'] as int,
    victimIds: (json['victimIds'] as List<dynamic>).cast<String>(),
    victimNames: (json['victimNames'] as List<dynamic>).cast<String>(),
    pointsPerVictim: json['pointsPerVictim'] as int,
  );
}
