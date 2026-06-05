/// Một bảng trong giải đấu chia bảng.
///
/// [playerIds] giữ membership theo thứ tự chia bảng ban đầu. Stats/xếp hạng
/// vẫn nằm ở [LeaguePlayer] và được engine tính lại từ fixtures vòng bảng.
class LeagueGroup {
  LeagueGroup({
    required this.id,
    required this.name,
    List<String> playerIds = const [],
  }) : playerIds = List.unmodifiable(playerIds);

  final String id;
  final String name;
  final List<String> playerIds;

  LeagueGroup copyWith({String? id, String? name, List<String>? playerIds}) {
    return LeagueGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      playerIds: playerIds ?? this.playerIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'playerIds': playerIds,
  };

  factory LeagueGroup.fromJson(Map<String, dynamic> json) => LeagueGroup(
    id: json['id'] as String,
    name: json['name'] as String,
    playerIds: (json['playerIds'] as List<dynamic>? ?? const [])
        .map((e) => e as String)
        .toList(),
  );
}
