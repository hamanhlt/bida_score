import 'dart:math';

/// Bể emoji con vật dễ thương để random cho player mỗi khi start game.
abstract final class PlayerAvatarPool {
  static const List<String> animals = [
    '🐱', // mèo
    '🐶', // chó
    '🐰', // thỏ
    '🐻', // gấu
    '🦊', // cáo
    '🐼', // gấu trúc
    '🐸', // ếch
    '🐵', // khỉ
    '🐯', // hổ
    '🐨', // koala
    '🐷', // heo
    '🦁', // sư tử
    '🐮', // bò
    '🐹', // chuột hamster
    '🦄', // kỳ lân
    '🦉', // cú
    '🐧', // chim cánh cụt
    '🦒', // hươu cao cổ
    '🐢', // rùa
    '🐙', // bạch tuộc
    '🐻‍❄️', // gấu bắc cực
    '🦘', // kangaroo
    '🦥', // lười
    '🦦', // rái cá
  ];

  /// Chọn [count] avatar không trùng nhau, random. Nếu [count] > pool,
  /// cho phép trùng (hiếm khi xảy ra với ≤ 24 người chơi).
  static List<String> randomUnique(int count, {Random? rng}) {
    final random = rng ?? Random();
    if (count <= animals.length) {
      final shuffled = [...animals]..shuffle(random);
      return shuffled.take(count).toList(growable: false);
    }
    // Pool không đủ — vẫn random nhưng có thể trùng.
    return List<String>.generate(
      count,
      (_) => animals[random.nextInt(animals.length)],
      growable: false,
    );
  }

  /// Chọn 1 avatar random không nằm trong [exclude]. Nếu hết avatar khả dụng
  /// (đã dùng hết pool) thì cho phép trùng.
  static String pickOne(Set<String> exclude, {Random? rng}) {
    final random = rng ?? Random();
    final available = animals.where((a) => !exclude.contains(a)).toList();
    if (available.isNotEmpty) {
      return available[random.nextInt(available.length)];
    }
    return animals[random.nextInt(animals.length)];
  }
}
