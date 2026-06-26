import 'package:bida_score/logic/nine_ball_engine.dart';
import 'package:bida_score/models/nine_ball_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = NineBallEngine();

  group('NineBallState JSON (persist trận Pool đang chơi)', () {
    test('round-trip giữ nguyên các field live', () {
      var state = engine.startGame(
        ['An', 'Bình'],
        120,
        variantLabel: '10-Ball',
        shotClockSeconds: 45,
      );
      // Chơi vài rack để có rackWins + rackWinnerNames.
      state = engine.winRack(state, 0);
      state = engine.winRack(state, 1);
      state = engine.winRack(state, 0);

      final restored = NineBallState.fromJson(state.toJson());

      expect(restored.players.map((p) => p.name), ['An', 'Bình']);
      expect(restored.rackWins, state.rackWins);
      expect(restored.raceTarget, 120);
      expect(restored.breakerIndex, state.breakerIndex);
      expect(restored.currentRack, state.currentRack);
      expect(restored.status, NineBallStatus.inProgress);
      expect(restored.rackWinnerNames, ['An', 'Bình', 'An']);
      expect(restored.variantLabel, '10-Ball');
      expect(restored.shotClockSeconds, 45);
    });

    test('không persist undo history (bắt đầu rỗng sau restore)', () {
      var state = engine.startGame(['An', 'Bình'], 5);
      state = engine.winRack(state, 0); // tạo 1 entry history
      expect(state.history, isNotEmpty);

      final restored = NineBallState.fromJson(state.toJson());
      expect(restored.history, isEmpty);
      expect(restored.canUndo, isFalse);
    });

    test('variantLabel null vẫn round-trip được', () {
      final state = engine.startGame(['An', 'Bình'], 7);
      final restored = NineBallState.fromJson(state.toJson());
      expect(restored.variantLabel, isNull);
      expect(restored.shotClockSeconds, 0);
    });
  });
}
