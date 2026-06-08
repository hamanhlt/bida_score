import 'package:bida_score/widgets/player_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('assignPlayerColors', () {
    test('cùng input → cùng output (stable)', () {
      final a = assignPlayerColors(['p_alice', 'p_bob', 'p_charlie']);
      final b = assignPlayerColors(['p_charlie', 'p_bob', 'p_alice']);
      // Order khác nhưng map cuối cùng phải giống nhau (sort by id internally).
      expect(a, b);
    });

    test('mỗi player có 1 màu trong palette', () {
      final ids = List.generate(8, (i) => 'p_$i');
      final map = assignPlayerColors(ids);
      expect(map.keys.toSet(), ids.toSet());
      for (final c in map.values) {
        expect(kPlayerPalette, contains(c));
      }
    });

    test('player count < palette size → tất cả màu khác nhau', () {
      final ids = List.generate(8, (i) => 'p_$i');
      final map = assignPlayerColors(ids);
      expect(map.values.toSet().length, ids.length);
    });

    test('player count > palette size → wrap-around (cycle)', () {
      final n = kPlayerPalette.length + 3;
      final ids = List.generate(n, (i) => 'p_${i.toString().padLeft(3, '0')}');
      final map = assignPlayerColors(ids);
      // Có ít nhất 1 collision (theo pigeonhole).
      expect(map.values.toSet().length, lessThanOrEqualTo(kPlayerPalette.length));
    });
  });
}
