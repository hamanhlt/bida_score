/// Trạng thái UI của League shell — quyết định màn user đang xem trong
/// luồng giải đấu (list nhiều giải vs 1 giải cụ thể).
enum LeagueViewMode { list, current }

/// Snapshot của session giải đấu, persist qua kill app để user mở lại
/// vẫn đúng màn đang xem dở.
///
/// - [viewMode] = list → LeagueListScreen.
/// - [viewMode] = current → routing theo `LeagueState.status` (setup /
///   inProgress / finished). [currentId] non-null = đang edit giải có id
///   đó; null = tạo giải mới (status sẽ là setup).
class LeagueSessionData {
  const LeagueSessionData({
    this.viewMode = LeagueViewMode.list,
    this.currentId,
  });

  factory LeagueSessionData.initial() => const LeagueSessionData();

  final LeagueViewMode viewMode;
  final String? currentId;

  Map<String, dynamic> toJson() => {
    'viewMode': viewMode.name,
    'currentId': currentId,
  };

  factory LeagueSessionData.fromJson(Map<String, dynamic> json) {
    final modeName = json['viewMode'] as String?;
    final mode = LeagueViewMode.values.firstWhere(
      (v) => v.name == modeName,
      orElse: () => LeagueViewMode.list,
    );
    return LeagueSessionData(
      viewMode: mode,
      currentId: json['currentId'] as String?,
    );
  }
}
