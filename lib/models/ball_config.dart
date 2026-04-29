class BallConfig {
  const BallConfig({required this.number, required this.points});

  final int number;
  final int points;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BallConfig &&
          other.number == number &&
          other.points == points;

  @override
  int get hashCode => Object.hash(number, points);

  Map<String, dynamic> toJson() => {'number': number, 'points': points};

  factory BallConfig.fromJson(Map<String, dynamic> json) => BallConfig(
    number: json['number'] as int,
    points: json['points'] as int,
  );

  static const List<BallConfig> defaultPreset = [
    BallConfig(number: 3, points: 1),
    BallConfig(number: 6, points: 2),
    BallConfig(number: 9, points: 3),
  ];
}
