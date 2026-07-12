import 'package:bida_score/logic/cash_game_engine.dart';
import 'package:bida_score/models/cash_game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = CashGameEngine();

  group('CashGameEngine.startGame', () {
    test('khởi tạo đúng 2 người + mức tiền', () {
      final s = engine.startGame(
        ['A', 'B'],
        moneyPerRack: 40000,
        moneyPerBall: 20000,
      );
      expect(s.status, CashGameStatus.inProgress);
      expect(s.playerNames, ['A', 'B']);
      expect(s.rackWins, [0, 0]);
      expect(s.balls, [0, 0]);
      expect(s.rackResults, isEmpty);
      expect(s.settledOffsets, [0, 0]);
      expect(s.settledRackWins, [0, 0]);
      expect(s.currentRackNumber, 1);
      expect(s.moneyPerRack, 40000);
      expect(s.moneyPerBall, 20000);
      expect(s.startedAt, isNotNull);
    });

    test('reject khác 2 người', () {
      expect(
        () => engine.startGame(['A'], moneyPerRack: 1, moneyPerBall: 1),
        throwsArgumentError,
      );
      expect(
        () =>
            engine.startGame(['A', 'B', 'C'], moneyPerRack: 1, moneyPerBall: 1),
        throwsArgumentError,
      );
    });

    test('reject tên trùng (case-insensitive)', () {
      expect(
        () => engine.startGame(
          ['Minh', 'minh'],
          moneyPerRack: 1,
          moneyPerBall: 1,
        ),
        throwsArgumentError,
      );
    });

    test('reject mức tiền âm', () {
      expect(
        () => engine.startGame(['A', 'B'], moneyPerRack: -1, moneyPerBall: 0),
        throwsArgumentError,
      );
    });
  });

  group('CashGameEngine scoring', () {
    CashGameState fresh() =>
        engine.startGame(['A', 'B'], moneyPerRack: 40000, moneyPerBall: 20000);

    test('addRackWin cộng dồn ván thắng toàn trận', () {
      var s = fresh();
      s = engine.addRackWin(s, 0);
      s = engine.addRackWin(s, 0);
      expect(s.rackWins, [2, 0]);
      expect(s.moneyOf(0), 80000);

      s = engine.addRackWin(s, 1);
      expect(s.rackWins, [2, 1]);
      expect(s.moneyOf(0), 80000);
      expect(s.moneyOf(1), 40000);
    });

    test('addBall cộng bi ván hiện tại + tiền đúng', () {
      var s = fresh();
      s = engine.addBall(s, 1);
      s = engine.addBall(s, 1);
      s = engine.addBall(s, 1);
      expect(s.balls[1], 3);
      expect(s.moneyOf(1), 60000); // 3 * 20k
    });

    test('tiền tổng = ván thắng cộng dồn + lỗ 10 hiện tại', () {
      var s = fresh();
      s = engine.addRackWin(s, 0); // +40k
      s = engine.addBall(s, 0); // +20k
      s = engine.addBall(s, 0); // +20k
      expect(s.moneyOf(0), 80000);
      expect(s.currentMoneyOf(0), 40000);
    });

    test('settleRack chốt lỗ 10, giữ điểm số và trừ hiệu số', () {
      var s = fresh();
      s = engine.addRackWin(s, 0); // +40k
      s = engine.addRackWin(s, 1); // +40k
      s = engine.addRackWin(s, 1); // +40k
      s = engine.addRackWin(s, 1); // +40k
      s = engine.addBall(s, 0); // +20k
      s = engine.addBall(s, 0); // +20k
      s = engine.addBall(s, 0); // +20k
      s = engine.addBall(s, 0); // +20k
      s = engine.addBall(s, 1); // +20k

      s = engine.settleRack(s);

      expect(s.rackWins, [1, 3]);
      expect(s.balls, [0, 0]);
      expect(s.rackResults, hasLength(1));
      expect(s.currentRackNumber, 2);
      expect(s.grossMoneyOf(0), 120000);
      expect(s.grossMoneyOf(1), 140000);
      expect(s.settledOffsets, [120000, 120000]);
      expect(s.settledRackWins, [1, 3]);
      expect(s.moneyOf(0), 0);
      expect(s.moneyOf(1), 20000);
      expect(s.totalRackWinsOf(0), 1);
      expect(s.totalRackWinsOf(1), 3);
      expect(s.totalBallsOf(0), 4);
      expect(s.totalBallsOf(1), 1);
    });

    test('decrementRackWin floor 0', () {
      var s = fresh();
      s = engine.decrementRackWin(s, 0);
      expect(s.rackWins[0], 0);
      s = engine.addRackWin(s, 0);
      s = engine.decrementRackWin(s, 0);
      expect(s.rackWins[0], 0);
    });

    test('removeBall floor 0', () {
      var s = fresh();
      s = engine.removeBall(s, 0);
      expect(s.balls[0], 0);
      s = engine.addBall(s, 0);
      s = engine.removeBall(s, 0);
      expect(s.balls[0], 0);
    });

    test('leaderIndex + moneyDifference', () {
      var s = fresh();
      s = engine.addRackWin(s, 0); // A: 40k
      s = engine.addBall(s, 1); // B: 20k
      expect(s.leaderIndex, 0);
      expect(s.moneyDifference, 20000);
    });

    test('leaderIndex null khi hoà tiền', () {
      var s = fresh();
      s = engine.addBall(s, 0); // A 20k
      s = engine.addBall(s, 1); // B 20k
      expect(s.leaderIndex, isNull);
      expect(s.moneyDifference, 0);
    });

    test('settleRack khi chưa có lỗ 10 vẫn chốt ván nếu điểm số đổi', () {
      final s = fresh();
      final after = engine.settleRack(s);
      expect(after.rackResults, isEmpty);
      expect(after.canUndo, isFalse);

      var withScore = engine.addRackWin(s, 0);
      withScore = engine.addRackWin(withScore, 1);
      withScore = engine.addRackWin(withScore, 1);
      withScore = engine.addRackWin(withScore, 1);
      final afterScore = engine.settleRack(withScore);
      expect(afterScore.rackResults, hasLength(1));
      expect(afterScore.rackWins, [1, 3]);
      expect(afterScore.settledRackWins, [1, 3]);
      expect(afterScore.currentRackNumber, 2);
      expect(afterScore.moneyOf(0), 0);
      expect(afterScore.moneyOf(1), 80000);

      final repeated = engine.settleRack(afterScore);
      expect(repeated.rackResults, hasLength(1));
      expect(repeated.canUndo, afterScore.canUndo);
    });
  });

  group('CashGameEngine undo', () {
    test('undo khôi phục state trước', () {
      var s = engine.startGame(
        ['A', 'B'],
        moneyPerRack: 40000,
        moneyPerBall: 20000,
      );
      s = engine.addRackWin(s, 0);
      s = engine.addBall(s, 0);
      expect(s.moneyOf(0), 60000);
      expect(s.canUndo, isTrue);
      s = engine.undo(s); // bỏ ball
      expect(s.moneyOf(0), 40000);
      s = engine.undo(s); // bỏ rack
      expect(s.moneyOf(0), 0);
      expect(s.canUndo, isFalse);
    });

    test('undo sau khi chốt ván khôi phục ván đang nhập', () {
      var s = engine.startGame(
        ['A', 'B'],
        moneyPerRack: 40000,
        moneyPerBall: 20000,
      );
      s = engine.addRackWin(s, 1);
      s = engine.addBall(s, 1);
      s = engine.settleRack(s);
      expect(s.rackResults, hasLength(1));
      expect(s.rackWins, [0, 1]);
      expect(s.balls, [0, 0]);
      expect(s.settledRackWins, [0, 1]);
      expect(s.moneyOf(1), 60000);

      s = engine.undo(s);
      expect(s.rackResults, isEmpty);
      expect(s.rackWins, [0, 1]);
      expect(s.balls, [0, 1]);
      expect(s.settledRackWins, [0, 0]);
      expect(s.moneyOf(1), 60000);
    });

    test('undo trên state rỗng = noop', () {
      final s = engine.startGame(['A', 'B'], moneyPerRack: 1, moneyPerBall: 1);
      final after = engine.undo(s);
      expect(after.rackWins, s.rackWins);
    });
  });

  group('CashGameEngine finish + guard', () {
    test('finishGame giữ ván thắng, tự chốt lỗ 10 và trừ hiệu số', () {
      var s = engine.startGame(['A', 'B'], moneyPerRack: 1, moneyPerBall: 1);
      s = engine.addRackWin(s, 0);
      s = engine.addRackWin(s, 1);
      s = engine.addRackWin(s, 1);
      s = engine.addRackWin(s, 1);
      s = engine.addBall(s, 0);
      s = engine.finishGame(s);
      expect(s.status, CashGameStatus.finished);
      expect(s.rackResults, hasLength(1));
      expect(s.rackWins, [1, 3]);
      expect(s.moneyOf(0), 0);
      expect(s.moneyOf(1), 1);
    });

    test('finishGame tạo ván chốt không lỗ 10 khi điểm số đổi', () {
      var s = engine.startGame(['A', 'B'], moneyPerRack: 1, moneyPerBall: 1);
      s = engine.addRackWin(s, 0);
      s = engine.addRackWin(s, 1);
      s = engine.addRackWin(s, 1);
      s = engine.finishGame(s);
      expect(s.status, CashGameStatus.finished);
      expect(s.rackResults, hasLength(1));
      expect(s.rackWins, [1, 2]);
      expect(s.settledRackWins, [1, 2]);
      expect(s.moneyOf(0), 0);
      expect(s.moneyOf(1), 1);
    });

    test('addRackWin/addBall noop sau khi finished', () {
      var s = engine.startGame(['A', 'B'], moneyPerRack: 1, moneyPerBall: 1);
      s = engine.finishGame(s);
      final after = engine.addRackWin(s, 0);
      expect(after.rackWins[0], 0);
      final after2 = engine.addBall(s, 0);
      expect(after2.balls[0], 0);
    });

    test('index ngoài range = noop', () {
      var s = engine.startGame(['A', 'B'], moneyPerRack: 1, moneyPerBall: 1);
      s = engine.addRackWin(s, 5);
      expect(s.rackWins, [0, 0]);
    });
  });

  group('formatVnd', () {
    test('phân nhóm nghìn', () {
      expect(formatVnd(0), '0');
      expect(formatVnd(1000), '1.000');
      expect(formatVnd(40000), '40.000');
      expect(formatVnd(360000), '360.000');
      expect(formatVnd(1234567), '1.234.567');
    });

    test('số âm có dấu trừ', () {
      expect(formatVnd(-20000), '-20.000');
    });
  });
}
