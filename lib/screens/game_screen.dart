import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ball_config.dart';
import '../models/game_snapshot.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/turn_state.dart';
import '../providers/game_controller.dart';
import '../services/pip_service.dart';
import '../theme/app_colors.dart';
import '../widgets/animated_score_text.dart';
import '../widgets/ball_action_button.dart';
import '../widgets/pip_scoreboard_view.dart';
import '../widgets/table_background.dart';
import 'history_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool get _pipAvailable => !kIsWeb && Platform.isAndroid;
  bool _inPip = false;
  StreamSubscription<bool>? _pipSub;

  @override
  void initState() {
    super.initState();
    if (_pipAvailable) {
      _pipSub = PipService.instance.statusStream.listen((inPip) {
        if (mounted) setState(() => _inPip = inPip);
      });
    }
  }

  @override
  void dispose() {
    _pipSub?.cancel();
    super.dispose();
  }

  Future<void> _enterPip() async {
    if (!_pipAvailable) return;
    await PipService.instance.enterPip(
      aspectNumerator: 4,
      aspectDenominator: 3,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    if (state.status != GameStatus.inProgress || state.players.isEmpty) {
      return const SizedBox.shrink();
    }

    final turn = state.turnState;
    final step = _currentStep(turn);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Bắn đền · Ván ${state.roundNumber}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_pipAvailable)
            IconButton(
              tooltip: 'Cửa sổ nổi (PiP)',
              icon: const Icon(Icons.picture_in_picture_alt_rounded),
              onPressed: _enterPip,
            ),
          PopupMenuButton<_GameMenuAction>(
            onSelected: (action) async {
              switch (action) {
                case _GameMenuAction.history:
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HistoryScreen(),
                    ),
                  );
                  return;
                case _GameMenuAction.addPlayer:
                  final name = await showDialog<String>(
                    context: context,
                    builder: (_) => const _AddPlayerDialog(),
                  );
                  if (name == null) return;
                  try {
                    controller.addPlayer(name);
                  } on ArgumentError catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message.toString())),
                      );
                    }
                  }
                  return;
                case _GameMenuAction.reset:
                  final shouldReset = await _showResetDialog(context);
                  if (shouldReset == true) {
                    controller.resetGame();
                  }
                  return;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _GameMenuAction.history,
                child: Text('Lịch sử'),
              ),
              PopupMenuItem(
                value: _GameMenuAction.addPlayer,
                child: Text('Thêm người chơi'),
              ),
              PopupMenuItem(
                value: _GameMenuAction.reset,
                child: Text('Làm mới trận'),
              ),
            ],
          ),
        ],
      ),
      body: _inPip
          ? const PipScoreboardView()
          : _buildNormalBody(context, step, state, turn, controller),
    );
  }

  Widget _buildNormalBody(
    BuildContext context,
    _TurnStep step,
    GameState state,
    TurnState turn,
    GameController controller,
  ) {
    return TableBackground(
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _CompactScoreboard(),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey(step),
                  child: _StepContent(
                    step: step,
                    state: state,
                    controller: controller,
                  ),
                ),
              ),
            ),
            _BottomActionBar(
              turn: turn,
              canUndo: state.canUndo,
              onClear: controller.clearDraft,
              onUndo: controller.undo,
              onEndRound: () async {
                final confirmed = await _showEndRoundDialog(
                  context,
                  roundNumber: state.roundNumber,
                );
                if (confirmed == true) {
                  controller.endRound();
                }
              },
              onFinishGame: () async {
                final confirmed = await _showFinishGameDialog(context);
                if (confirmed == true) {
                  controller.finishGame();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  _TurnStep _currentStep(TurnState turn) {
    if (turn.shooterIndex == null) return _TurnStep.pickShooter;
    if (turn.pocketedBalls.isEmpty) return _TurnStep.pickBalls;
    return _TurnStep.pickVictim;
  }

  Future<bool?> _showEndRoundDialog(
    BuildContext context, {
    required int roundNumber,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kết thúc ván?'),
          content: Text(
            'Ván $roundNumber sẽ được đóng lại. '
            'Điểm được giữ nguyên và thứ tự người chơi có thể đổi theo lượt ghi điểm cuối.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Hết ván'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showResetDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Làm mới trận?'),
          content: const Text('Toàn bộ điểm hiện tại sẽ bị xóa.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Làm mới trận'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showFinishGameDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kết thúc trận?'),
          content: const Text(
            'Trận sẽ được chốt lại và lưu vào lịch sử. '
            'Bạn sẽ xem bảng kết quả cuối.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Kết thúc trận'),
            ),
          ],
        );
      },
    );
  }
}

