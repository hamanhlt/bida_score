import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/nine_ball_state.dart';
import '../providers/nine_ball_controller.dart';
import '../widgets/table_background.dart';

class NineBallResultScreen extends ConsumerWidget {
  const NineBallResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nineBallControllerProvider);

    if (state.status != NineBallStatus.finished || state.players.length < 2) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final winnerIdx = state.matchWinnerIndex;
    final w1 = state.rackWins[0];
    final w2 = state.rackWins[1];

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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                Text(
                  'Kết quả',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: const Color(0xFF16322C),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Trận đã kết thúc.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF4A6057),
                  ),
                ),
                const SizedBox(height: 24),
                // Winner card
                if (winnerIdx != null)
                  Card(
                    color: const Color(0xFF16322C),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text(
                            '🏆',
                            style: TextStyle(fontSize: 48),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            state.players[winnerIdx].name,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2B544),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '$w1 — $w2',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: const Color(0xFF16322C),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (winnerIdx == null)
                  // Kết thúc sớm, chưa ai đạt race target
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            'Chưa có người thắng',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${state.players[0].name}: $w1 — ${state.players[1].name}: $w2',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: const Color(0xFF5F726A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                // Stats
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _StatChip(label: 'Race to ${state.raceTarget}'),
                        _StatChip(label: 'Tổng rack: ${state.currentRack - 1}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed:
                      ref.read(nineBallControllerProvider.notifier).backToList,
                  icon: const Icon(Icons.list_rounded),
                  label: const Text('Về danh sách'),
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
