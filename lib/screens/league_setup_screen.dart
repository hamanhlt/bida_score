import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/league_engine.dart';
import '../providers/game_controller.dart';
import '../providers/league_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/name_history_button.dart';
import '../widgets/table_background.dart';

enum _SetupMode { roundRobin, groupKnockout, doubleElim }

/// Setup giải đấu — 3 thể thức:
/// - **Vòng tròn**: list phẳng người chơi, mỗi người gặp nhau 1 lần.
/// - **Vòng bảng**: user chia bảng **bằng tay** (default 2 bảng A, B mỗi
///   bảng 4 người). +/- bảng, +/- người chơi trong bảng.
/// - **Đấu nhánh kép**: nhập từng cặp đấu lượt 1, sau lượt 1 mới tách nhánh.
class LeagueSetupScreen extends ConsumerStatefulWidget {
  const LeagueSetupScreen({super.key});

  @override
  ConsumerState<LeagueSetupScreen> createState() => _LeagueSetupScreenState();
}

class _LeagueSetupScreenState extends ConsumerState<LeagueSetupScreen> {
  final TextEditingController _nameController = TextEditingController(
    text: 'Giải đấu mới',
  );

  // Round-robin: flat list 3..16 người.
  final List<TextEditingController> _rrControllers = [];

  // Vòng bảng: nested list. Default 2 bảng × 4 người (8 total).
  final List<List<TextEditingController>> _groupControllers = [];

  // Đấu nhánh kép: flat list theo cặp lượt 1, N phải là 8/16/32.
  final List<TextEditingController> _deControllers = [];

  String? _errorText;
  _SetupMode _mode = _SetupMode.roundRobin;

  static const _minPlayers = 3;
  static const _maxPlayers = 16;
  static const _minGroups = 2;
  static const _maxGroups = 8;
  static const _minGroupSize = 2;
  static const _maxGroupSize = 8;

  @override
  void initState() {
    super.initState();
    // Round-robin defaults: 4 người.
    for (var i = 0; i < 4; i++) {
      _rrControllers.add(TextEditingController(text: 'Người chơi ${i + 1}'));
    }
    // Vòng bảng defaults: 2 bảng × 4 người. Tên format "A1, A2, ... B4".
    for (var g = 0; g < 2; g++) {
      final letter = _groupLetter(g);
      _groupControllers.add([
        for (var p = 0; p < 4; p++)
          TextEditingController(text: '$letter${p + 1}'),
      ]);
    }
    // Đấu nhánh defaults: 8 người (power of 2 phổ biến).
    for (var i = 0; i < 8; i++) {
      _deControllers.add(TextEditingController(text: 'Người chơi ${i + 1}'));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _rrControllers) {
      c.dispose();
    }
    for (final group in _groupControllers) {
      for (final c in group) {
        c.dispose();
      }
    }
    for (final c in _deControllers) {
      c.dispose();
    }
    super.dispose();
  }

  int get _groupTotalPlayers =>
      _groupControllers.fold<int>(0, (sum, g) => sum + g.length);

  // ────────────────────────── round-robin actions ──────────────────────────

  void _rrAdd() {
    if (_rrControllers.length >= _maxPlayers) return;
    setState(() {
      _rrControllers.add(
        TextEditingController(text: 'Người chơi ${_rrControllers.length + 1}'),
      );
    });
  }

  void _rrRemove(int index) {
    if (_rrControllers.length <= _minPlayers) return;
    setState(() {
      _rrControllers.removeAt(index).dispose();
    });
  }

  // ────────────────────────── group actions ──────────────────────────

  void _addGroup() {
    if (_groupControllers.length >= _maxGroups) return;
    if (_groupTotalPlayers + _minGroupSize > _maxPlayers) return;
    setState(() {
      final letter = _groupLetter(_groupControllers.length);
      _groupControllers.add([
        for (var p = 0; p < _minGroupSize; p++)
          TextEditingController(text: '$letter${p + 1}'),
      ]);
    });
  }

