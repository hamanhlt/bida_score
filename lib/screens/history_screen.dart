import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/game_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/round_history_view.dart';
import '../widgets/table_background.dart';

/// Trang lịch sử các lượt ghi điểm của trận đang chơi — gộp theo ván
/// (kể cả ván trống). Reuse [RoundHistoryView] với data từ GameState.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(
      gameControllerProvider.select((s) => s.scoreEvents),
    );
    final roundNumber = ref.watch(
      gameControllerProvider.select((s) => s.roundNumber),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        foregroundColor: AppColors.textDark,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        title: const Text(
          'Lịch sử ghi điểm',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: TableBackground(
        child: SafeArea(
          child: RoundHistoryView(events: events, totalRounds: roundNumber),
        ),
      ),
    );
  }
}
