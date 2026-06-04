import 'ball_config.dart';

/// Snapshot setup gần nhất user đã bấm "Bắt đầu" — dùng để auto-fill
/// Setup screen ở lần mở sau (kể cả sau khi kill app).
///
/// [variantLabel] = biến thể Pool đã chọn ("8-Ball" / "9-Ball" / "10-Ball" /
/// tên tuỳ ý). Null cho setup cũ trước migration hoặc cho Bắn đền (không dùng).
class LastSetup {
  const LastSetup({
    required this.playerNames,
    required this.ballConfigs,
    this.variantLabel,
  });

  final List<String> playerNames;
  final List<BallConfig> ballConfigs;
  final String? variantLabel;

  Map<String, dynamic> toJson() => {
    'playerNames': playerNames,
    'ballConfigs': ballConfigs.map((b) => b.toJson()).toList(),
    if (variantLabel != null) 'variantLabel': variantLabel,
  };

  factory LastSetup.fromJson(Map<String, dynamic> json) => LastSetup(
    playerNames: (json['playerNames'] as List<dynamic>).cast<String>(),
    ballConfigs: (json['ballConfigs'] as List<dynamic>)
        .map((e) => BallConfig.fromJson(e as Map<String, dynamic>))
        .toList(),
    variantLabel: json['variantLabel'] as String?,
  );
}
