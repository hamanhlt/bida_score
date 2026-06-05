import 'dart:convert';

import 'package:bida_score/models/league_session.dart';
import 'package:bida_score/models/league_state.dart';
import 'package:bida_score/providers/active_leagues_controller.dart';
import 'package:bida_score/providers/league_controller.dart';
import 'package:bida_score/providers/league_history_controller.dart';
import 'package:bida_score/providers/league_session_controller.dart';
import 'package:bida_score/services/active_leagues_storage.dart';
import 'package:bida_score/services/league_history_storage.dart';
import 'package:bida_score/services/league_session_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LeagueController multi-active', () {
    test(
      'startTournament adds league to active list (sync via listenSelf)',
      () async {
        final c = ProviderContainer();
        addTearDown(c.dispose);

        c.read(leagueControllerProvider.notifier).startTournament([
          'A',
          'B',
          'C',
        ]);

        final list = c.read(activeLeaguesControllerProvider);
        expect(list, hasLength(1));
        expect(list.first.status, LeagueStatus.inProgress);
        expect(list.first.id, isNotEmpty);
        expect(
          c.read(leagueSessionControllerProvider).currentId,
          list.first.id,
        );
        expect(
          c.read(leagueSessionControllerProvider).viewMode,
          LeagueViewMode.current,
        );
      },
    );

    test(
      'openLeague short-circuits when already opened (no extra upsert)',
      () async {
        final c = ProviderContainer();
        addTearDown(c.dispose);

        final ctrl = c.read(leagueControllerProvider.notifier);
        ctrl.startTournament(['A', 'B', 'C']);
        final league = c.read(activeLeaguesControllerProvider).first;
        final listBefore = c.read(activeLeaguesControllerProvider);

        ctrl.openLeague(league);

        // List instance không đổi vì state.id == league.id → bypass mutation.
        expect(
          identical(c.read(activeLeaguesControllerProvider), listBefore),
          isTrue,
        );
      },
    );

    test(
      'updateScore from list-restored league persists across reset',
      () async {
        final c = ProviderContainer();
        addTearDown(c.dispose);

        final ctrl = c.read(leagueControllerProvider.notifier);
        ctrl.startTournament(['A', 'B', 'C']);
        final fid = c.read(leagueControllerProvider).fixtures.first.id;
        ctrl.updateScore(fid, 5, 2);

        final updated = c.read(activeLeaguesControllerProvider).first;
        final updatedFixture = updated.fixtures.firstWhere((f) => f.id == fid);
        expect(updatedFixture.isPlayed, isTrue);
        expect(updatedFixture.score1, 5);
        expect(updatedFixture.score2, 2);
      },
    );

    test('renameTournament updates active list snapshot', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final ctrl = c.read(leagueControllerProvider.notifier);
      ctrl.startTournament(['A', 'B', 'C'], tournamentName: 'Tên cũ');
      ctrl.renameTournament('Tên mới');

      final state = c.read(leagueControllerProvider);
      final active = c.read(activeLeaguesControllerProvider).first;
      expect(state.name, 'Tên mới');
      expect(active.name, 'Tên mới');
    });

    test('vòng bảng đủ tỷ số vẫn chờ xác nhận rồi mới tạo knockout', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final ctrl = c.read(leagueControllerProvider.notifier);
      ctrl.startTournament(List.generate(8, (i) => 'P$i'), groupSize: 4);

      for (final fixture in c.read(leagueControllerProvider).groupFixtures) {
        ctrl.updateScore(fixture.id, 2, 0);
      }

      var state = c.read(leagueControllerProvider);
      expect(state.groupStageComplete, isTrue);
      expect(state.phase, LeaguePhase.groupStage);
      expect(state.knockoutFixtures, isEmpty);

      ctrl.startKnockout();
      state = c.read(leagueControllerProvider);
      expect(state.phase, LeaguePhase.knockout);
      expect(state.knockoutFixtures, isNotEmpty);
      expect(
        c.read(activeLeaguesControllerProvider).first.phase,
        LeaguePhase.knockout,
      );
    });

    test(
      'two concurrent leagues — edit one doesn\'t affect the other',
      () async {
        final c = ProviderContainer();
        addTearDown(c.dispose);

        final ctrl = c.read(leagueControllerProvider.notifier);
        ctrl.startTournament(['A', 'B', 'C']);
        final leagueA = c.read(activeLeaguesControllerProvider).first;
        ctrl.backToList();

        ctrl.createNew();
        ctrl.startTournament(['D', 'E', 'F']);
        final leagueB = c.read(activeLeaguesControllerProvider).first;
        expect(leagueB.id, isNot(leagueA.id));

        // Edit B.
        final bFixId = leagueB.fixtures.first.id;
        ctrl.updateScore(bFixId, 7, 0);

        // A vẫn nguyên (chưa có trận nào đá).
        final allLeagues = c.read(activeLeaguesControllerProvider);
        final aFromList = allLeagues.firstWhere((l) => l.id == leagueA.id);
        expect(aFromList.matchesPlayed, 0);
        // B đã có 1 trận.
        final bFromList = allLeagues.firstWhere((l) => l.id == leagueB.id);
        expect(bFromList.matchesPlayed, 1);
      },
    );

    test(
      'finishTournament removes from active list + adds to history',
      () async {
        final c = ProviderContainer();
        addTearDown(c.dispose);

        final ctrl = c.read(leagueControllerProvider.notifier);
        ctrl.startTournament(['A', 'B', 'C']);
        final id = c.read(leagueControllerProvider).id;
        await ctrl.finishTournament();

        expect(c.read(activeLeaguesControllerProvider), isEmpty);
        final history = await c.read(leagueHistoryControllerProvider.future);
        expect(history.map((l) => l.id), contains(id));
        expect(history.first.status, LeagueStatus.finished);
      },
    );

    test('cancelTournament removes league, no history entry', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final ctrl = c.read(leagueControllerProvider.notifier);
      ctrl.startTournament(['A', 'B', 'C']);
      ctrl.cancelTournament();

      expect(c.read(activeLeaguesControllerProvider), isEmpty);
      final history = await c.read(leagueHistoryControllerProvider.future);
      expect(history, isEmpty);
      expect(
        c.read(leagueSessionControllerProvider).viewMode,
        LeagueViewMode.list,
      );
    });

    test('cancelTournament guards: noop khi status != inProgress', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final ctrl = c.read(leagueControllerProvider.notifier);
      // Chưa start → setup status → cancel phải noop.
      ctrl.cancelTournament();
      expect(c.read(activeLeaguesControllerProvider), isEmpty);
      expect(c.read(leagueControllerProvider).status, LeagueStatus.setup);
    });

    test('backToList keeps league in active list (resume sau)', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final ctrl = c.read(leagueControllerProvider.notifier);
      ctrl.startTournament(['A', 'B', 'C']);
      final id = c.read(leagueControllerProvider).id;
      ctrl.backToList();

      // List vẫn có giải.
      final list = c.read(activeLeaguesControllerProvider);
      expect(list.map((l) => l.id), contains(id));
      // Session về list view.
      expect(
        c.read(leagueSessionControllerProvider).viewMode,
        LeagueViewMode.list,
      );
    });

    test('build seeds active league from session.currentId', () async {
      final initial = ProviderContainer();
      final ctrl = initial.read(leagueControllerProvider.notifier);
      ctrl.startTournament(['A', 'B', 'C']);
      final fid = initial.read(leagueControllerProvider).fixtures.first.id;
      ctrl.updateScore(fid, 3, 1);
      final state = initial.read(leagueControllerProvider);
      final session = initial.read(leagueSessionControllerProvider);
      initial.dispose();

      // Mô phỏng cold start: seed các provider bằng snapshot.
      final restored = ProviderContainer(
        overrides: [
          activeLeaguesSeedProvider.overrideWithValue([state]),
          leagueSessionSeedProvider.overrideWithValue(session),
        ],
      );
      addTearDown(restored.dispose);

      final restoredState = restored.read(leagueControllerProvider);
      expect(restoredState.id, state.id);
      expect(restoredState.fixtures.firstWhere((f) => f.id == fid).score1, 3);
    });

    test('stale session.currentId → defers goToList → viewMode=list', () async {
      final c = ProviderContainer(
        overrides: [
          activeLeaguesSeedProvider.overrideWithValue(const []),
          leagueSessionSeedProvider.overrideWithValue(
            const LeagueSessionData(
              viewMode: LeagueViewMode.current,
              currentId: 'lg_ghost',
            ),
          ),
        ],
      );
      addTearDown(c.dispose);

      // Đọc state → trigger build → schedule microtask goToList.
      final state = c.read(leagueControllerProvider);
      expect(state.status, LeagueStatus.setup);
      // Chờ microtask flush.
      await Future<void>.delayed(Duration.zero);
      expect(
        c.read(leagueSessionControllerProvider).viewMode,
        LeagueViewMode.list,
      );
    });
  });

  group('LeagueHistoryController', () {
    test('removeLeague filters by id (not finishedAt)', () async {
      // 2 entry cùng finishedAt nhưng id khác → remove 1 không xoá cái kia.
      final at = DateTime(2026, 1, 1);
      final a = LeagueState(
        id: 'lg_a',
        status: LeagueStatus.finished,
        finishedAt: at,
      );
      final b = LeagueState(
        id: 'lg_b',
        status: LeagueStatus.finished,
        finishedAt: at,
      );
      await LeagueHistoryStorage.save([a, b]);

      final c = ProviderContainer();
      addTearDown(c.dispose);

      await c.read(leagueHistoryControllerProvider.notifier).removeLeague(a);

      final after = await c.read(leagueHistoryControllerProvider.future);
      expect(after.map((l) => l.id), ['lg_b']);
    });
  });

  group('ActiveLeaguesStorage', () {
    test('loadAll skips corrupted entry, keeps the rest', () async {
      final good = LeagueState(
        id: 'lg_good',
        status: LeagueStatus.inProgress,
        startedAt: DateTime(2026, 1, 1),
      );
      SharedPreferences.setMockInitialValues({
        'active_leagues_v1': jsonEncode([
          good.toJson(),
          {'status': 'nonsenseInvalid'}, // entry hỏng → bị skip
        ]),
      });

      final loaded = await ActiveLeaguesStorage.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.id, 'lg_good');
    });

    test('loadAll clears legacy key after migration', () async {
      final legacy = LeagueState(
        id: 'lg_legacy_one',
        status: LeagueStatus.inProgress,
        startedAt: DateTime(2025, 12, 31),
      );
      SharedPreferences.setMockInitialValues({
        'active_league_v1': jsonEncode(legacy.toJson()),
      });

      final loaded = await ActiveLeaguesStorage.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.id, 'lg_legacy_one');

      // Legacy key removed.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('active_league_v1'), isFalse);
      // New key được saveAll viết.
      expect(prefs.containsKey('active_leagues_v1'), isTrue);
    });

    test('loadAll cleans legacy key even khi new key đã có', () async {
      final newOne = LeagueState(
        id: 'lg_new',
        status: LeagueStatus.inProgress,
        startedAt: DateTime(2026, 1, 1),
      );
      SharedPreferences.setMockInitialValues({
        'active_leagues_v1': jsonEncode([newOne.toJson()]),
        'active_league_v1': jsonEncode(newOne.toJson()),
      });

      await ActiveLeaguesStorage.loadAll();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('active_league_v1'), isFalse);
    });

    test('saveAll filters non-inProgress entries', () async {
      final inProg = LeagueState(
        id: 'lg_a',
        status: LeagueStatus.inProgress,
        startedAt: DateTime(2026, 1, 1),
      );
      final finished = LeagueState(
        id: 'lg_b',
        status: LeagueStatus.finished,
        finishedAt: DateTime(2026, 1, 1),
      );
      await ActiveLeaguesStorage.saveAll([inProg, finished]);

      final loaded = await ActiveLeaguesStorage.loadAll();
      expect(loaded.map((l) => l.id), ['lg_a']);
    });
  });

  group('LeagueSessionStorage', () {
    test('save/load round-trip', () async {
      const data = LeagueSessionData(
        viewMode: LeagueViewMode.current,
        currentId: 'lg_xyz',
      );
      await LeagueSessionStorage.save(data);
      final loaded = await LeagueSessionStorage.load();
      expect(loaded.viewMode, LeagueViewMode.current);
      expect(loaded.currentId, 'lg_xyz');
    });

    test('load returns initial on corrupted blob', () async {
      SharedPreferences.setMockInitialValues({'league_session_v1': 'not-json'});
      final loaded = await LeagueSessionStorage.load();
      expect(loaded.viewMode, LeagueViewMode.list);
      expect(loaded.currentId, isNull);
    });
  });
}
