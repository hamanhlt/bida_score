import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/game_controller.dart';
import '../providers/league_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/name_history_button.dart';
import '../widgets/table_background.dart';

/// Setup giải đấu vòng tròn — nhập danh sách người chơi (≥ 3) rồi bấm "Tạo
/// giải". Mỗi field tên có popup gợi ý từ `playerNameHistoryProvider`
/// (dùng chung với Bắn đền / Pool).
class LeagueSetupScreen extends ConsumerStatefulWidget {
  const LeagueSetupScreen({super.key});

  @override
  ConsumerState<LeagueSetupScreen> createState() => _LeagueSetupScreenState();
}

class _LeagueSetupScreenState extends ConsumerState<LeagueSetupScreen> {
  final List<TextEditingController> _controllers = [];
  String? _errorText;

  static const _minPlayers = 3;
  static const _maxPlayers = 16;

  @override
  void initState() {
    super.initState();
    // Khởi động với 4 người chơi mặc định.
    for (var i = 0; i < 4; i++) {
      _controllers.add(TextEditingController(text: 'Người chơi ${i + 1}'));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    if (_controllers.length >= _maxPlayers) return;
    setState(() {
      _controllers.add(
        TextEditingController(text: 'Người chơi ${_controllers.length + 1}'),
      );
    });
  }

  void _removeRow(int index) {
    if (_controllers.length <= _minPlayers) return;
    setState(() {
      _controllers.removeAt(index).dispose();
    });
  }

  Set<String> _otherNames(int excludeIndex) {
    return {
      for (var j = 0; j < _controllers.length; j++)
        if (j != excludeIndex) _controllers[j].text.trim().toLowerCase(),
    }..removeWhere((n) => n.isEmpty);
  }

  void _clearError() {
    if (_errorText != null) setState(() => _errorText = null);
  }

  void _start() {
    final names = _controllers.map((c) => c.text.trim()).toList();
    if (names.any((n) => n.isEmpty)) {
      setState(() => _errorText = 'Mỗi người chơi cần có tên.');
      return;
    }
    final lower = names.map((n) => n.toLowerCase()).toSet();
    if (lower.length != names.length) {
      setState(() => _errorText = 'Tên người chơi phải khác nhau.');
      return;
    }

    try {
      ref.read(leagueControllerProvider.notifier).startTournament(names);
      // Lưu tên vào pool dùng chung (Setup screen lần sau gợi ý lại).
      // Fire-and-forget — không block UI navigation.
      ref.read(playerNameHistoryProvider.notifier).addAll(names);
    } on ArgumentError catch (e) {
      // `e.message` là `Object?` — guard null để tránh in chuỗi "null".
      setState(
        () => _errorText = e.message?.toString() ?? 'Danh sách không hợp lệ.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canRemove = _controllers.length > _minPlayers;
    final canAdd = _controllers.length < _maxPlayers;

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
                  'Giải đấu',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vòng tròn — mỗi người gặp nhau đúng 1 lần. Thắng = +1 điểm.',
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
                        Row(
                          children: [
                            Text(
                              'Người chơi',
                              style: theme.textTheme.titleLarge,
                            ),
                            const Spacer(),
                            Text(
                              '${_controllers.length}/$_maxPlayers',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSubtle,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tối thiểu $_minPlayers người. Tổng số trận = '
                          'N×(N-1)/2 = ${_pairCount(_controllers.length)} trận.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSubtle,
                          ),
                        ),
                        const SizedBox(height: 14),
                        for (var i = 0; i < _controllers.length; i++) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controllers[i],
                                  textInputAction: i == _controllers.length - 1
                                      ? TextInputAction.done
                                      : TextInputAction.next,
                                  onChanged: (_) => _clearError(),
                                  decoration: InputDecoration(
                                    labelText: 'Người chơi ${i + 1}',
                                    suffixIcon: NameHistoryButton(
                                      excluded: _otherNames(i),
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
                              const SizedBox(width: 10),
                              IconButton.filledTonal(
                                onPressed: canRemove
                                    ? () => _removeRow(i)
                                    : null,
                                tooltip: 'Xoá người chơi',
                                icon: const Icon(Icons.remove_rounded),
                              ),
                            ],
                          ),
                          if (i != _controllers.length - 1)
                            const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: canAdd ? _addRow : null,
                          icon: const Icon(Icons.person_add_rounded),
                          label: const Text('Thêm người chơi'),
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
                  color: AppColors.textDark,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: FilledButton(
                      onPressed: _start,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.textDark,
                      ),
                      child: const Text('Tạo giải'),
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

  int _pairCount(int n) => n < 2 ? 0 : n * (n - 1) ~/ 2;
}