  void _removeGroup(int groupIndex) {
    if (_groupControllers.length <= _minGroups) return;
    setState(() {
      for (final c in _groupControllers[groupIndex]) {
        c.dispose();
      }
      _groupControllers.removeAt(groupIndex);
    });
  }

  void _addPlayerToGroup(int groupIndex) {
    if (_groupControllers[groupIndex].length >= _maxGroupSize) return;
    if (_groupTotalPlayers >= _maxPlayers) return;
    setState(() {
      final letter = _groupLetter(groupIndex);
      final pos = _groupControllers[groupIndex].length + 1;
      _groupControllers[groupIndex].add(
        TextEditingController(text: '$letter$pos'),
      );
    });
  }

  void _removePlayerFromGroup(int groupIndex, int playerIndex) {
    if (_groupControllers[groupIndex].length <= _minGroupSize) return;
    setState(() {
      _groupControllers[groupIndex].removeAt(playerIndex).dispose();
    });
  }

  // ────────────────────────── name picker excludes ──────────────────────────

  Set<String> _excludedRr(int excludeIndex) {
    return {
      for (var j = 0; j < _rrControllers.length; j++)
        if (j != excludeIndex) _rrControllers[j].text.trim().toLowerCase(),
    }..removeWhere((n) => n.isEmpty);
  }

  Set<String> _excludedGroup(int gIdx, int pIdx) {
    final result = <String>{};
    for (var gi = 0; gi < _groupControllers.length; gi++) {
      for (var pi = 0; pi < _groupControllers[gi].length; pi++) {
        if (gi == gIdx && pi == pIdx) continue;
        final n = _groupControllers[gi][pi].text.trim().toLowerCase();
        if (n.isNotEmpty) result.add(n);
      }
    }
    return result;
  }

  void _clearError() {
    if (_errorText != null) setState(() => _errorText = null);
  }

  // ────────────────────────── submit ──────────────────────────

  void _start() {
    final tournamentName = _nameController.text.trim();
    if (tournamentName.isEmpty) {
      setState(() => _errorText = 'Tên giải không được để trống.');
      return;
    }

    if (_mode == _SetupMode.roundRobin) {
      final names = _rrControllers.map((c) => c.text.trim()).toList();
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
        ref
            .read(leagueControllerProvider.notifier)
            .startTournament(names, tournamentName: tournamentName);
        ref.read(playerNameHistoryProvider.notifier).addAll(names);
      } on ArgumentError catch (e) {
        setState(
          () => _errorText = e.message?.toString() ?? 'Danh sách không hợp lệ.',
        );
      }
      return;
    }

    if (_mode == _SetupMode.doubleElim) {
      final names = _deControllers.map((c) => c.text.trim()).toList();
      if (names.any((n) => n.isEmpty)) {
        setState(() => _errorText = 'Mỗi người chơi cần có tên.');
        return;
      }
      final lower = names.map((n) => n.toLowerCase()).toSet();
      if (lower.length != names.length) {
        setState(() => _errorText = 'Tên người chơi phải khác nhau.');
        return;
      }
      if (!LeagueEngine.doubleElimSizes.contains(names.length)) {
        setState(
          () => _errorText =
              'Đấu nhánh cần tối thiểu 8 người và hỗ trợ 8/16/32 người '
              '(hiện ${names.length}).',
        );
        return;
      }
      try {
        ref
            .read(leagueControllerProvider.notifier)
            .startTournament(
              names,
              tournamentName: tournamentName,
              doubleElim: true,
            );
        ref.read(playerNameHistoryProvider.notifier).addAll(names);
      } on ArgumentError catch (e) {
        setState(
          () => _errorText = e.message?.toString() ?? 'Cấu hình không hợp lệ.',
        );
      }
      return;
    }

