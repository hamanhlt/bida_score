import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cash_game_state.dart';
import '../providers/cash_game_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/table_background.dart';

/// Kết quả trận Chơi điểm — người tiền cao hơn thắng, hiện chênh lệch
/// (số tiền người thua trả người thắng) + chi tiết ván/lỗ 10 mỗi người.
class CashGameResultScreen extends ConsumerWidget {
  const CashGameResultScreen({super.key});

  static const _blue = Color(0xFF2962E0);
  static const _red = Color(0xFFD93838);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cashGameControllerProvider);
    if (state.status != CashGameStatus.finished ||
        state.playerNames.length < 2) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final leader = state.leaderIndex;
    final diff = state.moneyDifference;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TableBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Kết quả',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: AppColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Card chênh lệch / hoà.
                    Card(
                      color: AppColors.textDark,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Text('🏆', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 10),
                            if (leader != null) ...[
                              Text(
                                state.playerNames[leader],
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'thắng',
                                style: TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '+${formatVnd(diff)} đ',
                                  style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'chênh lệch phải trả',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white60,
                                ),
                              ),
                            ] else
                              Text(
                                'Hoà tiền',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PlayerSummary(
                      name: state.playerNames[0],
                      money: state.moneyOf(0),
                      rackWins: state.totalRackWinsOf(0),
                      balls: state.totalBallsOf(0),
                      color: _blue,
                      isLeader: leader == 0,
                    ),
                    const SizedBox(height: 10),
                    _PlayerSummary(
                      name: state.playerNames[1],
                      money: state.moneyOf(1),
                      rackWins: state.totalRackWinsOf(1),
                      balls: state.totalBallsOf(1),
                      color: _red,
                      isLeader: leader == 1,
                    ),
                    const SizedBox(height: 14),
                    if (state.rackResults.isNotEmpty) ...[
                      _RackResultsCard(state: state),
                      const SizedBox(height: 14),
                    ],
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            _StatChip(
                              label: '${state.settledRackCount} ván chốt',
                            ),
                            _StatChip(
                              label: '${formatVnd(state.moneyPerRack)} đ/ván',
                            ),
                            _StatChip(
                              label: '${formatVnd(state.moneyPerBall)} đ/lỗ 10',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: ref
                          .read(cashGameControllerProvider.notifier)
                          .resetGame,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Trận mới'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RackResultsCard extends StatelessWidget {
  const _RackResultsCard({required this.state});

  final CashGameState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Các ván đã chốt',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textDark,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            for (final rack in state.rackResults) ...[
              _RackResultRow(
                rack: rack,
                playerNames: state.playerNames,
                colors: const [
                  CashGameResultScreen._blue,
                  CashGameResultScreen._red,
                ],
              ),
              if (rack != state.rackResults.last)
                const Divider(height: 14, color: AppColors.border),
            ],
          ],
        ),
      ),
    );
  }
}

class _RackResultRow extends StatelessWidget {
  const _RackResultRow({
    required this.rack,
    required this.playerNames,
    required this.colors,
  });

  final CashGameRackResult rack;
  final List<String> playerNames;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE7EFEA),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Ván ${rack.rackNumber}',
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < playerNames.length; i++)
                Text(
                  '${playerNames[i]}: +${formatVnd(rack.money[i])} đ'
                  ' (${rack.balls[i]} lỗ 10)',
                  style: TextStyle(
                    color: colors[i],
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerSummary extends StatelessWidget {
  const _PlayerSummary({
    required this.name,
    required this.money,
    required this.rackWins,
    required this.balls,
    required this.color,
    required this.isLeader,
  });

  final String name;
  final int money;
  final int rackWins;
  final int balls;
  final Color color;
  final bool isLeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLeader ? color : AppColors.border,
          width: isLeader ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          if (isLeader) ...[
            Icon(Icons.emoji_events_rounded, color: color, size: 22),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$rackWins ván · $balls lỗ 10',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSubtle,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${formatVnd(money)} đ',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE7EFEA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFF35524A),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
