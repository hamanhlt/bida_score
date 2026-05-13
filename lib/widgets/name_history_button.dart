import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/game_controller.dart';
import '../theme/app_colors.dart';

/// Nút icon ở cuối field tên người chơi → mở popup menu các tên đã từng dùng
/// ([playerNameHistoryProvider], pool dùng chung cho mọi mode). Tap 1 tên để
/// fill vào field; tap icon × để xoá tên đó khỏi lịch sử.
///
/// - List sort theo thứ tự mới nhập trước (newest-first — `PlayerNameHistoryStorage`
///   luôn prepend).
/// - [excluded] chứa tên (lowercase) đang dùng ở các field khác — bị ẩn khỏi
///   list để tránh chọn trùng.
class NameHistoryButton extends ConsumerWidget {
  const NameHistoryButton({
    super.key,
    required this.onPick,
    required this.excluded,
  });

  final ValueChanged<String> onPick;
  final Set<String> excluded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(playerNameHistoryProvider);
    final filtered = [
      for (final name in history)
        if (!excluded.contains(name.toLowerCase())) name,
    ];
    if (filtered.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      tooltip: 'Tên đã dùng',
      icon: const Icon(
        Icons.history_rounded,
        color: AppColors.textSubtle,
      ),
      onSelected: onPick,
      itemBuilder: (popupContext) => [
        for (final name in filtered)
          PopupMenuItem<String>(
            value: name,
            child: Row(
              children: [
                Expanded(child: Text(name)),
                const SizedBox(width: 8),
                // InkWell ăn tap riêng (gesture arena) → không trigger
                // onSelected của PopupMenuItem cha.
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    Navigator.of(popupContext).pop();
                    ref
                        .read(playerNameHistoryProvider.notifier)
                        .remove(name);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.black45,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
