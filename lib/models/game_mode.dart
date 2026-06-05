/// Chế độ chơi bi-a. 2 modes:
/// - [penalty369] (Bắn đền): cấu hình bi linh hoạt, ai ăn bi cộng điểm, chọn người trừ.
/// - [pool]: race-to-X, biến thể (8/9/10-Ball / Khác) chọn ở Setup screen
///   và lưu vào `MatchResult.modeLabel`.
enum GameMode {
  penalty369(
    'Bắn đền',
    'Cấu hình bi linh hoạt — ai ăn bi cộng điểm, chọn người để trừ.',
    '🔴',
  ),
  pool(
    'Pool',
    '2 người, race-to-X ván. Chọn biến thể 8/9/10-Ball / Khác ở Setup.',
    '🎱',
    iconBallNumber: 9,
  ),
  league(
    'Giải đấu',
    'Vòng tròn hoặc vòng bảng + knockout. Bảng xếp hạng realtime.',
    '🏆',
  );

  const GameMode(
    this.label,
    this.description,
    this.icon, {
    this.iconBallNumber,
  });

  final String label;
  final String description;
  final String icon;

  /// Nếu khác null, mode card render [BallIcon] với số này thay vì emoji.
  final int? iconBallNumber;

  /// Map tên enum cũ (`nineBall`/`eightBall`/`tenBall`) sang `pool` để
  /// `GameState.fromJson` resume đúng race-to-X shell với save cũ.
  static const Set<String> legacyPoolNames = {
    'nineBall',
    'eightBall',
    'tenBall',
  };
}
