import 'dart:convert';

import 'package:bida_score/models/nine_ball_state.dart';
import 'package:bida_score/models/pool_session.dart';
import 'package:bida_score/providers/active_pools_controller.dart';
import 'package:bida_score/providers/match_history_controller.dart';
import 'package:bida_score/providers/nine_ball_controller.dart';
import 'package:bida_score/providers/pool_session_controller.dart';
import 'package:bida_score/services/active_pools_storage.dart';
import 'package:bida_score/services/pool_session_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NineBallController multi-active', () {
    test('startGame thêm trận vào active list + session current', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      c.read(nineBallControllerProvider.notifier).startGame(['An', 'Bình'], 5);

      final list = c.read(activePoolsControllerProvider);
      expect(list, hasLength(1));
      expect(list.first.status, NineBallStatus.inProgress);
      expect(list.first.id, isNotEmpty);
      expect(c.read(poolSessionControllerProvider).currentId, list.first.id);
      expect(
        c.read(poolSessionControllerProvider).viewMode,
        PoolViewMode.current,
      );
    });

    test('openMatch short-circuit khi đã mở đúng trận', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final ctrl = c.read(nineBallControllerProvider.notifier);
      ctrl.startGame(['An', 'Bình'], 5);
      final match = c.read(activePoolsControllerProvider).first;
      final listBefore = c.read(activePoolsControllerProvider);

      ctrl.openMatch(match);

      expect(
        identical(c.read(activePoolsControllerProvider), listBefore),
        isTrue,
      );
    });

    test('winRack persist vào active list', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final ctrl = c.read(nineBallControllerProvider.notifier);
      ctrl.startGame(['An', 'Bình'], 5);
      ctrl.winRack(0);

      final updated = c.read(activePoolsControllerProvider).first;
      expect(updated.rackWins[0], 1);
      expect(updated.status, NineBallStatus.inProgress);
    });

    test('2 trận song song — sửa trận này không ảnh hưởng trận kia', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final ctrl = c.read(nineBallControllerProvider.notifier);
      ctrl.startGame(['An', 'Bình'], 5);
      final matchA = c.read(activePoolsControllerProvider).first;
      ctrl.backToList();

      ctrl.createNew();
      ctrl.startGame(['Cường', 'Dũng'], 5);
      final matchB = c.read(activePoolsControllerProvider).first;
      expect(matchB.id, isNot(matchA.id));

      ctrl.winRack(0); // trận B

      final all = c.read(activePoolsControllerProvider);
      expect(all.firstWhere((m) => m.id == matchA.id).rackWins[0], 0);
      expect(all.firstWhere((m) => m.id == matchB.id).rackWins[0], 1);
    });

    test('đạt race target → finished → remove khỏi list + ghi lịch sử',
        () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final ctrl = c.read(nineBallControllerProvider.notifier);
      ctrl.startGame(['An', 'Bình'], 1, variantLabel: '9-Ball');
      ctrl.winRack(0); // race 1 → finished ngay

      expect(c.read(nineBallControllerProvider).status,
          NineBallStatus.finished);
      expect(c.read(activePoolsControllerProvider), isEmpty);

      final history = await c.read(matchHistoryControllerProvider.future);
      expect(history, hasLength(1));
      expect(history.first.modeLabel, '9-Ball');
      // Log thao tác đi kèm vào lịch sử chung (time + +1/−1).
      expect(history.first.poolLog, hasLength(1));
      expect(history.first.poolLog.first.delta, 1);
      expect(history.first.poolLog.first.playerName, 'An');
    });

    test('cancelMatch xoá khỏi list, không ghi lịch sử, về list view',
        () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final ctrl = c.read(nineBallControllerProvider.notifier);
      ctrl.startGame(['An', 'Bình'], 5);
      ctrl.cancelMatch();

      expect(c.read(activePoolsControllerProvider), isEmpty);
      final history = await c.read(matchHistoryControllerProvider.future);
      expect(history, isEmpty);
      expect(
        c.read(poolSessionControllerProvider).viewMode,
        PoolViewMode.list,
      );
    });

    test('backToList giữ trận trong active list (resume sau)', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final ctrl = c.read(nineBallControllerProvider.notifier);
      ctrl.startGame(['An', 'Bình'], 5);
      final id = c.read(nineBallControllerProvider).id;
      ctrl.backToList();

      expect(
        c.read(activePoolsControllerProvider).map((m) => m.id),
        contains(id),
      );
      expect(
        c.read(poolSessionControllerProvider).viewMode,
        PoolViewMode.list,
      );
    });

    test('build seed trận từ session.currentId (cold start)', () {
      final initial = ProviderContainer();
      final ctrl = initial.read(nineBallControllerProvider.notifier);
      ctrl.startGame(['An', 'Bình'], 5);
      ctrl.winRack(0);
      final state = initial.read(nineBallControllerProvider);
      final session = initial.read(poolSessionControllerProvider);
      initial.dispose();

      final restored = ProviderContainer(
        overrides: [
          activePoolsSeedProvider.overrideWithValue([state]),
          poolSessionSeedProvider.overrideWithValue(session),
        ],
      );
      addTearDown(restored.dispose);

      final restoredState = restored.read(nineBallControllerProvider);
      expect(restoredState.id, state.id);
      expect(restoredState.rackWins[0], 1);
      expect(restoredState.status, NineBallStatus.inProgress);
    });

    test('stale session.currentId → defer goToList → viewMode=list', () async {
      final c = ProviderContainer(
        overrides: [
          activePoolsSeedProvider.overrideWithValue(const []),
          poolSessionSeedProvider.overrideWithValue(
            const PoolSessionData(
              viewMode: PoolViewMode.current,
              currentId: 'pool_ghost',
            ),
          ),
        ],
      );
      addTearDown(c.dispose);

      final state = c.read(nineBallControllerProvider);
      expect(state.status, NineBallStatus.setup);
      await Future<void>.delayed(Duration.zero);
      expect(
        c.read(poolSessionControllerProvider).viewMode,
        PoolViewMode.list,
      );
    });
  });

  group('NineBall log thao tác', () {
    test('winRack +1, decrementWin −1 — đúng delta + tỷ số chạy', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final ctrl = c.read(nineBallControllerProvider.notifier);
      ctrl.startGame(['An', 'Bình'], 5);
      // Kịch bản của user: bấm nhầm An thắng, sửa lại −1 An rồi +1 Bình.
      ctrl.winRack(0); // +1 An
      ctrl.decrementWin(0); // −1 An (sửa nhầm)
      ctrl.winRack(1); // +1 Bình

      final log = c.read(nineBallControllerProvider).log;
      expect(log, hasLength(3));
      expect(log[0].playerName, 'An');
      expect(log[0].delta, 1);
      expect(log[0].winsAfter, [1, 0]);
      expect(log[1].playerName, 'An');
      expect(log[1].delta, -1);
      expect(log[1].winsAfter, [0, 0]);
      expect(log[2].playerName, 'Bình');
      expect(log[2].delta, 1);
      expect(log[2].winsAfter, [0, 1]);
    });

    test('undo gỡ luôn entry log cuối', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final ctrl = c.read(nineBallControllerProvider.notifier);
      ctrl.startGame(['An', 'Bình'], 5);
      ctrl.winRack(0);
      expect(c.read(nineBallControllerProvider).log, hasLength(1));
      ctrl.undo();
      expect(c.read(nineBallControllerProvider).log, isEmpty);
    });

    test('log round-trip qua JSON (persist + restore)', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final ctrl = c.read(nineBallControllerProvider.notifier);
      ctrl.startGame(['An', 'Bình'], 5);
      ctrl.winRack(0);
      ctrl.winRack(1);
      final state = c.read(nineBallControllerProvider);

      final restored = NineBallState.fromJson(state.toJson());
      expect(restored.log, hasLength(2));
      expect(restored.log[0].playerName, 'An');
      expect(restored.log[0].delta, 1);
      expect(restored.log[1].playerName, 'Bình');
      expect(restored.log[1].winsAfter, [1, 1]);
    });
  });

  group('ActivePoolsStorage', () {
    NineBallState mkMatch(String id, NineBallStatus status) => NineBallState(
          players: const [],
          rackWins: const [0, 0],
          raceTarget: 5,
          status: status,
          id: id,
          startedAt: DateTime(2026, 1, 1),
        );

    test('loadAll skip entry hỏng, giữ phần còn lại', () async {
      final good = mkMatch('pool_good', NineBallStatus.inProgress);
      SharedPreferences.setMockInitialValues({
        'active_pools_v1': jsonEncode([
          good.toJson(),
          {'status': 'nonsenseInvalid'},
        ]),
      });

      final loaded = await ActivePoolsStorage.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.id, 'pool_good');
    });

    test('loadAll migrate legacy single key', () async {
      final legacy = mkMatch('pool_legacy', NineBallStatus.inProgress);
      SharedPreferences.setMockInitialValues({
        'active_pool_state_v1': jsonEncode(legacy.toJson()),
      });

      final loaded = await ActivePoolsStorage.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.id, 'pool_legacy');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('active_pool_state_v1'), isFalse);
      expect(prefs.containsKey('active_pools_v1'), isTrue);
    });

    test('saveAll lọc bỏ entry không inProgress', () async {
      await ActivePoolsStorage.saveAll([
        mkMatch('pool_a', NineBallStatus.inProgress),
        mkMatch('pool_b', NineBallStatus.finished),
      ]);

      final loaded = await ActivePoolsStorage.loadAll();
      expect(loaded.map((m) => m.id), ['pool_a']);
    });
  });

  group('PoolSessionStorage', () {
    test('save/load round-trip', () async {
      const data = PoolSessionData(
        viewMode: PoolViewMode.current,
        currentId: 'pool_xyz',
      );
      await PoolSessionStorage.save(data);
      final loaded = await PoolSessionStorage.load();
      expect(loaded.viewMode, PoolViewMode.current);
      expect(loaded.currentId, 'pool_xyz');
    });

    test('load trả initial khi blob hỏng', () async {
      SharedPreferences.setMockInitialValues({'pool_session_v1': 'not-json'});
      final loaded = await PoolSessionStorage.load();
      expect(loaded.viewMode, PoolViewMode.list);
      expect(loaded.currentId, isNull);
    });
  });
}
