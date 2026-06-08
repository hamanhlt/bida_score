import 'package:flutter/material.dart';

import '../models/match_fixture.dart';
import '../theme/app_colors.dart';

/// Render bracket tree: mỗi round là một cột, card xếp dọc và nối vào round
/// kế tiếp nếu tìm được đủ 2 trận nguồn.
///
/// Dùng cho winners bracket, losers bracket dạng đơn giản và knockout phase.
/// Với losers bracket, các đường rơi từ WB xuống LB không vẽ chéo để sơ đồ dễ
/// đọc trên màn nhỏ.
class BracketTree extends StatelessWidget {
  const BracketTree({
    super.key,
    required this.rounds,
    required this.nameById,
    required this.colorById,
    required this.onTap,
    this.roundLabels,
  });

  /// `rounds[r]` là list fixture của round r (0-indexed). Mỗi fixture round
  /// r > 0 sẽ được nối với 2 fixture liền nhau (index 2i, 2i+1) của round r-1
  /// nếu các source đó tồn tại.
  final List<List<MatchFixture>> rounds;
  final Map<String, String> nameById;
  final Map<String, Color> colorById;
  final void Function(MatchFixture) onTap;

  /// Nhãn hiển thị phía trên mỗi cột. Nếu null thì lấy từ `fixture.roundName`.
  final List<String>? roundLabels;

  static const double cardW = 160;
  static const double cardH = 60;
  static const double colGap = 32;
  static const double baseRowGap = 16;
  static const double headerH = 28;

  static double get _slotHeight => cardH + baseRowGap;

  static double layoutHeight(List<List<MatchFixture>> rounds) {
    if (rounds.isEmpty || rounds.first.isEmpty) return 200;
    final matchTops = _computeMatchTops([
      for (final round in rounds) round.length,
    ]);
    var maxBottom = headerH + cardH;
    for (final roundTops in matchTops) {
      for (final top in roundTops) {
        final bottom = top + cardH;
        if (bottom > maxBottom) maxBottom = bottom;
      }
    }
    return maxBottom + 8;
  }

  static List<List<double>> _computeMatchTops(List<int> counts) {
    final result = <List<double>>[];
    for (var r = 0; r < counts.length; r++) {
      final count = counts[r];
      if (count <= 0) {
        result.add(const []);
        continue;
      }
      if (r == 0) {
        result.add([for (var i = 0; i < count; i++) headerH + i * _slotHeight]);
        continue;
      }

      final prev = result[r - 1];
      if (prev.isEmpty) {
        result.add([for (var i = 0; i < count; i++) headerH + i * _slotHeight]);
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

  static double columnX(int round) => round * (cardW + colGap);

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty || rounds.first.isEmpty) {
      return const SizedBox.shrink();
    }
    final matchTops = _computeMatchTops([
      for (final round in rounds) round.length,
    ]);
    final totalH = layoutHeight(rounds);
    final totalW = rounds.length * (cardW + colGap) - colGap;

    return InteractiveViewer(
      minScale: 0.4,
      maxScale: 2.0,
      boundaryMargin: const EdgeInsets.all(80),
      constrained: false,
      child: SizedBox(
        width: totalW + 8,
        height: totalH,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BracketLinesPainter(
                  rounds: rounds,
                  matchTops: matchTops,
                ),
              ),
            ),
            for (var r = 0; r < rounds.length; r++)
              Positioned(
                left: columnX(r),
                top: 0,
                width: cardW,
                child: _RoundHeader(
                  label: roundLabels != null && r < roundLabels!.length
                      ? roundLabels![r]
                      : (rounds[r].isNotEmpty ? rounds[r].first.roundName : ''),
                ),
              ),
            for (var r = 0; r < rounds.length; r++)
              for (var i = 0; i < rounds[r].length; i++)
                Positioned(
                  left: columnX(r),
                  top: matchTops[r][i],
                  width: cardW,
                  height: cardH,
                  child: _BracketMatchCard(
                    fixture: rounds[r][i],
                    nameById: nameById,
                    colorById: colorById,
                    onTap: () => onTap(rounds[r][i]),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _BracketLinesPainter extends CustomPainter {
  _BracketLinesPainter({required this.rounds, required this.matchTops});

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
        final xSrcRight = BracketTree.columnX(r - 1) + BracketTree.cardW;
        final xTgtLeft = BracketTree.columnX(r);
        final xMid = (xSrcRight + xTgtLeft) / 2;
        final yT = matchTops[r][i] + BracketTree.cardH / 2;

        if (rounds[r - 1].length >= rounds[r].length * 2) {
          final srcA = i * 2;
          final srcB = i * 2 + 1;
          if (srcA >= rounds[r - 1].length || srcB >= rounds[r - 1].length) {
            continue;
          }
          final yA = matchTops[r - 1][srcA] + BracketTree.cardH / 2;
          final yB = matchTops[r - 1][srcB] + BracketTree.cardH / 2;

          canvas.drawLine(Offset(xSrcRight, yA), Offset(xMid, yA), paint);
          canvas.drawLine(Offset(xSrcRight, yB), Offset(xMid, yB), paint);
          canvas.drawLine(Offset(xMid, yA), Offset(xMid, yB), paint);
          canvas.drawLine(Offset(xMid, yT), Offset(xTgtLeft, yT), paint);
        } else if (rounds[r - 1].length == rounds[r].length &&
            i < matchTops[r - 1].length) {
          final yPrev = matchTops[r - 1][i] + BracketTree.cardH / 2;
          canvas.drawLine(
            Offset(xSrcRight, yPrev),
            Offset(xTgtLeft, yT),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BracketLinesPainter oldDelegate) =>
      oldDelegate.rounds != rounds || oldDelegate.matchTops != matchTops;
}

class _RoundHeader extends StatelessWidget {
  const _RoundHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: BracketTree.headerH - 4,
      child: Center(
        child: Text(
          label.isEmpty ? '-' : label,
          style: const TextStyle(
            color: AppColors.textBody,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.3,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _BracketMatchCard extends StatelessWidget {
  const _BracketMatchCard({
    required this.fixture,
    required this.nameById,
    required this.colorById,
    required this.onTap,
  });

  final MatchFixture fixture;
  final Map<String, String> nameById;
  final Map<String, Color> colorById;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p1Win = fixture.isPlayed && fixture.score1 > fixture.score2;
    final p2Win = fixture.isPlayed && fixture.score2 > fixture.score1;
    final p1Name = nameById[fixture.player1Id] ?? 'Chờ';
    final p2Name = nameById[fixture.player2Id] ?? 'Chờ';
    final p1Color = colorById[fixture.player1Id] ?? AppColors.textSubtle;
    final p2Color = colorById[fixture.player2Id] ?? AppColors.textSubtle;
    final isReady = fixture.isReady;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isReady ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isReady
                  ? AppColors.border
                  : AppColors.border.withAlpha(120),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BracketRow(
                name: p1Name,
                color: p1Color,
                isWinner: p1Win,
                score: fixture.isPlayed ? '${fixture.score1}' : '',
              ),
              const SizedBox(height: 4),
              _BracketRow(
                name: p2Name,
                color: p2Color,
                isWinner: p2Win,
                score: fixture.isPlayed ? '${fixture.score2}' : '',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BracketRow extends StatelessWidget {
  const _BracketRow({
    required this.name,
    required this.color,
    required this.isWinner,
    required this.score,
  });

  final String name;
  final Color color;
  final bool isWinner;
  final String score;

  @override
  Widget build(BuildContext context) {
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
