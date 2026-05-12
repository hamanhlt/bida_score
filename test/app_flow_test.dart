import 'package:bida_score/app.dart';
import 'package:bida_score/models/game_snapshot.dart';
import 'package:bida_score/providers/game_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('App flow', () {
    testWidgets('setup validation blocks invalid player lists', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildApp(container));
      await _selectMode(tester);

      await tester.enterText(find.byKey(const ValueKey('player_name_0')), '');
      await _tapVisible(tester, find.text('Bắt đầu'));
      await tester.pumpAndSettle();

      expect(find.text('Mỗi người chơi cần có tên.'), findsOneWidget);
      expect(container.read(gameControllerProvider).status, GameStatus.setup);
    });

    testWidgets(
      'game flow: shooter → ball → victim auto-applies and resets draft',
      (tester) async {
        _setLargeViewport(tester);
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(_buildApp(container));
        await _startDefaultGame(tester);

        expect(container.read(gameControllerProvider).canUndo, isFalse);

        await _tapVisible(tester, find.byKey(const ValueKey('shooter_role_0')));
        await tester.pumpAndSettle();

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('ball_3')),
        );
        await tester.pumpAndSettle();

        // Popup victim picker opens; tap row for player index 2.
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('sheet_victim_2')),
        );
        await tester.pumpAndSettle();

        final state = container.read(gameControllerProvider);
        expect(state.players[0].score, 1);
        expect(state.players[2].score, -1);
        expect(state.canUndo, isTrue);
        // Draft reset — back to shooter picker.
        expect(state.turnState.shooterIndex, isNull);
        expect(state.turnState.pocketedBalls, isEmpty);
        // ScoreEvent logged.
        expect(state.scoreEvents, hasLength(1));
      },
    );

    testWidgets('finish game opens the result screen with final scores', (
      tester,
    ) async {
      _setLargeViewport(tester);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildApp(container));
      await _startDefaultGame(tester);

      await _tapVisible(tester, find.byKey(const ValueKey('shooter_role_0')));
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('ball_9')),
      );
      await tester.pumpAndSettle();
      // Popup victim picker — tap player index 1.
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('sheet_victim_1')),
      );
      await tester.pumpAndSettle();

      // Nút "Kết thúc trận" ở bottom bar → confirm dialog → xác nhận.
      await _tapVisible(tester, find.text('Kết thúc trận'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kết thúc trận').last);
      await tester.pumpAndSettle();

      expect(find.text('Kết quả cuối'), findsOneWidget);
      expect(
        container.read(gameControllerProvider).status,
        GameStatus.finished,
      );
      expect(find.text('+3'), findsOneWidget);
    });

    testWidgets('reset returns to setup after confirmation', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_buildApp(container));
      await _startDefaultGame(tester);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Làm mới trận').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Làm mới trận'));
      await tester.pumpAndSettle();

      expect(find.text('Thể thức thi đấu'), findsOneWidget);
      expect(
        container.read(gameControllerProvider).status,
        GameStatus.modeSelection,
      );
    });
  });
}

Widget _buildApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const BidaScoreApp(),
  );
}

void _setLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _selectMode(WidgetTester tester) async {
  await _tapVisible(tester, find.text('Bắn đền'));
  await tester.pumpAndSettle();
}

Future<void> _startDefaultGame(WidgetTester tester) async {
  await _selectMode(tester);
  await _tapVisible(tester, find.text('Bắt đầu'));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  final target = finder.first;
  if (tester.any(target)) {
    await tester.ensureVisible(target);
  } else {
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.tap(target);
}