/// Dialog nhập tên người chơi thêm giữa trận. StatefulWidget để controller
/// dispose đúng lifecycle qua [State.dispose] (tránh assertion _dependents).
class _AddPlayerDialog extends StatefulWidget {
  const _AddPlayerDialog();

  @override
  State<_AddPlayerDialog> createState() => _AddPlayerDialogState();
}

class _AddPlayerDialogState extends State<_AddPlayerDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nhập tên người chơi.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm người chơi'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _confirm(),
        decoration: InputDecoration(
          labelText: 'Tên người chơi mới',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('Thêm'),
        ),
      ],
    );
  }
}

enum _GameMenuAction { history, addPlayer, reset }

enum _TurnStep { pickShooter, pickBalls, pickVictim }

class _StepContent extends StatelessWidget {
  const _StepContent({
    required this.step,
    required this.state,
    required this.controller,
  });

  final _TurnStep step;
  final GameState state;
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return switch (step) {
      _TurnStep.pickShooter => _ShooterPicker(
          players: state.players,
          onPick: controller.selectShooter,
        ),
      _TurnStep.pickBalls => _BallPicker(
          shooter: state.players[state.turnState.shooterIndex!],
          shooterIndex: state.turnState.shooterIndex!,
          players: state.players,
          ballConfigs: state.ballConfigs,
          onBack: controller.clearDraft,
          onChamPha: controller.chamPha,
          onApplyBalls: controller.applyBallsToVictims,
        ),
      _TurnStep.pickVictim => _VictimPicker(
          shooter: state.players[state.turnState.shooterIndex!],
          shooterIndex: state.turnState.shooterIndex!,
          players: state.players,
          pocketedBalls: state.turnState.pocketedBalls,
          totalPoints: state.turnState.totalPoints,
          chamMode: state.turnState.chamMode,
          ballConfigs: state.ballConfigs,
          onBack: controller.clearDraft,
          onAddMoreBall: controller.addBall,
          onRemoveBallAt: controller.removeBallAt,
          onPickSingleVictim: controller.pickSingleVictim,
          onApplyToAll: controller.applyToAllVictims,
        ),
    };
  }
}

class _CompactScoreboard extends ConsumerWidget {
  const _CompactScoreboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch chỉ players — scoreboard không rebuild khi chỉ turnState/history đổi.
    final players =
        ref.watch(gameControllerProvider.select((s) => s.players));
    final theme = Theme.of(context);

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < players.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white.withAlpha(36),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            players[i].avatar,
                            style: const TextStyle(fontSize: 13, height: 1.0),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              players[i].name,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withAlpha(190),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      AnimatedScoreText(
                        key: ValueKey('compact_${players[i].id}'),
                        score: players[i].score,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: _scoreColor(players[i].score),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _scoreColor(int s) {
    if (s > 0) return AppColors.accent;
    if (s < 0) return AppColors.negativeSoft;
    return Colors.white;
  }
}

/// Bước 1: chọn người bắn.
class _ShooterPicker extends StatelessWidget {
  const _ShooterPicker({required this.players, required this.onPick});

