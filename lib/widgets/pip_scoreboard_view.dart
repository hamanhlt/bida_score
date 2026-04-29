import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/game_controller.dart';
import '../theme/app_colors.dart';

/// UI compact để hiển thị trong cửa sổ Picture-in-Picture (~220×160 dp).
/// Chỉ hiện tên + điểm từng người, không có tương tác.
class PipScoreboardView extends ConsumerWidget {
  const PipScoreboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players =
        ref.watch(gameControllerProvider.select((s) => s.players));
    final roundNumber =
        ref.watch(gameControllerProvider.select((s) => s.roundNumber));

    return Material(
      color: AppColors.primaryDark,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'Bida Score',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Ván $roundNumber',
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: players.length,
                  itemBuilder: (_, i) {
                    final p = players[i];
                    return _PipPlayerRow(
                      avatar: p.avatar,
                      name: p.name,
                      score: p.score,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PipPlayerRow extends StatelessWidget {
  const _PipPlayerRow({
    required this.avatar,
    required this.name,
    required this.score,
  });

  final String avatar;
  final String name;
  final int score;

  @override
  Widget build(BuildContext context) {
    final scoreColor = score > 0
        ? AppColors.accent
        : score < 0
            ? AppColors.negativeSoft
            : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            avatar,
            style: const TextStyle(fontSize: 14, height: 1.0),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            score > 0 ? '+$score' : '$score',
            style: TextStyle(
              color: scoreColor,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