    // Vòng bảng — chia bảng bằng tay.
    final manualGroups = _groupControllers
        .map((g) => g.map((c) => c.text.trim()).toList())
        .toList();
    if (manualGroups.any((g) => g.any((n) => n.isEmpty))) {
      setState(() => _errorText = 'Mỗi người chơi cần có tên.');
      return;
    }
    final allNames = manualGroups.expand((g) => g).toList();
    final lower = allNames.map((n) => n.toLowerCase()).toSet();
    if (lower.length != allNames.length) {
      setState(() => _errorText = 'Tên người chơi phải khác nhau.');
      return;
    }
    try {
      ref
          .read(leagueControllerProvider.notifier)
          .startTournament(
            allNames,
            tournamentName: tournamentName,
            manualGroups: manualGroups,
          );
      ref.read(playerNameHistoryProvider.notifier).addAll(allNames);
    } on ArgumentError catch (e) {
      setState(
        () =>
            _errorText = e.message?.toString() ?? 'Cấu hình bảng không hợp lệ.',
      );
    }
  }

  // ────────────────────────── build ──────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
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
                      onPressed: () => ref
                          .read(leagueControllerProvider.notifier)
                          .backToList(),
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
                    'Chọn vòng tròn hoặc tự chia bảng rồi đấu knockout.',
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
                  DefaultTabController(
                    length: 3,
                    initialIndex: _mode.index,
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
                                  _mode = _SetupMode.values[index];
                                  _errorText = null;
                                });
                              },
                              labelColor: AppColors.primaryDark,
                              unselectedLabelColor: AppColors.textSubtle,
                              indicatorColor: AppColors.accent,
                              indicatorWeight: 3,
                              isScrollable: true,
                              tabs: const [
                                Tab(
                                  text: 'Vòng tròn',
                                  icon: Icon(Icons.table_rows_rounded),
                                ),
                                Tab(
                                  text: 'Vòng bảng',
                                  icon: Icon(Icons.account_tree_rounded),
                                ),
                                Tab(
                                  text: 'Đấu nhánh',
                                  icon: Icon(Icons.hub_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _modeDescription(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSubtle,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
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
                  const SizedBox(height: 14),
                  switch (_mode) {
                    _SetupMode.roundRobin => _buildRoundRobinCard(theme),
                    _SetupMode.groupKnockout => _buildGroupsCard(theme),
                    _SetupMode.doubleElim => _buildDoubleElimCard(theme),
                  },
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

  // ────────────────────────── cards ──────────────────────────

  Widget _buildRoundRobinCard(ThemeData theme) {
    final canRemove = _rrControllers.length > _minPlayers;
    final canAdd = _rrControllers.length < _maxPlayers;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Người chơi', style: theme.textTheme.titleLarge),
                const Spacer(),
                Text(
                  '${_rrControllers.length}/$_maxPlayers',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSubtle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < _rrControllers.length; i++) ...[
              _PlayerNameRow(
                controller: _rrControllers[i],
                label: 'Người chơi ${i + 1}',
                textInputAction: i == _rrControllers.length - 1
                    ? TextInputAction.done
                    : TextInputAction.next,
                excluded: _excludedRr(i),
                canRemove: canRemove,
                onPick: (name) {
                  _rrControllers[i].text = name;
                  _rrControllers[i].selection = TextSelection.collapsed(
                    offset: name.length,
                  );
                  _clearError();
                },
                onChanged: _clearError,
                onRemove: () => _rrRemove(i),
              ),
              if (i != _rrControllers.length - 1) const SizedBox(height: 12),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: canAdd ? _rrAdd : null,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Thêm người chơi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsCard(ThemeData theme) {
    final total = _groupTotalPlayers;
    final canAddGroup =
        _groupControllers.length < _maxGroups &&
        total + _minGroupSize <= _maxPlayers;
    final canRemoveGroup = _groupControllers.length > _minGroups;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Các bảng', style: theme.textTheme.titleLarge),
                const Spacer(),
                Text(
                  '$total/$_maxPlayers người · '
                  '${_groupControllers.length}/$_maxGroups bảng',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSubtle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (var gi = 0; gi < _groupControllers.length; gi++) ...[
              _GroupCard(
                title: 'Bảng ${_groupLetter(gi)}',
                playerCount: _groupControllers[gi].length,
                canRemoveGroup: canRemoveGroup,
                canAddPlayer:
                    _groupControllers[gi].length < _maxGroupSize &&
                    total < _maxPlayers,
                onRemoveGroup: () => _removeGroup(gi),
                onAddPlayer: () => _addPlayerToGroup(gi),
                children: [
                  for (var pi = 0; pi < _groupControllers[gi].length; pi++) ...[
                    _PlayerNameRow(
                      controller: _groupControllers[gi][pi],
                      label: 'Người ${pi + 1}',
                      textInputAction: TextInputAction.next,
                      excluded: _excludedGroup(gi, pi),
                      canRemove: _groupControllers[gi].length > _minGroupSize,
                      onPick: (name) {
                        _groupControllers[gi][pi].text = name;
                        _groupControllers[gi][pi].selection =
                            TextSelection.collapsed(offset: name.length);
                        _clearError();
                      },
                      onChanged: _clearError,
                      onRemove: () => _removePlayerFromGroup(gi, pi),
                    ),
                    if (pi != _groupControllers[gi].length - 1)
                      const SizedBox(height: 10),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: canAddGroup ? _addGroup : null,
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Thêm bảng'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoubleElimCard(ThemeData theme) {
    final n = _deControllers.length;
    final pairCount = n ~/ 2;
    final isValidSize = LeagueEngine.doubleElimSizes.contains(n);
    final nextSize = _nextDeSize();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Cặp đấu lượt 1', style: theme.textTheme.titleLarge),
                const Spacer(),
                Text(
                  '$n người · $pairCount cặp',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isValidSize
                        ? AppColors.textSubtle
                        : theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Nhập đúng từng cặp mở màn. App giữ nguyên thứ tự này, không '
              'bốc ngẫu nhiên.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isValidSize
                    ? AppColors.textSubtle
                    : theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Quick-set buttons.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final size in LeagueEngine.doubleElimSizes)
                  ChoiceChip(
                    label: Text('$size người'),
                    selected: n == size,
                    onSelected: (_) => _setDeSize(size),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            for (var pairIndex = 0; pairIndex < pairCount; pairIndex++) ...[
              _DoubleElimPairSection(
                title: 'Cặp đấu ${pairIndex + 1}',
                children: [
                  for (var offset = 0; offset < 2; offset++) ...[
                    _PlayerNameRow(
                      controller: _deControllers[pairIndex * 2 + offset],
                      label: 'Cơ thủ ${offset + 1}',
                      textInputAction: pairIndex == pairCount - 1 && offset == 1
                          ? TextInputAction.done
                          : TextInputAction.next,
                      excluded: _excludedDe(pairIndex * 2 + offset),
                      canRemove: false,
                      showRemove: false,
                      onPick: (name) {
                        final index = pairIndex * 2 + offset;
                        _deControllers[index].text = name;
                        _deControllers[index].selection =
                            TextSelection.collapsed(offset: name.length);
                        _clearError();
                      },
                      onChanged: _clearError,
                      onRemove: () {},
                    ),
                    if (offset == 0) const SizedBox(height: 10),
                  ],
                ],
              ),
              if (pairIndex != pairCount - 1) const SizedBox(height: 12),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: nextSize == null ? null : () => _setDeSize(nextSize),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                nextSize == null
                    ? 'Đã đủ ${LeagueEngine.doubleElimSizes.last} người'
                    : 'Thêm lên $nextSize người',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setDeSize(int size) {
    setState(() {
      while (_deControllers.length > size) {
        _deControllers.removeLast().dispose();
      }
      while (_deControllers.length < size) {
        _deControllers.add(
          TextEditingController(
            text: 'Người chơi ${_deControllers.length + 1}',
          ),
        );
      }
      _errorText = null;
    });
  }

  int? _nextDeSize() {
    for (final size in LeagueEngine.doubleElimSizes) {
      if (size > _deControllers.length) return size;
    }
    return null;
  }

  Set<String> _excludedDe(int excludeIndex) {
    return {
      for (var j = 0; j < _deControllers.length; j++)
        if (j != excludeIndex) _deControllers[j].text.trim().toLowerCase(),
    }..removeWhere((n) => n.isEmpty);
  }

  // ────────────────────────── helpers ──────────────────────────

  int _pairCount(int n) => n < 2 ? 0 : n * (n - 1) ~/ 2;

  int _plannedMatchCount() {
    switch (_mode) {
      case _SetupMode.roundRobin:
        return _pairCount(_rrControllers.length);
      case _SetupMode.doubleElim:
        final n = _deControllers.length;
        if (!LeagueEngine.doubleElimSizes.contains(n)) return 0;
        // Double-elim 1 trận chung kết tổng: WB (N-1) + LB (N-2) + GF.
        return 2 * n - 2;
      case _SetupMode.groupKnockout:
        final groupMatches = _groupControllers.fold<int>(
          0,
          (sum, g) => sum + _pairCount(g.length),
        );
        final knockoutPlayers = _groupControllers.length * 2;
        final mainBracket = knockoutPlayers <= 1 ? 0 : knockoutPlayers - 1;
        final hasSemifinals = knockoutPlayers == 4;
        final extraThird = hasSemifinals ? 1 : 0;
        return groupMatches + mainBracket + extraThird;
    }
  }

  String _modeDescription() {
    switch (_mode) {
      case _SetupMode.roundRobin:
        return 'Mỗi người gặp nhau 1 lần. Thắng = +1 điểm.';
      case _SetupMode.groupKnockout:
        return 'Tự chia bảng. Mỗi bảng đấu vòng tròn, top 2 vào knockout '
            '(kèm tranh 3-4).';
      case _SetupMode.doubleElim:
        return 'Đấu nhánh kép: Nhánh thắng + Nhánh thua + Chung kết tổng. '
            'Lượt 1 nhập theo cặp, không random. Thua 2 lần mới bị loại.';
    }
  }

  String _groupLetter(int index) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (index >= 0 && index < letters.length) return letters[index];
    return '${index + 1}';
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.title,
    required this.playerCount,
    required this.canRemoveGroup,
    required this.canAddPlayer,
    required this.onRemoveGroup,
    required this.onAddPlayer,
    required this.children,
  });

  final String title;
  final int playerCount;
  final bool canRemoveGroup;
  final bool canAddPlayer;
  final VoidCallback onRemoveGroup;
  final VoidCallback onAddPlayer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$playerCount người',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSubtle,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Xoá bảng',
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppColors.victim,
                onPressed: canRemoveGroup ? onRemoveGroup : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: canAddPlayer ? onAddPlayer : null,
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('Thêm người vào bảng'),
          ),
        ],
      ),
    );
  }
}

class _DoubleElimPairSection extends StatelessWidget {
  const _DoubleElimPairSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.textDark,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
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
    this.showRemove = true,
    required this.onPick,
    required this.onChanged,
    required this.onRemove,
  });

  final TextEditingController controller;
  final String label;
  final TextInputAction textInputAction;
  final Set<String> excluded;
  final bool canRemove;
  final bool showRemove;
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
        if (showRemove) ...[
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: canRemove ? onRemove : null,
            tooltip: 'Xoá người chơi',
            icon: const Icon(Icons.remove_rounded),
          ),
        ],
      ],
    );
  }
}
