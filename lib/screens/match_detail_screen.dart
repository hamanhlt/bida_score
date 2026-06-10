import 'package:flutter/material.dart';

import '../models/cash_game_state.dart';
import '../models/game_mode.dart';
import '../models/match_result.dart';
import '../theme/app_colors.dart';
import '../widgets/round_history_view.dart';
import '../widgets/table_background.dart';

/// Chi tiết 1 trận đã lưu — header bảng điểm cuối + cây lịch sử ván/lượt
/// (giống màn "Lịch sử" trong trận). Mở từ [MatchHistoryScreen].
class MatchDetailScreen extends StatelessWidget {
  const MatchDetailScreen({super.key, required this.match});

  final MatchResult match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMoney = match.modeLabel == GameMode.cashGame.label;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        foregroundColor: AppColors.textDark,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        title: Text(
          '${match.modeLabel} · ${_formatDate(match.finishedAt)}',
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      body: TableBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header: bảng điểm cuối + số ván.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.textDark,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${match.roundsPlayed} ván · ${match.players.length} người',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (var i = 0; i < match.players.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i == match.players.length - 1 ? 0 : 6,
                          ),
                          child: _PlayerScoreRow(
                            rank: i + 1,
                            name: match.players[i].name,
                            score: match.players[i].score,
                            isMoney: isMoney,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: switch ((
                  match.events.isNotEmpty,
                  match.rackWinners.isNotEmpty,
                )) {
                  // Bắn đền — cây ván/lượt.
                  (true, _) => RoundHistoryView(
                    events: match.events,
                    totalRounds: match.roundsPlayed,
                  ),
                  // race-to-X — play-by-play từng rack.
                  (false, true) => _RackPlayByPlay(
                    rackWinners: match.rackWinners,
                    playerNames: [for (final p in match.players) p.name],
                  ),
                  // Trận cũ không lưu chi tiết.
                  (false, false) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Trận này không lưu chi tiết từng lượt.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSubtle,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                },
              ),
            ],
          ),
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

/// Play-by-play từng rack cho mode race-to-X (9/8/10-Ball). Mới nhất ở trên,
/// mỗi dòng: "Rack N · [người thắng] thắng" + tỉ số chạy tới rack đó.
class _RackPlayByPlay extends StatelessWidget {
  const _RackPlayByPlay({required this.rackWinners, required this.playerNames});

  /// Tên người thắng từng rack, theo thứ tự (rack 1 = phần tử 0).
  final List<String> rackWinners;

  /// Tên 2 người chơi — `[0]` là người thắng trận (theo thứ tự ranked).
  final List<String> playerNames;

  @override
  Widget build(BuildContext context) {
    if (rackWinners.isEmpty) {
      return const SizedBox.shrink();
    }
    final nameA = playerNames.isNotEmpty ? playerNames[0] : '';
    final nameB = playerNames.length > 1 ? playerNames[1] : '';

    final total = rackWinners.length;
    // Hiển thị mới nhất (rack cao nhất) ở trên.
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: total,
      itemBuilder: (context, idx) {
        final rackNumber = total - idx; // idx 0 → rack cuối cùng
        final winner = rackWinners[rackNumber - 1];
        // Tỉ số chạy tính tới hết rack này (gồm cả rack hiện tại).
        var a = 0;
        var b = 0;
        for (var k = 0; k < rackNumber; k++) {
          if (rackWinners[k] == nameA) a++;
          if (rackWinners[k] == nameB) b++;
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _RackRow(
            rackNumber: rackNumber,
            winner: winner,
            scoreA: a,
            scoreB: b,
          ),
        );
      },
    );
  }
}

class _RackRow extends StatelessWidget {
  const _RackRow({
    required this.rackNumber,
    required this.winner,
    required this.scoreA,
    required this.scoreB,
  });

  final int rackNumber;
  final String winner;
  final int scoreA;
  final int scoreB;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Rack $rackNumber',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.primaryDark,
                ),
                children: [
                  TextSpan(
                    text: winner,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(text: ' thắng'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(40),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accent.withAlpha(120)),
            ),
            child: Text(
              '$scoreA – $scoreB',
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerScoreRow extends StatelessWidget {
  const _PlayerScoreRow({
    required this.rank,
    required this.name,
    required this.score,
    required this.isMoney,
  });

  final int rank;
  final String name;
  final int score;
  final bool isMoney;

  @override
  Widget build(BuildContext context) {
    final rankColor = switch (rank) {
      1 => AppColors.trophyGold,
      2 => AppColors.trophySilver,
      3 => AppColors.trophyBronze,
      _ => Colors.white70,
    };
    final scoreColor = score > 0
        ? AppColors.shooter
        : score < 0
        ? AppColors.negativeSoft
        : Colors.white70;

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
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
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              color: Colors.white,
              fontWeight: rank == 1 ? FontWeight.w900 : FontWeight.w700,
              fontSize: 15,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          _formatScore(score),
          style: TextStyle(
            color: scoreColor,
            fontWeight: FontWeight.w900,
            fontSize: 17,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  String _formatScore(int s) {
    if (!isMoney) return s > 0 ? '+$s' : '$s';
    final value = formatVnd(s.abs());
    if (s > 0) return '+$value';
    if (s < 0) return '-$value';
    return value;
  }
}
