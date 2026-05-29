import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/cover_image_controller.dart';
import 'providers/game_controller.dart';
import 'services/ball_config_history_storage.dart';
import 'services/cover_image_storage.dart';
import 'services/game_persistence.dart';
import 'services/player_name_history_storage.dart';
import 'services/setup_persistence.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preload từ disk trước khi build UI:
  // - Trận đang chơi (khôi phục sau kill)
  // - Setup gần nhất (auto-fill Setup screen)
  // - History tên người chơi (gợi ý ở Setup screen)
  // - Ảnh bìa tuỳ chỉnh (nếu user đã chọn)
  final savedState = await GamePersistence.load();
  final savedSetup = await SetupPersistence.load();
  final savedNames = await PlayerNameHistoryStorage.load();
  final savedCover = await CoverImageStorage.load();
  final savedBalls = await BallConfigHistoryStorage.load();

  runApp(
    ProviderScope(
      overrides: [
        initialGameStateProvider.overrideWithValue(savedState),
        lastSetupSeedProvider.overrideWithValue(savedSetup),
        playerNameHistorySeedProvider.overrideWithValue(savedNames),
        coverImageSeedProvider.overrideWithValue(savedCover),
        ballConfigHistorySeedProvider.overrideWithValue(savedBalls),
      ],
      child: const BidaScoreApp(),
    ),
  );
}