  final List<Player> players;
  final void Function(int index) onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        children: [
          _StepHeader(
            number: 1,
            title: 'Ai là người bắn?',
            caption: 'Chạm vào người chơi vừa thực hiện cú đánh.',
            color: AppColors.shooter,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < players.length; i++) ...[
                  Expanded(
                    child: _BigPlayerCard(
                      key: ValueKey('shooter_role_$i'),
                      player: players[i],
                      accent: AppColors.shooter,
                      actionLabel: 'Chọn làm người bắn',
                      onTap: () => onPick(i),
                    ),
                  ),
                  if (i != players.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bước 2: chọn bi đã ăn (flow thường) hoặc chấm sành điệu (shortcut).
///
/// Chấm đơn / chấm phá dùng **tổng điểm tất cả bi cấu hình × 2** — không
/// cần chọn bi riêng lẻ.
/// Callback áp điểm — 1 đường đi duy nhất sau khi chọn bi xong.
typedef _ApplyBallsCallback = void Function({
  required List<BallConfig> balls,
  required List<int> victimIndices,
  int multiplier,
});

class _BallPicker extends StatelessWidget {
  const _BallPicker({
    required this.shooter,
    required this.shooterIndex,
    required this.players,
    required this.ballConfigs,
    required this.onBack,
    required this.onChamPha,
    required this.onApplyBalls,
  });

  final Player shooter;
  final int shooterIndex;
  final List<Player> players;
  final List<BallConfig> ballConfigs;
  final VoidCallback onBack;
  final VoidCallback onChamPha;
  final _ApplyBallsCallback onApplyBalls;

  List<_VictimCandidate> _candidates() => [
    for (var i = 0; i < players.length; i++)
      if (i != shooterIndex) _VictimCandidate(index: i, player: players[i]),
  ];

  Future<void> _pickVictimForBall(
    BuildContext context,
    BallConfig ball,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _VictimPickerDialog(
        title: 'Ai bị trừ?',
        subtitle: 'Bi ${ball.number} · -${ball.points} điểm',
        pointsPerVictim: ball.points,
        accent: AppColors.victim,
        candidates: _candidates(),
        onPickOne: (index) => onApplyBalls(
          balls: [ball],
          victimIndices: [index],
        ),
      ),
    );
  }

  Future<void> _pickVictimForChamDon(BuildContext context) async {
    final sumAllBalls =
        ballConfigs.fold<int>(0, (sum, ball) => sum + ball.points);
    final perVictim = sumAllBalls * 2;
    await showDialog<void>(
      context: context,
      builder: (_) => _VictimPickerDialog(
        title: 'Chấm đơn ×2',
        subtitle: '-$perVictim điểm cho 1 người',
        pointsPerVictim: perVictim,
        accent: AppColors.accent,
        candidates: _candidates(),
        onPickOne: (index) => onApplyBalls(
          balls: ballConfigs,
          victimIndices: [index],
          multiplier: 2,
        ),
      ),
    );
  }

  /// Bắt 3 đui: tổng điểm tất cả bi (×1) trừ vào 1 người được chọn.
  /// Khác Chấm đơn ở chỗ không nhân đôi.
  Future<void> _pickVictimForBaDui(BuildContext context) async {
    final sumAllBalls =
        ballConfigs.fold<int>(0, (sum, ball) => sum + ball.points);
    await showDialog<void>(
      context: context,
      builder: (_) => _VictimPickerDialog(
        title: 'Bắt 3 đui',
        subtitle: '-$sumAllBalls điểm cho 1 người',
        pointsPerVictim: sumAllBalls,
        accent: AppColors.shooter,
        candidates: _candidates(),
        onPickOne: (index) => onApplyBalls(
          balls: ballConfigs,
          victimIndices: [index],
          multiplier: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sumAllBalls =
        ballConfigs.fold<int>(0, (sum, ball) => sum + ball.points);
    final chamAmount = sumAllBalls * 2;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [
        _ShooterHeader(shooter: shooter, onChange: onBack),
        const SizedBox(height: 14),
        _StepHeader(
          number: 2,
          title: 'Ăn bi nào?',
          caption: 'Chạm bi → chọn người bị trừ là xong.',
          color: AppColors.primary,
        ),
        const SizedBox(height: 14),
        if (ballConfigs.isNotEmpty) ...[
          // Bi đã ăn lên trên — đây là thao tác thường ngày: chạm bi → chọn
          // người bị trừ.
          _BallGrid(
            ballConfigs: ballConfigs,
            onTap: (ball) => _pickVictimForBall(context, ball),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                  child: Divider(color: AppColors.border, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'hoặc chấm nhanh',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSubtle,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Expanded(
                  child: Divider(color: AppColors.border, thickness: 1)),
            ],
          ),
          const SizedBox(height: 14),
          _ChamCtaCard(
            title: 'Bắt 3 đui',
            subtitle: '-$sumAllBalls cho 1 người (tổng bi ×1)',
            icon: Icons.adjust_rounded,
            accent: AppColors.shooter,
            foreground: Colors.white,
            onTap: () => _pickVictimForBaDui(context),
          ),
          const SizedBox(height: 10),
          _ChamCtaCard(
            title: 'Chấm đơn',
            subtitle: '-$chamAmount cho 1 người (tổng bi ×2)',
            icon: Icons.person_remove_rounded,
            onTap: () => _pickVictimForChamDon(context),
          ),
          const SizedBox(height: 10),
          _ChamCtaCard(
            title: 'Chấm phá',
            subtitle: 'Mỗi người -$chamAmount, cả bàn luôn',
            icon: Icons.bolt_rounded,
            onTap: onChamPha,
          ),
        ] else
          Text(
            'Chưa cấu hình bi nào.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSubtle,
            ),
          ),
      ],
    );
  }
}

class _VictimCandidate {
  const _VictimCandidate({required this.index, required this.player});
  final int index;
  final Player player;
}

/// Dialog trung tâm hiện list người để tap chọn trừ điểm.
class _VictimPickerDialog extends StatelessWidget {
  const _VictimPickerDialog({
    required this.title,
    required this.subtitle,
    required this.pointsPerVictim,
    required this.accent,
    required this.candidates,
    required this.onPickOne,
  });

  final String title;
  final String subtitle;
  final int pointsPerVictim;
  final Color accent;
  final List<_VictimCandidate> candidates;
  final void Function(int index) onPickOne;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: const Color(0xFFFFFBF4),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w900,
                fontSize: 26,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textSubtle,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            for (final c in candidates) ...[
              _VictimSheetRow(
                key: ValueKey('sheet_victim_${c.index}'),
                candidate: c,
                deduction: pointsPerVictim,
                accent: accent,
                onTap: () {
                  Navigator.of(context).pop();
                  onPickOne(c.index);
                },
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Hủy'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VictimSheetRow extends StatelessWidget {
  const _VictimSheetRow({
    super.key,
    required this.candidate,
    required this.deduction,
    required this.accent,
    required this.onTap,
  });

  final _VictimCandidate candidate;
  final int deduction;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final player = candidate.player;
    final scoreColor = player.score > 0
        ? AppColors.primary
        : player.score < 0
            ? AppColors.victim
            : AppColors.primaryDark;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  player.avatar,
                  style: const TextStyle(fontSize: 32, height: 1.0),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Điểm: ${player.score > 0 ? '+' : ''}${player.score}',
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '-$deduction',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: -0.3,
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

/// Nút lớn gọi action chấm sành điệu (đơn / phá).
class _ChamCtaCard extends StatelessWidget {
  const _ChamCtaCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.accent = AppColors.accent,
    this.foreground = AppColors.primaryDark,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(80),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: foreground, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: foreground.withAlpha(200),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: foreground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bước 3: chọn người bị trừ. Có toggle "Chấm sành điệu ×2" và nút
/// "Đền cả bàn" để hỗ trợ đủ 4 kiểu:
/// - Toggle off + tap 1 người = bắn đền thường (×1)
/// - Toggle off + Đền cả = đền cả bàn (×1 cho tất cả)
/// - Toggle on + tap 1 người = chấm đơn (×2)
/// - Toggle on + Đền cả = chấm phá (×2 cho tất cả)
class _VictimPicker extends StatelessWidget {
  const _VictimPicker({
    required this.shooter,
    required this.shooterIndex,
    required this.players,
    required this.pocketedBalls,
    required this.totalPoints,
    required this.chamMode,
    required this.ballConfigs,
    required this.onBack,
    required this.onAddMoreBall,
    required this.onRemoveBallAt,
    required this.onPickSingleVictim,
    required this.onApplyToAll,
  });

  final Player shooter;
  final int shooterIndex;
  final List<Player> players;
  final List<BallConfig> pocketedBalls;
  final int totalPoints;
  final bool chamMode;
  final List<BallConfig> ballConfigs;
  final VoidCallback onBack;
  final void Function(BallConfig ball) onAddMoreBall;
  final void Function(int ballIndex) onRemoveBallAt;
  final void Function(int playerIndex) onPickSingleVictim;
  final VoidCallback onApplyToAll;

  @override
  Widget build(BuildContext context) {
    final multiplier = chamMode ? 2 : 1;
    final pointsPerVictim = totalPoints * multiplier;
    final nonShooterCount = players.length - 1;
    final shooterGainIfAll = pointsPerVictim * nonShooterCount;

    final singleLabel = chamMode
        ? 'Chấm đơn: trừ $pointsPerVictim điểm'
        : 'Trừ $pointsPerVictim điểm';
    final allButtonLabel = chamMode ? 'Chấm phá cả bàn' : 'Đền cả bàn';
    final allButtonSubLabel =
        'Mỗi người -$pointsPerVictim, bạn +$shooterGainIfAll';

    final victimIndices = <int>[
      for (var i = 0; i < players.length; i++)
        if (i != shooterIndex) i,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          _ShooterHeader(shooter: shooter, onChange: onBack),
          const SizedBox(height: 10),
          _SelectedBallsPanel(
            balls: pocketedBalls,
            totalPoints: totalPoints,
            ballConfigs: ballConfigs,
            chamMode: chamMode,
            onAddMore: onAddMoreBall,
            onRemoveAt: onRemoveBallAt,
          ),
          const SizedBox(height: 12),
          _StepHeader(
            number: 3,
            title: 'Trừ điểm ai?',
            caption: 'Chạm người để áp, hoặc "Đền cả bàn" ở dưới.',
            color: AppColors.victim,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < victimIndices.length; i++) ...[
                  Expanded(
                    child: _BigPlayerCard(
                      key: ValueKey('victim_role_${victimIndices[i]}'),
                      player: players[victimIndices[i]],
                      accent: AppColors.victim,
                      actionLabel: singleLabel,
                      onTap: () =>
                          onPickSingleVictim(victimIndices[i]),
                    ),
                  ),
                  if (i != victimIndices.length - 1)
                    const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          _AllVictimsButton(
            key: const ValueKey('apply_to_all_button'),
            label: allButtonLabel,
            subLabel: allButtonSubLabel,
            cham: chamMode,
            onTap: onApplyToAll,
          ),
        ],
      ),
    );
  }
}

class _AllVictimsButton extends StatelessWidget {
  const _AllVictimsButton({
    super.key,
    required this.label,
    required this.subLabel,
    required this.cham,
    required this.onTap,
  });

  final String label;
  final String subLabel;
  final bool cham;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = cham ? AppColors.accent : AppColors.victim;

    return Material(
      color: accent,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Row(
            children: [
              Icon(
                cham ? Icons.auto_awesome_rounded : Icons.groups_rounded,
                color: cham ? AppColors.primaryDark : Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color:
                            cham ? AppColors.primaryDark : Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cham
                            ? AppColors.primaryDark.withAlpha(200)
                            : Colors.white.withAlpha(220),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cham ? AppColors.primaryDark : Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.number,
    required this.title,
    required this.caption,
    required this.color,
  });

  final int number;
  final String title;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                caption,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSubtle),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShooterHeader extends StatelessWidget {
  const _ShooterHeader({required this.shooter, required this.onChange});

  final Player shooter;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.shooter, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.shooter.withAlpha(30),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.shooter,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Người bắn',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              shooter.name,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: onChange,
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('Đổi'),
          ),
        ],
      ),
    );
  }
}

class _BigPlayerCard extends StatefulWidget {
  const _BigPlayerCard({
    super.key,
    required this.player,
    required this.accent,
    required this.actionLabel,
    required this.onTap,
  });

  final Player player;
  final Color accent;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  State<_BigPlayerCard> createState() => _BigPlayerCardState();
}

class _BigPlayerCardState extends State<_BigPlayerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flashController;
  late final Animation<double> _flash;
  Color? _flashTint;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _flash = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 28,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(
          CurveTween(curve: Curves.easeIn),
        ),
        weight: 72,
      ),
    ]).animate(_flashController);
  }

