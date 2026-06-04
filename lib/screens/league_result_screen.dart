import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/league_state.dart';
import '../providers/league_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/table_background.dart';
import 'league_standings_view.dart';

/// Màn kết quả cuối giải đấu (status = finished). Hiển thị bảng xếp hạng
/// chung cuộc + nút "Tạo giải mới".
///
/// Mở từ:
/// - LeaguePlayScreen "Kết thúc giải" → `finishTournament` → state.finished
///   → _AppShell route sang đây.
/// - LeagueHistoryScreen tap 1 entry → push trực tiếp với `league` param
///   (đọc từ history, không phụ thuộc LeagueController state).
class LeagueResultScreen extends ConsumerWidget {
  const LeagueResultScreen({super.key, this.league});

  /// Nếu khác null → render giải này (từ history). Null → render
  /// `leagueControllerProvider` state (giải vừa kết thúc).
  final LeagueState? league;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LeagueState state =
        league ?? ref.watch(leagueControllerProvider);
    final theme = Theme.of(context);
    final isFromHistory = league != null;

    // Khi mở từ history mà entry hỏng (data lạ) — vẫn render AppBar có back
    // để user thoát; không trả `SizedBox.shrink` (sẽ tạo trang trắng kẹt).
    if (state.status != LeagueStatus.finished || state.players.isEmpty) {
      if (isFromHistory) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Giải đấu'),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Dữ liệu giải này không hợp lệ.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSubtle,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final champion = state.players.first;
    // Không trao "vô địch" nếu chưa đấu trận nào — champion sẽ là người
    // alphabet đầu tiên với 0 điểm, gây hiểu nhầm.
    final showChampion = state.matchesPlayed > 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: isFromHistory
          ? AppBar(
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                'Giải đấu · ${_formatDate(state.finishedAt)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            )
          : null,
      body: TableBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isFromHistory) ...[
                  Text(
                    'Kết quả giải',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Giải đã chốt và lưu vào lịch sử.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textBody,
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                if (showChampion) ...[
                  _ChampionCard(name: champion.name, points: champion.points),
                  const SizedBox(height: 14),
                ],
                _StatsCard(state: state),
                const SizedBox(height: 14),
                LeagueStandingsView(
                  players: state.players,
                  highlightChampion: showChampion,
                ),
                const SizedBox(height: 20),
                if (!isFromHistory)
                  FilledButton.icon(
                    onPressed: () => ref
                        .read(leagueControllerProvider.notifier)
                        .resetTournament(),
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Tạo giải mới'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? at) {
    if (at == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)}/${at.year} '
        '${two(at.hour)}:${two(at.minute)}';
  }
}

class _ChampionCard extends StatelessWidget {
  const _ChampionCard({required this.name, required this.points});

  final String name;
  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.textDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          const Text(
            'Vô địch',
            style: TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$points điểm',
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.state});

  final LeagueState state;

  @override
  Widget build(BuildContext context) {
    final unfinished = state.matchesTotal - state.matchesPlayed;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          _Chip(label: 'Số người: ${state.players.length}'),
          _Chip(label: 'Số trận: ${state.matchesPlayed}/${state.matchesTotal}'),
          if (unfinished > 0)
            _Chip(
              label: '$unfinished trận chưa đấu',
              color: AppColors.victim.withAlpha(40),
              textColor: AppColors.victim,
            ),
          if (state.finishedAt != null)
            _Chip(
              label: _formatDate(state.finishedAt!),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)}/${at.year} '
        '${two(at.hour)}:${two(at.minute)}';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.color, this.textColor});
  final String label;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? AppColors.primary.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor ?? AppColors.primaryDark,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
