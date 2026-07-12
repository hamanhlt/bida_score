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
      // Vẫn còn trận tranh 3-4 chưa đá → knockoutComplete = false.
      expect(state.knockoutComplete, isFalse);
      expect(state.championId, finalFixture.player1Id);
      expect(() => local.finishTournament(state), throwsArgumentError);

      final thirdPlace = state.thirdPlaceFixture;
      expect(thirdPlace, isNotNull);
      state = local.updateScore(state, thirdPlace!.id, 5, 2);
      expect(state.knockoutComplete, isTrue);

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

    test('head-to-head ưu tiên trước GD/GF khi đúng 2 player cùng điểm', () {
      // Scenario 4 player: A và B cùng 2 điểm, C và D cùng 1 điểm.
      // A vs B: B thắng đối đầu. A đại thắng C, D → overall HS của A
      // tốt hơn B nhiều. Nhưng H2H phải đưa B trên A.
      var state = engine.startTournament(['A', 'B', 'C', 'D']);
      final ids = {for (final p in state.players) p.name: p.id};
      final a = ids['A']!, b = ids['B']!, c = ids['C']!, d = ids['D']!;
      void play(String x, String y, int sx, int sy) {
        final f = state.fixtures.firstWhere(
          (f) => {f.player1Id, f.player2Id}.containsAll({x, y}),
        );
        state = engine.updateScore(
          state,
          f.id,
          f.player1Id == x ? sx : sy,
          f.player1Id == x ? sy : sx,
        );
      }

      // A: thắng C 10-0, thắng D 10-0, thua B 1-5 → 2 pts, GF=21, HS=+16.
      // B: thắng A 5-1, thắng C 5-3, thua D 0-1 → 2 pts, GF=10, HS=+5.
      // C: thua A, thua B, thắng D 1-0 → 1 pt.
      // D: thua A, thắng B 1-0, thua C 0-1 → 1 pt.
      play(a, c, 10, 0);
      play(a, d, 10, 0);
      play(b, a, 5, 1);
      play(b, c, 5, 3);
      play(b, d, 0, 1);
      play(c, d, 1, 0);

      final pA = state.players.firstWhere((p) => p.id == a);
      final pB = state.players.firstWhere((p) => p.id == b);
      expect(pA.points, 2);
      expect(pB.points, 2);
      // Overall HS: A=+16 cao hơn B=+5. Without H2H A sẽ xếp trên.
      expect(pA.goalDifference, greaterThan(pB.goalDifference));

      final rankOfB = state.players.indexWhere((p) => p.id == b);
      final rankOfA = state.players.indexWhere((p) => p.id == a);
      expect(
        rankOfB,
        lessThan(rankOfA),
        reason: 'B thắng đối đầu A nên B phải xếp trên dù HS A tốt hơn',
      );

      // Tier C/D: D thắng B (1-0), C thắng D (1-0). H2H giữa C và D:
      // C thắng D → C trên D.
      final rankOfC = state.players.indexWhere((p) => p.id == c);
      final rankOfD = state.players.indexWhere((p) => p.id == d);
      expect(
        rankOfC,
        lessThan(rankOfD),
        reason: 'C thắng D đối đầu nên C phải xếp trên',
      );
    });

    test(
      'H2H trong vòng bảng — chỉ tính trận giữa các player tied trong cùng bảng',
      () {
        final local = LeagueEngine(rng: Random(123));
        var state = local.startTournament(
          const [],
          manualGroups: const [
            ['A1', 'A2', 'A3'],
            ['B1', 'B2', 'B3'],
          ],
        );
        // Bảng A: A1 thắng A2 5-1, A1 thua A3 0-9, A2 thắng A3 3-0.
        // A1, A2, A3 đều 1 điểm. H2H pairwise wins: mỗi người 1W-1L
        // (Condorcet cycle) → mini-points đều =1 → fall through xuống
        // overall GD. Overall trùng tier (chỉ gặp nhau trong nhóm) →
        // A3 GD=+6, A2 GD=-1, A1 GD=-5 → A3 → A2 → A1.
        final a1 = state.players.firstWhere((p) => p.name == 'A1').id;
        final a2 = state.players.firstWhere((p) => p.name == 'A2').id;
        final a3 = state.players.firstWhere((p) => p.name == 'A3').id;
        for (final f in state.groupFixtures.where(
          (f) =>
              {f.player1Id, f.player2Id}.contains(a1) ||
              {f.player1Id, f.player2Id}.contains(a2) ||
              {f.player1Id, f.player2Id}.contains(a3),
        )) {
          final ids = {f.player1Id, f.player2Id};
          int s1 = 0, s2 = 0;
          if (ids.containsAll({a1, a2})) {
            s1 = f.player1Id == a1 ? 5 : 1;
            s2 = f.player1Id == a1 ? 1 : 5;
          } else if (ids.containsAll({a1, a3})) {
            s1 = f.player1Id == a3 ? 9 : 0;
            s2 = f.player1Id == a3 ? 0 : 9;
          } else if (ids.containsAll({a2, a3})) {
            s1 = f.player1Id == a2 ? 3 : 0;
            s2 = f.player1Id == a2 ? 0 : 3;
          }
          state = local.updateScore(state, f.id, s1, s2);
        }
        // Bảng B: bỏ trống, không cần.
        final groupA = state.groups[0];
        final ranking = state.playersInGroup(groupA);
        // Expect: A3 → A2 → A1 dựa trên mini-GD.
        expect(ranking[0].id, a3);
        expect(ranking[1].id, a2);
        expect(ranking[2].id, a1);
      },
    );

    test('3-cycle tied: Condorcet cycle → fall back overall HS/GF (không '
        'dùng mini-GD)', () {
      // Reproduce screenshot: 4 player vòng bảng.
      // Tất cả 3 player tied 2 điểm thắng/thua chéo lẫn nhau (cycle).
      // Mini-GD sẽ ưu tiên Việt-Phú Đô (đại thắng CAV 10-1) nhưng spec
      // mới: cycle → fall xuống overall. Việt Anh có overall GF cao hơn
      // nhờ thắng đậm A Dũng 15-3 → Việt Anh lên #1.
      final local = LeagueEngine(rng: Random(99));
      var state = local.startTournament(
        const [],
        manualGroups: const [
          ['Việt-Phú Đô', 'Việt Anh', 'Công An Viên', 'A Dũng TST'],
          ['HIẾU', 'Lê Văn Chương'],
        ],
      );
      final ids = {for (final p in state.players) p.name: p.id};
      final vpd = ids['Việt-Phú Đô']!;
      final va = ids['Việt Anh']!;
      final cav = ids['Công An Viên']!;
      final adt = ids['A Dũng TST']!;
      void play(String x, String y, int sx, int sy) {
        final f = state.groupFixtures.firstWhere(
          (f) => {f.player1Id, f.player2Id}.containsAll({x, y}),
        );
        state = local.updateScore(
          state,
          f.id,
          f.player1Id == x ? sx : sy,
          f.player1Id == x ? sy : sx,
        );
      }

      // Đúng theo screenshot.
      play(vpd, adt, 3, 2);
      play(cav, adt, 1, 0);
      play(va, vpd, 5, 4);
      play(va, cav, 2, 6);
      play(vpd, cav, 10, 1);
      play(va, adt, 15, 3);

      // Tất cả 3 tied 2 điểm với 1 win 1 loss trong tier (cycle).
      final groupA = state.groups[0];
      final ranking = state.playersInGroup(groupA);
      // Spec mới: cycle → overall HS → overall GF.
      // Việt Anh: HS=+9, GF=22 → #1.
      // Việt-Phú Đô: HS=+9, GF=17 → #2.
      // CAV: HS=-4 → #3.
      // A Dũng: 0 đ → #4.
      expect(ranking[0].id, va);
      expect(ranking[1].id, vpd);
      expect(ranking[2].id, cav);
      expect(ranking[3].id, adt);
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

    // ─────── Manual groups (user-defined bảng) ───────

    test('startTournament với manualGroups sinh bảng đúng layout', () {
      final local = LeagueEngine(rng: Random(7));
      final state = local.startTournament(
        const [],
        tournamentName: 'Giải tay',
        manualGroups: const [
          ['A1', 'A2', 'A3', 'A4'],
          ['B1', 'B2', 'B3', 'B4'],
        ],
      );
      expect(state.usesGroupStage, isTrue);
      expect(state.groups, hasLength(2));
      expect(state.groups[0].name, 'Bảng A');
      expect(state.groups[1].name, 'Bảng B');
      expect(state.groups[0].playerIds, hasLength(4));
      expect(state.groups[1].playerIds, hasLength(4));
      expect(state.groupFixtures, hasLength(12));
      expect(state.knockoutFixtures, isEmpty);
    });

    test('manualGroups: bảng có size khác nhau', () {
      final local = LeagueEngine(rng: Random(7));
      final state = local.startTournament(
        const [],
        manualGroups: const [
          ['A1', 'A2', 'A3'],
          ['B1', 'B2', 'B3'],
          ['C1', 'C2', 'C3', 'C4'],
        ],
      );
      expect(state.groups, hasLength(3));
      expect(state.groups[2].playerIds, hasLength(4));
      expect(state.groupFixtures, hasLength(12));
    });

    test('manualGroups reject: <2 bảng', () {
      final local = LeagueEngine(rng: Random(7));
      expect(
        () => local.startTournament(
          const [],
          manualGroups: const [
            ['A1', 'A2', 'A3'],
          ],
        ),
        throwsArgumentError,
      );
    });

    test('manualGroups reject: bảng có <2 người', () {
      final local = LeagueEngine(rng: Random(7));
      expect(
        () => local.startTournament(
          const [],
          manualGroups: const [
            ['A1'],
            ['B1', 'B2'],
          ],
        ),
        throwsArgumentError,
      );
    });

    test('manualGroups reject: tên trùng xuyên bảng', () {
      final local = LeagueEngine(rng: Random(7));
      expect(
        () => local.startTournament(
          const [],
          manualGroups: const [
            ['X', 'A2'],
            ['X', 'B2'],
          ],
        ),
        throwsArgumentError,
      );
    });

    // ─────── 3rd-place playoff ───────

    test('semifinals advance sinh thêm trận tranh 3-4', () {
      final local = LeagueEngine(rng: Random(31));
      var state = local.startTournament(
        const [],
        manualGroups: const [
          ['A1', 'A2', 'A3', 'A4'],
          ['B1', 'B2', 'B3', 'B4'],
        ],
      );
      // Đá hết vòng bảng — A1, A2 lên top bảng A; B1, B2 top bảng B.
      for (final group in state.groups) {
        final ranking = {
          for (var i = 0; i < group.playerIds.length; i++)
            group.playerIds[i]: i,
        };
        for (final f in state.groupFixtures.where(
          (f) => f.groupId == group.id,
        )) {
          state = local.updateScore(
            state,
            f.id,
            ranking[f.player1Id]! < ranking[f.player2Id]! ? 3 : 0,
            ranking[f.player1Id]! < ranking[f.player2Id]! ? 0 : 3,
          );
        }
      }
      state = local.startKnockout(state);
      expect(state.knockoutFixtures, hasLength(2));
      expect(state.thirdPlaceFixture, isNull);

      final semiIds = state.knockoutFixtures.map((f) => f.id).toList();
      for (final fid in semiIds) {
        state = local.updateScore(state, fid, 5, 2);
      }
      expect(state.knockoutFixtures, hasLength(4));
      expect(state.thirdPlaceFixture, isNotNull);
      expect(state.finalFixture, isNotNull);
      expect(
        state.thirdPlaceFixture!.roundIndex,
        state.finalFixture!.roundIndex,
      );
      // Tính losers từ state CUỐI (đã update score), không từ semis stale.
      final playedSemis = state.knockoutFixtures
          .where((f) => f.roundName == 'Bán kết')
          .toList();
      final loserIds = playedSemis
          .map((f) => f.score1 > f.score2 ? f.player2Id : f.player1Id)
          .toSet();
      expect({
        state.thirdPlaceFixture!.player1Id,
        state.thirdPlaceFixture!.player2Id,
      }, loserIds);
    });

    test('3rd-place getters + knockoutComplete cần cả 2 trận đá xong', () {
      final local = LeagueEngine(rng: Random(33));
      var state = local.startTournament(
        const [],
        manualGroups: const [
          ['A1', 'A2', 'A3'],
          ['B1', 'B2', 'B3'],
        ],
      );
      for (final group in state.groups) {
        final ranking = {
          for (var i = 0; i < group.playerIds.length; i++)
            group.playerIds[i]: i,
        };
        for (final f in state.groupFixtures.where(
          (f) => f.groupId == group.id,
        )) {
          state = local.updateScore(
            state,
            f.id,
            ranking[f.player1Id]! < ranking[f.player2Id]! ? 3 : 0,
            ranking[f.player1Id]! < ranking[f.player2Id]! ? 0 : 3,
          );
        }
      }
      state = local.startKnockout(state);
      for (final f in state.knockoutFixtures.toList()) {
        state = local.updateScore(state, f.id, 5, 2);
      }
      final third = state.thirdPlaceFixture!;
      final fin = state.finalFixture!;
      state = local.updateScore(state, fin.id, 7, 4);
      expect(state.knockoutComplete, isFalse);
      expect(state.championId, isNotNull);
      expect(state.thirdPlaceWinnerId, isNull);

      state = local.updateScore(state, third.id, 6, 3);
      expect(state.knockoutComplete, isTrue);
      expect(state.thirdPlaceWinnerId, third.player1Id);
      expect(state.fourthPlaceId, third.player2Id);
    });

    test('finalFixture skip trận tranh 3-4 khi tính chung kết', () {
      final state = LeagueState(
        id: 'lg_test',
        status: LeagueStatus.inProgress,
        phase: LeaguePhase.knockout,
        players: const [],
        groups: const [],
        fixtures: const [
          MatchFixture(
            id: 'ko_2_1',
            player1Id: 'a',
            player2Id: 'b',
            stage: MatchStage.knockout,
            roundIndex: 2,
            roundName: 'Chung kết',
          ),
          MatchFixture(
            id: 'ko_2_3rd',
            player1Id: 'c',
            player2Id: 'd',
            stage: MatchStage.knockout,
            roundIndex: 2,
            roundName: 'Tranh 3-4',
          ),
        ],
      );
      expect(state.finalFixture?.id, 'ko_2_1');
      expect(state.thirdPlaceFixture?.id, 'ko_2_3rd');
    });

    // ─────── Double Elimination ───────

    test('startDoubleElim reject size không hỗ trợ', () {
      final local = LeagueEngine(rng: Random(1));
      expect(() => local.startDoubleElim(['A', 'B', 'C']), throwsArgumentError);
      expect(
        () => local.startDoubleElim(['A', 'B', 'C', 'D', 'E', 'F']),
        throwsArgumentError,
      );
    });

    test('startDoubleElim N=4: tổng 6 trận (3 WB + 2 LB + 1 GF)', () {
      final local = LeagueEngine(rng: Random(1));
      final state = local.startDoubleElim(['A', 'B', 'C', 'D']);
      expect(state.usesDoubleElim, isTrue);
      expect(state.fixtures, hasLength(6));
      expect(state.winnersFixtures, hasLength(3)); // 2 + 1
      expect(state.losersFixtures, hasLength(2)); // 1 + 1
      expect(state.grandFinalFixture, isNotNull);

      // WB R1: 2 trận có người sẵn.
      final wbR1 = state.winnersFixtures
          .where((f) => f.roundIndex == 1)
          .toList();
      expect(wbR1, hasLength(2));
      for (final f in wbR1) {
        expect(f.isReady, isTrue);
      }
      // LB R1 nhận thua WB R1; LB R2 nhận thua WB final.
      final lbR1 = state.losersFixtures.singleWhere((f) => f.roundIndex == 1);
      expect(lbR1.sourceLoserOfP1Id, 'wb_r1_m1');
      expect(lbR1.sourceLoserOfP2Id, 'wb_r1_m2');
      final lbR2 = state.losersFixtures.singleWhere((f) => f.roundIndex == 2);
      expect(lbR2.sourceWinnerOfP1Id, 'lb_r1_m1');
      expect(lbR2.sourceLoserOfP2Id, 'wb_r2_m1');
    });

    test('chơi xong toàn bộ bracket N=4 → champion = GF winner', () {
      final local = LeagueEngine(rng: Random(3));
      var state = local.startDoubleElim(['A', 'B', 'C', 'D']);
      var guard = 0;
      while (!state.doubleElimComplete && guard < 50) {
        guard++;
        final ready = state.fixtures.firstWhere(
          (f) => f.isReady && !f.isPlayed,
          orElse: () => throw StateError('Không còn trận ready để đá.'),
        );
        state = local.updateScore(state, ready.id, 5, 1);
      }
      expect(state.doubleElimComplete, isTrue);
      expect(state.championId, isNotNull);
      expect(state.runnerUpId, isNotNull);
      state = local.finishTournament(state);
      expect(state.status, LeagueStatus.finished);
    });

    test('startDoubleElim N=8: tổng 13 trận (7 WB + 5 LB + 1 GF)', () {
      final local = LeagueEngine(rng: Random(1));
      final state = local.startDoubleElim(
        List.generate(8, (i) => 'P${i + 1}'),
        tournamentName: 'Test',
      );
      expect(state.usesDoubleElim, isTrue);
      expect(state.format, LeagueFormat.doubleElim);
      expect(state.fixtures, hasLength(13));
      expect(state.winnersFixtures, hasLength(7)); // 4+2+1
      expect(state.losersFixtures, hasLength(5)); // 2+2+1
      expect(state.grandFinalFixture, isNotNull);

      // WB R1: 4 trận, players điền đầy đủ.
      final wbR1 = state.winnersFixtures
          .where((f) => f.roundIndex == 1)
          .toList();
      expect(wbR1, hasLength(4));
      for (final f in wbR1) {
        expect(f.player1Id, isNotEmpty);
        expect(f.player2Id, isNotEmpty);
      }

      // WB R2: placeholder, sources = winners của WB R1.
      final wbR2 = state.winnersFixtures
          .where((f) => f.roundIndex == 2)
          .toList();
      expect(wbR2, hasLength(2));
      expect(wbR2.first.player1Id, isEmpty);
      expect(wbR2.first.player2Id, isEmpty);
      expect(wbR2.first.sourceWinnerOfP1Id, 'wb_r1_m1');
      expect(wbR2.first.sourceWinnerOfP2Id, 'wb_r1_m2');

      // LB R1: placeholder, sources = losers của WB R1.
      final lbR1 = state.losersFixtures
          .where((f) => f.roundIndex == 1)
          .toList();
      expect(lbR1, hasLength(2));
      expect(lbR1.first.sourceLoserOfP1Id, 'wb_r1_m1');
      expect(lbR1.first.sourceLoserOfP2Id, 'wb_r1_m2');

      // GF placeholder.
      final gf = state.grandFinalFixture!;
      expect(gf.sourceWinnerOfP1Id, 'wb_r3_m1');
      expect(gf.sourceWinnerOfP2Id, 'lb_r3_m1');
      expect(
        state.fixtures.any(
          (f) =>
              f.sourceLoserOfP1Id == 'wb_r3_m1' ||
              f.sourceLoserOfP2Id == 'wb_r3_m1',
        ),
        isFalse,
      );
    });

    test('startDoubleElim N=16: tổng 27 trận (15 WB + 11 LB + 1 GF)', () {
      final local = LeagueEngine(rng: Random(1));
      final state = local.startDoubleElim(
        List.generate(16, (i) => 'P${i + 1}'),
      );
      expect(state.fixtures, hasLength(27));
      expect(state.winnersFixtures, hasLength(15)); // 8+4+2+1
      expect(state.losersFixtures, hasLength(11)); // 4+4+2+1
    });

    test(
      'updateScore double-elim cascade: winner đẩy lên WB R2, loser xuống LB R1',
      () {
        final local = LeagueEngine(rng: Random(1));
        var state = local.startDoubleElim(List.generate(8, (i) => 'P${i + 1}'));
        final a = state.players[0].id;
        final b = state.players[1].id;
        final wbR1m1 = state.fixtures.firstWhere((f) => f.id == 'wb_r1_m1');
        // A wins.
        state = local.updateScore(
          state,
          'wb_r1_m1',
          wbR1m1.player1Id == a ? 5 : 1,
          wbR1m1.player1Id == a ? 1 : 5,
        );
        // WB R2 m1 player1 = A (winner of wb_r1_m1).
        final wbR2 = state.fixtures.firstWhere((f) => f.id == 'wb_r2_m1');
        expect(wbR2.player1Id, a);
        expect(wbR2.player2Id, isEmpty); // wb_r1_m2 chưa đá.
        // LB R1 m1 player1 = B (loser of wb_r1_m1).
        final lbR1 = state.fixtures.firstWhere((f) => f.id == 'lb_r1_m1');
        expect(lbR1.player1Id, b);
      },
    );

    test('chơi xong toàn bộ bracket N=8 → champion = GF winner', () {
      final local = LeagueEngine(rng: Random(1));
      var state = local.startDoubleElim(List.generate(8, (i) => 'P${i + 1}'));

      var guard = 0;
      while (!state.doubleElimComplete && guard < 100) {
        guard++;
        final ready = state.fixtures.firstWhere(
          (f) => f.isReady && !f.isPlayed,
          orElse: () => throw StateError('Không còn trận ready để đá.'),
        );
        state = local.updateScore(state, ready.id, 5, 1);
      }

      expect(state.doubleElimComplete, isTrue);
      expect(state.championId, isNotNull);
      expect(state.runnerUpId, isNotNull);
      state = local.finishTournament(state);
      expect(state.status, LeagueStatus.finished);
    });

    test('finishTournament double-elim chưa xong → throw', () {
      final local = LeagueEngine(rng: Random(1));
      final state = local.startDoubleElim(List.generate(8, (i) => 'P${i + 1}'));
      expect(() => local.finishTournament(state), throwsArgumentError);
    });

    test('updateScore double-elim reject hoà', () {
      final local = LeagueEngine(rng: Random(1));
      final state = local.startDoubleElim(List.generate(8, (i) => 'P${i + 1}'));
      expect(
        () => local.updateScore(state, 'wb_r1_m1', 3, 3),
        throwsArgumentError,
      );
    });

    test('updateScore double-elim reject khi fixture chưa ready', () {
      final local = LeagueEngine(rng: Random(1));
      final state = local.startDoubleElim(List.generate(8, (i) => 'P${i + 1}'));
      // wb_r2_m1 chưa có người (WB R1 chưa đá).
      expect(
        () => local.updateScore(state, 'wb_r2_m1', 5, 1),
        throwsArgumentError,
      );
    });

    test('clearScore double-elim cascade invalidate descendants', () {
      final local = LeagueEngine(rng: Random(1));
      var state = local.startDoubleElim(List.generate(8, (i) => 'P${i + 1}'));
      final a = state.players[0].id;
      final c = state.players[2].id;

      void play(String fixtureId, String winnerId) {
        final f = state.fixtures.firstWhere((x) => x.id == fixtureId);
        final p1Wins = f.player1Id == winnerId;
        state = local.updateScore(
          state,
          fixtureId,
          p1Wins ? 5 : 0,
          p1Wins ? 0 : 5,
        );
      }

      play('wb_r1_m1', a);
      play('wb_r1_m2', c);
      play('wb_r2_m1', a); // WB Final played.

      // Clear WB R1 m1 → WB R2 và LB R1 (slot phụ thuộc) phải clear.
      state = local.clearScore(state, 'wb_r1_m1');
      final wbR2 = state.fixtures.firstWhere((f) => f.id == 'wb_r2_m1');
      expect(wbR2.isPlayed, isFalse);
      expect(wbR2.player1Id, isEmpty);
      // Player2 vẫn còn (winner của wb_r1_m2).
      expect(wbR2.player2Id, c);
      final lbR1 = state.fixtures.firstWhere((f) => f.id == 'lb_r1_m1');
      expect(lbR1.player1Id, isEmpty);
    });

    test('sửa winner double-elim reset slot chung kết tổng bị phụ thuộc', () {
      final local = LeagueEngine(rng: Random(1));
      var state = local.startDoubleElim(List.generate(8, (i) => 'P${i + 1}'));

      String idOf(String name) =>
          state.players.firstWhere((p) => p.name == name).id;

      void play(String fixtureId, String winnerId) {
        final f = state.fixtures.firstWhere((x) => x.id == fixtureId);
        final p1Wins = f.player1Id == winnerId;
        state = local.updateScore(
          state,
          fixtureId,
          p1Wins ? 5 : 1,
          p1Wins ? 1 : 5,
        );
      }

      final p1 = idOf('P1');
      final p4 = idOf('P4');
      final p5 = idOf('P5');
      final p6 = idOf('P6');

      play('wb_r1_m1', p1);
      play('wb_r1_m2', idOf('P3'));
      play('wb_r1_m3', p5);
      play('wb_r1_m4', idOf('P7'));
      play('wb_r2_m1', p1);
      play('wb_r2_m2', p5);
      play('lb_r1_m1', p4);
      play('lb_r1_m2', p6);
      play('lb_r2_m1', p4);
      play('lb_r2_m2', p6);
      play('lb_r3_m1', p6);
      play('wb_r3_m1', p5);

      expect(state.grandFinalFixture!.player1Id, p5);
      expect(state.grandFinalFixture!.player2Id, p6);
      play('gf_1', p5);
      expect(state.grandFinalFixture!.isPlayed, isTrue);

      // Đổi kết quả LB R3: P4 mới là người vào chung kết tổng. GF đã đá nên
      // phải reset và không được giữ P6 cũ ở slot nhánh thua.
      play('lb_r3_m1', p4);

      final gfAfterEdit = state.grandFinalFixture!;
      expect(gfAfterEdit.player1Id, p5);
      expect(gfAfterEdit.player2Id, p4);
      expect(gfAfterEdit.isPlayed, isFalse);
    });
  });
}
