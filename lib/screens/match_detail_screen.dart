import 'package:flutter/material.dart';

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${match.modeLabel} · ${_formatDate(match.finishedAt)}',
          style: const TextStyle(
            color: Colors.white,
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
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: match.events.isEmpty
                    ? Center(
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
                      )
                    : RoundHistoryView(
                        events: match.events,
                        totalRounds: match.roundsPlayed,
                      ),
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

class _PlayerScoreRow extends StatelessWidget {
  const _PlayerScoreRow({
    required this.rank,
    required this.name,
    required this.score,
  });

  final int rank;
  final String name;
  final int score;

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
          score > 0 ? '+$score' : '$score',
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
}
