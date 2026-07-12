/// Cấu hình mức tiền cho chế độ Chơi điểm — lưu lại để Setup screen lần sau
/// auto-fill (mỗi quán mức cược khác nhau, ít đổi).
class CashConfig {
  const CashConfig({required this.moneyPerRack, required this.moneyPerBall});

  final int moneyPerRack;
  final int moneyPerBall;

  Map<String, dynamic> toJson() => {
    'moneyPerRack': moneyPerRack,
    'moneyPerBall': moneyPerBall,
  };

  factory CashConfig.fromJson(Map<String, dynamic> json) => CashConfig(
    moneyPerRack: json['moneyPerRack'] as int? ?? 40000,
    moneyPerBall: json['moneyPerBall'] as int? ?? 20000,
  );
}
