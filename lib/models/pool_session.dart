/// Trạng thái UI của Pool shell — quyết định màn user đang xem trong luồng
/// Pool (list nhiều trận đang chơi vs 1 trận cụ thể). Mirror League session.
enum PoolViewMode { list, current }

/// Snapshot session Pool, persist qua kill app để mở lại đúng màn đang xem dở.
///
/// - [viewMode] = list → NineBallListScreen.
/// - [viewMode] = current → routing theo `NineBallState.status` (setup /
///   inProgress / finished). [currentId] non-null = đang chơi trận có id đó;
///   null = tạo trận mới (status sẽ là setup).
class PoolSessionData {
  const PoolSessionData({
    this.viewMode = PoolViewMode.list,
    this.currentId,
  });

  factory PoolSessionData.initial() => const PoolSessionData();

  final PoolViewMode viewMode;
  final String? currentId;

  Map<String, dynamic> toJson() => {
    'viewMode': viewMode.name,
    'currentId': currentId,
  };

  factory PoolSessionData.fromJson(Map<String, dynamic> json) {
    final modeName = json['viewMode'] as String?;
    final mode = PoolViewMode.values.firstWhere(
      (v) => v.name == modeName,
      orElse: () => PoolViewMode.list,
    );
    return PoolSessionData(
      viewMode: mode,
      currentId: json['currentId'] as String?,
    );
  }
}
