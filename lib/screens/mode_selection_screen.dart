import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/game_mode.dart';
import '../providers/cover_image_controller.dart';
import '../providers/game_controller.dart';
import '../providers/league_history_controller.dart';
import '../providers/match_history_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/ball_icon.dart';
import '../widgets/table_background.dart';
import 'match_history_screen.dart';

class ModeSelectionScreen extends ConsumerWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final customCover = ref.watch(coverImageProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TableBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero banner — brand moment đầu phiên. Nhấn giữ để đổi ảnh.
                GestureDetector(
                  onLongPress: () => _showCoverSheet(context, ref),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(50),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AspectRatio(
                        aspectRatio: 3 / 2,
                        child: customCover != null
                            ? Image.memory(
                                customCover,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              )
                            : Image.asset(
                                'assets/banner.jpg',
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Thể thức thi đấu', style: theme.textTheme.titleLarge),
                const SizedBox(height: 14),
                for (final mode in GameMode.values) ...[
                  _ModeCard(
                    mode: mode,
                    onTap: () {
                      ref
                          .read(gameControllerProvider.notifier)
                          .selectMode(mode);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 20),
                _HistoryEntryCard(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MatchHistoryScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    '© 2026 Bản quyền thuộc về Mạnh Bóng Đêm - TCG',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSubtle,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bottom sheet đổi ảnh bìa: chọn ảnh từ thư viện, hoặc khôi phục mặc định.
  Future<void> _showCoverSheet(BuildContext context, WidgetRef ref) async {
    final hasCustom = ref.read(coverImageProvider) != null;
    final notifier = ref.read(coverImageProvider.notifier);

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Chọn ảnh bìa từ thư viện'),
              onTap: () => Navigator.of(sheetCtx).pop('pick'),
            ),
            if (hasCustom)
              ListTile(
                leading: const Icon(Icons.restore_rounded),
                title: const Text('Khôi phục ảnh mặc định'),
                onTap: () => Navigator.of(sheetCtx).pop('reset'),
              ),
          ],
        ),
      ),
    );

    if (action == 'pick') {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      notifier.set(bytes);
    } else if (action == 'reset') {
      notifier.clearCustom();
    }
  }
}

class _HistoryEntryCard extends ConsumerWidget {
  const _HistoryEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(matchHistoryControllerProvider);
    final leagueHistoryAsync = ref.watch(leagueHistoryControllerProvider);
    final matchCount = historyAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );
    final leagueCount = leagueHistoryAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );
    final count = matchCount + leagueCount;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF2F80ED).withAlpha(32),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(
                    Icons.history_edu_rounded,
                    color: Color(0xFF2F80ED),
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lịch sử trận đấu',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count == 0
                          ? 'Chưa có trận hoặc giải nào được lưu.'
                          : 'Đã lưu $matchCount trận, $leagueCount giải. Nhấn để xem.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode, required this.onTap});

  final GameMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              if (mode.iconBallNumber != null)
                BallIcon(number: mode.iconBallNumber!, size: 52)
              else
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      mode.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mode.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
