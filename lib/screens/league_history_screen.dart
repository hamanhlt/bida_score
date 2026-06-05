import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/league_state.dart';
import '../providers/league_history_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/table_background.dart';
import 'league_result_screen.dart';

/// Lịch sử các giải đấu đã kết thúc — tap 1 entry → mở `LeagueResultScreen`
/// ở chế độ read-only. Swipe-left để xoá 1 entry; AppBar có "Xoá tất cả".
class LeagueHistoryScreen extends ConsumerWidget {
  const LeagueHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(leagueHistoryControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Lịch sử giải đấu',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          historyAsync.maybeWhen(
            data: (list) => list.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Xoá tất cả',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      final ok = await _confirmClear(context);
                      if (ok == true) {
                        await ref
                            .read(leagueHistoryControllerProvider.notifier)
                            .clearAll();
                      }
                    },
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: TableBackground(
        child: SafeArea(
          child: historyAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không đọc được lịch sử: $err',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.victim,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (list) => list.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount: list.length,
                    itemBuilder: (itemContext, i) {
                      final league = list[i];
                      final notifier = ref.read(
                        leagueHistoryControllerProvider.notifier,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Dismissible(
                          // Stable key theo `id` (engine sinh hoặc legacy
                          // fallback). Tránh re-attach Dismissible state
                          // sang row khác sau khi xoá + reorder.
                          key: ValueKey(_dismissKey(league, i)),
                          direction: DismissDirection.endToStart,
                          background: const _DismissBg(),
                          confirmDismiss: (_) => _confirmRemoveOne(itemContext),
                          onDismissed: (_) => notifier.removeLeague(league),
                          child: _LeagueCard(league: league),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  /// Stable key per entry. Ưu tiên `league.id` (engine guarantee non-empty;
  /// legacy fromJson cũng fallback `_legacyId`). Fallback composite khi
  /// data quá cũ id rỗng.
  String _dismissKey(LeagueState league, int index) {
    if (league.id.isNotEmpty) return 'lg_${league.id}';
    final finishedTag =
        league.finishedAt?.microsecondsSinceEpoch.toString() ?? 'noend';
    final nameTag = league.players.map((p) => p.name).join('|');
    return '${finishedTag}_${league.matchesPlayed}_${nameTag.hashCode}_$index';
  }

  Future<bool?> _confirmClear(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá toàn bộ lịch sử giải?'),
        content: const Text(
          'Tất cả giải đã lưu sẽ bị xoá và không khôi phục được.',
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

  Future<bool?> _confirmRemoveOne(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá giải này?'),
        content: const Text('Giải đã chọn sẽ bị xoá khỏi lịch sử.'),
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

class _DismissBg extends StatelessWidget {
  const _DismissBg();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.victim,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_rounded, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'Xoá',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
              size: 64,
              color: AppColors.textSubtle.withAlpha(140),
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có giải đấu nào',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textBody,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Kết thúc 1 giải để lưu vào lịch sử.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSubtle,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LeagueCard extends StatelessWidget {
  const _LeagueCard({required this.league});

  final LeagueState league;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showPodium = league.usesGroupStage
        ? league.knockoutComplete
        : league.matchesPlayed > 0;
    final champion = showPodium && league.usesGroupStage
        ? league.championPlayer
        : showPodium && league.players.isNotEmpty
        ? league.players.first
        : null;
    final runnerUp = showPodium && league.usesGroupStage
        ? league.runnerUpPlayer
        : showPodium && league.players.length > 1
        ? league.players[1]
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LeagueResultScreen(league: league),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        league.phaseLabel,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _summaryText(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSubtle,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(league.finishedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSubtle,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textSubtle,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  league.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (champion != null) ...[
                  const SizedBox(height: 12),
                  _ChampionRow(
                    name: champion.name,
                    trailing: league.usesGroupStage
                        ? 'Vô địch'
                        : '${champion.points} đ',
                    medal: AppColors.trophyGold,
                  ),
                  if (runnerUp != null) ...[
                    const SizedBox(height: 4),
                    _ChampionRow(
                      name: runnerUp.name,
                      trailing: league.usesGroupStage
                          ? 'Á quân'
                          : '${runnerUp.points} đ',
                      medal: AppColors.trophySilver,
                      rank: 2,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? at) {
    if (at == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)}/${at.year} '
        '${two(at.hour)}:${two(at.minute)}';
  }

  String _summaryText() {
    if (!league.usesGroupStage) {
      return '${league.players.length} người · '
          '${league.matchesPlayed}/${league.matchesTotal} trận';
    }
    return '${league.players.length} người · '
        'Bảng ${league.groupMatchesPlayed}/${league.groupMatchesTotal} · '
        'KO ${league.knockoutMatchesPlayed}/${league.knockoutMatchesTotal}';
  }
}

class _ChampionRow extends StatelessWidget {
  const _ChampionRow({
    required this.name,
    required this.trailing,
    required this.medal,
    this.rank = 1,
  });

  final String name;
  final String trailing;
  final Color medal;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: medal.withAlpha(40),
            shape: BoxShape.circle,
            border: Border.all(color: medal, width: 1.2),
          ),
          child: Text(
            '$rank',
            style: TextStyle(
              color: medal,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: AppColors.primaryDark,
              fontWeight: rank == 1 ? FontWeight.w900 : FontWeight.w700,
              fontSize: 15,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          trailing,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
