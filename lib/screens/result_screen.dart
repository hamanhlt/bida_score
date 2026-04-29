import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_snapshot.dart';
import '../models/player.dart';
import '../providers/game_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/table_background.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);

    if (state.status != GameStatus.finished || state.players.isEmpty) {
      return const SizedBox.shrink();
    }

    final rankedPlayers = [...state.players]..sort(_sortPlayers);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TableBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kết quả cuối',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Trận đã kết thúc. Xem điểm rồi bắt đầu trận mới.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textBody,
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  color: AppColors.textDark,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ResultChip(label: 'Số người: ${state.players.length}'),
                        _ResultChip(label: 'Số ván: ${state.roundNumber}'),
                        _ResultChip(label: 'Tổng: ${state.totalScore}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                for (var i = 0; i < rankedPlayers.length; i++) ...[
                  _RankCard(player: rankedPlayers[i], rank: i + 1),
                  if (i != rankedPlayers.length - 1) const SizedBox(height: 12),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed:
                      ref.read(gameControllerProvider.notifier).resetGame,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Trận mới'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _sortPlayers(Player left, Player right) {
    final scoreCompare = right.score.compareTo(left.score);
    if (scoreCompare != 0) {
      return scoreCompare;
    }
    return left.name.compareTo(right.name);
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({required this.player, required this.rank});

  final Player player;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final accentColor = switch (rank) {
      1 => AppColors.trophyGold,
      2 => AppColors.trophySilver,
      3 => AppColors.trophyBronze,
      _ => AppColors.primary,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accentColor.withAlpha(41),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$rank',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                player.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text(
              _formatScore(player.score),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: player.score >= 0
                    ? AppColors.primary
                    : AppColors.victim,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatScore(int score) => score > 0 ? '+$score' : '$score';
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(26),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
