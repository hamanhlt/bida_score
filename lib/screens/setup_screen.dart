import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ball_config.dart';
import '../providers/game_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/name_history_button.dart';
import '../widgets/table_background.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  late final List<TextEditingController> _controllers;
  late List<_BallDraft> _ballDrafts;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(lastSetupProvider);

    final names = (saved != null && saved.playerNames.isNotEmpty)
        ? saved.playerNames
        : const ['Người chơi 1', 'Người chơi 2', 'Người chơi 3'];
    _controllers = [
      for (final name in names) TextEditingController(text: name),
    ];

    final balls = (saved != null && saved.ballConfigs.isNotEmpty)
        ? saved.ballConfigs
        : BallConfig.defaultPreset;
    _ballDrafts = balls.map(_BallDraft.fromConfig).toList();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final draft in _ballDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _addPlayer() {
    setState(() {
      _controllers.add(
        TextEditingController(text: 'Người chơi ${_controllers.length + 1}'),
      );
    });
  }

  void _removePlayer(int index) {
    if (_controllers.length <= 2) {
      return;
    }

    setState(() {
      final controller = _controllers.removeAt(index);
      controller.dispose();
    });
  }

  void _addBall() {
    setState(() {
      _ballDrafts.add(_BallDraft.empty());
    });
  }

  void _removeBall(int index) {
    if (_ballDrafts.length <= 1) {
      return;
    }
    setState(() {
      final draft = _ballDrafts.removeAt(index);
      draft.dispose();
    });
  }

  void _startGame() {
    final names = _controllers
        .map((controller) => controller.text)
        .toList(growable: false);

    final nameError = _validateNames(names);
    if (nameError != null) {
      setState(() => _errorText = nameError);
      return;
    }

    final List<BallConfig> ballConfigs;
    try {
      ballConfigs = _readBalls();
    } on ArgumentError catch (error) {
      setState(() => _errorText = error.message.toString());
      return;
    }

    try {
      ref
          .read(gameControllerProvider.notifier)
          .startGame(names, ballConfigs);
    } on ArgumentError catch (error) {
      setState(() => _errorText = error.message.toString());
    }
  }

  String? _validateNames(List<String> names) {
    final trimmed = names.map((name) => name.trim()).toList(growable: false);
    if (trimmed.any((name) => name.isEmpty)) {
      return 'Mỗi người chơi cần có tên.';
    }

    final uniqueNames = trimmed.map((name) => name.toLowerCase()).toSet();
    if (uniqueNames.length != trimmed.length) {
      return 'Tên người chơi phải khác nhau.';
    }

    if (trimmed.length < 2) {
      return 'Cần ít nhất 2 người chơi.';
    }

    return null;
  }

  List<BallConfig> _readBalls() {
    if (_ballDrafts.isEmpty) {
      throw ArgumentError('Cần ít nhất 1 loại bi.');
    }

    final configs = <BallConfig>[];
    final seenNumbers = <int>{};

    for (var i = 0; i < _ballDrafts.length; i++) {
      final draft = _ballDrafts[i];
      final number = int.tryParse(draft.numberController.text.trim());
      final points = int.tryParse(draft.pointsController.text.trim());

      if (number == null || points == null) {
        throw ArgumentError('Bi #${i + 1}: nhập số bi và điểm.');
      }
      if (number <= 0) {
        throw ArgumentError('Bi #${i + 1}: số bi phải > 0.');
      }
      if (points <= 0) {
        throw ArgumentError('Bi #${i + 1}: điểm phải > 0.');
      }
      if (!seenNumbers.add(number)) {
        throw ArgumentError('Số bi $number bị trùng.');
      }

      configs.add(BallConfig(number: number, points: points));
    }

    return configs;
  }

  /// Clear error + setState. Setup screen rebuilds → `_otherSelectedNames`
  /// được tính lại với text mới nhất → popup history ẩn đúng tên đã dùng.
  void _clearError() {
    setState(() => _errorText = null);
  }

  /// Tập tên đang dùng ở các field KHÁC field [excludeIndex].
  /// Lowercase + bỏ rỗng để compare case-insensitive.
  Set<String> _otherSelectedNames(int excludeIndex) {
    return {
      for (var j = 0; j < _controllers.length; j++)
        if (j != excludeIndex)
          _controllers[j].text.trim().toLowerCase(),
    }..removeWhere((n) => n.isEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TableBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () {
                      ref.read(gameControllerProvider.notifier).resetGame();
                    },
                    icon: const Icon(Icons.arrow_back),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Bắn đền',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nhập tên người chơi và cấu hình bi rồi bắt đầu ván.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textBody,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Người chơi', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                          'Cần ít nhất 2 tên khác nhau.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSubtle,
                          ),
                        ),
                        const SizedBox(height: 18),
                        for (var i = 0; i < _controllers.length; i++) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: ValueKey('player_name_$i'),
                                  controller: _controllers[i],
                                  textInputAction: TextInputAction.next,
                                  onChanged: (_) => _clearError(),
                                  decoration: InputDecoration(
                                    labelText: 'Người chơi ${i + 1}',
                                    suffixIcon: NameHistoryButton(
                                      excluded: _otherSelectedNames(i),
                                      onPick: (name) {
                                        _controllers[i].text = name;
                                        _controllers[i].selection =
                                            TextSelection.collapsed(
                                          offset: name.length,
                                        );
                                        _clearError();
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton.filledTonal(
                                onPressed: _controllers.length > 2
                                    ? () => _removePlayer(i)
                                    : null,
                                tooltip: 'Xóa người chơi',
                                icon: const Icon(Icons.remove_rounded),
                              ),
                            ],
                          ),
                          if (i != _controllers.length - 1)
                            const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _addPlayer,
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('Thêm người chơi'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Danh sách bi', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                          'Mỗi bi gồm số bi và số điểm cộng khi ăn.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSubtle,
                          ),
                        ),
                        const SizedBox(height: 18),
                        for (var i = 0; i < _ballDrafts.length; i++) ...[
                          _BallConfigRow(
                            key: ValueKey(_ballDrafts[i].id),
                            draft: _ballDrafts[i],
                            index: i,
                            canRemove: _ballDrafts.length > 1,
                            onRemove: () => _removeBall(i),
                            onChanged: _clearError,
                          ),
                          if (i != _ballDrafts.length - 1)
                            const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _addBall,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Thêm bi'),
                        ),
                        if (_errorText != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _errorText!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  color: AppColors.textDark,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _RuleChip(
                          label: 'Chọn người bắn → bi → người bị trừ',
                        ),
                        const SizedBox(height: 10),
                        const _RuleChip(label: 'Tổng điểm luôn = 0'),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _startGame,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.textDark,
                          ),
                          child: const Text('Bắt đầu'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BallDraft {
  _BallDraft({required this.numberController, required this.pointsController})
    : id = _counter++;

  factory _BallDraft.fromConfig(BallConfig config) {
    return _BallDraft(
      numberController: TextEditingController(text: '${config.number}'),
      pointsController: TextEditingController(text: '${config.points}'),
    );
  }

  factory _BallDraft.empty() {
    return _BallDraft(
      numberController: TextEditingController(),
      pointsController: TextEditingController(),
    );
  }

  static int _counter = 0;

  final int id;
  final TextEditingController numberController;
  final TextEditingController pointsController;

  void dispose() {
    numberController.dispose();
    pointsController.dispose();
  }
}


class _BallConfigRow extends ConsumerWidget {
  const _BallConfigRow({
    super.key,
    required this.draft,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  final _BallDraft draft;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lấy distinct (giữ thứ tự mới-nhất-trước) cho mỗi field — chọn riêng số bi
    // và riêng điểm thay vì cụm pair.
    final history = ref.watch(ballConfigHistoryProvider);
    final numbers = history.map((c) => c.number).toSet().toList();
    final points = history.map((c) => c.points).toSet().toList();

    void setNumber(int n) {
      draft.numberController.text = '$n';
      draft.numberController.selection = TextSelection.collapsed(
        offset: draft.numberController.text.length,
      );
      onChanged();
    }

    void setPoints(int p) {
      draft.pointsController.text = '$p';
      draft.pointsController.selection = TextSelection.collapsed(
        offset: draft.pointsController.text.length,
      );
      onChanged();
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: draft.numberController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              labelText: 'Số bi #${index + 1}',
              hintText: 'VD: 3',
              suffixIcon: _IntHistoryButton(
                values: numbers,
                tooltip: 'Số bi đã dùng',
                onPick: setNumber,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: draft.pointsController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              labelText: 'Điểm',
              hintText: 'VD: 1',
              suffixIcon: _IntHistoryButton(
                values: points,
                tooltip: 'Điểm đã dùng',
                onPick: setPoints,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          onPressed: canRemove ? onRemove : null,
          tooltip: 'Xóa bi',
          icon: const Icon(Icons.remove_rounded),
        ),
      ],
    );
  }
}

/// Popup các giá trị int đã dùng — gợi ý cho field số bi hoặc field điểm
/// riêng biệt (không cụm pair). Ẩn nếu chưa có lịch sử.
class _IntHistoryButton extends StatelessWidget {
  const _IntHistoryButton({
    required this.values,
    required this.onPick,
    required this.tooltip,
  });

  final List<int> values;
  final ValueChanged<int> onPick;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<int>(
      tooltip: tooltip,
      icon: const Icon(Icons.history_rounded, color: AppColors.textSubtle),
      onSelected: onPick,
      itemBuilder: (_) => [
        for (final v in values)
          PopupMenuItem<int>(value: v, child: Text('$v')),
      ],
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(26),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
