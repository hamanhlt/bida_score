/// Chế độ chơi bi-a.
enum GameMode {
  penalty369(
    'Bắn đền',
    'Cấu hình bi linh hoạt — ai ăn bi cộng điểm, chọn người để trừ.',
    '🔴',
  ),
  tenBall(
    '10-Ball',
    '2 người, race-to-X ván. Call-shot, bi 10 là money ball.',
    '🔟',
    iconBallNumber: 10,
  ),
  nineBall('9-Ball', '2 người, race-to-X ván.', '🟡', iconBallNumber: 9),
  eightBall('8-Ball', '2 người, race-to-X ván.', '🎱', iconBallNumber: 8);

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
}
