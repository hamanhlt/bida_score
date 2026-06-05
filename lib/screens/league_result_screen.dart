import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/league_state.dart';
import '../models/match_fixture.dart';
import '../providers/league_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/table_background.dart';
import 'league_standings_view.dart';

/// Màn kết quả cuối giải đấu (status = finished). Hiển thị bảng xếp hạng
/// chung cuộc + nút "Tạo giải mới".
///
/// Mở từ:
/// - LeaguePlayScreen "Kết thúc giải" → `finishTournament` → state.finished
///   → _AppShell route sang đây.
/// - LeagueHistoryScreen tap 1 entry → push trực tiếp với `league` param
///   (đọc từ history, không phụ thuộc LeagueController state).
class LeagueResultScreen extends ConsumerWidget {
  const LeagueResultScreen({super.key, this.league});

  /// Nếu khác null → render giải này (từ history). Null → render
  /// `leagueControllerProvider` state (giải vừa kết thúc).
  final LeagueState? league;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LeagueState state = league ?? ref.watch(leagueControllerProvider);
    final theme = Theme.of(context);
    final isFromHistory = league != null;

    // Khi mở từ history mà entry hỏng (data lạ) — vẫn render AppBar có back
    // để user thoát; không trả `SizedBox.shrink` (sẽ tạo trang trắng kẹt).
    if (state.status != LeagueStatus.finished || state.players.isEmpty) {
      if (isFromHistory) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            foregroundColor: AppColors.textDark,
            iconTheme: const IconThemeData(color: AppColors.textDark),
            title: const Text('Giải đấu'),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Dữ liệu giải này không hợp lệ.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSubtle,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }
      // Trạng thái không hợp lệ ngoài history (vd lỗi defensive) — render
      // Scaffold với back button để user không kẹt màn trắng.
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          foregroundColor: AppColors.textDark,
          iconTheme: const IconThemeData(color: AppColors.textDark),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                ref.read(leagueControllerProvider.notifier).backToList(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Dữ liệu giải không hợp lệ.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSubtle,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final champion = state.usesGroupStage
        ? state.championPlayer
        : state.players.first;
    // Không trao "vô địch" nếu chưa đấu trận nào — champion sẽ là người
    // alphabet đầu tiên với 0 điểm, gây hiểu nhầm.
    final showChampion = state.usesGroupStage
        ? champion != null && state.knockoutComplete
        : state.matchesPlayed > 0;

    return PopScope(
      // Khi từ history (push qua Navigator) → để default pop. Khi từ
      // finishTournament → hardware back về list (KHÔNG pop Navigator
      // vì screen này là child của _AppShell, không có route phía dưới).
      canPop: isFromHistory,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || isFromHistory) return;
        ref.read(leagueControllerProvider.notifier).backToList();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: isFromHistory
            ? AppBar(
                foregroundColor: AppColors.textDark,
                iconTheme: const IconThemeData(color: AppColors.textDark),
                title: Text(
                  '${state.displayName} · ${_formatDate(state.finishedAt)}',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              )
            : null,
        body: TableBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isFromHistory) ...[
                    Text(
                      state.displayName,
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kết quả giải đã chốt và lưu vào lịch sử.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textBody,
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (showChampion) ...[
                    _ChampionCard(
                      name: champion!.name,
                      badgeText: state.usesGroupStage
                          ? 'Knockout'
                          : '${champion.points} điểm',
                    ),
                    const SizedBox(height: 14),
                  ],
                  _StatsCard(state: state),
                  const SizedBox(height: 14),
                  if (state.usesGroupStage) ...[
                    LeagueGroupsStandingsView(state: state, scrollable: false),
                    _KnockoutSummary(state: state),
                  ] else
                    LeagueStandingsView(
                      players: state.players,
                      highlightChampion: showChampion,
                    ),
                  const SizedBox(height: 20),
                  if (!isFromHistory)
                    FilledButton.icon(
                      onPressed: () => ref
                          .read(leagueControllerProvider.notifier)
                          .backToList(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Về danh sách giải'),
                    ),
                ],
              ),
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

class _ChampionCard extends StatelessWidget {
  const _ChampionCard({required this.name, required this.badgeText});

  final String name;
  final String badgeText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.textDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          const Text(
            'Vô địch',
            style: TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.state});

  final LeagueState state;

  @override
  Widget build(BuildContext context) {
    final unfinished = state.matchesTotal - state.matchesPlayed;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          _Chip(label: 'Số người: ${state.players.length}'),
          _Chip(label: state.phaseLabel),
          if (state.usesGroupStage) ...[
            _Chip(label: '${state.groups.length} bảng · ${_groupSizeText()}'),
            _Chip(
              label:
                  'Vòng bảng: ${state.groupMatchesPlayed}/${state.groupMatchesTotal}',
            ),
            _Chip(
              label:
                  'Knockout: ${state.knockoutMatchesPlayed}/${state.knockoutMatchesTotal}',
            ),
          ] else
            _Chip(
              label: 'Số trận: ${state.matchesPlayed}/${state.matchesTotal}',
            ),
          if (unfinished > 0)
            _Chip(
              label: '$unfinished trận chưa đấu',
              color: AppColors.victim.withAlpha(40),
              textColor: AppColors.victim,
            ),
          if (state.finishedAt != null)
            _Chip(label: _formatDate(state.finishedAt!)),
        ],
      ),
    );
  }

  String _formatDate(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)}/${at.year} '
        '${two(at.hour)}:${two(at.minute)}';
  }

  String _groupSizeText() {
    final sizes = [for (final g in state.groups) g.playerIds.length];
    if (sizes.isEmpty) return '${state.groupSize} người';
    final uniqueSizes = sizes.toSet();
    if (uniqueSizes.length == 1) return '${sizes.first} người/bảng';
    return sizes.join(' + ');
  }
}

class _KnockoutSummary extends StatelessWidget {
  const _KnockoutSummary({required this.state});

  final LeagueState state;

  @override
  Widget build(BuildContext context) {
    if (state.knockoutFixtures.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final nameById = {for (final p in state.players) p.id: p.name};
    final byRound = <int, List<MatchFixture>>{};
    for (final f in state.knockoutFixtures) {
      byRound.putIfAbsent(f.roundIndex, () => []).add(f);
    }
    final rounds = byRound.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        Text(
          'Nhánh knockout',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.textDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        for (final round in rounds) ...[
          Text(
            byRound[round]!.first.roundName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textBody,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          for (final fixture in byRound[round]!)
            _KnockoutResultRow(
              p1Name: nameById[fixture.player1Id] ?? '?',
              p2Name: nameById[fixture.player2Id] ?? '?',
              score: fixture.isPlayed
                  ? '${fixture.score1} – ${fixture.score2}'
                  : 'Chưa đấu',
            ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _KnockoutResultRow extends StatelessWidget {
  const _KnockoutResultRow({
    required this.p1Name,
    required this.p2Name,
    required this.score,
  });

  final String p1Name;
  final String p2Name;
  final String score;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              p1Name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              score,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              p2Name,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.color, this.textColor});
  final String label;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? AppColors.primary.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor ?? AppColors.primaryDark,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
