import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_mode.dart';
import '../models/match_result.dart';
import '../providers/match_history_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/table_background.dart';
import 'match_detail_screen.dart';

/// Lịch sử tất cả các trận đã kết thúc (bền qua lần mở app). Có tab theo mode:
/// "Tất cả" + 1 tab mỗi `GameMode` — ấn tab nào ra list trận của mode đó.
class MatchHistoryScreen extends ConsumerWidget {
  const MatchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(matchHistoryControllerProvider);
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 1 + GameMode.values.length,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Lịch sử trận đấu',
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
                              .read(matchHistoryControllerProvider.notifier)
                              .clearAll();
                        }
                      },
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: AppColors.accent,
            indicatorWeight: 3,
            tabs: [
              const Tab(text: 'Tất cả'),
              for (final m in GameMode.values) Tab(text: m.label),
            ],
          ),
        ),
        body: TableBackground(
          child: SafeArea(
            top: false,
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
              data: (list) => TabBarView(
                children: [
                  _MatchListView(matches: list),
                  for (final m in GameMode.values)
                    _MatchListView(
                      matches: list
                          .where((x) => x.modeLabel == m.label)
                          .toList(),
                      emptyHint: 'Chưa có trận ${m.label}.',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmClear(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá toàn bộ lịch sử?'),
        content: const Text(
          'Tất cả trận đã lưu (mọi mode) sẽ bị xoá và không khôi phục được.',
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

/// List trận (đã lọc theo mode hoặc tất cả). Swipe-to-delete từng trận, tap để
/// mở chi tiết (nếu có). Rỗng → hiện hint.
class _MatchListView extends ConsumerWidget {
  const _MatchListView({required this.matches, this.emptyHint});

  final List<MatchResult> matches;

  /// Text hiện khi list rỗng. Null → dùng empty-state mặc định ("Tất cả").
  final String? emptyHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (matches.isEmpty) {
      return _EmptyState(hint: emptyHint);
    }
    final notifier = ref.read(matchHistoryControllerProvider.notifier);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: matches.length,
      itemBuilder: (itemContext, i) {
        final match = matches[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Dismissible(
            // finishedAt là DateTime unique mỗi lần addResult.
            key: ValueKey(match.finishedAt.toIso8601String()),
            direction: DismissDirection.endToStart,
            background: _DismissBackground(),
            confirmDismiss: (_) => _confirmRemoveOne(itemContext),
            onDismissed: (_) => notifier.removeMatch(match),
            child: _MatchCard(match: match),
          ),
        );
      },
    );
  }

  Future<bool?> _confirmRemoveOne(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá trận này?'),
        content: const Text('Trận đã chọn sẽ bị xoá khỏi lịch sử.'),
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

class _DismissBackground extends StatelessWidget {
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
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.hint});

  final String? hint;

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
              hint ?? 'Chưa có trận nào được lưu',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textBody,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Kết thúc 1 trận để lưu vào lịch sử.',
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

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final MatchResult match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Có chi tiết (Bắn đền: lượt ghi điểm; race-to-X: winner từng rack) → tap mở.
    final tappable = match.events.isNotEmpty || match.rackWinners.isNotEmpty;

    final content = Padding(
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
                  match.modeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${match.roundsPlayed} ván',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSubtle,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(match.finishedAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSubtle,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (tappable) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textSubtle,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < match.players.length; i++) ...[
            _PlayerRow(
              rank: i + 1,
              player: match.players[i],
              isWinner: i == 0,
            ),
            if (i != match.players.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );

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
          onTap: tappable
              ? () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MatchDetailScreen(match: match),
                    ),
                  )
              : null,
          child: content,
        ),
      ),
    );
  }

  String _formatDate(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)}/${at.year} '
        '${two(at.hour)}:${two(at.minute)}';
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.rank,
    required this.player,
    required this.isWinner,
  });

  final int rank;
  final MatchPlayerResult player;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    final rankColor = switch (rank) {
      1 => AppColors.trophyGold,
      2 => AppColors.trophySilver,
      3 => AppColors.trophyBronze,
      _ => AppColors.textSubtle,
    };
    final scoreColor = player.score > 0
        ? AppColors.primary
        : player.score < 0
            ? AppColors.victim
            : AppColors.textBody;

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: rankColor.withAlpha(40),
            shape: BoxShape.circle,
            border: Border.all(color: rankColor, width: 1.2),
          ),
          child: Text(
            '$rank',
            style: TextStyle(
              color: rankColor,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            player.name,
            style: TextStyle(
              color: AppColors.primaryDark,
              fontWeight: isWinner ? FontWeight.w900 : FontWeight.w700,
              fontSize: 15,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          _formatScore(player.score),
          style: TextStyle(
            color: scoreColor,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  String _formatScore(int s) => s > 0 ? '+$s' : '$s';
}
