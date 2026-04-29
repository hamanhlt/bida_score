import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/nine_ball_engine.dart';
import '../models/nine_ball_state.dart';
import 'game_controller.dart';

final nineBallEngineProvider =
    Provider<NineBallEngine>((ref) => const NineBallEngine());

final nineBallControllerProvider =
    NotifierProvider<NineBallController, NineBallState>(
  NineBallController.new,
);

class NineBallController extends Notifier<NineBallState> {
  NineBallEngine get _engine => ref.read(nineBallEngineProvider);

  @override
  NineBallState build() => NineBallState.initial();

  void startGame(List<String> names, int raceTarget) {
    state = _engine.startGame(names, raceTarget);
  }

  void winRack(int winnerIndex) {
    state = _engine.winRack(state, winnerIndex);
  }

  void decrementWin(int playerIndex) {
    state = _engine.decrementWin(state, playerIndex);
  }

  void finishGame() {
    state = _engine.finishGame(state);
  }

  void undo() {
    state = _engine.undo(state);
  }

  void resetGame() {
    state = _engine.resetGame();
    // Quay về mode selection
    ref.read(gameControllerProvider.notifier).resetGame();
  }
}
