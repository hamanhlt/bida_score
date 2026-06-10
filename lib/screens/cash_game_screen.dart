import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cash_game_state.dart';
import '../providers/cash_game_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/table_background.dart';

/// Màn chơi chế độ Chơi điểm. 2 panel trái/phải:
/// - Tap panel chính → +1 ván thắng, giữ cộng dồn đến cuối trận.
/// - Nút +/- "Lỗ 10" → nhập lỗ 10 của ván hiện tại.
/// - Bấm "Chốt" để khóa lỗ 10 rồi đối trừ hiệu số hai người.
class CashGameScreen extends ConsumerWidget {
  const CashGameScreen({super.key});

  static const _blue = Color(0xFF2962E0);
  static const _red = Color(0xFFD93838);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cashGameControllerProvider);
    final controller = ref.read(cashGameControllerProvider.notifier);

    if (state.status != CashGameStatus.inProgress ||
        state.playerNames.length < 2) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Chơi điểm · ${formatVnd(state.moneyPerRack)}/ván · '
          '${formatVnd(state.moneyPerBall)}/lỗ 10',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
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
                final ok = await _confirmReset(context);
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
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) =>
                _buildBoard(state, controller, constraints),
          ),
        ),
      ),
    );
  }

  Widget _buildBoard(
    CashGameState state,
    CashGameController controller,
    BoxConstraints constraints,
  ) {
    final isLandscape = constraints.maxWidth > constraints.maxHeight;
    final padding = isLandscape
        ? const EdgeInsets.fromLTRB(8, 6, 8, 8)
        : const EdgeInsets.fromLTRB(10, 10, 10, 10);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RackSettlementBar(
            state: state,
            isLandscape: isLandscape,
            onSettleRack: controller.settleRack,
          ),
          SizedBox(height: isLandscape ? 6 : 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildPlayerPanel(
                    state: state,
                    controller: controller,
                    index: 0,
                    panelColor: _blue,
                    isLandscape: isLandscape,
                  ),
                ),
                SizedBox(width: isLandscape ? 8 : 10),
                Expanded(
                  child: _buildPlayerPanel(
                    state: state,
                    controller: controller,
                    index: 1,
                    panelColor: _red,
                    isLandscape: isLandscape,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerPanel({
    required CashGameState state,
    required CashGameController controller,
    required int index,
    required Color panelColor,
    required bool isLandscape,
  }) {
    final onDecrementRack = state.rackWins[index] > 0
        ? () => controller.decrementRackWin(index)
        : null;
    final onRemoveBall = state.balls[index] > 0
        ? () => controller.removeBall(index)
        : null;

    if (isLandscape) {
      return _LandscapePlayerPanel(
        name: state.playerNames[index],
        money: state.moneyOf(index),
        rackWins: state.rackWins[index],
        balls: state.balls[index],
        panelColor: panelColor,
        onWinRack: () => controller.addRackWin(index),
        onDecrementRack: onDecrementRack,
        onAddBall: () => controller.addBall(index),
        onRemoveBall: onRemoveBall,
      );
    }

    return _PlayerColumn(
      name: state.playerNames[index],
      money: state.moneyOf(index),
      rackWins: state.rackWins[index],
      balls: state.balls[index],
      panelColor: panelColor,
      onWinRack: () => controller.addRackWin(index),
      onDecrementRack: onDecrementRack,
      onAddBall: () => controller.addBall(index),
      onRemoveBall: onRemoveBall,
    );
  }

  Future<bool?> _confirmReset(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Làm mới trận?'),
        content: const Text('Toàn bộ tỷ số và tiền sẽ bị xoá.'),
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

class _RackSettlementBar extends StatelessWidget {
  const _RackSettlementBar({
    required this.state,
    required this.isLandscape,
    required this.onSettleRack,
  });

  final CashGameState state;
  final bool isLandscape;
  final VoidCallback onSettleRack;

  @override
  Widget build(BuildContext context) {
    final after0 = state.moneyAfterSettleOf(0);
    final after1 = state.moneyAfterSettleOf(1);
    final currentText = state.canSettleRack
        ? 'Sau chốt: ${state.playerNames[0]} ${formatVnd(after0)} đ'
              ' · ${state.playerNames[1]} ${formatVnd(after1)} đ'
        : 'Chưa có lỗ 10/hiệu số để chốt';

    return SizedBox(
      height: isLandscape ? 46 : 62,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Ván ${state.currentRackNumber}',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: isLandscape
                    ? Text(
                        currentText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Chốt hiệu số',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            currentText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 34,
                child: FilledButton.icon(
                  onPressed: state.canSettleRack ? onSettleRack : null,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Chốt'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textDark,
                    disabledBackgroundColor: Colors.white24,
                    disabledForegroundColor: Colors.white54,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerColumn extends StatelessWidget {
  const _PlayerColumn({
    required this.name,
    required this.money,
    required this.rackWins,
    required this.balls,
    required this.panelColor,
    required this.onWinRack,
    required this.onDecrementRack,
    required this.onAddBall,
    required this.onRemoveBall,
  });

  final String name;
  final int money;
  final int rackWins;
  final int balls;
  final Color panelColor;
  final VoidCallback onWinRack;
  final VoidCallback? onDecrementRack;
  final VoidCallback onAddBall;
  final VoidCallback? onRemoveBall;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 30,
          child: Center(
            child: Text(
              name,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Tiền tổng — headline.
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: panelColor.withAlpha(30),
            borderRadius: BorderRadius.circular(14),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${formatVnd(money)} đ',
              style: TextStyle(
                color: panelColor,
                fontWeight: FontWeight.w900,
                fontSize: 28,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Panel chính: tap = +1 ván thắng.
        Expanded(
          child: Material(
            color: panelColor,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onWinRack,
              splashColor: Colors.white24,
              highlightColor: Colors.white10,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'VÁN THẮNG',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Text(
                          '$rackWins',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 160,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                    const Text(
                      'Chạm để +1 ván',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // −1 ván (sửa nhầm).
        SizedBox(
          height: 34,
          child: OutlinedButton.icon(
            onPressed: onDecrementRack,
            icon: const Icon(Icons.remove_rounded, size: 16),
            label: const Text('1 ván'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              foregroundColor: const Color(0xFF1F2937),
              disabledForegroundColor: Colors.black26,
              side: BorderSide(color: Colors.black.withAlpha(60)),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Lỗ 10 — counter +/-.
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Text(
                'Lỗ 10',
                style: TextStyle(
                  color: Color(0xFF5F726A),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _BallButton(
                    icon: Icons.remove_rounded,
                    onPressed: onRemoveBall,
                    color: panelColor,
                    filled: false,
                  ),
                  Text(
                    '$balls',
                    style: TextStyle(
                      color: panelColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 30,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  _BallButton(
                    icon: Icons.add_rounded,
                    onPressed: onAddBall,
                    color: panelColor,
                    filled: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LandscapePlayerPanel extends StatelessWidget {
  const _LandscapePlayerPanel({
    required this.name,
    required this.money,
    required this.rackWins,
    required this.balls,
    required this.panelColor,
    required this.onWinRack,
    required this.onDecrementRack,
    required this.onAddBall,
    required this.onRemoveBall,
  });

  final String name;
  final int money;
  final int rackWins;
  final int balls;
  final Color panelColor;
  final VoidCallback onWinRack;
  final VoidCallback? onDecrementRack;
  final VoidCallback onAddBall;
  final VoidCallback? onRemoveBall;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(238),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: panelColor.withAlpha(54)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 42,
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 4,
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: panelColor.withAlpha(26),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${formatVnd(money)} đ',
                          style: TextStyle(
                            color: panelColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 34,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final sideWidth = constraints.maxWidth < 340 ? 118.0 : 132.0;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _LandscapeRackPanel(
                          rackWins: rackWins,
                          panelColor: panelColor,
                          onWinRack: onWinRack,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: sideWidth,
                        child: _LandscapeSideControls(
                          balls: balls,
                          panelColor: panelColor,
                          onDecrementRack: onDecrementRack,
                          onAddBall: onAddBall,
                          onRemoveBall: onRemoveBall,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandscapeRackPanel extends StatelessWidget {
  const _LandscapeRackPanel({
    required this.rackWins,
    required this.panelColor,
    required this.onWinRack,
  });

  final int rackWins;
  final Color panelColor;
  final VoidCallback onWinRack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: panelColor,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onWinRack,
        splashColor: Colors.white24,
        highlightColor: Colors.white10,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'VÁN THẮNG',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Text(
                    '$rackWins',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 150,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const Text(
                'Chạm để +1 ván',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandscapeSideControls extends StatelessWidget {
  const _LandscapeSideControls({
    required this.balls,
    required this.panelColor,
    required this.onDecrementRack,
    required this.onAddBall,
    required this.onRemoveBall,
  });

  final int balls;
  final Color panelColor;
  final VoidCallback? onDecrementRack;
  final VoidCallback onAddBall;
  final VoidCallback? onRemoveBall;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Text(
                  'Lỗ 10',
                  style: TextStyle(
                    color: AppColors.textSubtle,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$balls',
                        style: TextStyle(
                          color: panelColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 54,
                          height: 1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: Row(
                    children: [
                      Expanded(
                        child: _LandscapeBallButton(
                          icon: Icons.remove_rounded,
                          onPressed: onRemoveBall,
                          color: panelColor,
                          filled: false,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _LandscapeBallButton(
                          icon: Icons.add_rounded,
                          onPressed: onAddBall,
                          color: panelColor,
                          filled: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 38,
          child: OutlinedButton.icon(
            onPressed: onDecrementRack,
            icon: const Icon(Icons.remove_rounded, size: 16),
            label: const Text('1 ván'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              foregroundColor: AppColors.textDark,
              disabledForegroundColor: Colors.black26,
              side: BorderSide(color: Colors.black.withAlpha(58)),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LandscapeBallButton extends StatelessWidget {
  const _LandscapeBallButton({
    required this.icon,
    required this.onPressed,
    required this.color,
    required this.filled,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withAlpha(60),
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: shape,
        ),
        child: Icon(icon, size: 22, color: Colors.white),
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: color.withAlpha(120)),
        foregroundColor: color,
        disabledForegroundColor: Colors.black26,
        shape: shape,
      ),
      child: Icon(icon, size: 22),
    );
  }
}

class _BallButton extends StatelessWidget {
  const _BallButton({
    required this.icon,
    required this.onPressed,
    required this.color,
    required this.filled,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 44,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                disabledBackgroundColor: color.withAlpha(60),
                padding: EdgeInsets.zero,
                minimumSize: const Size(52, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Icon(icon, size: 22, color: Colors.white),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(52, 44),
                side: BorderSide(color: color.withAlpha(120)),
                foregroundColor: color,
                disabledForegroundColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Icon(icon, size: 22),
            ),
    );
  }
}
