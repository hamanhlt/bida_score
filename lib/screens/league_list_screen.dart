import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/league_state.dart';
import '../providers/active_leagues_controller.dart';
import '../providers/league_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/table_background.dart';
import 'league_history_screen.dart';

/// Màn danh sách giải đấu đang chơi — landing screen khi user chọn mode
/// "Giải đấu". Tap 1 giải → mở `LeaguePlayScreen` của giải đó. Tap FAB
/// "Tạo giải mới" → `LeagueSetupScreen`.
///
/// Cho phép quản lý NHIỀU giải song song. Mỗi giải tỷ số riêng, switch
/// qua lại không mất gì.
class LeagueListScreen extends ConsumerWidget {
  const LeagueListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leagues = ref.watch(activeLeaguesControllerProvider);
    final theme = Theme.of(context);

    return PopScope(
      // Hardware back → exit về Mode Selection (đồng nhất với AppBar back).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ref.read(leagueControllerProvider.notifier).exitToModeSelection();
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
                .read(leagueControllerProvider.notifier)
                .exitToModeSelection(),
          ),
          title: const Text(
            'Giải đấu',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Lịch sử giải đã kết thúc',
              icon: const Icon(
                Icons.history_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LeagueHistoryScreen(),
                ),
              ),
            ),
          ],
        ),
        body: TableBackground(
          child: SafeArea(
            top: false,
            child: leagues.isEmpty
                ? _EmptyState(
                    onCreate: () =>
                        ref.read(leagueControllerProvider.notifier).createNew(),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                    itemCount: leagues.length + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '${leagues.length} giải đang chơi',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }
                      final league = leagues[i - 1];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ActiveLeagueCard(
                          league: league,
                          onTap: () => ref
                              .read(leagueControllerProvider.notifier)
                              .openLeague(league),
                          onDelete: () async {
                            final ok = await _confirmDelete(context);
                            if (ok == true) {
                              ref
                                  .read(
                                    activeLeaguesControllerProvider.notifier,
                                  )
                                  .remove(league.id);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ),
        floatingActionButton: leagues.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () =>
                    ref.read(leagueControllerProvider.notifier).createNew(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tạo giải mới'),
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
        title: const Text('Xoá giải này?'),
        content: const Text(
          'Mọi tỷ số đã nhập sẽ bị xoá. Không khôi phục được.',
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

class _ActiveLeagueCard extends StatelessWidget {
  const _ActiveLeagueCard({
    required this.league,
    required this.onTap,
    required this.onDelete,
  });

  final LeagueState league;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leader = league.players.isNotEmpty ? league.players.first : null;
    final progress = league.matchesTotal == 0
        ? 0.0
        : league.matchesPlayed / league.matchesTotal;

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
                      Icons.workspace_premium_rounded,
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
                          league.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${league.players.length} người · '
                          '${league.phaseLabel} · ${_subtitle(league)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSubtle,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Xoá giải',
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
                    '${league.matchesPlayed}/${league.matchesTotal} trận đã đấu',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textBody,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (leader != null && league.matchesPlayed > 0) ...[
                    const Icon(
                      Icons.emoji_events_rounded,
                      size: 14,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${leader.name} · ${leader.points}đ',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(LeagueState l) {
    final started = l.startedAt;
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
              Icons.emoji_events_outlined,
              size: 72,
              color: AppColors.textSubtle.withAlpha(160),
            ),
            const SizedBox(height: 18),
            Text(
              'Chưa có giải nào đang chơi',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textDark,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tạo giải vòng tròn hoặc vòng bảng + knockout.\n'
              'Có thể chơi nhiều giải song song.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textBody,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tạo giải mới'),
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
