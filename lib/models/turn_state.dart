import 'ball_config.dart';

class TurnState {
  TurnState({
    this.shooterIndex,
    List<BallConfig> pocketedBalls = const [],
    this.chamMode = false,
  }) : pocketedBalls = List.unmodifiable(pocketedBalls);

  final int? shooterIndex;
  final List<BallConfig> pocketedBalls;

  /// True khi bật "Chấm sành điệu ×2" — điểm mỗi bi nhân đôi.
  final bool chamMode;

  bool get hasPocketedBalls => pocketedBalls.isNotEmpty;

  int get totalPoints =>
      pocketedBalls.fold(0, (sum, ball) => sum + ball.points);

  /// Hệ số nhân cho lượt (chấm = 2, thường = 1).
  int get multiplier => chamMode ? 2 : 1;

  TurnState copyWith({
    int? Function()? shooterIndex,
    List<BallConfig>? pocketedBalls,
    bool? chamMode,
  }) {
    return TurnState(
      shooterIndex:
          shooterIndex != null ? shooterIndex() : this.shooterIndex,
      pocketedBalls: pocketedBalls ?? this.pocketedBalls,
      chamMode: chamMode ?? this.chamMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'shooterIndex': shooterIndex,
    'pocketedBalls': pocketedBalls.map((b) => b.toJson()).toList(),
    'chamMode': chamMode,
  };

  factory TurnState.fromJson(Map<String, dynamic> json) => TurnState(
    shooterIndex: json['shooterIndex'] as int?,
    pocketedBalls: (json['pocketedBalls'] as List<dynamic>? ?? const [])
        .map((e) => BallConfig.fromJson(e as Map<String, dynamic>))
        .toList(),
    chamMode: json['chamMode'] as bool? ?? false,
  );
}
