import 'package:bida_score/logic/game_engine.dart';
import 'package:bida_score/models/ball_config.dart';
import 'package:bida_score/models/game_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameEngine', () {
    const engine = GameEngine();
    const defaultBalls = BallConfig.defaultPreset;
    const ball3 = BallConfig(number: 3, points: 1);
    const ball6 = BallConfig(number: 6, points: 2);
    const ball9 = BallConfig(number: 9, points: 3);

    test('applyScore single victim — shooter gains, victim loses', () {
      var state = engine.startGame(['A', 'B', 'C'], defaultBalls);
      state = engine.selectShooter(state, 1);
      state = engine.addBall(state, ball3);
      state = engine.applyScore(state, victimIndices: [0]);

      expect(state.players[1].score, 1);
      expect(state.players[0].score, -1);
      expect(state.totalScore, 0);
      expect(state.turnState.shooterIndex, isNull);
      expect(state.turnState.pocketedBalls, isEmpty);
    });

    test('applyScore logs a ScoreEvent', () {
      var state = engine.startGame(['A', 'B', 'C'], defaultBalls);
      state = engine.selectShooter(state, 0);
      state = engine.addBall(state, ball6);
      state = engine.applyScore(state, victimIndices: [2]);

      expect(state.scoreEvents, hasLength(1));
      final event = state.scoreEvents.single;
      expect(event.shooterName, 'A');
      expect(event.victimNames, ['C']);
      expect(event.multiplier, 1);
      expect(event.pointsPerVictim, 2);
      expect(event.shooterGain, 2);
      expect(event.balls, [ball6]);
    });

    test('applyScore with multiplier=2 (chấm đơn)', () {
      var state = engine.startGame(['A', 'B', 'C'], defaultBalls);
      state = engine.selectShooter(state, 0);
      state = engine.addBall(state, ball9);
      state = engine.applyScore(state, victimIndices: [1], multiplier: 2);

      // bi 9 = 3 điểm × 2 = 6 cho mỗi victim
      expect(state.players[0].score, 6);
      expect(state.players[1].score, -6);
      expect(state.players[2].score, 0);
      expect(state.totalScore, 0);
      expect(state.scoreEvents.single.multiplier, 2);
      expect(state.scoreEvents.single.pointsPerVictim, 6);
    });

    test('applyScore all victims — đền cả bàn (multiplier=1)', () {
      var state = engine.startGame(['A', 'B', 'C'], defaultBalls);
      state = engine.selectShooter(state, 0);
      state = engine.addBall(state, ball6); // +2

      // Đền cả: mỗi victim -2, shooter +2×2=4
      state = engine.applyScore(state, victimIndices: [1, 2]);

      expect(state.players[0].score, 4);
      expect(state.players[1].score, -2);
      expect(state.players[2].score, -2);
      expect(state.totalScore, 0);
      final event = state.scoreEvents.single;
      expect(event.victimNames, ['B', 'C']);
      expect(event.pointsPerVictim, 2);
      expect(event.shooterGain, 4);
    });

    test('applyScore all victims × multiplier 2 — chấm phá', () {
      // Ví dụ của user: 4 người, bi 1+2+3=6, ×2 ×3 = 36
      var state = engine.startGame(
        ['A', 'B', 'C', 'D'],
        const [
          BallConfig(number: 1, points: 1),
          BallConfig(number: 2, points: 2),
          BallConfig(number: 3, points: 3),
        ],
      );
      state = engine.selectShooter(state, 0);
      state = engine.addBall(state, const BallConfig(number: 1, points: 1));
      state = engine.addBall(state, const BallConfig(number: 2, points: 2));
      state = engine.addBall(state, const BallConfig(number: 3, points: 3));

      state = engine.applyScore(
        state,
        victimIndices: [1, 2, 3],
        multiplier: 2,
      );

      // Mỗi victim -12 (= 6 × 2), shooter +36 (= 12 × 3)
      expect(state.players[0].score, 36);
      expect(state.players[1].score, -12);
      expect(state.players[2].score, -12);
      expect(state.players[3].score, -12);
      expect(state.totalScore, 0);
    });

    test('applyScore ignores when shooter is in victim list', () {
      var state = engine.startGame(['A', 'B'], defaultBalls);
      state = engine.selectShooter(state, 0);
      state = engine.addBall(state, ball3);
      state = engine.applyScore(state, victimIndices: [0]);

      expect(state.players.every((p) => p.score == 0), isTrue);
      expect(state.scoreEvents, isEmpty);
    });

    test('applyScore ignores duplicate victim indices', () {
      var state = engine.startGame(['A', 'B'], defaultBalls);
      state = engine.selectShooter(state, 0);
      state = engine.addBall(state, ball3);
      state = engine.applyScore(state, victimIndices: [1, 1]);

      expect(state.players.every((p) => p.score == 0), isTrue);
    });

    test('applyScore ignores when no balls', () {
      var state = engine.startGame(['A', 'B'], defaultBalls);
      state = engine.selectShooter(state, 0);
      state = engine.applyScore(state, victimIndices: [1]);

      expect(state.players.every((p) => p.score == 0), isTrue);
      expect(state.scoreEvents, isEmpty);
    });

    test('applyScore ignores when no shooter', () {
      var state = engine.startGame(['A', 'B'], defaultBalls);
      state = engine.addBall(state, ball3);
      state = engine.applyScore(state, victimIndices: [1]);

      expect(state.players.every((p) => p.score == 0), isTrue);
    });

    test('multiple balls accumulate points', () {
      var state = engine.startGame(['A', 'B', 'C'], defaultBalls);
      state = engine.selectShooter(state, 0);
      state = engine.addBall(state, ball3);
      state = engine.addBall(state, ball9);
      state = engine.applyScore(state, victimIndices: [2]);

      expect(state.players[0].score, 4);
      expect(state.players[2].score, -4);
    });

    test('removeBallAt removes correct ball', () {
      var state = engine.startGame(['A', 'B'], defaultBalls);
      state = engine.addBall(state, ball3);
      state = engine.addBall(state, ball6);
      state = engine.addBall(state, ball9);
      state = engine.removeBallAt(state, 1);

      expect(state.turnState.pocketedBalls, [ball3, ball9]);
    });

    test('clearDraft resets turn', () {
      var state = engine.startGame(['A', 'B'], defaultBalls);
      state = engine.selectShooter(state, 0);
      state = engine.addBall(state, ball6);
      state = engine.clearDraft(state);

      expect(state.turnState.shooterIndex, isNull);
      expect(state.turnState.pocketedBalls, isEmpty);
    });

    test('undo restores scores and removes the scoreEvent from the log', () {
      var state = engine.startGame(['A', 'B', 'C'], defaultBalls);
      state = engine.selectShooter(state, 0);
      state = engine.addBall(state, ball6);
      state = engine.applyScore(state, victimIndices: [1]);
      expect(state.players[0].score, 2);
      expect(state.scoreEvents, hasLength(1));

      state = engine.undo(state);
      // Điểm đã lùi.
      expect(state.players.every((p) => p.score == 0), isTrue);
      // Lượt ghi điểm bị undo cũng biến mất khỏi log — không để lại "rác".
      expect(state.scoreEvents, isEmpty);
    });

    test('undo a non-scoring action keeps earlier scoreEvents intact', () {
      var state = engine.startGame(['A', 'B', 'C'], defaultBalls);
      state = engine.selectShooter(state, 0);
      state = engine.addBall(state, ball6);
      state = engine.applyScore(state, victimIndices: [1]);
      expect(state.scoreEvents, hasLength(1));

      // Hành động không-ghi-điểm tiếp theo.
      state = engine.selectShooter(state, 1);
      // Undo cái selectShooter này → scoreEvents giữ nguyên 1.
      state = engine.undo(state);
      expect(state.scoreEvents, hasLength(1));
    });

    test('endRound reorders based on last single-victim scoring', () {
      var state = engine.startGame(['A', 'B', 'C'], defaultBalls);
      state = engine.selectShooter(state, 1);
      state = engine.addBall(state, ball9);
      state = engine.applyScore(state, victimIndices: [0]);

      expect(state.lastScorerIndex, 1);
      expect(state.lastVictimIndex, 0);

      state = engine.endRound(state);
      expect(state.roundNumber, 2);
      expect(state.players[0].name, 'B');
      expect(state.players[1].name, 'A');
      expect(state.players[2].name, 'C');
    });

    test('endRound does NOT reorder when last scoring was multi-victim', () {
      var state = engine.startGame(['A', 'B', 'C'], defaultBalls);
      state = engine.selectShooter(state, 0);
      state = engine.addBall(state, ball3);
      state = engine.applyScore(state, victimIndices: [1, 2]);

      expect(state.lastScorerIndex, 0);
      expect(state.lastVictimIndex, isNull);

      state = engine.endRound(state);
      expect(state.players[0].name, 'A');
      expect(state.players[1].name, 'B');
      expect(state.players[2].name, 'C');
    });

    test('scores carry over across rounds', () {
      var state = engine.startGame(['A', 'B', 'C'], defaultBalls);
      state = engine.selectShooter(state, 0);
      state = engine.addBall(state, ball6);
      state = engine.applyScore(state, victimIndices: [2]);

      state = engine.selectShooter(state, 1);
      state = engine.addBall(state, ball9);
      state = engine.applyScore(state, victimIndices: [0]);

      state = engine.endRound(state);

      expect(state.roundNumber, 2);
      expect(state.totalScore, 0);
      expect(state.players.firstWhere((p) => p.name == 'B').score, 3);
      expect(state.players.firstWhere((p) => p.name == 'A').score, -1);
      expect(state.players.firstWhere((p) => p.name == 'C').score, -2);
    });

    test('startGame rejects empty ball configs', () {
      expect(
        () => engine.startGame(['A', 'B'], []),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('finishGame marks state as finished', () {
      var state = engine.startGame(['A', 'B'], defaultBalls);
      state = engine.finishGame(state);
      expect(state.status, GameStatus.finished);
    });

    test('enterCham fills all configured balls + sets chamMode', () {
      var state = engine.startGame(['A', 'B', 'C'], defaultBalls);
      state = engine.selectShooter(state, 0);
      state = engine.enterCham(state);

      expect(state.turnState.chamMode, isTrue);
      expect(state.turnState.pocketedBalls, defaultBalls);
      expect(state.turnState.totalPoints, 1 + 2 + 3); // 3+6+9 points
      expect(state.turnState.multiplier, 2);
    });

    test('enterCham + applyScore matches user example (4P × 6 × 2 × 3 = 36)', () {
      const balls = [
        BallConfig(number: 1, points: 1),
        BallConfig(number: 2, points: 2),
        BallConfig(number: 3, points: 3),
      ];
      var state = engine.startGame(['A', 'B', 'C', 'D'], balls);
      state = engine.selectShooter(state, 0);
      state = engine.enterCham(state);

      // Chấm phá: tất cả victim với multiplier 2
      state = engine.applyScore(
        state,
        victimIndices: const [1, 2, 3],
        multiplier: 2,
      );

      expect(state.players[0].score, 36);
      expect(state.players[1].score, -12);
      expect(state.players[2].score, -12);
      expect(state.players[3].score, -12);
    });

    test('enterCham requires shooter', () {
      var state = engine.startGame(['A', 'B'], defaultBalls);
      state = engine.enterCham(state);

      expect(state.turnState.chamMode, isFalse);
      expect(state.turnState.pocketedBalls, isEmpty);
    });

    test('chấm phá với 3 người + 4 bi (1+2+3+4): +40/-20/-20', () {
      // Trường hợp user báo: 3 người, 4 bi 1+2+3+4=10 điểm, tap Chấm phá.
      const balls = [
        BallConfig(number: 1, points: 1),
        BallConfig(number: 2, points: 2),
        BallConfig(number: 3, points: 3),
        BallConfig(number: 4, points: 4),
      ];
      var state = engine.startGame(['A', 'B', 'C'], balls);
      state = engine.selectShooter(state, 0);
      state = engine.enterCham(state);
      state = engine.applyScore(
        state,
        victimIndices: const [1, 2],
        multiplier: 2,
      );

      // Tổng bi = 10, ×2 = 20 điểm/victim. Shooter +20×2 = +40.
      expect(state.players[0].score, 40);
      expect(state.players[1].score, -20);
      expect(state.players[2].score, -20);
      expect(state.totalScore, 0);
    });
  });
}
