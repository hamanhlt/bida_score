import 'dart:math';

import 'package:bida_score/logic/league_engine.dart';
import 'package:bida_score/models/league_state.dart';
import 'package:bida_score/models/match_fixture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Deterministic engine — fixed seed shuffles fixtures the same way mỗi run.
  final engine = LeagueEngine(rng: Random(42));

  group('LeagueEngine', () {
    test('startTournament rejects <3 players', () {
      expect(() => engine.startTournament(['A', 'B']), throwsArgumentError);
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
          expect(
            pairs[i].difference(pairs[j]).length,
            isNonZero,
            reason: 'Cặp $i và $j trùng',
          );
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

    test(
      'updateScore re-edit doesn\'t double-count (recalculates from scratch)',
      () {
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
      },
    );

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
      expect(() => engine.updateScore(state, f.id, -1, 0), throwsArgumentError);
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

    test(
      'updateScore validates input BEFORE status guard (throws even when finished)',
      () {
        var state = engine.startTournament(['A', 'B', 'C']);
        final fId = state.fixtures.first.id;
        state = engine.finishTournament(state);
        expect(
          () => engine.updateScore(state, fId, -1, 0),
          throwsArgumentError,
          reason: 'Validation phải fire kể cả khi giải đã finished',
        );
      },
    );

    test('round-robin coverage: N=3..10 đủ pairs, unique', () {
      for (var n = 3; n <= 10; n++) {
        final names = List.generate(n, (i) => 'P$i');
        final state = engine.startTournament(names);
        expect(state.fixtures, hasLength(n * (n - 1) ~/ 2), reason: 'N=$n');
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

    test('startTournament groupSize generates group-stage fixtures', () {
      final local = LeagueEngine(rng: Random(7));
      final state = local.startTournament(
        List.generate(8, (i) => 'P$i'),
        groupSize: 4,
      );

      expect(state.phase, LeaguePhase.groupStage);
      expect(state.groupSize, 4);
      expect(state.groups, hasLength(2));
      expect(state.groupFixtures, hasLength(12)); // 2 bảng * 4*3/2
      expect(state.knockoutFixtures, isEmpty);
      expect(state.fixtures.every((f) => f.stage == MatchStage.group), isTrue);
    });

    test('group stage keeps manual group order from setup screen', () {
      final local = LeagueEngine(rng: Random(12));
      final state = local.startTournament([
        'A1',
        'A2',
        'B1',
        'B2',
        'C1',
        'C2',
        'D1',
        'D2',
      ], groupSize: 2);

      expect(state.groups, hasLength(4));
      final namesById = {for (final p in state.players) p.id: p.name};
      final groupedNames = [
        for (final group in state.groups)
          [for (final id in group.playerIds) namesById[id]],
      ];
      expect(groupedNames, [
        ['A1', 'A2'],
        ['B1', 'B2'],
        ['C1', 'C2'],
        ['D1', 'D2'],
      ]);
    });

    test(
      'groupSize accepts odd remainder by adding players to existing groups',
      () {
        final local = LeagueEngine(rng: Random(10));
        final state = local.startTournament(
          List.generate(9, (i) => 'P$i'),
          groupSize: 4,
        );

        expect(state.groups, hasLength(2));
        expect(state.groups.map((g) => g.playerIds.length), [5, 4]);
        expect(state.groupFixtures, hasLength(16)); // 5*4/2 + 4*3/2
        expect(LeagueEngine.validGroupSizesFor(9), contains(4));
      },
    );

    test('group size options are fixed from 2 to 6', () {
      expect(LeagueEngine.validGroupSizesFor(8), [2, 3, 4, 5, 6]);
      expect(LeagueEngine.validGroupSizesFor(12), [2, 3, 4, 5, 6]);
    });

    test('3 bảng dùng play-off và bye trước bán kết knockout', () {
      final local = LeagueEngine(rng: Random(13));
      var state = local.startTournament(
        List.generate(12, (i) => 'P$i'),
        groupSize: 4,
      );

      expect(state.groups, hasLength(3));
      expect(state.groups.map((g) => g.playerIds.length), [4, 4, 4]);

      for (final group in state.groups) {
        final rankById = {
          for (var i = 0; i < group.playerIds.length; i++)
            group.playerIds[i]: i,
        };
        final fixtures = state.groupFixtures
            .where((f) => f.groupId == group.id)
            .toList();
        for (final f in fixtures) {
          final p1Rank = rankById[f.player1Id]!;
          final p2Rank = rankById[f.player2Id]!;
          state = local.updateScore(
            state,
            f.id,
            p1Rank < p2Rank ? 3 : 0,
            p1Rank < p2Rank ? 0 : 3,
          );
        }
      }

      state = local.startKnockout(state);

      expect(state.knockoutByePlayerIds, hasLength(2));
      expect(state.knockoutFixtures, hasLength(2));
      expect(state.knockoutFixtures.map((f) => f.roundName).toSet(), {
        'Play-off',
      });
      final decoded = LeagueState.fromJson(
        Map<String, dynamic>.from(state.toJson()),
      );
      expect(decoded.knockoutByePlayerIds, state.knockoutByePlayerIds);

      final playoffs = state.knockoutFixtures
          .where((f) => f.roundIndex == 1)
          .toList();
      for (final f in playoffs) {
        state = local.updateScore(state, f.id, 4, 2);
      }

      expect(state.knockoutByePlayerIds, isEmpty);
      final semis = state.knockoutFixtures
          .where((f) => f.roundIndex == 2)
          .toList();
      expect(semis, hasLength(2));
      expect(semis.map((f) => f.roundName).toSet(), {'Bán kết'});

      for (final f in semis) {
        state = local.updateScore(state, f.id, 5, 3);
      }
      final finals = state.knockoutFixtures.where(
        (f) => f.roundName == 'Chung kết',
      );
      expect(finals, hasLength(1));
    });

    test('vòng bảng hoàn tất vẫn chờ xác nhận trước khi vào knockout', () {
      final local = LeagueEngine(rng: Random(8));
      var state = local.startTournament(
        List.generate(8, (i) => 'P$i'),
        groupSize: 4,
      );

      for (final group in state.groups) {
        final rankById = {
          for (var i = 0; i < group.playerIds.length; i++)
            group.playerIds[i]: i,
        };
        final fixtures = state.groupFixtures
            .where((f) => f.groupId == group.id)
            .toList();
        for (final f in fixtures) {
          final p1Rank = rankById[f.player1Id]!;
          final p2Rank = rankById[f.player2Id]!;
          state = local.updateScore(
            state,
            f.id,
            p1Rank < p2Rank ? 3 : 0,
            p1Rank < p2Rank ? 0 : 3,
          );
        }
      }

      expect(state.phase, LeaguePhase.groupStage);
      expect(state.groupStageComplete, isTrue);
      expect(state.knockoutFixtures, isEmpty);

      state = local.startKnockout(state);

      expect(state.phase, LeaguePhase.knockout);
      expect(state.knockoutFixtures, hasLength(2));
      expect(state.knockoutFixtures.map((f) => f.roundName).toSet(), {
        'Bán kết',
      });
      final qualified = state.knockoutFixtures
          .expand((f) => [f.player1Id, f.player2Id])
          .toSet();
      final expected = state.groups.expand((g) => g.playerIds.take(2)).toSet();
      expect(qualified, expected);
    });

    test('startKnockout rejects khi vòng bảng chưa đủ tỷ số', () {
      final local = LeagueEngine(rng: Random(11));
      final state = local.startTournament(
        List.generate(8, (i) => 'P$i'),
        groupSize: 4,
      );

      expect(() => local.startKnockout(state), throwsArgumentError);
    });

    test('knockout rejects draw, advances rounds, and exposes champion', () {
      final local = LeagueEngine(rng: Random(9));
      var state = local.startTournament(
        List.generate(8, (i) => 'P$i'),
        groupSize: 4,
      );
      for (final group in state.groups) {
        final rankById = {
          for (var i = 0; i < group.playerIds.length; i++)
            group.playerIds[i]: i,
        };
        final fixtures = state.groupFixtures
            .where((f) => f.groupId == group.id)
            .toList();
        for (final f in fixtures) {
          final p1Rank = rankById[f.player1Id]!;
          final p2Rank = rankById[f.player2Id]!;
          state = local.updateScore(
            state,
            f.id,
            p1Rank < p2Rank ? 3 : 0,
            p1Rank < p2Rank ? 0 : 3,
          );
        }
      }
      state = local.startKnockout(state);

      expect(
        () => local.updateScore(state, state.knockoutFixtures.first.id, 1, 1),
        throwsArgumentError,
      );
      expect(() => local.finishTournament(state), throwsArgumentError);

      final semis = state.knockoutFixtures.toList();
      for (final f in semis) {
        state = local.updateScore(state, f.id, 5, 3);
      }
      final finals = state.knockoutFixtures.where(
        (f) => f.roundName == 'Chung kết',
      );
      expect(finals, hasLength(1));

      final finalFixture = finals.single;
      state = local.updateScore(state, finalFixture.id, 7, 4);
      expect(state.knockoutComplete, isTrue);
      expect(state.championId, finalFixture.player1Id);

      state = local.finishTournament(state);
      expect(state.status, LeagueStatus.finished);
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
      final decoded = LeagueState.fromJson(Map<String, dynamic>.from(json));

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
      final decodedPlayed = decoded.fixtures.where((f) => f.isPlayed).length;
      expect(decodedPlayed, origPlayed);
    });

    test(
      'LeagueState.fromJson throws on unknown status (no silent coerce)',
      () {
        expect(
          () => LeagueState.fromJson({
            'status': 'someInvalidStatus',
            'players': <dynamic>[],
            'fixtures': <dynamic>[],
          }),
          throwsFormatException,
        );
      },
    );

    test('LeagueState.fromJson defaults to setup when status missing', () {
      final state = LeagueState.fromJson(<String, dynamic>{
        'players': <dynamic>[],
        'fixtures': <dynamic>[],
      });
      expect(state.status, LeagueStatus.setup);
    });

    test('startTournament assigns unique non-empty id', () {
      final a = engine.startTournament(['A', 'B', 'C']);
      final b = engine.startTournament(['D', 'E', 'F']);
      expect(a.id, isNotEmpty);
      expect(b.id, isNotEmpty);
      expect(a.id, isNot(b.id));
      expect(a.id, startsWith('lg_'));
    });

    test('startTournament stores tournament name', () {
      final state = engine.startTournament([
        'A',
        'B',
        'C',
      ], tournamentName: 'Cúp tối thứ sáu');
      expect(state.name, 'Cúp tối thứ sáu');
      expect(state.displayName, 'Cúp tối thứ sáu');
    });

    test('JSON round-trip preserves id', () {
      final state = engine.startTournament([
        'A',
        'B',
        'C',
      ], tournamentName: 'Cúp nội bộ');
      final decoded = LeagueState.fromJson(
        Map<String, dynamic>.from(state.toJson()),
      );
      expect(decoded.id, state.id);
      expect(decoded.name, state.name);
    });

    test('fromJson falls back to legacy id when id missing or empty', () {
      final s1 = LeagueState.fromJson(<String, dynamic>{
        'status': 'inProgress',
        'players': <dynamic>[],
        'fixtures': <dynamic>[],
        'startedAt': DateTime(2026, 1, 2, 3, 4).toIso8601String(),
      });
      expect(s1.id, startsWith('lg_legacy_'));
      // Cùng startedAt → deterministic id.
      final s2 = LeagueState.fromJson(
        Map<String, dynamic>.from(s1.toJson())..remove('id'),
      );
      expect(s2.id, s1.id);
    });

    test('fromJson tolerates non-string id (int / null)', () {
      final s1 = LeagueState.fromJson(<String, dynamic>{
        'id': 42, // sai type
        'status': 'inProgress',
        'players': <dynamic>[],
        'fixtures': <dynamic>[],
        'startedAt': DateTime(2026, 1, 2).toIso8601String(),
      });
      expect(s1.id, startsWith('lg_legacy_'));

      final s2 = LeagueState.fromJson(<String, dynamic>{
        'id': null,
        'status': 'setup',
        'players': <dynamic>[],
        'fixtures': <dynamic>[],
      });
      expect(s2.id, startsWith('lg_legacy_'));
    });

    test(
      'legacy id avoids collision when startedAt null (uses content hash)',
      () {
        final a = LeagueState.fromJson(<String, dynamic>{
          'status': 'setup',
          'players': <dynamic>[],
          'fixtures': <dynamic>[],
          'finishedAt': '2026-01-01T00:00:00.000',
        });
        final b = LeagueState.fromJson(<String, dynamic>{
          'status': 'setup',
          'players': <dynamic>[],
          'fixtures': <dynamic>[],
          'finishedAt': '2026-02-02T00:00:00.000',
        });
        // Khác payload (finishedAt) → khác id legacy dù cùng null startedAt.
        expect(a.id, isNot(b.id));
      },
    );
  });
}
