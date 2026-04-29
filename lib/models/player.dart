class Player {
  const Player({
    required this.id,
    required this.name,
    required this.score,
    this.avatar = _defaultAvatar,
  });

  static const _defaultAvatar = '🐾';

  final String id;
  final String name;
  final int score;

  /// Emoji con vật đại diện, gán ngẫu nhiên khi startGame.
  final String avatar;

  Player copyWith({String? id, String? name, int? score, String? avatar}) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      score: score ?? this.score,
      avatar: avatar ?? this.avatar,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'score': score,
    'avatar': avatar,
  };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    id: json['id'] as String,
    name: json['name'] as String,
    score: json['score'] as int,
    avatar: json['avatar'] as String? ?? _defaultAvatar,
  );
}
