import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/nine_ball_state.dart';
import '../providers/active_pools_controller.dart';
import '../providers/nine_ball_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/table_background.dart';

/// Màn danh sách trận Pool đang chơi — landing khi chọn mode Pool. Tap 1 trận
/// → chơi tiếp; FAB "Tạo trận mới" → NineBallSetupScreen. Mirror
/// LeagueListScreen — cho phép nhiều trận song song, switch không mất tỷ số.
class NineBallListScreen extends ConsumerWidget {
  const NineBallListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(activePoolsControllerProvider);
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ref.read(nineBallControllerProvider.notifier).exitToModeSelection();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => ref
                .read(nineBallControllerProvider.notifier)
                .exitToModeSelection(),
          ),
          title: const Text(
            'Pool',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
        body: TableBackground(
          child: SafeArea(
            top: false,
            child: matches.isEmpty
                ? _EmptyState(
                    onCreate: () => ref
                        .read(nineBallControllerProvider.notifier)
                        .createNew(),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                    itemCount: matches.length + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '${matches.length} trận đang chơi',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }
                      final match = matches[i - 1];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ActiveMatchCard(
                          match: match,
                          onTap: () => ref
                              .read(nineBallControllerProvider.notifier)
                              .openMatch(match),
                          onDelete: () async {
                            final ok = await _confirmDelete(context);
                            if (ok == true) {
                              ref
                                  .read(activePoolsControllerProvider.notifier)
                                  .remove(match.id);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ),
        floatingActionButton: matches.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () =>
                    ref.read(nineBallControllerProvider.notifier).createNew(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tạo trận mới'),
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textDark,
              ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá trận này?'),
        content: const Text(
          'Mọi tỷ số đã ghi sẽ bị xoá. Không khôi phục được.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }
}

class _ActiveMatchCard extends StatelessWidget {
  const _ActiveMatchCard({
    required this.match,
    required this.onTap,
    required this.onDelete,
  });

  final NineBallState match;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w1 = match.rackWins.isNotEmpty ? match.rackWins[0] : 0;
    final w2 = match.rackWins.length > 1 ? match.rackWins[1] : 0;
    final maxWins = w1 > w2 ? w1 : w2;
    final progress = match.raceTarget == 0
        ? 0.0
        : (maxWins / match.raceTarget).clamp(0.0, 1.0);
    final variant = match.variantLabel ?? 'Pool';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.sports_bar_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$variant · Race ${match.raceTarget} · '
                          '${_subtitle(match)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSubtle,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Xoá trận',
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.textSubtle,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Tỷ số $w1 — $w2',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textBody,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.play_circle_outline_rounded,
                    size: 16,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Chơi tiếp',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(NineBallState m) {
    final started = m.startedAt;
    if (started == null) return 'Đang chơi';
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Bắt đầu ${two(started.day)}/${two(started.month)} '
        '${two(started.hour)}:${two(started.minute)}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_bar_outlined,
              size: 72,
              color: AppColors.textSubtle.withAlpha(160),
            ),
            const SizedBox(height: 18),
            Text(
              'Chưa có trận nào đang chơi',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textDark,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tạo trận race-to mới (8/9/10-Ball hoặc tuỳ chọn).\n'
              'Có thể chơi nhiều trận song song, vào đánh tiếp bất cứ lúc nào.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textBody,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tạo trận mới'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
