import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/game_controller.dart';
import 'services/game_persistence.dart';
import 'services/player_name_history_storage.dart';
import 'services/setup_persistence.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preload từ disk trước khi build UI:
  // - Trận đang chơi (khôi phục sau kill)
  // - Setup gần nhất (auto-fill Setup screen)
  // - History tên người chơi (gợi ý ở Setup screen)
  final savedState = await GamePersistence.load();
  final savedSetup = await SetupPersistence.load();
  final savedNames = await PlayerNameHistoryStorage.load();

  runApp(
    ProviderScope(
      overrides: [
        initialGameStateProvider.overrideWithValue(savedState),
        lastSetupSeedProvider.overrideWithValue(savedSetup),
        playerNameHistorySeedProvider.overrideWithValue(savedNames),
      ],
      child: const BidaScoreApp(),
    ),
  );
}