  @override
  void didUpdateWidget(covariant _BigPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player.score != widget.player.score) {
      final delta = widget.player.score - oldWidget.player.score;
      setState(() {
        _flashTint = delta > 0 ? AppColors.shooter : AppColors.victim;
      });
      _flashController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final accent = widget.accent;
    final scoreColor = player.score > 0
        ? AppColors.primary
        : player.score < 0
            ? AppColors.victim
            : AppColors.primaryDark;

    return Stack(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      player.avatar,
                      style: const TextStyle(fontSize: 30, height: 1.0),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            player.name,
                            maxLines: 1,
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 32,
                              letterSpacing: -0.5,
                              height: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.actionLabel,
                          style: TextStyle(
                            color: accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedScoreText(
                    key: ValueKey('big_${player.id}'),
                    score: player.score,
                    style: TextStyle(
                      color: scoreColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 48,
                      letterSpacing: -1,
                      height: 1.0,
                    ),
                    badgeOffset: -40,
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: accent, size: 28),
                ],
              ),
            ),
          ),
        ),
        if (_flashTint != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _flash,
                builder: (_, _) {
                  final v = _flash.value;
                  if (v <= 0) return const SizedBox.shrink();
                  return Container(
                    decoration: BoxDecoration(
                      color: _flashTint!.withAlpha((110 * v).round()),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _flashTint!.withAlpha((220 * v).round()),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _BallGrid extends StatelessWidget {
  const _BallGrid({required this.ballConfigs, required this.onTap});

  final List<BallConfig> ballConfigs;
  final void Function(BallConfig ball) onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      runSpacing: 18,
      alignment: WrapAlignment.center,
      children: [
        for (final ball in ballConfigs)
          BallActionButton(
            key: ValueKey('ball_${ball.number}'),
            ball: ball,
            size: 96,
            onPressed: () => onTap(ball),
          ),
      ],
    );
  }
}

class _SelectedBallsPanel extends StatelessWidget {
  const _SelectedBallsPanel({
    required this.balls,
    required this.totalPoints,
    required this.ballConfigs,
    required this.chamMode,
    required this.onAddMore,
    required this.onRemoveAt,
  });

  final List<BallConfig> balls;
  final int totalPoints;
  final List<BallConfig> ballConfigs;
  final bool chamMode;
  final void Function(BallConfig ball) onAddMore;
  final void Function(int index) onRemoveAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayPoints = totalPoints * (chamMode ? 2 : 1);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: chamMode ? AppColors.accent : AppColors.border,
          width: chamMode ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Bi đã ăn',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (chamMode) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 13,
                        color: AppColors.primaryDark,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Chấm ×2',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+$displayPoints',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < balls.length; i++)
                InputChip(
                  label: Text(
                    'Bi ${balls[i].number}  +${balls[i].points}',
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onDeleted: () => onRemoveAt(i),
                  deleteIcon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.primaryDark,
                  ),
                  backgroundColor: AppColors.accent.withAlpha(60),
                  side: const BorderSide(color: AppColors.accent),
                ),
              if (ballConfigs.isNotEmpty)
                PopupMenuButton<BallConfig>(
                  icon: const Icon(Icons.add_circle_outline_rounded,
                      color: AppColors.primary),
                  tooltip: 'Thêm bi',
                  onSelected: onAddMore,
                  itemBuilder: (_) => [
                    for (final b in ballConfigs)
                      PopupMenuItem(
                        value: b,
                        child: Text('Bi ${b.number}  +${b.points}'),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.turn,
    required this.canUndo,
    required this.onClear,
    required this.onUndo,
    required this.onEndRound,
    required this.onFinishGame,
  });

  final TurnState turn;
  final bool canUndo;
  final VoidCallback onClear;
  final VoidCallback onUndo;
  final VoidCallback onEndRound;
  final VoidCallback onFinishGame;

  @override
  Widget build(BuildContext context) {
    final hasDraft =
        turn.shooterIndex != null || turn.pocketedBalls.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(14),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _BottomAction(
              icon: Icons.refresh_rounded,
              label: 'Xóa chọn',
              onPressed: hasDraft ? onClear : null,
            ),
          ),
          Expanded(
            child: _BottomAction(
              icon: Icons.undo_rounded,
              label: 'Hoàn tác',
              onPressed: canUndo ? onUndo : null,
            ),
          ),
          Expanded(
            child: _BottomAction(
              icon: Icons.sports_rounded,
              label: 'Hết ván',
              onPressed: onEndRound,
            ),
          ),
          Expanded(
            child: _BottomAction(
              icon: Icons.flag_rounded,
              label: 'Kết thúc trận',
              onPressed: onFinishGame,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled ? AppColors.primaryDark : AppColors.textSubtle.withAlpha(140);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
