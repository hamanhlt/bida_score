/// Ảnh bi thật trong `assets/ball/` (đã đăng ký ở pubspec.yaml).
///
/// Hiện chỉ có 6 bi: 3, 4, 5, 6, 9, 10. Bi không có ảnh → widget tự vẽ
/// (gradient + sọc) như cũ. Thêm ảnh mới: bỏ file `biN.png` vào folder rồi
/// thêm `N` vào [kBallImageNumbers].
const Set<int> kBallImageNumbers = {3, 4, 5, 6, 9, 10};

/// Đường dẫn asset ảnh bi `number`. Chỉ hợp lệ khi `kBallImageNumbers.contains(number)`.
String ballAssetPath(int number) => 'assets/ball/bi$number.png';

/// Có ảnh thật cho bi này không?
bool hasBallImage(int number) => kBallImageNumbers.contains(number);

/// Hệ số zoom ảnh bi bên trong `ClipOval` — ảnh chụp có lề/cạnh mờ quanh ball,
/// zoom lên để clip cắt bỏ lề. Mỗi ảnh lề khác nhau nên có override riêng.
/// Default 1.15; ảnh nào lề rộng hơn (vd bi5) thì zoom mạnh hơn.
double ballImageZoom(int number) => switch (number) {
      5 => 1.34,
      _ => 1.15,
    };
