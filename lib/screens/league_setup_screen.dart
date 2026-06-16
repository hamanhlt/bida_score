import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/league_engine.dart';
import '../providers/game_controller.dart';
import '../providers/league_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/draw_wheel.dart';
import '../widgets/name_history_button.dart';
import '../widgets/table_background.dart';

enum _SetupMode { roundRobin, groupKnockout, doubleElim }

enum _GroupInputMode { manual, draw }

enum _DoubleElimInputMode { manual, draw }

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
  final Random _drawRng = Random();
  final TextEditingController _nameController = TextEditingController(
    text: 'Giải đấu mới',
  );

  // Round-robin: flat list 3..16 người.
  final List<TextEditingController> _rrControllers = [];

  // Vòng bảng: nested list. Default 2 bảng × 4 người (8 total).
  final List<List<TextEditingController>> _groupControllers = [];
  final List<TextEditingController> _groupSeedControllers = [];
  final List<TextEditingController> _groupDrawPoolControllers = [];
  List<List<String>> _groupDrawAssignments = [];
  int _groupDrawGroupCount = 4;
  int _groupDrawSize = 4;
  int _groupDrawPlayerCount = 16;
  // Vòng quay bốc thăm (popup): bảng + tên sẽ gán cho lần quay hiện tại.
  int? _pendingGroupTarget;
  String? _pendingGroupName;

  // Đấu nhánh kép: flat list theo cặp lượt 1, N phải là 8/16/32.
  final List<TextEditingController> _deControllers = [];
  final List<TextEditingController> _deSeedControllers = [];
  final List<TextEditingController> _deDrawPoolControllers = [];
  List<String?> _deDrawOpponents = [];
  int? _pendingDePair;
  String? _pendingDeName;

  String? _errorText;
  _SetupMode _mode = _SetupMode.roundRobin;
  _GroupInputMode _groupInputMode = _GroupInputMode.manual;
  _DoubleElimInputMode _deInputMode = _DoubleElimInputMode.manual;

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
    _syncGroupDrawControllers();
    // Đấu nhánh defaults: 8 người (power of 2 phổ biến).
    for (var i = 0; i < 8; i++) {
      _deControllers.add(TextEditingController(text: 'Người chơi ${i + 1}'));
    }
    _syncDeDrawControllers();
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
    for (final c in _groupSeedControllers) {
      c.dispose();
    }
    for (final c in _groupDrawPoolControllers) {
      c.dispose();
    }
    for (final c in _deControllers) {
      c.dispose();
    }
    for (final c in _deSeedControllers) {
      c.dispose();
    }
    for (final c in _deDrawPoolControllers) {
      c.dispose();
    }
    super.dispose();
  }

  int get _groupTotalPlayers =>
      _groupControllers.fold<int>(0, (sum, g) => sum + g.length);

  int get _groupDrawCapacity => _groupDrawGroupCount * _groupDrawSize;
  int get _groupDrawMinPlayers => _groupDrawGroupCount * _minGroupSize;
  int get _groupDrawMaxPlayers => min(_maxPlayers, _groupDrawCapacity);
  int get _groupDrawTotalPlayers => _groupDrawPlayerCount;
  int get _groupDrawPoolCount =>
      max(0, _groupDrawPlayerCount - _groupDrawGroupCount);
  List<int> get _groupDrawTargetSizes {
    final baseSize = _groupDrawPlayerCount ~/ _groupDrawGroupCount;
    final extra = _groupDrawPlayerCount % _groupDrawGroupCount;
    return [
      for (var i = 0; i < _groupDrawGroupCount; i++)
        min(_groupDrawSize, baseSize + (i < extra ? 1 : 0)),
    ];
  }

  bool get _groupDrawComplete =>
      _groupDrawAssignments.length == _groupDrawGroupCount &&
      _groupDrawAssignments.asMap().entries.every(
        (entry) => entry.value.length >= _groupDrawTargetSizes[entry.key] - 1,
      );

  int get _dePairCount => _deControllers.length ~/ 2;
  bool get _deDrawComplete =>
      _deDrawOpponents.length == _dePairCount &&
      _deDrawOpponents.every((name) => name != null && name.trim().isNotEmpty);

  void _resizeControllers(
    List<TextEditingController> controllers,
    int targetLength,
    String Function(int index) defaultText,
  ) {
    while (controllers.length > targetLength) {
      controllers.removeLast().dispose();
    }
    while (controllers.length < targetLength) {
      controllers.add(
        TextEditingController(text: defaultText(controllers.length)),
      );
    }
  }

  void _syncGroupDrawControllers() {
    _normalizeGroupDrawPlayerCount();
    _resizeControllers(
      _groupSeedControllers,
      _groupDrawGroupCount,
      (i) => 'Hạt giống ${i + 1}',
    );
    _resizeControllers(
      _groupDrawPoolControllers,
      _groupDrawPoolCount,
      (i) => 'Người chơi ${_groupDrawGroupCount + i + 1}',
    );
    _normalizeGeneratedPlayerNames(
      _groupDrawPoolControllers,
      startNumber: _groupDrawGroupCount + 1,
      reservedControllers: _groupSeedControllers,
    );
    _resetGroupDrawResult();
  }

  void _normalizeGroupDrawPlayerCount() {
    final minPlayers = _groupDrawMinPlayers;
    final maxPlayers = _groupDrawMaxPlayers;
    _groupDrawPlayerCount = _groupDrawPlayerCount
        .clamp(minPlayers, maxPlayers)
        .toInt();
  }

  void _normalizeGeneratedPlayerNames(
    List<TextEditingController> controllers, {
    required int startNumber,
    Iterable<TextEditingController> reservedControllers = const [],
  }) {
    final generatedName = RegExp(r'^Người chơi \d+$');
    final used = <String>{
      for (final c in reservedControllers)
        if (c.text.trim().isNotEmpty) c.text.trim().toLowerCase(),
      for (final c in controllers)
        if (!generatedName.hasMatch(c.text.trim()) && c.text.trim().isNotEmpty)
          c.text.trim().toLowerCase(),
    };
    var nextNumber = startNumber;
    for (final c in controllers) {
      final text = c.text.trim();
      if (text.isNotEmpty && !generatedName.hasMatch(text)) continue;
      var nextName = 'Người chơi $nextNumber';
      while (used.contains(nextName.toLowerCase())) {
        nextNumber++;
        nextName = 'Người chơi $nextNumber';
      }
      c.text = nextName;
      c.selection = TextSelection.collapsed(offset: nextName.length);
      used.add(nextName.toLowerCase());
      nextNumber++;
    }
  }

  void _resetGroupDrawResult() {
    _groupDrawAssignments = [
      for (var i = 0; i < _groupDrawGroupCount; i++) <String>[],
    ];
    _pendingGroupTarget = null;
    _pendingGroupName = null;
  }

  void _syncDeDrawControllers() {
    _resizeControllers(
      _deSeedControllers,
      _dePairCount,
      (i) => 'Hạt giống ${i + 1}',
    );
    _resizeControllers(
      _deDrawPoolControllers,
      _dePairCount,
      (i) => 'Người chơi ${_dePairCount + i + 1}',
    );
    _resetDeDrawResult();
  }

  void _resetDeDrawResult() {
    _deDrawOpponents = List<String?>.filled(_dePairCount, null);
    _pendingDePair = null;
    _pendingDeName = null;
  }

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

  Set<String> _excludedGroupDrawSeed(int excludeIndex) {
    return _excludedFromControllers([
      ..._groupSeedControllers
          .asMap()
          .entries
          .where((e) => e.key != excludeIndex)
          .map((e) => e.value),
      ..._groupDrawPoolControllers,
    ]);
  }

  Set<String> _excludedGroupDrawPool(int excludeIndex) {
    return _excludedFromControllers([
      ..._groupSeedControllers,
      ..._groupDrawPoolControllers
          .asMap()
          .entries
          .where((e) => e.key != excludeIndex)
          .map((e) => e.value),
    ]);
  }

  Set<String> _excludedDeDrawSeed(int excludeIndex) {
    return _excludedFromControllers([
      ..._deSeedControllers
          .asMap()
          .entries
          .where((e) => e.key != excludeIndex)
          .map((e) => e.value),
      ..._deDrawPoolControllers,
    ]);
  }

  Set<String> _excludedDeDrawPool(int excludeIndex) {
    return _excludedFromControllers([
      ..._deSeedControllers,
      ..._deDrawPoolControllers
          .asMap()
          .entries
          .where((e) => e.key != excludeIndex)
          .map((e) => e.value),
    ]);
  }

  Set<String> _excludedFromControllers(
    Iterable<TextEditingController> controllers,
  ) {
    return {for (final c in controllers) c.text.trim().toLowerCase()}
      ..removeWhere((n) => n.isEmpty);
  }

  void _clearError() {
    if (_errorText != null) setState(() => _errorText = null);
  }

  void _clearGroupDrawAndError() {
    setState(() {
      _resetGroupDrawResult();
      _errorText = null;
    });
  }

  void _clearDeDrawAndError() {
    setState(() {
      _resetDeDrawResult();
      _errorText = null;
    });
  }

  String? _validateUniqueNames(List<String> names) {
    if (names.any((n) => n.trim().isEmpty)) {
      return 'Mỗi người chơi cần có tên.';
    }
    final lower = names.map((n) => n.trim().toLowerCase()).toSet();
    if (lower.length != names.length) {
      return 'Tên người chơi phải khác nhau.';
    }
    return null;
  }

  String? _validateGroupDrawInputs() {
    if (_groupDrawTotalPlayers < _groupDrawMinPlayers) {
      return 'Mỗi bảng cần ít nhất $_minGroupSize người.';
    }
    if (_groupDrawTotalPlayers > _groupDrawMaxPlayers) {
      return 'Bốc thăm vòng bảng hỗ trợ tối đa $_maxPlayers người.';
    }
    final names = [
      ..._groupSeedControllers.map((c) => c.text.trim()),
      ..._groupDrawPoolControllers.map((c) => c.text.trim()),
    ];
    return _validateUniqueNames(names);
  }

  String? _validateDeDrawInputs() {
    final names = [
      ..._deSeedControllers.map((c) => c.text.trim()),
      ..._deDrawPoolControllers.map((c) => c.text.trim()),
    ];
    return _validateUniqueNames(names);
  }

  /// Bảng kế tiếp cần bốc thêm người (ít người nhất, tie → index nhỏ).
  int? _nextGroupToFill() {
    final targets = _groupDrawTargetSizes;
    int? best;
    var bestDrawn = 1 << 30;
    for (var i = 0; i < _groupDrawGroupCount; i++) {
      final drawn = _groupDrawAssignments[i].length;
      if (drawn >= targets[i] - 1) continue; // đã đủ (trừ hạt giống)
      if (drawn < bestDrawn) {
        best = i;
        bestDrawn = drawn;
      }
    }
    return best;
  }

  /// Người chờ bốc CHƯA được gán — wheel chỉ hiện những người này.
  List<String> _groupRemainingPool() {
    final assigned = _groupDrawAssignments.expand((g) => g).toSet();
    return [
      for (final c in _groupDrawPoolControllers)
        if (!assigned.contains(c.text.trim())) c.text.trim(),
    ];
  }

  /// Chọn ngẫu nhiên 1 vị trí trong [_groupRemainingPool] để wheel dừng,
  /// ghi nhớ bảng + tên sẽ gán. Trả null nếu không còn gì để bốc.
  int? _planGroupDraw() {
    if (_groupDrawComplete) return null;
    final group = _nextGroupToFill();
    if (group == null) return null;
    final remaining = _groupRemainingPool();
    if (remaining.isEmpty) return null;
    final pos = _drawRng.nextInt(remaining.length);
    _pendingGroupTarget = group;
    _pendingGroupName = remaining[pos];
    return pos;
  }

  void _commitGroupDraw() {
    final group = _pendingGroupTarget;
    final name = _pendingGroupName;
    if (group == null || name == null) return;
    _groupDrawAssignments[group].add(name);
    _pendingGroupTarget = null;
    _pendingGroupName = null;
  }

  List<String> _deRemainingPool() {
    final assigned = _deDrawOpponents
        .whereType<String>()
        .map((s) => s.trim())
        .toSet();
    return [
      for (final c in _deDrawPoolControllers)
        if (!assigned.contains(c.text.trim())) c.text.trim(),
    ];
  }

  int? _planDeDraw() {
    if (_deDrawComplete) return null;
    final pair = _deDrawOpponents.indexWhere(
      (o) => o == null || o.trim().isEmpty,
    );
    if (pair < 0) return null;
    final remaining = _deRemainingPool();
    if (remaining.isEmpty) return null;
    final pos = _drawRng.nextInt(remaining.length);
    _pendingDePair = pair;
    _pendingDeName = remaining[pos];
    return pos;
  }

  void _commitDeDraw() {
    final pair = _pendingDePair;
    final name = _pendingDeName;
    if (pair == null || name == null) return;
    _deDrawOpponents[pair] = name;
    _pendingDePair = null;
    _pendingDeName = null;
  }

  Future<void> _openGroupDrawWheel() async {
    final error = _validateGroupDrawInputs();
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    setState(() => _errorText = null);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DrawWheelDialog(
        title: 'Bốc thăm chia bảng',
        remainingPool: _groupRemainingPool,
        isComplete: () => _groupDrawComplete,
        nextTargetLabel: () {
          final g = _nextGroupToFill();
          return g == null ? null : 'Bảng ${_groupLetter(g)}';
        },
        plan: _planGroupDraw,
        commit: _commitGroupDraw,
      ),
    );
    setState(() {}); // refresh result cards ngoài popup
  }

  Future<void> _openDeDrawWheel() async {
    final error = _validateDeDrawInputs();
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    setState(() => _errorText = null);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DrawWheelDialog(
        title: 'Bốc thăm đối thủ',
        remainingPool: _deRemainingPool,
        isComplete: () => _deDrawComplete,
        nextTargetLabel: () {
          final p = _deDrawOpponents.indexWhere(
            (o) => o == null || o.trim().isEmpty,
          );
          return p < 0 ? null : 'Cặp ${p + 1}';
        },
        plan: _planDeDraw,
        commit: _commitDeDraw,
      ),
    );
    setState(() {});
  }

  List<List<String>> _drawnGroups() {
    final targetSizes = _groupDrawTargetSizes;
    return [
      for (var i = 0; i < _groupDrawGroupCount; i++)
        [
          _groupSeedControllers[i].text.trim(),
          ..._groupDrawAssignments[i].take(targetSizes[i] - 1),
        ],
    ];
  }

  List<String> _drawnDoubleElimNames() {
    return [
      for (var i = 0; i < _dePairCount; i++) ...[
        _deSeedControllers[i].text.trim(),
        _deDrawOpponents[i]!.trim(),
      ],
    ];
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
      if (_deInputMode == _DoubleElimInputMode.draw) {
        final error = _validateDeDrawInputs();
        if (error != null) {
          setState(() => _errorText = error);
          return;
        }
        if (!_deDrawComplete) {
          setState(() => _errorText = 'Cần quay đủ đối thủ cho các hạt giống.');
          return;
        }
      }
      final names = _deInputMode == _DoubleElimInputMode.draw
          ? _drawnDoubleElimNames()
          : _deControllers.map((c) => c.text.trim()).toList();
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

    // Vòng bảng — chia bảng bằng tay hoặc bốc thăm từ hạt giống.
    if (_groupInputMode == _GroupInputMode.draw) {
      final error = _validateGroupDrawInputs();
      if (error != null) {
        setState(() => _errorText = error);
        return;
      }
      if (!_groupDrawComplete) {
        setState(() => _errorText = 'Cần quay đủ các lượt chia bảng.');
        return;
      }
    }
    final manualGroups = _groupInputMode == _GroupInputMode.draw
        ? _drawnGroups()
        : _groupControllers
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
                              labelPadding: EdgeInsets.zero,
                              tabs: [
                                _ModeTab(
                                  label: 'Đấu vòng tròn',
                                  assetPath: 'assets/dau_vong_tron.png',
                                ),
                                _ModeTab(
                                  label: 'Đấu bảng',
                                  assetPath: 'assets/dau_bang.png',
                                ),
                                _ModeTab(
                                  label: 'Đấu nhánh\nthắng - thua',
                                  assetPath: 'assets/dau_nhanh_thang_thua.png',
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
    final displayTotal = _groupInputMode == _GroupInputMode.draw
        ? _groupDrawTotalPlayers
        : total;
    final displayGroupCount = _groupInputMode == _GroupInputMode.draw
        ? _groupDrawGroupCount
        : _groupControllers.length;
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
                  '$displayTotal/$_maxPlayers người · '
                  '$displayGroupCount/$_maxGroups bảng',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSubtle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InputModeChips<_GroupInputMode>(
              value: _groupInputMode,
              options: const [
                _InputModeOption(
                  value: _GroupInputMode.manual,
                  label: 'Nhập tay',
                ),
                _InputModeOption(
                  value: _GroupInputMode.draw,
                  label: 'Bốc thăm',
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _groupInputMode = value;
                  _errorText = null;
                });
              },
            ),
            const SizedBox(height: 14),
            if (_groupInputMode == _GroupInputMode.manual) ...[
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
                    for (
                      var pi = 0;
                      pi < _groupControllers[gi].length;
                      pi++
                    ) ...[
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
            ] else
              _buildGroupDrawSetup(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupDrawSetup(ThemeData theme) {
    final groupOptions = [
      for (var count = _minGroups; count <= _maxGroups; count++)
        if (count * _groupDrawSize <= _maxPlayers) count,
    ];
    final sizeOptions = [
      for (final size in LeagueEngine.groupSizeOptions)
        if (size * _groupDrawGroupCount <= _maxPlayers) size,
    ];
    final playerCountOptions = [
      for (
        var count = _groupDrawMinPlayers;
        count <= _groupDrawMaxPlayers;
        count++
      )
        count,
    ];
    final targetSizes = _groupDrawTargetSizes;
    final canReset = _groupDrawAssignments.any((g) => g.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nhập hạt giống trước, sau đó quay từng lượt để chia người còn lại.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSubtle,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _DrawConfigBlock(
          title: 'Số bảng',
          children: [
            for (final count in groupOptions)
              ChoiceChip(
                label: Text('$count bảng'),
                selected: _groupDrawGroupCount == count,
                onSelected: (_) {
                  setState(() {
                    _groupDrawGroupCount = count;
                    _syncGroupDrawControllers();
                    _errorText = null;
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        _DrawConfigBlock(
          title: 'Tối đa mỗi bảng',
          children: [
            for (final size in sizeOptions)
              ChoiceChip(
                label: Text('$size người'),
                selected: _groupDrawSize == size,
                onSelected: (_) {
                  setState(() {
                    _groupDrawSize = size;
                    final maxGroupsForSize = _maxPlayers ~/ size;
                    if (_groupDrawGroupCount > maxGroupsForSize) {
                      _groupDrawGroupCount = max(_minGroups, maxGroupsForSize);
                    }
                    _syncGroupDrawControllers();
                    _errorText = null;
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        _DrawConfigBlock(
          title: 'Tổng số người',
          children: [
            for (final count in playerCountOptions)
              ChoiceChip(
                label: Text('$count người'),
                selected: _groupDrawPlayerCount == count,
                onSelected: (_) {
                  setState(() {
                    _groupDrawPlayerCount = count;
                    _syncGroupDrawControllers();
                    _errorText = null;
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < targetSizes.length; i++)
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(
                  'Bảng ${_groupLetter(i)}: ${targetSizes[i]}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                backgroundColor: AppColors.primary.withAlpha(12),
                side: const BorderSide(color: AppColors.border),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const _SectionBadgeTitle('Hạt giống'),
        const SizedBox(height: 10),
        for (var i = 0; i < _groupSeedControllers.length; i++) ...[
          _PlayerNameRow(
            controller: _groupSeedControllers[i],
            label: 'Hạt giống bảng ${_groupLetter(i)}',
            textInputAction: TextInputAction.next,
            excluded: _excludedGroupDrawSeed(i),
            canRemove: false,
            showRemove: false,
            onPick: (name) {
              _groupSeedControllers[i].text = name;
              _groupSeedControllers[i].selection = TextSelection.collapsed(
                offset: name.length,
              );
              _clearGroupDrawAndError();
            },
            onChanged: _clearGroupDrawAndError,
            onRemove: () {},
          ),
          if (i != _groupSeedControllers.length - 1) const SizedBox(height: 10),
        ],
        const SizedBox(height: 14),
        const _SectionBadgeTitle('Danh sách bốc thăm'),
        const SizedBox(height: 10),
        for (var i = 0; i < _groupDrawPoolControllers.length; i++) ...[
          _PlayerNameRow(
            controller: _groupDrawPoolControllers[i],
            label: 'Người chờ bốc ${i + 1}',
            textInputAction: i == _groupDrawPoolControllers.length - 1
                ? TextInputAction.done
                : TextInputAction.next,
            excluded: _excludedGroupDrawPool(i),
            canRemove: false,
            showRemove: false,
            onPick: (name) {
              _groupDrawPoolControllers[i].text = name;
              _groupDrawPoolControllers[i].selection = TextSelection.collapsed(
                offset: name.length,
              );
              _clearGroupDrawAndError();
            },
            onChanged: _clearGroupDrawAndError,
            onRemove: () {},
          ),
          if (i != _groupDrawPoolControllers.length - 1)
            const SizedBox(height: 10),
        ],
        const SizedBox(height: 16),
        _DrawLaunchRow(
          complete: _groupDrawComplete,
          canReset: canReset,
          onOpen: _openGroupDrawWheel,
          onReset: () {
            setState(() {
              _resetGroupDrawResult();
              _errorText = null;
            });
          },
        ),
        const SizedBox(height: 14),
        _DrawWheelGrid(
          children: [
            for (var i = 0; i < _groupDrawGroupCount; i++)
              _DrawResultCard(
                title: 'Bảng ${_groupLetter(i)}',
                seed: _groupSeedControllers[i].text.trim(),
                drawnNames: _groupDrawAssignments[i],
                totalSlots: targetSizes[i],
              ),
          ],
        ),
      ],
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
              _deInputMode == _DoubleElimInputMode.manual
                  ? 'Nhập đúng từng cặp mở màn. App giữ nguyên thứ tự này.'
                  : 'Nhập hạt giống từng cặp, sau đó quay để bốc đối thủ.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isValidSize
                    ? AppColors.textSubtle
                    : theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _InputModeChips<_DoubleElimInputMode>(
              value: _deInputMode,
              options: const [
                _InputModeOption(
                  value: _DoubleElimInputMode.manual,
                  label: 'Nhập cặp',
                ),
                _InputModeOption(
                  value: _DoubleElimInputMode.draw,
                  label: 'Bốc thăm',
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _deInputMode = value;
                  _errorText = null;
                });
              },
            ),
            const SizedBox(height: 12),
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
            if (_deInputMode == _DoubleElimInputMode.manual) ...[
              for (var pairIndex = 0; pairIndex < pairCount; pairIndex++) ...[
                _DoubleElimPairSection(
                  title: 'Cặp đấu ${pairIndex + 1}',
                  children: [
                    for (var offset = 0; offset < 2; offset++) ...[
                      _PlayerNameRow(
                        controller: _deControllers[pairIndex * 2 + offset],
                        label: 'Cơ thủ ${offset + 1}',
                        textInputAction:
                            pairIndex == pairCount - 1 && offset == 1
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
            ] else
              _buildDoubleElimDrawSetup(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildDoubleElimDrawSetup(ThemeData theme) {
    final canReset = _deDrawOpponents.any((name) => name != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mỗi hạt giống giữ một cặp mở màn. Quay xong app sẽ ghép đối thủ '
          'theo thứ tự các cặp.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSubtle,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        const _SectionBadgeTitle('Hạt giống'),
        const SizedBox(height: 10),
        for (var i = 0; i < _deSeedControllers.length; i++) ...[
          _PlayerNameRow(
            controller: _deSeedControllers[i],
            label: 'Hạt giống cặp ${i + 1}',
            textInputAction: TextInputAction.next,
            excluded: _excludedDeDrawSeed(i),
            canRemove: false,
            showRemove: false,
            onPick: (name) {
              _deSeedControllers[i].text = name;
              _deSeedControllers[i].selection = TextSelection.collapsed(
                offset: name.length,
              );
              _clearDeDrawAndError();
            },
            onChanged: _clearDeDrawAndError,
            onRemove: () {},
          ),
          if (i != _deSeedControllers.length - 1) const SizedBox(height: 10),
        ],
        const SizedBox(height: 14),
        const _SectionBadgeTitle('Danh sách bốc thăm'),
        const SizedBox(height: 10),
        for (var i = 0; i < _deDrawPoolControllers.length; i++) ...[
          _PlayerNameRow(
            controller: _deDrawPoolControllers[i],
            label: 'Người chờ bốc ${i + 1}',
            textInputAction: i == _deDrawPoolControllers.length - 1
                ? TextInputAction.done
                : TextInputAction.next,
            excluded: _excludedDeDrawPool(i),
            canRemove: false,
            showRemove: false,
            onPick: (name) {
              _deDrawPoolControllers[i].text = name;
              _deDrawPoolControllers[i].selection = TextSelection.collapsed(
                offset: name.length,
              );
              _clearDeDrawAndError();
            },
            onChanged: _clearDeDrawAndError,
            onRemove: () {},
          ),
          if (i != _deDrawPoolControllers.length - 1)
            const SizedBox(height: 10),
        ],
        const SizedBox(height: 16),
        _DrawLaunchRow(
          complete: _deDrawComplete,
          canReset: canReset,
          onOpen: _openDeDrawWheel,
          onReset: () {
            setState(() {
              _resetDeDrawResult();
              _errorText = null;
            });
          },
        ),
        const SizedBox(height: 14),
        _DrawWheelGrid(
          children: [
            for (var i = 0; i < _dePairCount; i++)
              _DrawResultCard(
                title: 'Cặp ${i + 1}',
                seed: _deSeedControllers[i].text.trim(),
                drawnNames: [
                  if (_deDrawOpponents.length > i &&
                      _deDrawOpponents[i] != null)
                    _deDrawOpponents[i]!,
                ],
                totalSlots: 2,
              ),
          ],
        ),
      ],
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
      _syncDeDrawControllers();
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
        final groupSizes = _groupInputMode == _GroupInputMode.draw
            ? _groupDrawTargetSizes
            : [for (final g in _groupControllers) g.length];
        final groupMatches = groupSizes.fold<int>(
          0,
          (sum, size) => sum + _pairCount(size),
        );
        final knockoutPlayers = groupSizes.length * 2;
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
        return 'Tự chia bảng hoặc bốc thăm hạt giống. Mỗi bảng đấu vòng tròn, '
            'top 2 vào knockout (kèm tranh 3-4).';
      case _SetupMode.doubleElim:
        return 'Đấu nhánh kép: Nhánh thắng + Nhánh thua + Chung kết tổng. '
            'Lượt 1 nhập theo cặp hoặc bốc thăm hạt giống.';
    }
  }

  String _groupLetter(int index) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (index >= 0 && index < letters.length) return letters[index];
    return '${index + 1}';
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.label, required this.assetPath});

  final String label;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 38,
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.category_rounded, size: 30),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputModeOption<T> {
  const _InputModeOption({required this.value, required this.label});

  final T value;
  final String label;
}

class _InputModeChips<T> extends StatelessWidget {
  const _InputModeChips({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<_InputModeOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option.label),
            selected: option.value == value,
            onSelected: (_) => onChanged(option.value),
          ),
      ],
    );
  }
}

class _DrawConfigBlock extends StatelessWidget {
  const _DrawConfigBlock({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionBadgeTitle(title),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _SectionBadgeTitle extends StatelessWidget {
  const _SectionBadgeTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(145),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withAlpha(70)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textDark,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _DrawWheelGrid extends StatelessWidget {
  const _DrawWheelGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: children,
    );
  }
}

/// Hàng nút mở vòng quay (popup) + reset. Hiện ở màn Setup; vòng quay
/// thật nằm trong [_DrawWheelDialog] fullscreen.
class _DrawLaunchRow extends StatelessWidget {
  const _DrawLaunchRow({
    required this.complete,
    required this.canReset,
    required this.onOpen,
    required this.onReset,
  });

  final bool complete;
  final bool canReset;
  final VoidCallback onOpen;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.casino_rounded),
            label: Text(complete ? 'Xem / quay lại vòng quay' : 'Mở vòng quay'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (canReset) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Quay lại từ đầu'),
          ),
        ],
      ],
    );
  }
}

/// Popup fullscreen chứa vòng quay lớn. Mỗi lần bấm Quay → wheel xoay →
/// dừng 1 người → [commit] gán vào slot, người đó biến mất khỏi vòng.
/// Dialog tự rebuild qua setState; data thật nằm ở State cha (mutate trực
/// tiếp qua [plan]/[commit]).
class _DrawWheelDialog extends StatefulWidget {
  const _DrawWheelDialog({
    required this.title,
    required this.remainingPool,
    required this.isComplete,
    required this.nextTargetLabel,
    required this.plan,
    required this.commit,
  });

  final String title;
  final List<String> Function() remainingPool;
  final bool Function() isComplete;
  final String? Function() nextTargetLabel;

  /// Trả về vị trí (trong remainingPool hiện tại) wheel sẽ dừng, hoặc null.
  final int? Function() plan;
  final VoidCallback commit;

  @override
  State<_DrawWheelDialog> createState() => _DrawWheelDialogState();
}

class _DrawWheelDialogState extends State<_DrawWheelDialog> {
  int _nonce = 0;
  int _target = 0;
  bool _spinning = false;
  String? _lastPicked;

  void _spin() {
    if (_spinning) return;
    final pos = widget.plan();
    if (pos == null) return;
    setState(() {
      _target = pos;
      _nonce++;
      _spinning = true;
    });
  }

  void _onEnd() {
    final names = widget.remainingPool();
    final picked = (_target >= 0 && _target < names.length)
        ? names[_target]
        : null;
    widget.commit();
    setState(() {
      _spinning = false;
      _lastPicked = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final names = widget.remainingPool();
    final complete = widget.isComplete();
    final nextLabel = widget.nextTargetLabel();
    final media = MediaQuery.sizeOf(context);
    final wheelSize = (min(media.width, media.height) - 48).clamp(220.0, 460.0);

    return Dialog.fullscreen(
      backgroundColor: AppColors.scaffoldBg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DrawWheel(
                        names: names,
                        spinNonce: _nonce,
                        targetIndex: _target,
                        onSpinEnd: _onEnd,
                        size: wheelSize,
                      ),
                      const SizedBox(height: 12),
                      if (complete)
                        const Text(
                          '✓ Đã bốc đủ',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        )
                      else if (_spinning && nextLabel != null)
                        Text(
                          'Đang quay cho $nextLabel…',
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        )
                      else if (_lastPicked != null)
                        Text(
                          '🎯 $_lastPicked',
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        )
                      else if (nextLabel != null)
                        Text(
                          'Tiếp theo: $nextLabel',
                          style: const TextStyle(
                            color: AppColors.textSubtle,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_spinning || complete) ? null : _spin,
                  icon: const Icon(Icons.casino_rounded),
                  label: Text(
                    complete
                        ? 'Đã bốc đủ — Đóng'
                        : _spinning
                        ? 'Đang quay…'
                        : 'QUAY',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textDark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card kết quả 1 bảng/cặp sau khi quay — title + đếm + danh sách tên
/// (hạt giống đứng đầu). Không còn vòng tròn xoay (đã có DrawWheel lớn).
class _DrawResultCard extends StatelessWidget {
  const _DrawResultCard({
    required this.title,
    required this.seed,
    required this.drawnNames,
    required this.totalSlots,
  });

  final String title;
  final String seed;
  final List<String> drawnNames;
  final int totalSlots;

  @override
  Widget build(BuildContext context) {
    final names = [
      if (seed.trim().isNotEmpty) seed.trim(),
      ...drawnNames.where((n) => n.trim().isNotEmpty),
    ];

    return SizedBox(
      width: 154,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${names.length}/$totalSlots người',
              style: const TextStyle(
                color: AppColors.textSubtle,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < names.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == names.length - 1 ? 0 : 3),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == 0
                            ? AppColors.accent.withAlpha(80)
                            : AppColors.primary.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        names[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: i == 0
                              ? AppColors.textDark
                              : AppColors.textBody,
                          fontWeight: i == 0
                              ? FontWeight.w900
                              : FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
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
