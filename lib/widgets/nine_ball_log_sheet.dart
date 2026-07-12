import 'package:flutter/material.dart';

import '../models/nine_ball_state.dart';

const _p1Color = Color(0xFF2962E0);
const _p2Color = Color(0xFFD93838);

Color _colorFor(String name, List<String> playerNames) {
  if (playerNames.isNotEmpty && name == playerNames[0]) return _p1Color;
  if (playerNames.length > 1 && name == playerNames[1]) return _p2Color;
  return const Color(0xFF35524A);
}

/// Bottom sheet hiển thị log thao tác +1/−1 của 1 trận Pool (kèm thời gian +
/// tỷ số chạy). Minh bạch khi sửa nhầm để khỏi cãi nhau. Gọi từ game screen.
Future<void> showNineBallLogSheet(
  BuildContext context, {
  required List<String> playerNames,
  required List<NineBallLogEntry> log,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _NineBallLogSheet(playerNames: playerNames, log: log),
  );
}

class _NineBallLogSheet extends StatelessWidget {
  const _NineBallLogSheet({required this.playerNames, required this.log});

  final List<String> playerNames;
  final List<NineBallLogEntry> log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(40),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: Color(0xFF16322C)),
                  const SizedBox(width: 10),
                  Text(
                    'Lịch sử thao tác',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF16322C),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${log.length} lượt',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5F726A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: NineBallLogList(playerNames: playerNames, log: log),
            ),
          ],
        ),
      ),
    );
  }
}

/// List cuộn các dòng log +1/−1 (mới nhất trước). Dùng chung cho bottom sheet
/// trong trận lẫn màn chi tiết lịch sử.
class NineBallLogList extends StatelessWidget {
  const NineBallLogList({
    super.key,
    required this.playerNames,
    required this.log,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
  });

  final List<String> playerNames;
  final List<NineBallLogEntry> log;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (log.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            'Chưa có thao tác nào.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF5F726A),
            ),
          ),
        ),
      );
    }
    // Mới nhất trước.
    final entries = log.reversed.toList(growable: false);
    return ListView.separated(
      padding: padding,
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) => _LogRow(
        entry: entries[i],
        color: _colorFor(entries[i].playerName, playerNames),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry, required this.color});

  final NineBallLogEntry entry;
  final Color color;

  String _time(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPlus = entry.delta >= 0;
    final badgeColor =
        isPlus ? const Color(0xFF2E9E6F) : const Color(0xFFD93838);
    final w1 = entry.winsAfter.isNotEmpty ? entry.winsAfter[0] : 0;
    final w2 = entry.winsAfter.length > 1 ? entry.winsAfter[1] : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Badge +1 / −1.
          Container(
            width: 42,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isPlus ? '+1' : '−1',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Tên + thời gian.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.playerName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _time(entry.at),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5F726A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Tỷ số chạy sau thao tác.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0E7E3)),
            ),
            child: Text(
              '$w1 — $w2',
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0xFF16322C),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
