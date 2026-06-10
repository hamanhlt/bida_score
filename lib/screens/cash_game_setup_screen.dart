import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cash_game_state.dart';
import '../providers/cash_game_controller.dart';
import '../providers/game_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/name_history_button.dart';
import '../widgets/table_background.dart';

/// Setup chế độ Chơi điểm — 2 người chơi + mức tiền/ván + tiền/lỗ 10.
class CashGameSetupScreen extends ConsumerStatefulWidget {
  const CashGameSetupScreen({super.key});

  @override
  ConsumerState<CashGameSetupScreen> createState() =>
      _CashGameSetupScreenState();
}

class _CashGameSetupScreenState extends ConsumerState<CashGameSetupScreen> {
  late final List<TextEditingController> _controllers;
  int _moneyPerRack = 40000;
  int _moneyPerBall = 20000;
  String? _errorText;

  static const _rackOptions = [20000, 30000, 40000, 50000, 100000];
  static const _ballOptions = [10000, 20000, 30000, 50000];

  @override
  void initState() {
    super.initState();
    _controllers = [
      TextEditingController(text: 'Người chơi 1'),
      TextEditingController(text: 'Người chơi 2'),
    ];
    // Khôi phục mức tiền lần trước nếu có.
    final saved = ref.read(cashConfigProvider);
    if (saved != null) {
      _moneyPerRack = saved.moneyPerRack;
      _moneyPerBall = saved.moneyPerBall;
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Set<String> _otherSelectedNames(int excludeIndex) {
    return {
      for (var j = 0; j < _controllers.length; j++)
        if (j != excludeIndex) _controllers[j].text.trim().toLowerCase(),
    }..removeWhere((n) => n.isEmpty);
  }

  Future<void> _showCustomMoneyDialog({required bool forRack}) async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _MoneyInputDialog(
        initial: forRack ? _moneyPerRack : _moneyPerBall,
        title: forRack ? 'Tiền mỗi ván thắng' : 'Tiền mỗi lỗ 10',
      ),
    );
    if (result != null) {
      setState(() {
        if (forRack) {
          _moneyPerRack = result;
        } else {
          _moneyPerBall = result;
        }
      });
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
          .read(cashGameControllerProvider.notifier)
          .startGame(
            names,
            moneyPerRack: _moneyPerRack,
            moneyPerBall: _moneyPerBall,
          );
    } on ArgumentError catch (e) {
      setState(() => _errorText = e.message?.toString() ?? 'Cấu hình lỗi.');
    }
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
                  'Chơi điểm',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ván thắng cộng dồn đến cuối trận. Chốt sẽ khóa lỗ 10 rồi trừ hiệu số tiền đang treo.',
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
                _MoneyCard(
                  title: 'Tiền mỗi ván thắng',
                  subtitle: 'Cộng cho người thắng khi chốt ván.',
                  selected: _moneyPerRack,
                  options: _rackOptions,
                  onSelect: (v) => setState(() => _moneyPerRack = v),
                  onCustom: () => _showCustomMoneyDialog(forRack: true),
                ),
                const SizedBox(height: 16),
                _MoneyCard(
                  title: 'Tiền mỗi lỗ 10',
                  subtitle: 'Tính theo số lỗ 10 đã nhập trong ván hiện tại.',
                  selected: _moneyPerBall,
                  options: _ballOptions,
                  onSelect: (v) => setState(() => _moneyPerBall = v),
                  onCustom: () => _showCustomMoneyDialog(forRack: false),
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
                  color: AppColors.textDark,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: FilledButton(
                      onPressed: _startGame,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.textDark,
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

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.options,
    required this.onSelect,
    required this.onCustom,
  });

  final String title;
  final String subtitle;
  final int selected;
  final List<int> options;
  final ValueChanged<int> onSelect;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSubtle,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final v in options)
                  ChoiceChip(
                    label: Text(formatVnd(v)),
                    selected: v == selected,
                    onSelected: (_) => onSelect(v),
                  ),
                if (!options.contains(selected))
                  ChoiceChip(
                    label: Text(formatVnd(selected)),
                    selected: true,
                    onSelected: (_) {},
                  ),
                ActionChip(
                  avatar: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Khác…'),
                  onPressed: onCustom,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog nhập số tiền tuỳ ý. StatefulWidget để controller dispose đúng
/// lifecycle (tránh assertion `_dependents.isEmpty`).
class _MoneyInputDialog extends StatefulWidget {
  const _MoneyInputDialog({required this.initial, required this.title});

  final int initial;
  final String title;

  @override
  State<_MoneyInputDialog> createState() => _MoneyInputDialogState();
}

class _MoneyInputDialogState extends State<_MoneyInputDialog> {
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

  void _confirm() {
    final n = int.tryParse(_controller.text.trim());
    if (n == null || n < 0 || n > 100000000) {
      setState(() => _error = 'Nhập số tiền hợp lệ (0 – 100 triệu).');
      return;
    }
    Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(9),
        ],
        onSubmitted: (_) => _confirm(),
        decoration: InputDecoration(
          labelText: 'Số tiền (đồng)',
          hintText: 'VD: 40000',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('Áp dụng')),
      ],
    );
  }
}
