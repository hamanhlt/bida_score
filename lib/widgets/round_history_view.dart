import 'package:flutter/material.dart';

import '../models/score_event.dart';
import '../theme/app_colors.dart';
import 'ball_icon.dart';

/// Cây lịch sử ghi điểm — hiển thị tất cả ván `1..totalRounds` (kể cả ván
/// trống không có lượt ghi điểm), mỗi ván xổ ra danh sách lượt.
///
/// Dùng chung cho:
/// - [HistoryScreen] (lịch sử trong trận đang chơi — events từ GameState)
/// - [MatchDetailScreen] (lịch sử trận đã lưu — events từ MatchResult)
class RoundHistoryView extends StatelessWidget {
  const RoundHistoryView({
    super.key,
    required this.events,
    required this.totalRounds,
  });

  final List<ScoreEvent> events;
  final int totalRounds;

  @override
  Widget build(BuildContext context) {
    // Gộp event theo ván. Trong mỗi ván, sort lượt theo thời gian DESC
    // (lượt mới nhất ở trên).
    final byRound = <int, List<ScoreEvent>>{};
    for (final e in events) {
      byRound.putIfAbsent(e.roundNumber, () => []).add(e);
    }
    for (final list in byRound.values) {
      list.sort((a, b) => b.at.compareTo(a.at));
    }

    // Liệt kê TẤT CẢ ván 1..totalRounds (ít nhất 1), DESC. Ván trống vẫn hiện.
    final maxRound = totalRounds < 1 ? 1 : totalRounds;
    final rounds = [for (var r = maxRound; r >= 1; r--) r];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: rounds.length,
      itemBuilder: (context, roundIdx) {
        final roundNumber = rounds[roundIdx];
        final roundEvents = byRound[roundNumber] ?? const <ScoreEvent>[];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _RoundExpansion(
            roundNumber: roundNumber,
            events: roundEvents,
            // Ván mới nhất (đầu list) mở sẵn.
            initiallyExpanded: roundIdx == 0,
          ),
        );
      },
    );
  }
}

/// Header của 1 ván — tap để xổ/co list lượt bên trong. Ván trống hiện
/// dạng card phẳng, không xổ được.
class _RoundExpansion extends StatelessWidget {
  const _RoundExpansion({
    required this.roundNumber,
    required this.events,
    required this.initiallyExpanded,
  });

  final int roundNumber;
  final List<ScoreEvent> events;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final roundBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Ván $roundNumber',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );

    // Ván trống — không có lượt ghi điểm.
    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            roundBadge,
            const SizedBox(width: 12),
            Text(
              'Chưa ghi điểm',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSubtle,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    // Số thứ tự lượt theo thời gian thật (chronological): event đầu tiên
    // trong ván là #1, ngay cả khi ta đang sort DESC để hiển thị.
    final reverseIndex = events.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // Bỏ divider mặc định của ExpansionTile để không có line lạ.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          iconColor: AppColors.primaryDark,
          collapsedIconColor: AppColors.textSubtle,
          title: Row(
            children: [
              roundBadge,
              const SizedBox(width: 12),
              Text(
                '${events.length} lượt',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSubtle,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _RoundNetSummary(events: events),
          ),
          children: [
            for (var i = 0; i < events.length; i++) ...[
              // events đã sort DESC → event đầu list là lượt mới nhất.
              // Index hiển thị là số thứ tự chronological (lượt thực sự
              // diễn ra thứ mấy trong ván) → reverseIndex - i.
              _EventCard(event: events[i], index: reverseIndex - i),
              if (i != events.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dòng tổng net điểm trong 1 ván — hiển thị luôn ở header (cả collapsed),
/// giúp scan nhanh ai được/mất nhiều nhất ván đó.
class _RoundNetSummary extends StatelessWidget {
  const _RoundNetSummary({required this.events});

  final List<ScoreEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    // Tổng hợp net theo từng player.
    final netByPlayer = <String, int>{};
    for (final e in events) {
      netByPlayer.update(
        e.shooterName,
        (curr) => curr + e.shooterGain,
        ifAbsent: () => e.shooterGain,
      );
      for (final v in e.victimNames) {
        netByPlayer.update(
          v,
          (curr) => curr - e.pointsPerVictim,
          ifAbsent: () => -e.pointsPerVictim,
        );
      }
    }

    // Sort: dương trước (gainer), 0, âm cuối — dễ scan ai thắng to.
    final entries = netByPlayer.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final e in entries) _NetChip(name: e.key, net: e.value),
      ],
    );
  }
}

class _NetChip extends StatelessWidget {
  const _NetChip({required this.name, required this.net});

  final String name;
  final int net;

  @override
  Widget build(BuildContext context) {
    final color = net > 0
        ? AppColors.shooter
        : net < 0
            ? AppColors.victim
            : AppColors.textSubtle;
    final sign = net > 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(110)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: name,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            const TextSpan(text: '  '),
            TextSpan(
              text: '$sign$net',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.index});

  final ScoreEvent event;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMultiplier = event.multiplier > 1;
    final isMultiVictim = event.victimNames.length > 1;

    final tagLabel = switch ((isMultiplier, isMultiVictim)) {
      (true, true) => 'Chấm phá',
      (true, false) => 'Chấm đơn',
      (false, true) => 'Đền cả bàn',
      (false, false) => 'Bắn đền',
    };
    final tagColor = isMultiplier ? AppColors.accent : AppColors.shooter;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IndexBadge(index: index),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: tagColor.withAlpha(38),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: tagColor),
                ),
                child: Text(
                  tagLabel,
                  style: TextStyle(
                    color: tagColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(event.at),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSubtle,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Flow: shooter → balls → victims (wrap nếu hẹp).
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _PlayerTag(
                name: event.shooterName,
                color: AppColors.shooter,
                delta: '+${event.shooterGain}',
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.textSubtle,
              ),
              for (final b in event.balls)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BallIcon(number: b.number, size: 26),
                    const SizedBox(width: 4),
                    Text(
                      '+${b.points}',
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              if (event.multiplier > 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '×2',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.textSubtle,
              ),
              for (final victim in event.victimNames)
                _PlayerTag(
                  name: victim,
                  color: AppColors.victim,
                  delta: '-${event.pointsPerVictim}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }
}

class _IndexBadge extends StatelessWidget {
  const _IndexBadge({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primaryDark,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$index',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _PlayerTag extends StatelessWidget {
  const _PlayerTag({
    required this.name,
    required this.color,
    required this.delta,
  });

  final String name;
  final Color color;
  final String delta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            delta,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
