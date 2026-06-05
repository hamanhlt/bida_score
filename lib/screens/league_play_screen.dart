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

    return PopScope(
      // Hardware back → quay về list (đồng nhất AppBar back).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        controller.backToList();
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            foregroundColor: AppColors.textDark,
            iconTheme: const IconThemeData(color: AppColors.textDark),
            // Back về danh sách giải (active list giữ nguyên, giải vẫn ở đó).
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Về danh sách giải',
              onPressed: () => controller.backToList(),
            ),
            title: Text(
              '${state.displayName} · ${state.phaseLabel} · '
              '${state.matchesPlayed}/${state.matchesTotal} trận',
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w800,
                fontSize: 16,
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
                  if (action == 'rename') {
                    await _renameLeague(context, ref);
                  } else if (action == 'cancel') {
                    final ok = await _confirmCancel(context);
                    if (ok == true) controller.cancelTournament();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Đổi tên giải')),
                  PopupMenuItem(value: 'cancel', child: Text('Huỷ giải')),
                ],
              ),
            ],
            bottom: const TabBar(
              labelColor: AppColors.textDark,
              unselectedLabelColor: AppColors.textSubtle,
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
                  state.usesGroupStage
                      ? LeagueGroupsStandingsView(state: state)
                      : LeagueStandingsView(players: state.players),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _renameLeague(BuildContext context, WidgetRef ref) async {
    final state = ref.read(leagueControllerProvider);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameLeagueDialog(initialName: state.displayName),
    );
    if (name == null) return;
    try {
      ref.read(leagueControllerProvider.notifier).renameTournament(name);
    } on ArgumentError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message?.toString() ?? 'Tên giải không hợp lệ.'),
        ),
      );
    }
  }

  Future<void> _confirmFinish(BuildContext context, WidgetRef ref) async {
    final state = ref.read(leagueControllerProvider);
    if (state.usesGroupStage && !state.knockoutComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.phase == LeaguePhase.groupStage
                ? 'Cần vào knockout và hoàn thành chung kết trước.'
                : 'Cần hoàn thành trận chung kết knockout trước.',
          ),
        ),
      );
      return;
    }
    final unfinished = state.matchesTotal - state.matchesPlayed;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kết thúc giải?'),
        content: Text(
          state.usesGroupStage
              ? 'Nhà vô địch knockout sẽ được chốt và lưu vào lịch sử.'
              : unfinished == 0
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
    if (ok != true) return;
    try {
      await ref.read(leagueControllerProvider.notifier).finishTournament();
    } catch (_) {
      // finishTournament đã revert state về inProgress; báo user retry.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không lưu được lịch sử. Thử lại.')),
        );
      }
    }
  }

  Future<bool?> _confirmCancel(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Huỷ giải?'),
        content: const Text(
          'Toàn bộ tỷ số và lịch thi đấu của giải này sẽ bị mất. '
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

class _RenameLeagueDialog extends StatefulWidget {
  const _RenameLeagueDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameLeagueDialog> createState() => _RenameLeagueDialogState();
}

class _RenameLeagueDialogState extends State<_RenameLeagueDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Tên giải không được để trống.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đổi tên giải'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        onChanged: (_) {
          if (_errorText != null) setState(() => _errorText = null);
        },
        decoration: InputDecoration(
          labelText: 'Tên giải',
          errorText: _errorText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Lưu')),
      ],
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

    if (state.usesGroupStage) {
      if (state.phase == LeaguePhase.groupStage) {
        return _buildGroupStage(context, ref, nameById);
      }
      return _buildKnockout(context, ref, nameById);
    }

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

  Widget _buildGroupStage(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> nameById,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        if (state.groupStageComplete) ...[
          _InfoBanner(
            title: 'Vòng bảng đã đủ kết quả',
            subtitle: 'Kiểm tra lại tỷ số trước khi tạo nhánh knockout.',
            actionLabel: 'Vào knockout',
            onAction: () => _confirmStartKnockout(context, ref),
          ),
          const SizedBox(height: 12),
        ],
        for (final group in state.groups) ...[
          _SectionHeader(
            title: group.name,
            subtitle: '${state.playersInGroup(group).length} người',
          ),
          for (final entry
              in state.groupFixtures
                  .where((f) => f.groupId == group.id)
                  .toList()
                  .asMap()
                  .entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FixtureCard(
                index: entry.key + 1,
                fixture: entry.value,
                p1Name: nameById[entry.value.player1Id] ?? '?',
                p2Name: nameById[entry.value.player2Id] ?? '?',
                onTap: () =>
                    _openScoreSheet(context, ref, entry.value, nameById),
              ),
            ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildKnockout(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> nameById,
  ) {
    final byRound = <int, List<MatchFixture>>{};
    for (final f in state.knockoutFixtures) {
      byRound.putIfAbsent(f.roundIndex, () => []).add(f);
    }
    final rounds = byRound.keys.toList()..sort();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        _InfoBanner(
          title: 'Vòng bảng đã xong',
          subtitle: 'Top 2 mỗi bảng đã vào nhánh knockout.',
        ),
        const SizedBox(height: 12),
        for (final round in rounds) ...[
          _SectionHeader(
            title: byRound[round]!.first.roundName,
            subtitle:
                '${byRound[round]!.where((f) => f.isPlayed).length}/'
                '${byRound[round]!.length} trận',
          ),
          for (final entry in byRound[round]!.asMap().entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FixtureCard(
                index: entry.key + 1,
                fixture: entry.value,
                p1Name: nameById[entry.value.player1Id] ?? '?',
                p2Name: nameById[entry.value.player2Id] ?? '?',
                onTap: () =>
                    _openScoreSheet(context, ref, entry.value, nameById),
              ),
            ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Future<void> _openScoreSheet(
    BuildContext context,
    WidgetRef ref,
    MatchFixture f,
    Map<String, String> nameById,
  ) async {
    final shouldConfirmKnockout = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ScoreInputSheet(
        fixture: f,
        p1Name: nameById[f.player1Id] ?? '?',
        p2Name: nameById[f.player2Id] ?? '?',
      ),
    );
    if (shouldConfirmKnockout == true && context.mounted) {
      await _confirmStartKnockout(context, ref);
    }
  }

  Future<void> _confirmStartKnockout(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final state = ref.read(leagueControllerProvider);
    if (!state.usesGroupStage ||
        state.phase != LeaguePhase.groupStage ||
        !state.groupStageComplete) {
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vào vòng knockout?'),
        content: const Text(
          'Top 2 mỗi bảng sẽ được đưa vào nhánh knockout. '
          'Sau bước này không thể sửa tỷ số vòng bảng nữa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Sửa tiếp'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.account_tree_rounded),
            label: const Text('Vào knockout'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      ref.read(leagueControllerProvider.notifier).startKnockout();
    } on ArgumentError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message?.toString() ?? 'Không tạo được knockout.'),
        ),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textDark,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textBody,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(60),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_tree_rounded,
                  color: AppColors.primaryDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSubtle,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.account_tree_rounded),
                label: Text(actionLabel!),
              ),
            ),
          ],
        ],
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
    final p1Win = fixture.isPlayed && fixture.score1 > fixture.score2;
    final p2Win = fixture.isPlayed && fixture.score2 > fixture.score1;

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
                    _NameRow(name: p1Name, isWinner: p1Win),
                    const SizedBox(height: 4),
                    _NameRow(name: p2Name, isWinner: p2Win),
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
                    border: Border.all(color: AppColors.accent.withAlpha(150)),
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
          isWinner ? Icons.emoji_events_rounded : Icons.circle_outlined,
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
    try {
      final before = ref.read(leagueControllerProvider);
      ref
          .read(leagueControllerProvider.notifier)
          .updateScore(widget.fixture.id, s1, s2);
      final after = ref.read(leagueControllerProvider);
      final shouldConfirmKnockout =
          widget.fixture.stage == MatchStage.group &&
          before.usesGroupStage &&
          before.phase == LeaguePhase.groupStage &&
          after.usesGroupStage &&
          after.phase == LeaguePhase.groupStage &&
          after.groupStageComplete;
      Navigator.of(context).pop(shouldConfirmKnockout);
    } on ArgumentError catch (e) {
      setState(() => _error = e.message?.toString() ?? 'Không lưu được tỷ số.');
    }
  }

  void _clear() {
    try {
      ref.read(leagueControllerProvider.notifier).clearScore(widget.fixture.id);
      Navigator.of(context).pop();
    } on ArgumentError catch (e) {
      setState(() => _error = e.message?.toString() ?? 'Không xoá được tỷ số.');
    }
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
                child: _ScoreField(label: widget.p2Name, controller: _c2),
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
      decoration: InputDecoration(labelText: label, hintText: '0'),
    );
  }
}
