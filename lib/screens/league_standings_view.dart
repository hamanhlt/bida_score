import 'package:flutter/material.dart';

import '../models/league_player.dart';
import '../models/league_state.dart';
import '../theme/app_colors.dart';

/// Bảng xếp hạng league — table với cột: # · Tên · Trận · Thắng · GF · GA · HS · Điểm.
///
/// Players nhận từ ngoài (đã sort theo ranking trong engine). Dùng chung cho
/// LeaguePlayScreen tab "Bảng xếp hạng" + LeagueResultScreen + LeagueHistory
/// detail.
class LeagueStandingsView extends StatelessWidget {
  const LeagueStandingsView({
    super.key,
    required this.players,
    this.highlightChampion = false,
  });

  final List<LeaguePlayer> players;

  /// True → top-3 hiển thị màu medal (Gold/Silver/Bronze). Dùng ở Result screen.
  final bool highlightChampion;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Chưa có người chơi.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSubtle),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: _StandingsTable(
        players: players,
        highlightChampion: highlightChampion,
      ),
    );
  }
}

class LeagueGroupsStandingsView extends StatelessWidget {
  const LeagueGroupsStandingsView({
    super.key,
    required this.state,
    this.highlightQualified = true,
    this.scrollable = true,
  });

  final LeagueState state;
  final bool highlightQualified;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    if (state.groups.isEmpty) {
      return LeagueStandingsView(players: state.players);
    }

    final theme = Theme.of(context);
    final content = Column(
      children: [
        for (final group in state.groups) ...[
          Row(
            children: [
              Text(
                group.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Top 2 đi tiếp',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textBody,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _StandingsTable(
            players: state.playersInGroup(group),
            highlightQualified: highlightQualified,
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
    if (!scrollable) return content;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: content,
    );
  }
}

class _StandingsTable extends StatelessWidget {
  const _StandingsTable({
    required this.players,
    this.highlightChampion = false,
    this.highlightQualified = false,
  });

  final List<LeaguePlayer> players;
  final bool highlightChampion;
  final bool highlightQualified;

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        children: [
          const _StandingsHeader(),
          for (var i = 0; i < players.length; i++)
            _StandingsRow(
              rank: i + 1,
              player: players[i],
              isLast: i == players.length - 1,
              highlightChampion: highlightChampion,
              highlightQualified: highlightQualified,
            ),
        ],
      ),
    );
  }
}

class _StandingsHeader extends StatelessWidget {
  const _StandingsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryDark,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: const Row(
        children: [
          SizedBox(width: 28, child: _HeaderText('#', center: true)),
          SizedBox(width: 8),
          Expanded(child: _HeaderText('Người chơi')),
          _HeaderCell('Trận', width: 36),
          _HeaderCell('HS', width: 42),
          _HeaderCell('Điểm', width: 54),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text, {this.center = false});
  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: 12,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, {required this.width});
  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: _HeaderText(text, center: true));
  }
}

class _StandingsRow extends StatelessWidget {
  const _StandingsRow({
    required this.rank,
    required this.player,
    required this.isLast,
    required this.highlightChampion,
    required this.highlightQualified,
  });

  final int rank;
  final LeaguePlayer player;
  final bool isLast;
  final bool highlightChampion;
  final bool highlightQualified;

  @override
  Widget build(BuildContext context) {
    final medalColor = highlightChampion
        ? switch (rank) {
            1 => AppColors.trophyGold,
            2 => AppColors.trophySilver,
            3 => AppColors.trophyBronze,
            _ => null,
          }
        : null;
    final qualifiedColor = highlightQualified && rank <= 2
        ? AppColors.shooter
        : null;

    final rowBg =
        (medalColor ?? qualifiedColor)?.withAlpha(28) ?? Colors.transparent;

    return Container(
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : AppColors.border,
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: _RankBadge(rank: rank, color: medalColor ?? qualifiedColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              player.name,
              style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: rank == 1 && highlightChampion
                    ? FontWeight.w900
                    : FontWeight.w700,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _StatCell(text: '${player.matchesPlayed}', width: 36),
          _StatCell(
            text: _formatSigned(player.goalDifference),
            width: 42,
            color: player.goalDifference > 0
                ? AppColors.shooter
                : player.goalDifference < 0
                ? AppColors.victim
                : AppColors.textSubtle,
          ),
          _PointsCell(text: '${player.points}'),
        ],
      ),
    );
  }

  String _formatSigned(int n) => n > 0 ? '+$n' : '$n';
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, this.color});

  final int rank;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (color != null) {
      return Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color!.withAlpha(50),
          shape: BoxShape.circle,
          border: Border.all(color: color!, width: 1.2),
        ),
        child: Text(
          '$rank',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      );
    }
    return Text(
      '$rank',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.textSubtle,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.text,
    required this.width,
    this.color = AppColors.textBody,
  });

  final String text;
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _PointsCell extends StatelessWidget {
  const _PointsCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      child: Align(
        alignment: Alignment.center,
        child: Container(
          constraints: const BoxConstraints(minWidth: 34),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
