import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/league_player.dart';
import '../models/league_state.dart';
import '../models/match_fixture.dart';
import '../providers/league_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/bracket_tree.dart';
import '../widgets/player_colors.dart';
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
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
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
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
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

    final champion = (state.usesGroupStage || state.usesDoubleElim)
        ? state.championPlayer
        : state.players.first;
    // Không trao "vô địch" nếu chưa đấu trận nào — champion sẽ là người
    // alphabet đầu tiên với 0 điểm, gây hiểu nhầm.
    final showChampion = state.usesDoubleElim
        ? champion != null && state.doubleElimComplete
        : state.usesGroupStage
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
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                iconTheme: const IconThemeData(color: Colors.white),
                title: Text(
                  '${state.displayName} · ${_formatDate(state.finishedAt)}',
                  style: const TextStyle(
                    color: Colors.white,
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
                      badgeText: state.usesDoubleElim
                          ? 'Đấu nhánh'
                          : state.usesGroupStage
                          ? 'Knockout'
                          : '${champion.points} điểm',
                    ),
                    const SizedBox(height: 14),
                  ],
                  _StatsCard(state: state),
                  const SizedBox(height: 14),
                  if (state.usesDoubleElim) ...[
                    _DoubleElimSummary(state: state),
                  ] else if (state.usesGroupStage) ...[
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

/// Summary cho double-elim: render sơ đồ "butterfly" — WB cây bên trái,
/// cúp giữa, LB cây MIRRORED bên phải. Toàn bộ wrap 1 `InteractiveViewer`
/// chung để pan/zoom đồng bộ. Tap-disabled (read-only).
class _DoubleElimSummary extends StatelessWidget {
  const _DoubleElimSummary({required this.state});

  final LeagueState state;

  @override
  Widget build(BuildContext context) {
    if (state.fixtures.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final nameById = {for (final p in state.players) p.id: p.name};
    final colorById = assignPlayerColors(state.players.map((p) => p.id));

    final wbByRound = <int, List<MatchFixture>>{};
    final lbByRound = <int, List<MatchFixture>>{};
    for (final f in state.winnersFixtures) {
      wbByRound.putIfAbsent(f.roundIndex, () => []).add(f);
    }
    for (final f in state.losersFixtures) {
      lbByRound.putIfAbsent(f.roundIndex, () => []).add(f);
    }
    final wbRoundKeys = wbByRound.keys.toList()..sort();
    final lbRoundKeys = lbByRound.keys.toList()..sort();
    final wbAsList = [for (final r in wbRoundKeys) wbByRound[r]!];
    final lbAsList = [for (final r in lbRoundKeys) lbByRound[r]!];

    final gf = state.grandFinalFixture;

    final wbHeight = BracketTree.layoutHeight(wbAsList);
    final lbHeight = _lbHeight(lbAsList);
    final stageHeight = math.max(wbHeight, lbHeight) + 16;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sơ đồ thi đấu',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.textDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pinch để zoom · drag để di chuyển',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSubtle,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: stageHeight + 24,
          child: ClipRect(
            child: InteractiveViewer(
              minScale: 0.25,
              maxScale: 2.0,
              boundaryMargin: const EdgeInsets.all(120),
              constrained: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: stageHeight,
                    child: BracketTree(
                      rounds: wbAsList,
                      nameById: nameById,
                      colorById: colorById,
                      onTap: (_) {},
                      roundLabels: _wbLabels(wbRoundKeys),
                      interactive: false,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    height: stageHeight,
                    child: Center(
                      child: _CenterPodium(
                        fixture: gf,
                        champion: state.championPlayer,
                        runnerUp: state.runnerUpPlayer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (lbAsList.isNotEmpty)
                    SizedBox(
                      height: stageHeight,
                      child: _MirroredLbColumns(
                        rounds: lbAsList,
                        nameById: nameById,
                        colorById: colorById,
                        labels: _lbLabels(lbRoundKeys),
                        stageHeight: stageHeight,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _lbHeight(List<List<MatchFixture>> rounds) {
    if (rounds.isEmpty) return 0;
    final maxCount = rounds.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    return maxCount * (BracketTree.cardH + BracketTree.baseRowGap) -
        BracketTree.baseRowGap +
        BracketTree.headerH +
        12;
  }

  List<String> _wbLabels(List<int> rounds) {
    if (rounds.isEmpty) return const [];
    final finalRound = rounds.last;
    return [for (final r in rounds) _wbRoundLabel(r, finalRound: finalRound)];
  }

  String _wbRoundLabel(int round, {required int finalRound}) {
    if (round == finalRound) return 'WB Bán kết';
    if (state.players.length > 8 && round == finalRound - 1) return 'WB Tứ kết';
    return 'WB R$round';
  }

  List<String> _lbLabels(List<int> rounds) {
    if (rounds.isEmpty) return const [];
    final finalRound = rounds.last;
    return [
      for (final r in rounds)
        r == finalRound
            ? 'LB Bán kết'
            : state.players.length > 8 && r == finalRound - 1
            ? 'LB Tứ kết'
            : 'LB R$r',
    ];
  }
}

/// Cúp + tên vô địch ở giữa sơ đồ. Nhỏ gọn vì cần fit giữa WB & LB.
class _CenterPodium extends StatelessWidget {
  const _CenterPodium({
    required this.fixture,
    required this.champion,
    required this.runnerUp,
  });

  final MatchFixture? fixture;
  final LeaguePlayer? champion;
  final LeaguePlayer? runnerUp;

  @override
  Widget build(BuildContext context) {
    final played =
        fixture != null &&
        fixture!.isPlayed &&
        fixture!.score1 != fixture!.score2;
    // Score luôn hiển thị "championScore – runnerUpScore" thay vì
    // "score1 – score2" thô (fixture order). Tránh user đọc nhầm theo
    // thứ tự p1/p2 không thấy được.
    final int? championScore;
    final int? runnerUpScore;
    if (played && fixture != null && champion != null) {
      if (champion!.id == fixture!.player1Id) {
        championScore = fixture!.score1;
        runnerUpScore = fixture!.score2;
      } else {
        championScore = fixture!.score2;
        runnerUpScore = fixture!.score1;
      }
    } else {
      championScore = null;
      runnerUpScore = null;
    }
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.textDark, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withAlpha(70),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 6),
          const Text(
            'CHUNG KẾT TỔNG',
            style: TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            played ? (champion?.name ?? '?') : 'Chờ kết quả',
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          if (played && fixture != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$championScore – $runnerUpScore',
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (runnerUp != null) ...[
              const SizedBox(height: 6),
              Text(
                'Á quân: ${runnerUp!.name}',
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// LB rendered mirrored — R1 (most matches) on the RIGHT, LB Final on the
/// LEFT (closest to cup). Columns stack right-to-left.
class _MirroredLbColumns extends StatelessWidget {
  const _MirroredLbColumns({
    required this.rounds,
    required this.nameById,
    required this.colorById,
    required this.labels,
    required this.stageHeight,
  });

  final List<List<MatchFixture>> rounds;
  final Map<String, String> nameById;
  final Map<String, Color> colorById;
  final List<String> labels;
  final double stageHeight;

  static const double cardW = 160;
  static const double cardH = 60;
  static const double colGap = 18;
  static double get _slotHeight => cardH + BracketTree.baseRowGap;

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty) return const SizedBox.shrink();
    final rawMatchTops = _computeMatchTops([
      for (final round in rounds) round.length,
    ]);
    final matchTops = _centerOnFinalMatch(rawMatchTops);
    final totalW = rounds.length * (cardW + colGap) - colGap;

    return SizedBox(
      width: totalW + 8,
      height: stageHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MirroredLbLinesPainter(
                rounds: rounds,
                matchTops: matchTops,
              ),
            ),
          ),
          for (var roundIndex = 0; roundIndex < rounds.length; roundIndex++)
            Positioned(
              left: _columnX(_displayColumn(roundIndex, rounds.length)),
              top: 0,
              width: cardW,
              child: _LbRoundHeader(
                label: roundIndex < labels.length
                    ? labels[roundIndex]
                    : 'LB R${roundIndex + 1}',
              ),
            ),
          for (var roundIndex = 0; roundIndex < rounds.length; roundIndex++)
            for (
              var matchIndex = 0;
              matchIndex < rounds[roundIndex].length;
              matchIndex++
            )
              Positioned(
                left: _columnX(_displayColumn(roundIndex, rounds.length)),
                top: matchTops[roundIndex][matchIndex],
                width: cardW,
                height: cardH,
                child: _LbResultCard(
                  fixture: rounds[roundIndex][matchIndex],
                  nameById: nameById,
                  colorById: colorById,
                ),
              ),
        ],
      ),
    );
  }

  static double _columnX(int displayColumn) => displayColumn * (cardW + colGap);

  static int _displayColumn(int roundIndex, int roundCount) =>
      roundCount - 1 - roundIndex;

  static List<List<double>> _computeMatchTops(List<int> counts) {
    final result = <List<double>>[];
    for (var r = 0; r < counts.length; r++) {
      final count = counts[r];
      if (count <= 0) {
        result.add(const []);
        continue;
      }
      if (r == 0) {
        result.add([
          for (var i = 0; i < count; i++) BracketTree.headerH + i * _slotHeight,
        ]);
        continue;
      }

      final prev = result[r - 1];
      if (prev.isEmpty) {
        result.add([
          for (var i = 0; i < count; i++) BracketTree.headerH + i * _slotHeight,
        ]);
      } else if (prev.length >= count * 2) {
        result.add([
          for (var i = 0; i < count; i++) (prev[i * 2] + prev[i * 2 + 1]) / 2,
        ]);
      } else if (prev.length == count) {
        result.add([...prev]);
      } else if (count == 1) {
        result.add([(prev.first + prev.last) / 2]);
      } else {
        final step = prev.length == 1
            ? _slotHeight
            : (prev.last - prev.first) / (count - 1);
        result.add([for (var i = 0; i < count; i++) prev.first + i * step]);
      }
    }
    return result;
  }

  List<List<double>> _centerOnFinalMatch(List<List<double>> matchTops) {
    if (matchTops.isEmpty || matchTops.last.isEmpty) return matchTops;
    final targetTop = (stageHeight - cardH) / 2;
    final offset = targetTop - matchTops.last.first;
    return [
      for (final roundTops in matchTops)
        [for (final top in roundTops) top + offset],
    ];
  }
}

class _MirroredLbLinesPainter extends CustomPainter {
  _MirroredLbLinesPainter({required this.rounds, required this.matchTops});

  final List<List<MatchFixture>> rounds;
  final List<List<double>> matchTops;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textSubtle.withAlpha(150)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (var r = 1; r < rounds.length; r++) {
      for (var i = 0; i < rounds[r].length; i++) {
        final sourceDisplay = _MirroredLbColumns._displayColumn(
          r - 1,
          rounds.length,
        );
        final targetDisplay = _MirroredLbColumns._displayColumn(
          r,
          rounds.length,
        );
        final xSourceLeft = _MirroredLbColumns._columnX(sourceDisplay);
        final xTargetRight =
            _MirroredLbColumns._columnX(targetDisplay) +
            _MirroredLbColumns.cardW;
        final xMid = (xSourceLeft + xTargetRight) / 2;
        final yT = matchTops[r][i] + _MirroredLbColumns.cardH / 2;

        if (rounds[r - 1].length >= rounds[r].length * 2) {
          final srcA = i * 2;
          final srcB = i * 2 + 1;
          if (srcA >= rounds[r - 1].length || srcB >= rounds[r - 1].length) {
            continue;
          }
          final yA = matchTops[r - 1][srcA] + _MirroredLbColumns.cardH / 2;
          final yB = matchTops[r - 1][srcB] + _MirroredLbColumns.cardH / 2;

          canvas.drawLine(Offset(xSourceLeft, yA), Offset(xMid, yA), paint);
          canvas.drawLine(Offset(xSourceLeft, yB), Offset(xMid, yB), paint);
          canvas.drawLine(Offset(xMid, yA), Offset(xMid, yB), paint);
          canvas.drawLine(Offset(xMid, yT), Offset(xTargetRight, yT), paint);
        } else if (rounds[r - 1].length == rounds[r].length &&
            i < matchTops[r - 1].length) {
          final yPrev = matchTops[r - 1][i] + _MirroredLbColumns.cardH / 2;
          canvas.drawLine(
            Offset(xSourceLeft, yPrev),
            Offset(xTargetRight, yT),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_MirroredLbLinesPainter oldDelegate) =>
      oldDelegate.rounds != rounds || oldDelegate.matchTops != matchTops;
}

class _LbRoundHeader extends StatelessWidget {
  const _LbRoundHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: BracketTree.headerH - 4,
      child: Center(
        child: Text(
          label.isEmpty ? '-' : label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textBody,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _LbResultCard extends StatelessWidget {
  const _LbResultCard({
    required this.fixture,
    required this.nameById,
    required this.colorById,
  });

  final MatchFixture fixture;
  final Map<String, String> nameById;
  final Map<String, Color> colorById;

  @override
  Widget build(BuildContext context) {
    final p1Win = fixture.isPlayed && fixture.score1 > fixture.score2;
    final p2Win = fixture.isPlayed && fixture.score2 > fixture.score1;
    final p1Name = nameById[fixture.player1Id] ?? '— TBD —';
    final p2Name = nameById[fixture.player2Id] ?? '— TBD —';
    final p1Color = colorById[fixture.player1Id] ?? AppColors.textSubtle;
    final p2Color = colorById[fixture.player2Id] ?? AppColors.textSubtle;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _row(
            p1Name,
            p1Color,
            p1Win,
            fixture.isPlayed ? '${fixture.score1}' : '',
          ),
          const SizedBox(height: 4),
          _row(
            p2Name,
            p2Color,
            p2Win,
            fixture.isPlayed ? '${fixture.score2}' : '',
          ),
        ],
      ),
    );
  }

  Widget _row(String name, Color color, bool isWinner, String score) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: isWinner ? FontWeight.w900 : FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        if (isWinner) ...[
          const SizedBox(width: 4),
          const Icon(
            Icons.emoji_events_rounded,
            size: 13,
            color: AppColors.trophyGold,
          ),
        ],
        if (score.isNotEmpty) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isWinner
                  ? AppColors.accent.withAlpha(60)
                  : AppColors.border,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              score,
              style: TextStyle(
                color: isWinner ? AppColors.primaryDark : AppColors.textBody,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _KnockoutSummary extends StatelessWidget {
  const _KnockoutSummary({required this.state});

  final LeagueState state;

  static const _thirdPlaceLabel = 'Tranh 3-4';

  List<List<MatchFixture>> _splitByRoundName(List<MatchFixture> fixtures) {
    final main = fixtures
        .where((f) => f.roundName != _thirdPlaceLabel)
        .toList();
    final third = fixtures
        .where((f) => f.roundName == _thirdPlaceLabel)
        .toList();
    return [if (main.isNotEmpty) main, if (third.isNotEmpty) third];
  }

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
          // Tách 'Tranh 3-4' thành section riêng, chung kết trước.
          for (final section in _splitByRoundName(byRound[round]!)) ...[
            Text(
              section.first.roundName,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textBody,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            for (final fixture in section)
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
