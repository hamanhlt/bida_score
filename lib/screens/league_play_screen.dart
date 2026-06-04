import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/league_state.dart';
import '../models/match_fixture.dart';
import '../providers/league_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/table_background.dart';
import 'league_standings_view.dart';

/// Màn chính của giải đấu (status = inProgress) — 2 tab:
/// 1. **Trận đấu**: list fixtures, tap để nhập/sửa tỷ số.
/// 2. **Bảng xếp hạng**: realtime — recalculate sau mỗi updateScore.
///
/// AppBar action "Kết thúc giải" có confirm dialog → controller.finishTournament().
class LeaguePlayScreen extends ConsumerWidget {
  const LeaguePlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(leagueControllerProvider);
    final controller = ref.read(leagueControllerProvider.notifier);

    if (state.status != LeagueStatus.inProgress) {
      return const SizedBox.shrink();
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            'Giải đấu · ${state.matchesPlayed}/${state.matchesTotal} trận',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Kết thúc giải',
              icon: const Icon(Icons.flag_rounded),
              onPressed: () => _confirmFinish(context, ref),
            ),
            PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'reset') {
                  final ok = await _confirmReset(context);
                  if (ok == true) controller.resetTournament();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'reset', child: Text('Huỷ giải')),
              ],
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: AppColors.accent,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Trận đấu', icon: Icon(Icons.sports_rounded)),
              Tab(
                text: 'Bảng xếp hạng',
                icon: Icon(Icons.emoji_events_rounded),
              ),
            ],
          ),
        ),
        body: TableBackground(
          child: SafeArea(
            top: false,
            child: TabBarView(
              children: [
                _FixturesTab(state: state),
                LeagueStandingsView(players: state.players),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmFinish(BuildContext context, WidgetRef ref) async {
    final state = ref.read(leagueControllerProvider);
    final unfinished = state.matchesTotal - state.matchesPlayed;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kết thúc giải?'),
        content: Text(
          unfinished == 0
              ? 'Bảng xếp hạng cuối sẽ được chốt và lưu vào lịch sử.'
              : 'Còn $unfinished trận chưa nhập tỷ số. '
                  'Bảng xếp hạng vẫn được chốt theo các trận đã đấu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kết thúc'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(leagueControllerProvider.notifier).finishTournament();
    }
  }

  Future<bool?> _confirmReset(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Huỷ giải?'),
        content: const Text(
          'Toàn bộ tỷ số và lịch thi đấu sẽ bị mất. '
          'Giải chưa kết thúc nên không lưu vào lịch sử.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Huỷ giải'),
          ),
        ],
      ),
    );
  }
}

class _FixturesTab extends ConsumerWidget {
  const _FixturesTab({required this.state});

  final LeagueState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Map id → tên cho lookup nhanh khi render fixture.
    final nameById = {for (final p in state.players) p.id: p.name};

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: state.fixtures.length,
      itemBuilder: (context, i) {
        final f = state.fixtures[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _FixtureCard(
            index: i + 1,
            fixture: f,
            p1Name: nameById[f.player1Id] ?? '?',
            p2Name: nameById[f.player2Id] ?? '?',
            onTap: () => _openScoreSheet(context, ref, f, nameById),
          ),
        );
      },
    );
  }

  Future<void> _openScoreSheet(
    BuildContext context,
    WidgetRef ref,
    MatchFixture f,
    Map<String, String> nameById,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ScoreInputSheet(
        fixture: f,
        p1Name: nameById[f.player1Id] ?? '?',
        p2Name: nameById[f.player2Id] ?? '?',
      ),
    );
  }
}

class _FixtureCard extends StatelessWidget {
  const _FixtureCard({
    required this.index,
    required this.fixture,
    required this.p1Name,
    required this.p2Name,
    required this.onTap,
  });

  final int index;
  final MatchFixture fixture;
  final String p1Name;
  final String p2Name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p1Win =
        fixture.isPlayed && fixture.score1 > fixture.score2;
    final p2Win =
        fixture.isPlayed && fixture.score2 > fixture.score1;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NameRow(
                      name: p1Name,
                      isWinner: p1Win,
                    ),
                    const SizedBox(height: 4),
                    _NameRow(
                      name: p2Name,
                      isWinner: p2Win,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (fixture.isPlayed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent.withAlpha(150),
                    ),
                  ),
                  child: Text(
                    '${fixture.score1} – ${fixture.score2}',
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Chưa đấu',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSubtle,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.name, required this.isWinner});

  final String name;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isWinner
              ? Icons.emoji_events_rounded
              : Icons.circle_outlined,
          size: 14,
          color: isWinner ? AppColors.accent : AppColors.textSubtle,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            name,
            style: TextStyle(
              color: AppColors.primaryDark,
              fontWeight: isWinner ? FontWeight.w900 : FontWeight.w700,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet nhập / sửa tỷ số. StatefulWidget để TextEditingController
/// dispose đúng lifecycle (tránh assertion `_dependents.isEmpty`).
class _ScoreInputSheet extends ConsumerStatefulWidget {
  const _ScoreInputSheet({
    required this.fixture,
    required this.p1Name,
    required this.p2Name,
  });

  final MatchFixture fixture;
  final String p1Name;
  final String p2Name;

  @override
  ConsumerState<_ScoreInputSheet> createState() => _ScoreInputSheetState();
}

class _ScoreInputSheetState extends ConsumerState<_ScoreInputSheet> {
  late final TextEditingController _c1;
  late final TextEditingController _c2;
  String? _error;

  @override
  void initState() {
    super.initState();
    _c1 = TextEditingController(
      text: widget.fixture.isPlayed ? '${widget.fixture.score1}' : '',
    );
    _c2 = TextEditingController(
      text: widget.fixture.isPlayed ? '${widget.fixture.score2}' : '',
    );
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    super.dispose();
  }

  void _save() {
    final s1 = int.tryParse(_c1.text.trim());
    final s2 = int.tryParse(_c2.text.trim());
    if (s1 == null || s2 == null || s1 < 0 || s2 < 0) {
      setState(() => _error = 'Tỷ số phải là số nguyên ≥ 0.');
      return;
    }
    ref
        .read(leagueControllerProvider.notifier)
        .updateScore(widget.fixture.id, s1, s2);
    Navigator.of(context).pop();
  }

  void _clear() {
    ref
        .read(leagueControllerProvider.notifier)
        .clearScore(widget.fixture.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nhập tỷ số', style: theme.textTheme.titleLarge),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ScoreField(
                  label: widget.p1Name,
                  controller: _c1,
                  autofocus: true,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '–',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textSubtle,
                  ),
                ),
              ),
              Expanded(
                child: _ScoreField(
                  label: widget.p2Name,
                  controller: _c2,
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              if (widget.fixture.isPlayed)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clear,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Xoá kết quả'),
                  ),
                ),
              if (widget.fixture.isPlayed) const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Lưu'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreField extends StatelessWidget {
  const _ScoreField({
    required this.label,
    required this.controller,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      // Limit 3 ký tự → max 999. Tránh int overflow / parse → null gây
      // error message khó hiểu khi user gõ nhầm chuỗi dài.
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        color: AppColors.primaryDark,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
      ),
    );
  }
}

