import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/nine_ball_state.dart';
import '../providers/game_controller.dart';
import '../providers/nine_ball_controller.dart';
import '../widgets/table_background.dart';

class NineBallGameScreen extends ConsumerWidget {
  const NineBallGameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nineBallControllerProvider);
    final controller = ref.read(nineBallControllerProvider.notifier);

    if (state.status != NineBallStatus.inProgress || state.players.length < 2) {
      return const SizedBox.shrink();
    }

    final p1 = state.players[0];
    final p2 = state.players[1];
    final w1 = state.rackWins[0];
    final w2 = state.rackWins[1];

    final modeLabel =
        ref.watch(gameControllerProvider).gameMode?.label ?? '9-Ball';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '$modeLabel — Rack ${state.currentRack}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: state.canUndo ? controller.undo : null,
            icon: const Icon(Icons.undo_rounded),
            color: Colors.white,
            disabledColor: Colors.white38,
            tooltip: 'Hoàn tác',
          ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              if (action == 'finish') {
                controller.finishGame();
              } else if (action == 'reset') {
                final ok = await _showResetDialog(context);
                if (ok == true) controller.resetGame();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'finish', child: Text('Kết thúc trận')),
              PopupMenuItem(value: 'reset', child: Text('Làm mới trận')),
            ],
          ),
        ],
      ),
      body: TableBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                              const Row(
                                children: [
                                  Expanded(
                                    child: ColoredBox(
                                      color: Color(0xFFD0DCEF),
                                    ),
                                  ),
                                  Expanded(
                                    child: ColoredBox(
                                      color: Color(0xFFEDC8C8),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  14,
                                  18,
                                  14,
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _SideColumn(
                                        name: p1.name,
                                        wins: w1,
                                        panelColor:
                                            const Color(0xFF2962E0),
                                        onTap: () => controller.winRack(0),
                                        onDecrement: w1 > 0
                                            ? () => controller.decrementWin(0)
                                            : null,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF2B544),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Text(
                                            'Race ${state.raceTarget}',
                                            style: const TextStyle(
                                              color: Color(0xFF16322C),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 22,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: _SideColumn(
                                        name: p2.name,
                                        wins: w2,
                                        panelColor:
                                            const Color(0xFFD93838),
                                        onTap: () => controller.winRack(1),
                                        onDecrement: w2 > 0
                                            ? () => controller.decrementWin(1)
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showResetDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Làm mới trận?'),
        content: const Text('Toàn bộ kết quả sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Làm mới'),
          ),
        ],
      ),
    );
  }
}

/// Cột dọc cho 1 người chơi: tên ở trên (center), panel điểm chiếm phần
/// lớn chiều cao, nút "−1" ở dưới. Tất cả share cùng width của Expanded
/// → name và button luôn aligned theo trục dọc với panel của họ.
class _SideColumn extends StatelessWidget {
  const _SideColumn({
    required this.name,
    required this.wins,
    required this.panelColor,
    required this.onTap,
    required this.onDecrement,
  });

  final String name;
  final int wins;
  final Color panelColor;
  final VoidCallback onTap;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 32,
          child: Center(
            child: Text(
              name,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _ScorePanel(
            wins: wins,
            panelColor: panelColor,
            onTap: onTap,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: Center(child: _DecrementButton(onPressed: onDecrement)),
        ),
      ],
    );
  }
}

/// Panel màu hiển thị số điểm — fill cả chiều cao và chiều rộng được cấp
/// bởi parent. Tap = onTap (winRack +1).
///
/// Digit dùng `BoxFit.fitHeight` để 1-digit và 2-digit cùng cao bằng panel
/// height (số "10" sẽ rộng gấp ~2 số "7" nhưng cùng chiều cao).
class _ScorePanel extends StatelessWidget {
  const _ScorePanel({
    required this.wins,
    required this.panelColor,
    required this.onTap,
  });

  final int wins;
  final Color panelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: panelColor,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white24,
        highlightColor: Colors.white10,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(
              '$wins',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 200,
                fontWeight: FontWeight.w900,
                height: 1.0,
                letterSpacing: -4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút "−1" nhỏ. Disable khi onPressed null (tức là wins == 0).
class _DecrementButton extends StatelessWidget {
  const _DecrementButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.remove_rounded, size: 16),
        label: const Text('1'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: const Color(0xFF1F2937),
          disabledForegroundColor: Colors.black26,
          side: BorderSide(color: Colors.black.withAlpha(80)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
