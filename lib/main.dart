import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/active_leagues_controller.dart';
import 'providers/cash_game_controller.dart';
import 'providers/cover_image_controller.dart';
import 'providers/game_controller.dart';
import 'providers/league_session_controller.dart';
import 'providers/nine_ball_controller.dart';
import 'services/active_leagues_storage.dart';
import 'services/ball_config_history_storage.dart';
import 'services/cash_config_storage.dart';
import 'services/cover_image_storage.dart';
import 'services/game_persistence.dart';
import 'services/league_session_storage.dart';
import 'services/nine_ball_persistence.dart';
import 'services/player_name_history_storage.dart';
import 'services/setup_persistence.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preload từ disk trước khi build UI:
  // - Trận đang chơi (khôi phục sau kill — Bắn đền / Pool)
  // - List giải đấu đang chơi + session (viewMode + currentId)
  // - Setup gần nhất (auto-fill Setup screen)
  // - History tên người chơi (gợi ý ở Setup screen)
  // - Ảnh bìa tuỳ chỉnh (nếu user đã chọn)
  final savedState = await GamePersistence.load();
  final savedPoolState = await NineBallPersistence.load();
  final savedActiveLeagues = await ActiveLeaguesStorage.loadAll();
  final savedLeagueSession = await LeagueSessionStorage.load();
  final savedSetup = await SetupPersistence.load();
  final savedNames = await PlayerNameHistoryStorage.load();
  final savedCover = await CoverImageStorage.load();
  final savedBalls = await BallConfigHistoryStorage.load();
  final savedCashConfig = await CashConfigStorage.load();

  runApp(
    ProviderScope(
      overrides: [
        initialGameStateProvider.overrideWithValue(savedState),
        initialNineBallStateProvider.overrideWithValue(savedPoolState),
        activeLeaguesSeedProvider.overrideWithValue(savedActiveLeagues),
        leagueSessionSeedProvider.overrideWithValue(savedLeagueSession),
        lastSetupSeedProvider.overrideWithValue(savedSetup),
        playerNameHistorySeedProvider.overrideWithValue(savedNames),
        coverImageSeedProvider.overrideWithValue(savedCover),
        ballConfigHistorySeedProvider.overrideWithValue(savedBalls),
        cashConfigSeedProvider.overrideWithValue(savedCashConfig),
      ],
      child: const BidaScoreApp(),
    ),
  );
}
