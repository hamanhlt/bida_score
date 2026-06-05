import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/league_engine.dart';
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
  final TextEditingController _nameController = TextEditingController(
    text: 'Giải đấu mới',
  );
  final List<TextEditingController> _controllers = [];
  String? _errorText;
  bool _useGroupKnockout = false;
  int _groupSize = 4;

  static const _minPlayers = 3;
  static const _maxPlayers = 16;

  @override
  void initState() {
    super.initState();
    // Khởi động với 4 người chơi mặc định.
    for (var i = 0; i < 4; i++) {
      _controllers.add(TextEditingController(text: 'Người chơi ${i + 1}'));
    }
    _syncGroupSize();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    if (_controllers.length >= _maxPlayers) return;
    setState(() {
      final controller = TextEditingController(
        text: 'Người chơi ${_controllers.length + 1}',
      );
      final insertAt = _useGroupKnockout
          ? _nextGroupPlayerInsertIndex()
          : _controllers.length;
      _controllers.insert(insertAt, controller);
      _syncGroupSize();
    });
  }

  void _removeRow(int index) {
    if (_controllers.length <= _minPlayers) return;
    setState(() {
      _controllers.removeAt(index).dispose();
      _syncGroupSize();
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

  List<int> get _groupSizeOptions =>
      LeagueEngine.validGroupSizesFor(_controllers.length);

  int _preferredGroupSize(List<int> sizes) {
    if (sizes.contains(4)) return 4;
    return sizes.isEmpty ? _groupSize : sizes.first;
  }

  void _syncGroupSize() {
    final sizes = _groupSizeOptions;
    if (sizes.isEmpty) return;
    if (!sizes.contains(_groupSize)) {
      _groupSize = _preferredGroupSize(sizes);
    }
  }

  void _start() {
    final tournamentName = _nameController.text.trim();
    if (tournamentName.isEmpty) {
      setState(() => _errorText = 'Tên giải không được để trống.');
      return;
    }
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
    final groupSize = _useGroupKnockout ? _groupSize : null;

    try {
      ref
          .read(leagueControllerProvider.notifier)
          .startTournament(
            names,
            tournamentName: tournamentName,
            groupSize: groupSize,
          );
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
    final groupSizeOptions = _groupSizeOptions;
    final selectedGroupSize = groupSizeOptions.contains(_groupSize)
        ? _groupSize
        : (groupSizeOptions.isEmpty
              ? null
              : _preferredGroupSize(groupSizeOptions));
    final canPreviewGroups =
        _useGroupKnockout &&
        selectedGroupSize != null &&
        LeagueEngine.plannedGroupSizesFor(
          _controllers.length,
          selectedGroupSize,
        ).isNotEmpty;

    return PopScope(
      // Hardware back → quay về list (đồng nhất AppBar back).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ref.read(leagueControllerProvider.notifier).backToList();
      },
      child: Scaffold(
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
                        // Quay về list giải đấu (không xoá active list).
                        ref
                            .read(leagueControllerProvider.notifier)
                            .backToList();
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
                    'Chọn vòng tròn hoặc chia bảng rồi đấu knockout.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textBody,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: TextField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _clearError(),
                        decoration: const InputDecoration(
                          labelText: 'Tên giải',
                          prefixIcon: Icon(Icons.drive_file_rename_outline),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
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
                            _useGroupKnockout
                                ? 'Nhập người chơi trực tiếp theo từng bảng. '
                                      'App sẽ giữ đúng thứ tự Bảng A, B, C... khi tạo lịch.'
                                : 'Tối thiểu $_minPlayers người. Tổng số trận = '
                                      'N×(N-1)/2 = ${_pairCount(_controllers.length)} trận.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSubtle,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (canPreviewGroups)
                            _buildGroupPlayerFields(
                              context,
                              selectedGroupSize,
                              canRemove,
                            )
                          else
                            _buildRoundRobinPlayerFields(context, canRemove),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: canAdd ? _addRow : null,
                            icon: const Icon(Icons.person_add_rounded),
                            label: Text(
                              _useGroupKnockout
                                  ? 'Thêm người vào bảng'
                                  : 'Thêm người chơi',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DefaultTabController(
                    length: 2,
                    initialIndex: _useGroupKnockout ? 1 : 0,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Thể thức', style: theme.textTheme.titleLarge),
                            const SizedBox(height: 12),
                            TabBar(
                              onTap: (index) {
                                setState(() {
                                  _useGroupKnockout = index == 1;
                                  _syncGroupSize();
                                  _errorText = null;
                                });
                              },
                              labelColor: AppColors.primaryDark,
                              unselectedLabelColor: AppColors.textSubtle,
                              indicatorColor: AppColors.accent,
                              indicatorWeight: 3,
                              tabs: const [
                                Tab(
                                  text: 'Vòng tròn',
                                  icon: Icon(Icons.table_rows_rounded),
                                ),
                                Tab(
                                  text: 'Vòng bảng',
                                  icon: Icon(Icons.account_tree_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (_useGroupKnockout) ...[
                              DropdownButtonFormField<int>(
                                initialValue: selectedGroupSize,
                                decoration: const InputDecoration(
                                  labelText: 'Số người mỗi bảng',
                                ),
                                items: [
                                  for (final size in groupSizeOptions)
                                    DropdownMenuItem<int>(
                                      value: size,
                                      child: Text('$size người / bảng'),
                                    ),
                                ],
                                onChanged: groupSizeOptions.isEmpty
                                    ? null
                                    : (value) {
                                        if (value == null) return;
                                        setState(() {
                                          _groupSize = value;
                                          _errorText = null;
                                        });
                                      },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                selectedGroupSize == null
                                    ? 'Cần từ $_minPlayers đến $_maxPlayers người chơi.'
                                    : _groupPlanText(selectedGroupSize),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color:
                                      selectedGroupSize != null &&
                                          LeagueEngine.canStartGroupKnockout(
                                            _controllers.length,
                                            selectedGroupSize,
                                          )
                                      ? AppColors.textSubtle
                                      : theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ] else
                              Text(
                                'Mỗi người gặp nhau đúng 1 lần. Thắng = +1 điểm.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSubtle,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const SizedBox(height: 10),
                            Text(
                              'Dự kiến: ${_plannedMatchCount()} trận.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textBody,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
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
      ),
    );
  }

  int _pairCount(int n) => n < 2 ? 0 : n * (n - 1) ~/ 2;

  Widget _buildRoundRobinPlayerFields(BuildContext context, bool canRemove) {
    return Column(
      children: [
        for (var i = 0; i < _controllers.length; i++) ...[
          _PlayerNameRow(
            controller: _controllers[i],
            label: 'Người chơi ${i + 1}',
            textInputAction: i == _controllers.length - 1
                ? TextInputAction.done
                : TextInputAction.next,
            excluded: _otherNames(i),
            canRemove: canRemove,
            onPick: (name) => _setPlayerName(i, name),
            onChanged: _clearError,
            onRemove: () => _removeRow(i),
          ),
          if (i != _controllers.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildGroupPlayerFields(
    BuildContext context,
    int groupSize,
    bool canRemove,
  ) {
    final theme = Theme.of(context);
    final groups = _setupGroups(groupSize);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) ...[
          _GroupHeader(
            title: 'Bảng ${_groupLetter(groupIndex)}',
            subtitle: '${groups[groupIndex].length} người',
          ),
          const SizedBox(height: 8),
          for (
            var offset = 0;
            offset < groups[groupIndex].length;
            offset++
          ) ...[
            _PlayerNameRow(
              controller: _controllers[groups[groupIndex].start + offset],
              label: 'Người ${offset + 1}',
              textInputAction:
                  groups[groupIndex].start + offset == _controllers.length - 1
                  ? TextInputAction.done
                  : TextInputAction.next,
              excluded: _otherNames(groups[groupIndex].start + offset),
              canRemove: canRemove,
              onPick: (name) =>
                  _setPlayerName(groups[groupIndex].start + offset, name),
              onChanged: _clearError,
              onRemove: () => _removeRow(groups[groupIndex].start + offset),
            ),
            if (offset != groups[groupIndex].length - 1)
              const SizedBox(height: 10),
          ],
          if (groupIndex != groups.length - 1) ...[
            const SizedBox(height: 14),
            Divider(color: theme.colorScheme.outlineVariant.withAlpha(120)),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  void _setPlayerName(int index, String name) {
    _controllers[index].text = name;
    _controllers[index].selection = TextSelection.collapsed(
      offset: name.length,
    );
    _clearError();
  }

  List<_SetupGroup> _setupGroups(int groupSize) {
    final sizes = LeagueEngine.plannedGroupSizesFor(
      _controllers.length,
      groupSize,
    );
    var start = 0;
    final groups = <_SetupGroup>[];
    for (final size in sizes) {
      groups.add(_SetupGroup(start: start, length: size));
      start += size;
    }
    return groups;
  }

  int _nextGroupPlayerInsertIndex() {
    final oldSizes = LeagueEngine.plannedGroupSizesFor(
      _controllers.length,
      _groupSize,
    );
    final newSizes = LeagueEngine.plannedGroupSizesFor(
      _controllers.length + 1,
      _groupSize,
    );
    if (oldSizes.isEmpty ||
        newSizes.isEmpty ||
        oldSizes.length != newSizes.length) {
      return _controllers.length;
    }

    var start = 0;
    for (var i = 0; i < oldSizes.length; i++) {
      if (newSizes[i] > oldSizes[i]) {
        return start + oldSizes[i];
      }
      start += oldSizes[i];
    }
    return _controllers.length;
  }

  String _groupLetter(int index) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (index >= 0 && index < letters.length) return letters[index];
    return '${index + 1}';
  }

  int _plannedMatchCount() {
    final playerCount = _controllers.length;
    if (!_useGroupKnockout) {
      return _pairCount(playerCount);
    }
    final groupSizes = LeagueEngine.plannedGroupSizesFor(
      playerCount,
      _groupSize,
    );
    final groupMatches = groupSizes.fold<int>(
      0,
      (sum, size) => sum + _pairCount(size),
    );
    if (!LeagueEngine.canStartGroupKnockout(playerCount, _groupSize)) {
      return groupMatches;
    }
    final knockoutPlayers = groupSizes.length * 2;
    return groupMatches + knockoutPlayers - 1;
  }

  String _groupPlanText(int groupSize) {
    final sizes = LeagueEngine.plannedGroupSizesFor(
      _controllers.length,
      groupSize,
    );
    if (sizes.isEmpty) {
      return 'Cần ít nhất 2 bảng. Hãy giảm số người mỗi bảng hoặc thêm người chơi.';
    }
    if (sizes.any((size) => size < 2)) {
      return 'Mỗi bảng cần ít nhất 2 người để lấy top 2 vào knockout.';
    }
    return 'Sẽ có ${sizes.length} bảng (${_plannedGroupSizeText(groupSize)}), '
        'lấy 2 người đầu mỗi bảng vào knockout.';
  }

  String _plannedGroupSizeText(int groupSize) {
    final sizes = LeagueEngine.plannedGroupSizesFor(
      _controllers.length,
      groupSize,
    );
    if (sizes.isEmpty) return '';
    return sizes.map((s) => '$s').join(' + ');
  }
}

class _SetupGroup {
  const _SetupGroup({required this.start, required this.length});

  final int start;
  final int length;
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSubtle,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PlayerNameRow extends StatelessWidget {
  const _PlayerNameRow({
    required this.controller,
    required this.label,
    required this.textInputAction,
    required this.excluded,
    required this.canRemove,
    required this.onPick,
    required this.onChanged,
    required this.onRemove,
  });

  final TextEditingController controller;
  final String label;
  final TextInputAction textInputAction;
  final Set<String> excluded;
  final bool canRemove;
  final ValueChanged<String> onPick;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: textInputAction,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: NameHistoryButton(excluded: excluded, onPick: onPick),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          onPressed: canRemove ? onRemove : null,
          tooltip: 'Xoá người chơi',
          icon: const Icon(Icons.remove_rounded),
        ),
      ],
    );
  }
}
