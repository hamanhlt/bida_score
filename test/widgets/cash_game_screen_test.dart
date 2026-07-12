import 'package:bida_score/models/cash_game_state.dart';
import 'package:bida_score/providers/cash_game_controller.dart';
import 'package:bida_score/screens/cash_game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('màn Chơi điểm xoay ngang không bị overflow', (tester) async {
    tester.view.physicalSize = const Size(812, 375);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        cashGameControllerProvider.overrideWith(_TestCashGameController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CashGameScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Người chơi 1'), findsOneWidget);
    expect(find.text('Người chơi 2'), findsOneWidget);
    expect(find.text('Ván 1'), findsOneWidget);
    expect(find.text('Chốt'), findsOneWidget);
    expect(find.text('60.000 đ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestCashGameController extends CashGameController {
  @override
  CashGameState build() {
    return CashGameState(
      playerNames: const ['Người chơi 1', 'Người chơi 2'],
      rackWins: const [0, 1],
      balls: const [0, 1],
      moneyPerRack: 40000,
      moneyPerBall: 20000,
      status: CashGameStatus.inProgress,
    );
  }

  @override
  void addRackWin(int index) {}

  @override
  void decrementRackWin(int index) {}

  @override
  void addBall(int index) {}

  @override
  void removeBall(int index) {}

  @override
  void settleRack() {}

  @override
  void undo() {}

  @override
  void finishGame() {}

  @override
  void resetGame() {}
}
