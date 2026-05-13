import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/game_controller.dart';
import '../providers/nine_ball_controller.dart';
import '../widgets/name_history_button.dart';
import '../widgets/table_background.dart';

class NineBallSetupScreen extends ConsumerStatefulWidget {
  const NineBallSetupScreen({super.key});

  @override
  ConsumerState<NineBallSetupScreen> createState() =>
      _NineBallSetupScreenState();
}

class _NineBallSetupScreenState extends ConsumerState<NineBallSetupScreen> {
  late final List<TextEditingController> _controllers;
  int _raceTarget = 5;
  String? _errorText;

  static const _raceOptions = [3, 5, 7, 9, 11];

  @override
  void initState() {
    super.initState();
    _controllers = [
      TextEditingController(text: 'Người chơi 1'),
      TextEditingController(text: 'Người chơi 2'),
    ];
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Tên đang dùng ở field KHÁC [excludeIndex] (lowercase, bỏ rỗng) — để
  /// popup gợi ý ẩn tên đã chọn, tránh trùng.
  Set<String> _otherSelectedNames(int excludeIndex) {
    return {
      for (var j = 0; j < _controllers.length; j++)
        if (j != excludeIndex) _controllers[j].text.trim().toLowerCase(),
    }..removeWhere((n) => n.isEmpty);
  }

  Future<void> _showCustomRaceDialog() async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _RaceInputDialog(initial: _raceTarget),
    );
    if (result != null) {
      setState(() => _raceTarget = result);
    }
  }

  void _startGame() {
    final names = _controllers.map((c) => c.text).toList();
    final trimmed = names.map((n) => n.trim()).toList();

    if (trimmed.any((n) => n.isEmpty)) {
      setState(() => _errorText = 'Mỗi người chơi cần có tên.');
      return;
    }
    if (trimmed[0].toLowerCase() == trimmed[1].toLowerCase()) {
      setState(() => _errorText = 'Tên người chơi phải khác nhau.');
      return;
    }

    try {
      ref
          .read(nineBallControllerProvider.notifier)
          .startGame(names, _raceTarget);
    } on ArgumentError catch (e) {
      setState(() => _errorText = e.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final modeLabel =
        ref.watch(gameControllerProvider).gameMode?.label ?? '9-Ball';

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
                    color: const Color(0xFF16322C),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  modeLabel,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: const Color(0xFF16322C),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nhập tên 2 người chơi và chọn race-to.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF4A6057),
                  ),
                ),
                const SizedBox(height: 24),
                // Tên người chơi
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Người chơi', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 16),
                        for (var i = 0; i < 2; i++) ...[
                          TextField(
                            controller: _controllers[i],
                            textInputAction: i == 0
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onChanged: (_) {
                              if (_errorText != null) {
                                setState(() => _errorText = null);
                              }
                            },
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
                                  if (_errorText != null) {
                                    setState(() => _errorText = null);
                                  }
                                },
                              ),
                            ),
                          ),
                          if (i == 0) const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Race target
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Race to', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                          'Ai đạt đủ số ván trước thì thắng.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5F726A),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final val in _raceOptions)
                              ChoiceChip(
                                label: Text('$val'),
                                selected: val == _raceTarget,
                                onSelected: (_) {
                                  setState(() => _raceTarget = val);
                                },
                              ),
                            if (!_raceOptions.contains(_raceTarget))
                              ChoiceChip(
                                label: Text('$_raceTarget'),
                                selected: true,
                                onSelected: (_) {},
                              ),
                            ActionChip(
                              avatar: const Icon(Icons.edit_rounded, size: 16),
                              label: const Text('Khác…'),
                              onPressed: _showCustomRaceDialog,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
                const SizedBox(height: 20),
                Card(
                  color: const Color(0xFF16322C),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: FilledButton(
                      onPressed: _startGame,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF2B544),
                        foregroundColor: const Color(0xFF16322C),
                      ),
                      child: const Text('Bắt đầu'),
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

/// Dialog nhập race-to tuỳ ý (1–99). Tách ra StatefulWidget riêng để
/// `TextEditingController` được dispose đúng lifecycle qua `State.dispose`,
/// tránh assertion `_dependents.isEmpty` khi TextField rebuild sau pop.
class _RaceInputDialog extends StatefulWidget {
  const _RaceInputDialog({required this.initial});

  final int initial;

  @override
  State<_RaceInputDialog> createState() => _RaceInputDialogState();
}

class _RaceInputDialogState extends State<_RaceInputDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initial}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? _tryParse() {
    final n = int.tryParse(_controller.text.trim());
    if (n == null || n < 1 || n > 99) return null;
    return n;
  }

  void _confirm() {
    final n = _tryParse();
    if (n == null) {
      setState(() => _error = 'Nhập số nguyên 1–99.');
      return;
    }
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Race to'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        onSubmitted: (_) => _confirm(),
        decoration: InputDecoration(
          labelText: 'Số ván cần để thắng',
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
          child: const Text('Áp dụng'),
        ),
      ],
    );
  }
}
