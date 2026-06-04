import 'dart:math';

import 'package:bida_score/logic/league_engine.dart';
import 'package:bida_score/models/league_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Deterministic engine — fixed seed shuffles fixtures the same way mỗi run.
  final engine = LeagueEngine(rng: Random(42));

  group('LeagueEngine', () {
    test('startTournament rejects <3 players', () {
      expect(
        () => engine.startTournament(['A', 'B']),
        throwsArgumentError,
      );
    });

    test('startTournament rejects duplicate names (case-insensitive)', () {
      expect(
        () => engine.startTournament(['A', 'b', 'a']),
        throwsArgumentError,
      );
    });

    test('startTournament generates N*(N-1)/2 fixtures', () {
      final state = engine.startTournament(['A', 'B', 'C', 'D']);
      expect(state.fixtures, hasLength(6)); // 4*3/2
      expect(state.players, hasLength(4));
      expect(state.status, LeagueStatus.inProgress);
      // Mọi cặp đều unique (mỗi cặp đúng 1 trận).
      final pairs = state.fixtures
          .map((f) => {f.player1Id, f.player2Id})
          .toList();
      for (var i = 0; i < pairs.length; i++) {
        for (var j = i + 1; j < pairs.length; j++) {
          expect(pairs[i].difference(pairs[j]).length, isNonZero,
              reason: 'Cặp $i và $j trùng');
        }
      }
    });

    test('updateScore sets isPlayed + recalculates leaderboard', () {
      var state = engine.startTournament(['A', 'B', 'C']);
      final f = state.fixtures.first;
      state = engine.updateScore(state, f.id, 3, 1);

      final p1 = state.players.firstWhere((p) => p.id == f.player1Id);
      final p2 = state.players.firstWhere((p) => p.id == f.player2Id);
      expect(p1.points, 1);
      expect(p1.matchesPlayed, 1);
      expect(p1.goalsFor, 3);
      expect(p1.goalsAgainst, 1);
      expect(p1.goalDifference, 2);
      expect(p2.points, 0);
      expect(p2.goalsFor, 1);
      expect(p2.goalsAgainst, 3);

      final updated = state.fixtures.firstWhere((x) => x.id == f.id);
      expect(updated.isPlayed, isTrue);
      expect(updated.score1, 3);
      expect(updated.score2, 1);
    });

    test('updateScore re-edit doesn\'t double-count (recalculates from scratch)', () {
      var state = engine.startTournament(['A', 'B', 'C']);
      final f = state.fixtures.first;
      state = engine.updateScore(state, f.id, 5, 2);
      state = engine.updateScore(state, f.id, 1, 4); // sửa lại tỷ số

      final p1 = state.players.firstWhere((p) => p.id == f.player1Id);
      final p2 = state.players.firstWhere((p) => p.id == f.player2Id);
      // Tỷ số mới: 1-4 → p1 thua, p2 thắng. KHÔNG cộng dồn 5+1 hay 2+4.
      expect(p1.points, 0);
      expect(p1.goalsFor, 1);
      expect(p1.goalsAgainst, 4);
      expect(p2.points, 1);
      expect(p2.goalsFor, 4);
      expect(p2.goalsAgainst, 1);
    });

    test('draw gives 0 points to both sides', () {
      var state = engine.startTournament(['A', 'B', 'C']);
      final f = state.fixtures.first;
      state = engine.updateScore(state, f.id, 2, 2);

      final p1 = state.players.firstWhere((p) => p.id == f.player1Id);
      final p2 = state.players.firstWhere((p) => p.id == f.player2Id);
      expect(p1.points, 0);
      expect(p2.points, 0);
      expect(p1.goalDifference, 0);
      expect(p2.goalDifference, 0);
    });

    test('0-0 still counts as played (matchesPlayed = 1)', () {
      var state = engine.startTournament(['A', 'B', 'C']);
      final f = state.fixtures.first;
      state = engine.updateScore(state, f.id, 0, 0);

      final p1 = state.players.firstWhere((p) => p.id == f.player1Id);
      expect(p1.matchesPlayed, 1);
      expect(p1.points, 0);
    });

    test('updateScore throws on negative score', () {
      var state = engine.startTournament(['A', 'B', 'C']);
      final f = state.fixtures.first;
      expect(
        () => engine.updateScore(state, f.id, -1, 0),
        throwsArgumentError,
      );
    });

    test('clearScore removes match from stats', () {
      var state = engine.startTournament(['A', 'B', 'C']);
      final f = state.fixtures.first;
      state = engine.updateScore(state, f.id, 3, 0);
      state = engine.clearScore(state, f.id);

      final p1 = state.players.firstWhere((p) => p.id == f.player1Id);
      expect(p1.matchesPlayed, 0);
      expect(p1.points, 0);
      expect(p1.goalsFor, 0);
      final reset = state.fixtures.firstWhere((x) => x.id == f.id);
      expect(reset.isPlayed, isFalse);
    });

    test('leaderboard tie-breaker: GoalDifference > GoalsFor', () {
      var state = engine.startTournament(['A', 'B', 'C', 'D']);
      // Setup: A và B đều thắng 1 trận. A: 10-0. B: 5-1. Same points (1 each).
      // A có GD=10, B có GD=4 → A xếp trên B.
      final ids = state.players.map((p) => p.id).toList();
      final a = ids[0], b = ids[1], c = ids[2], d = ids[3];

      // Find A-vs-C fixture, set A wins 10-0.
      final aVsC = state.fixtures.firstWhere(
        (f) => {f.player1Id, f.player2Id}.containsAll({a, c}),
      );
      state = engine.updateScore(
        state,
        aVsC.id,
        aVsC.player1Id == a ? 10 : 0,
        aVsC.player1Id == a ? 0 : 10,
      );

      // Find B-vs-D fixture, set B wins 5-1.
      final bVsD = state.fixtures.firstWhere(
        (f) => {f.player1Id, f.player2Id}.containsAll({b, d}),
      );
      state = engine.updateScore(
        state,
        bVsD.id,
        bVsD.player1Id == b ? 5 : 1,
        bVsD.player1Id == b ? 1 : 5,
      );

      final standings = state.players;
      expect(standings[0].id, a, reason: 'A trên B do GD lớn hơn');
      expect(standings[1].id, b);
    });

    test('finishTournament sets finished status + finishedAt', () {
      var state = engine.startTournament(['A', 'B', 'C']);
      state = engine.finishTournament(state);
      expect(state.status, LeagueStatus.finished);
      expect(state.finishedAt, isNotNull);
    });

    test('finishTournament noop nếu chưa inProgress', () {
      final state = LeagueState.initial();
      final result = engine.finishTournament(state);
      expect(result.status, LeagueStatus.setup);
    });

    test('updateScore noop sau khi finishTournament', () {
      var state = engine.startTournament(['A', 'B', 'C']);
      final fId = state.fixtures.first.id;
      state = engine.finishTournament(state);
      final after = engine.updateScore(state, fId, 9, 9);
      expect(after.fixtures.firstWhere((f) => f.id == fId).isPlayed, isFalse);
    });

    test('startTournament rejects >16 players', () {
      final names = List.generate(17, (i) => 'P$i');
      expect(() => engine.startTournament(names), throwsArgumentError);
    });

    test('updateScore throws on score > 999 (max cap)', () {
      var state = engine.startTournament(['A', 'B', 'C']);
      final fId = state.fixtures.first.id;
      expect(
        () => engine.updateScore(state, fId, 1000, 0),
        throwsArgumentError,
      );
    });

    test('clearScore throws on unknown fixtureId (contract consistent)', () {
      var state = engine.startTournament(['A', 'B', 'C']);
      expect(
        () => engine.clearScore(state, 'mf_nonexistent'),
        throwsArgumentError,
      );
    });

    test('updateScore validates input BEFORE status guard (throws even when finished)', () {
      var state = engine.startTournament(['A', 'B', 'C']);
      final fId = state.fixtures.first.id;
      state = engine.finishTournament(state);
      expect(
        () => engine.updateScore(state, fId, -1, 0),
        throwsArgumentError,
        reason: 'Validation phải fire kể cả khi giải đã finished',
      );
    });

    test('round-robin coverage: N=3..10 đủ pairs, unique', () {
      for (var n = 3; n <= 10; n++) {
        final names = List.generate(n, (i) => 'P$i');
        final state = engine.startTournament(names);
        expect(state.fixtures, hasLength(n * (n - 1) ~/ 2),
            reason: 'N=$n');
        // Mỗi cặp unique.
        final pairs = state.fixtures
            .map((f) => '${f.player1Id}|${f.player2Id}')
            .toSet();
        expect(pairs.length, state.fixtures.length, reason: 'N=$n unique');
        // Mỗi player gặp đúng (n-1) người.
        for (final p in state.players) {
          final apps = state.fixtures
              .where((f) => f.player1Id == p.id || f.player2Id == p.id)
              .length;
          expect(apps, n - 1, reason: 'N=$n, player ${p.id}');
        }
      }
    });

    test('tie-breaker: GoalsFor khi Points và GD bằng nhau', () {
      var state = engine.startTournament(['A', 'B', 'C', 'D']);
      final ids = state.players.map((p) => p.id).toList();
      final a = ids[0], b = ids[1], c = ids[2], d = ids[3];

      // A win 5-3 vs C; B win 2-0 vs D. Both: Points=1, GD=+2.
      // GoalsFor: A=5, B=2 → A xếp trên B.
      final aVsC = state.fixtures.firstWhere(
        (f) => {f.player1Id, f.player2Id}.containsAll({a, c}),
      );
      state = engine.updateScore(
        state,
        aVsC.id,
        aVsC.player1Id == a ? 5 : 3,
        aVsC.player1Id == a ? 3 : 5,
      );
      final bVsD = state.fixtures.firstWhere(
        (f) => {f.player1Id, f.player2Id}.containsAll({b, d}),
      );
      state = engine.updateScore(
        state,
        bVsD.id,
        bVsD.player1Id == b ? 2 : 0,
        bVsD.player1Id == b ? 0 : 2,
      );

      final ranking = state.players;
      expect(ranking[0].id, a);
      expect(ranking[1].id, b);
    });

    test('all-tied scenario: 3 player 0-0 toàn bộ → sort theo alphabet', () {
      var state = engine.startTournament(['Charlie', 'Alice', 'Bob']);
      for (final f in state.fixtures) {
        state = engine.updateScore(state, f.id, 0, 0);
      }
      // All Points=0, GD=0, GoalsFor=0 → fallback alphabet.
      final names = state.players.map((p) => p.name).toList();
      expect(names, ['Alice', 'Bob', 'Charlie']);
    });

    test('JSON round-trip: toJson → fromJson preserves all fields', () {
      var state = engine.startTournament(['Alice', 'Bob', 'Charlie']);
      state = engine.updateScore(state, state.fixtures.first.id, 3, 1);
      state = engine.finishTournament(state);

      final json = state.toJson();
      final decoded = LeagueState.fromJson(
        Map<String, dynamic>.from(json),
      );

      expect(decoded.status, state.status);
      expect(decoded.players.length, state.players.length);
      expect(decoded.fixtures.length, state.fixtures.length);
      expect(decoded.finishedAt, state.finishedAt);
      // Players keep stats.
      for (var i = 0; i < state.players.length; i++) {
        expect(decoded.players[i].id, state.players[i].id);
        expect(decoded.players[i].points, state.players[i].points);
        expect(
          decoded.players[i].goalDifference,
          state.players[i].goalDifference,
        );
      }
      // Fixtures keep isPlayed.
      final origPlayed = state.fixtures.where((f) => f.isPlayed).length;
      final decodedPlayed =
          decoded.fixtures.where((f) => f.isPlayed).length;
      expect(decodedPlayed, origPlayed);
    });

    test('LeagueState.fromJson throws on unknown status (no silent coerce)', () {
      expect(
        () => LeagueState.fromJson({
          'status': 'someInvalidStatus',
          'players': <dynamic>[],
          'fixtures': <dynamic>[],
        }),
        throwsFormatException,
      );
    });

    test('LeagueState.fromJson defaults to setup when status missing', () {
      final state = LeagueState.fromJson(<String, dynamic>{
        'players': <dynamic>[],
        'fixtures': <dynamic>[],
      });
      expect(state.status, LeagueStatus.setup);
    });
  });
}
