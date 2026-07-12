import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/nine_ball_state.dart';
import '../providers/nine_ball_controller.dart';
import '../widgets/nine_ball_log_sheet.dart';
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

    // Hiển thị biến thể đã chọn (8/9/10-Ball/tuỳ ý) — fallback "Pool".
    final modeLabel = state.variantLabel ?? 'Pool';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Danh sách trận',
          // Về list — trận vẫn lưu trong active list để chơi tiếp sau.
          onPressed: controller.backToList,
        ),
        title: Text(
          '$modeLabel — Rack ${state.currentRack}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => showNineBallLogSheet(
              context,
              playerNames: [for (final p in state.players) p.name],
              log: state.log,
            ),
            icon: const Icon(Icons.history_rounded),
            color: Colors.white,
            tooltip: 'Lịch sử thao tác',
          ),
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
              } else if (action == 'cancel') {
                final ok = await _showCancelDialog(context);
                if (ok == true) controller.cancelMatch();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'finish', child: Text('Kết thúc trận')),
              PopupMenuItem(value: 'cancel', child: Text('Huỷ trận')),
            ],
          ),
        ],
      ),
      body: TableBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
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
              if (state.shotClockSeconds > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: ShotClockBar(
                    // Key theo số giây → đổi cấu hình thì tạo lại controller.
                    key: ValueKey('shotclock_${state.shotClockSeconds}'),
                    seconds: state.shotClockSeconds,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showCancelDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Huỷ trận này?'),
        content: const Text(
          'Trận sẽ bị xoá khỏi danh sách và không ghi vào lịch sử.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Huỷ trận'),
          ),
        ],
      ),
    );
  }
}

/// Cột dọc cho 1 người chơi: hàng đầu = nút "−1" + tên (căn giữa theo cụm),
/// panel điểm chiếm toàn bộ phần còn lại. Gộp "−1" lên cạnh tên (thay vì để
/// dưới) → panel điểm cao hơn, số to & dễ nhìn hơn.
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
          height: 36,
          // "−1" sát mép trái, tên căn giữa panel (padding 2 bên = chỗ nút
          // để tên không bị nút đè khi dài).
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 52),
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
              Align(
                alignment: Alignment.centerLeft,
                child: _DecrementButton(onPressed: onDecrement),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _ScorePanel(
            wins: wins,
            panelColor: panelColor,
            onTap: onTap,
          ),
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

/// Thanh đồng hồ giây (shot clock) ở đáy màn chơi Pool. Bấm "Chạy" →
/// thanh đếm ngược: xanh lá → vàng → đỏ theo thời gian còn lại. Hết giờ →
/// chuông báo (SystemSound + rung lặp) + popup; chạm popup mới reset & cho
/// chạy lại.
class ShotClockBar extends StatefulWidget {
  const ShotClockBar({super.key, required this.seconds});

  final int seconds;

  @override
  State<ShotClockBar> createState() => _ShotClockBarState();
}

class _ShotClockBarState extends State<ShotClockBar>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  // Nhấp nháy "rực lửa" khi vào vùng đỏ — repeat reverse, chỉ chạy khi cần.
  late final AnimationController _flameController;
  Timer? _alarmTimer;
  bool _alarmActive = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.seconds),
    )
      ..addStatusListener(_onStatus)
      ..addListener(_updateFlame);
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _alarmTimer?.cancel();
    _flameController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Bật ngọn lửa nhấp nháy khi đang chạy & còn ≤25% thời gian; tắt khi ra
  /// khỏi vùng đỏ / dừng / hết giờ để khỏi tốn frame.
  void _updateFlame() {
    final remaining = 1 - _controller.value;
    final inRed =
        _controller.isAnimating && remaining > 0 && remaining <= 0.25;
    if (inRed && !_flameController.isAnimating) {
      _flameController.repeat(reverse: true);
    } else if (!inRed && _flameController.isAnimating) {
      _flameController.stop();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _onExpire();
    }
  }

  void _run() {
    if (_alarmActive) return;
    _controller.forward(from: 0);
    setState(() {});
  }

  void _reset() {
    _controller.stop();
    _controller.reset();
    setState(() {});
  }

  void _beep() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
  }

  Future<void> _onExpire() async {
    _alarmActive = true;
    _beep();
    _alarmTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => _beep(),
    );
    if (mounted) setState(() {});

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        icon: const Icon(
          Icons.alarm_rounded,
          color: Color(0xFFD93838),
          size: 40,
        ),
        title: const Text('Hết giờ!', textAlign: TextAlign.center),
        content: const Text(
          'Đã hết thời gian cho cú đánh này.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đánh tiếp'),
          ),
        ],
      ),
    );

    _alarmTimer?.cancel();
    _alarmTimer = null;
    _alarmActive = false;
    if (mounted) {
      _controller.reset();
      setState(() {});
    }
  }

  Color _zoneColor(double remaining) {
    if (remaining > 0.5) return const Color(0xFF2E9E6F); // xanh lá
    if (remaining > 0.25) return const Color(0xFFF2B544); // vàng
    return const Color(0xFFD93838); // đỏ
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _flameController]),
      builder: (context, _) {
        final remaining = 1 - _controller.value;
        final remainingSecs = (_controller.value >= 1.0)
            ? 0
            : (widget.seconds * remaining).ceil();
        final color = _zoneColor(remaining);
        final running = _controller.isAnimating;
        // Vùng đỏ + đang chạy → bật hiệu ứng rực lửa.
        final inRed = running && remaining > 0 && remaining <= 0.25;
        final flame = _flameController.value; // 0..1 (reverse)

        return Row(
          children: [
            // Số giây còn lại — vùng đỏ thì nhấp nháy đỏ ↔ cam như than lửa.
            SizedBox(
              width: 56,
              child: Text(
                '$remainingSecs',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: inRed
                      ? Color.lerp(color, const Color(0xFFFFC107), flame)
                      : color,
                  fontWeight: FontWeight.w900,
                  fontSize: 30,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  shadows: inRed
                      ? [
                          Shadow(
                            color: const Color(
                              0xFFFF6B00,
                            ).withAlpha((150 + 105 * flame).round()),
                            blurRadius: 8 + 10 * flame,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Thanh đếm ngược — vùng đỏ thì glow cam + gradient lửa ở mép.
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: inRed
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFFFF6B00,
                            ).withAlpha((90 + 110 * flame).round()),
                            blurRadius: 8 + 14 * flame,
                            spreadRadius: 1 + 2 * flame,
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 26,
                    color: Colors.black.withAlpha(40),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        // Idle (chưa chạy) → đầy; đang/đã chạy → theo remaining.
                        widthFactor: remaining.clamp(0.0, 1.0),
                        child: inRed
                            ? Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      const Color(0xFF7A0C0C),
                                      const Color(0xFFD93838),
                                      Color.lerp(
                                        const Color(0xFFFF5722),
                                        const Color(0xFFFFC107),
                                        flame,
                                      )!,
                                    ],
                                    stops: const [0.0, 0.55, 1.0],
                                  ),
                                ),
                              )
                            : Container(color: color),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Nút chạy / đặt lại.
            SizedBox(
              width: 96,
              child: FilledButton.icon(
                onPressed: _alarmActive
                    ? null
                    : running
                    ? _reset
                    : _run,
                icon: Icon(
                  running ? Icons.refresh_rounded : Icons.play_arrow_rounded,
                  size: 20,
                ),
                label: Text(running ? 'Đặt lại' : 'Chạy'),
                style: FilledButton.styleFrom(
                  backgroundColor: running ? const Color(0xFF5F726A) : color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 44),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
