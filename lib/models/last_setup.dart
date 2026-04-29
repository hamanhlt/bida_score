import 'ball_config.dart';

/// Snapshot setup gần nhất user đã bấm "Bắt đầu" — dùng để auto-fill
/// Setup screen ở lần mở sau (kể cả sau khi kill app).
class LastSetup {
  const LastSetup({required this.playerNames, required this.ballConfigs});

  final List<String> playerNames;
  final List<BallConfig> ballConfigs;

  Map<String, dynamic> toJson() => {
    'playerNames': playerNames,
    'ballConfigs': ballConfigs.map((b) => b.toJson()).toList(),
  };

  factory LastSetup.fromJson(Map<String, dynamic> json) => LastSetup(
    playerNames: (json['playerNames'] as List<dynamic>).cast<String>(),
    ballConfigs: (json['ballConfigs'] as List<dynamic>)
        .map((e) => BallConfig.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
