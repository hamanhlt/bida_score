import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_mode.dart';
import '../models/league_state.dart';
import '../models/match_result.dart';
import '../providers/league_history_controller.dart';
import '../providers/match_history_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/table_background.dart';
import 'league_result_screen.dart';
import 'match_detail_screen.dart';

/// Lịch sử tất cả các trận/giải đã kết thúc (bền qua lần mở app).
/// Có tab "Tất cả" + 1 tab mỗi [GameMode].
class MatchHistoryScreen extends ConsumerWidget {
  const MatchHistoryScreen({super.key});

  static final List<GameMode> _historyModes = GameMode.values.toList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(matchHistoryControllerProvider);
    final leagueHistoryAsync = ref.watch(leagueHistoryControllerProvider);
    final theme = Theme.of(context);
    final matches = historyAsync.valueOrNull ?? const <MatchResult>[];
    final leagues = leagueHistoryAsync.valueOrNull ?? const <LeagueState>[];
    final entries = _buildEntries(matches, leagues);
    final isLoading = historyAsync.isLoading || leagueHistoryAsync.isLoading;
    final error = historyAsync.maybeWhen(
      error: (err, _) => err,
      orElse: () => leagueHistoryAsync.maybeWhen(
        error: (err, _) => err,
        orElse: () => null,
      ),
    );

    return DefaultTabController(
      length: 1 + _historyModes.length,
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
            entries.isEmpty
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
                        await ref
                            .read(leagueHistoryControllerProvider.notifier)
                            .clearAll();
                      }
                    },
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
              for (final m in _historyModes) Tab(text: m.label),
            ],
          ),
        ),
        body: TableBackground(
          child: SafeArea(
            top: false,
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Không đọc được lịch sử: $error',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.victim,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : TabBarView(
                    children: [
                      _HistoryListView(entries: entries),
                      for (final m in _historyModes)
                        _HistoryListView(
                          entries: entries
                              .where((x) => _matchesMode(x, m))
                              .toList(),
                          emptyHint: 'Chưa có lịch sử ${m.label}.',
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  List<_HistoryEntry> _buildEntries(
    List<MatchResult> matches,
    List<LeagueState> leagues,
  ) {
    final entries = [
      for (final match in matches) _HistoryEntry.match(match),
      for (final league in leagues) _HistoryEntry.league(league),
    ]..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    return entries;
  }

  /// Entry có thuộc tab [mode] không. penalty369 chỉ match label "Bắn đền".
  /// pool match tất cả không phải Bắn đền — gồm "Pool" mới, các biến thể
  /// "8/9/10-Ball" do user chọn ở Setup, và label legacy từ trận cũ.
  bool _matchesMode(_HistoryEntry entry, GameMode mode) {
    if (entry.league != null) return mode == GameMode.league;
    final label = entry.match!.modeLabel;
    switch (mode) {
      case GameMode.penalty369:
        return label == GameMode.penalty369.label;
      case GameMode.pool:
        return label != GameMode.penalty369.label;
      case GameMode.league:
        return false;
    }
  }

  Future<bool?> _confirmClear(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá toàn bộ lịch sử?'),
        content: const Text(
          'Tất cả trận và giải đã lưu sẽ bị xoá và không khôi phục được.',
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

class _HistoryEntry {
  const _HistoryEntry._({this.match, this.league});

  factory _HistoryEntry.match(MatchResult match) =>
      _HistoryEntry._(match: match);

  factory _HistoryEntry.league(LeagueState league) =>
      _HistoryEntry._(league: league);

  final MatchResult? match;
  final LeagueState? league;

  DateTime get finishedAt =>
      match?.finishedAt ??
      league?.finishedAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  String get dismissKey {
    final matchValue = match;
    if (matchValue != null) {
      return 'match_${matchValue.finishedAt.toIso8601String()}';
    }
    final leagueValue = league!;
    return 'league_${leagueValue.id}_${leagueValue.finishedAt?.toIso8601String() ?? 'noend'}';
  }
}

/// List lịch sử (đã lọc theo mode hoặc tất cả). Swipe-to-delete từng entry,
/// tap để mở chi tiết. Rỗng → hiện hint.
class _HistoryListView extends ConsumerWidget {
  const _HistoryListView({required this.entries, this.emptyHint});

  final List<_HistoryEntry> entries;

  /// Text hiện khi list rỗng. Null → dùng empty-state mặc định ("Tất cả").
  final String? emptyHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return _EmptyState(hint: emptyHint);
    }
    final matchNotifier = ref.read(matchHistoryControllerProvider.notifier);
    final leagueNotifier = ref.read(leagueHistoryControllerProvider.notifier);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: entries.length,
      itemBuilder: (itemContext, i) {
        final entry = entries[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Dismissible(
            key: ValueKey(entry.dismissKey),
            direction: DismissDirection.endToStart,
            background: _DismissBackground(),
            confirmDismiss: (_) => _confirmRemoveOne(itemContext),
            onDismissed: (_) {
              final match = entry.match;
              if (match != null) {
                matchNotifier.removeMatch(match);
                return;
              }
              leagueNotifier.removeLeague(entry.league!);
            },
            child: entry.match != null
                ? _MatchCard(match: entry.match!)
                : _LeagueHistoryCard(league: entry.league!),
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
        content: const Text('Mục đã chọn sẽ bị xoá khỏi lịch sử.'),
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
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
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
              hint ?? 'Chưa có lịch sử nào được lưu',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textBody,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Kết thúc 1 trận hoặc 1 giải để lưu vào lịch sử.',
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

class _LeagueHistoryCard extends StatelessWidget {
  const _LeagueHistoryCard({required this.league});

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
                      child: const Text(
                        'Giải đấu',
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
                        '${league.players.length} người · ${league.phaseLabel}',
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
                const SizedBox(height: 12),
                Text(
                  league.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (champion != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: AppColors.accent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          champion.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        league.usesGroupStage
                            ? 'Vô địch'
                            : '${champion.points} đ',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
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
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${match.roundsPlayed} ván',
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
            _PlayerRow(rank: i + 1, player: match.players[i], isWinner: i == 0),
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
