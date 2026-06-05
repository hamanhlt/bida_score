import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/game_mode.dart';
import 'models/game_snapshot.dart';
import 'models/league_session.dart';
import 'models/league_state.dart';
import 'models/nine_ball_state.dart';
import 'providers/game_controller.dart';
import 'providers/league_controller.dart';
import 'providers/league_session_controller.dart';
import 'providers/nine_ball_controller.dart';
import 'screens/game_screen.dart';
import 'screens/league_list_screen.dart';
import 'screens/league_play_screen.dart';
import 'screens/league_result_screen.dart';
import 'screens/league_setup_screen.dart';
import 'screens/mode_selection_screen.dart';
import 'screens/nine_ball_game_screen.dart';
import 'screens/nine_ball_result_screen.dart';
import 'screens/nine_ball_setup_screen.dart';
import 'screens/result_screen.dart';
import 'screens/setup_screen.dart';
import 'theme/app_colors.dart';

class BidaScoreApp extends StatelessWidget {
  const BidaScoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bida - Bắn đền',
      debugShowCheckedModeBanner: false,
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: _buildTheme(),
      home: const _AppShell(),
    );
  }

  ThemeData _buildTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: const Color(0xFFBF6A02),
      tertiary: const Color(0xFFB0362E),
      surface: AppColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.scaffoldBg,
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(height: 1.4),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white.withAlpha(229),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFE7EFEA),
        selectedColor: AppColors.primary,
        side: BorderSide.none,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        secondaryLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withAlpha(224),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withAlpha(115),
        thickness: 1,
      ),
    );
  }
}

class _AppShell extends ConsumerWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameControllerProvider);

    // Chưa chọn mode → ModeSelectionScreen
    if (gameState.status == GameStatus.modeSelection) {
      return const ModeSelectionScreen(
        key: ValueKey(GameStatus.modeSelection),
      );
    }

    // Route theo mode
    final mode = gameState.gameMode;

    if (mode == GameMode.pool) {
      return _buildNineBallShell(ref);
    }

    if (mode == GameMode.league) {
      return _buildLeagueShell(ref);
    }

    // Default: penalty369
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: switch (gameState.status) {
        GameStatus.modeSelection => const SizedBox.shrink(),
        GameStatus.setup => const SetupScreen(key: ValueKey(GameStatus.setup)),
        GameStatus.inProgress => const GameScreen(
          key: ValueKey(GameStatus.inProgress),
        ),
        GameStatus.finished => const ResultScreen(
          key: ValueKey(GameStatus.finished),
        ),
      },
    );
  }

  Widget _buildNineBallShell(WidgetRef ref) {
    final nbState = ref.watch(nineBallControllerProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: switch (nbState.status) {
        NineBallStatus.setup => const NineBallSetupScreen(
          key: ValueKey(NineBallStatus.setup),
        ),
        NineBallStatus.inProgress => const NineBallGameScreen(
          key: ValueKey(NineBallStatus.inProgress),
        ),
        NineBallStatus.finished => const NineBallResultScreen(
          key: ValueKey(NineBallStatus.finished),
        ),
      },
    );
  }

  Widget _buildLeagueShell(WidgetRef ref) {
    // viewMode quyết định màn ngoài cùng (list vs current). Khi current,
    // route theo LeagueState.status như cũ.
    final session = ref.watch(leagueSessionControllerProvider);
    if (session.viewMode == LeagueViewMode.list) {
      return const LeagueListScreen(key: ValueKey(LeagueViewMode.list));
    }
    final lgState = ref.watch(leagueControllerProvider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: switch (lgState.status) {
        LeagueStatus.setup => const LeagueSetupScreen(
          key: ValueKey(LeagueStatus.setup),
        ),
        LeagueStatus.inProgress => const LeaguePlayScreen(
          key: ValueKey(LeagueStatus.inProgress),
        ),
        LeagueStatus.finished => const LeagueResultScreen(
          key: ValueKey(LeagueStatus.finished),
        ),
      },
    );
  }
}
