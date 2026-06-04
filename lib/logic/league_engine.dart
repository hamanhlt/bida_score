import 'dart:math';

import '../models/league_player.dart';
import '../models/league_state.dart';
import '../models/match_fixture.dart';

/// Engine pure functions cho Chế độ giải đấu vòng tròn.
///
/// Input state → output state, throw [ArgumentError] khi validation fail.
/// Không Riverpod, không I/O — testable thuần.
///
/// **Quy tắc xếp hạng** (tie-breaker ưu tiên từ cao xuống thấp):
/// 1. Tổng điểm (Points)
/// 2. Hiệu số điểm (GoalDifference = goalsFor - goalsAgainst)
/// 3. Tổng điểm ghi được (GoalsFor)
///
/// **Quy tắc điểm trận**: Thắng = +1, Hoà = 0, Thua = 0.
class LeagueEngine {
  const LeagueEngine({Random? rng}) : _rng = rng;

  /// Random injection cho deterministic test. Production: null → `Random()`.
  final Random? _rng;

  static const _minPlayers = 3;
  static const _maxPlayers = 16;
  static const _maxScore = 999;

  /// Khởi tạo giải đấu: validate tên, sinh lịch round-robin (mỗi cặp gặp đúng
  /// 1 lần) và shuffle thứ tự. Trả `LeagueState` với `status = inProgress`.
  ///
  /// Throw [ArgumentError] khi:
  /// - Số người chơi < [_minPlayers] hoặc > [_maxPlayers].
  /// - Có tên trùng (case-insensitive sau trim).
  LeagueState startTournament(List<String> rawNames) {
    final names = rawNames
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    if (names.length < _minPlayers) {
      throw ArgumentError('Giải đấu cần ít nhất $_minPlayers người chơi.');
    }
    if (names.length > _maxPlayers) {
      throw ArgumentError(
        'Giải đấu hỗ trợ tối đa $_maxPlayers người chơi.',
      );
    }
    final lower = names.map((n) => n.toLowerCase()).toSet();
    if (lower.length != names.length) {
      throw ArgumentError('Tên người chơi phải khác nhau.');
    }

    final players = <LeaguePlayer>[
      for (var i = 0; i < names.length; i++)
        LeaguePlayer(
          id: 'lp_${i + 1}_${_slug(names[i])}',
          name: names[i],
        ),
    ];

    final fixtures = _generateFixtures(players);

    return LeagueState(
      status: LeagueStatus.inProgress,
      players: _sortByRanking(players),
      fixtures: fixtures,
      startedAt: DateTime.now(),
    );
  }

  /// Cập nhật tỷ số 1 trận. Set `isPlayed = true` ngay cả khi 0-0 (user đã
  /// xác nhận kết quả). Sau đó **recalculate toàn bộ leaderboard từ đầu** —
  /// duyệt lại mọi trận đã đá, tránh lỗi cộng dồn sai khi user edit tỷ số
  /// đã nhập trước đó.
  LeagueState updateScore(
    LeagueState state,
    String fixtureId,
    int score1,
    int score2,
  ) {
    // Validate input TRƯỚC status guard → caller phân biệt được "score xấu"
    // vs "giải đã kết thúc" (giải finished thì noop).
    if (score1 < 0 || score2 < 0) {
      throw ArgumentError('Tỷ số phải ≥ 0.');
    }
    if (score1 > _maxScore || score2 > _maxScore) {
      throw ArgumentError('Tỷ số tối đa $_maxScore.');
    }

    final idx = state.fixtures.indexWhere((f) => f.id == fixtureId);
    if (idx < 0) {
      throw ArgumentError('Không tìm thấy trận $fixtureId.');
    }

    if (state.status != LeagueStatus.inProgress) return state;

    final newFixtures = [...state.fixtures];
    newFixtures[idx] = newFixtures[idx].copyWith(
      score1: score1,
      score2: score2,
      isPlayed: true,
    );

    return _recalculateLeaderboard(
      state.copyWith(fixtures: newFixtures),
    );
  }

  /// Xoá kết quả 1 trận (`isPlayed = false`, score reset 0). Recalculate.
  /// Throw [ArgumentError] nếu fixtureId không tồn tại — contract đồng nhất
  /// với [updateScore].
  LeagueState clearScore(LeagueState state, String fixtureId) {
    final idx = state.fixtures.indexWhere((f) => f.id == fixtureId);
    if (idx < 0) {
      throw ArgumentError('Không tìm thấy trận $fixtureId.');
    }
    if (state.status != LeagueStatus.inProgress) return state;

    final newFixtures = [...state.fixtures];
    newFixtures[idx] = newFixtures[idx].copyWith(
      score1: 0,
      score2: 0,
      isPlayed: false,
    );

    return _recalculateLeaderboard(
      state.copyWith(fixtures: newFixtures),
    );
  }

  /// Chốt giải. Bảng xếp hạng cuối cùng dùng kết quả hiện tại của state
  /// (đã được recalculate sau mỗi updateScore).
  LeagueState finishTournament(LeagueState state) {
    if (state.status != LeagueStatus.inProgress) return state;
    return state.copyWith(
      status: LeagueStatus.finished,
      finishedAt: DateTime.now(),
    );
  }

  LeagueState resetTournament() => LeagueState.initial();

  // ────────────────────────── internals ──────────────────────────

  /// Sinh lịch round-robin: với N người, sinh `N*(N-1)/2` cặp (mỗi cặp duy nhất),
  /// shuffle thứ tự.
  List<MatchFixture> _generateFixtures(List<LeaguePlayer> players) {
    final fixtures = <MatchFixture>[];
    for (var i = 0; i < players.length; i++) {
      for (var j = i + 1; j < players.length; j++) {
        fixtures.add(
          MatchFixture(
            id: 'mf_${fixtures.length + 1}',
            player1Id: players[i].id,
            player2Id: players[j].id,
          ),
        );
      }
    }
    fixtures.shuffle(_rng ?? Random());
    return fixtures;
  }

  /// Tính lại stats từng player + sort theo ranking, **bắt đầu từ 0**.
  /// Duyệt mọi fixture có `isPlayed == true` và cộng dồn.
  LeagueState _recalculateLeaderboard(LeagueState state) {
    // Reset stats về 0, giữ id/name.
    final byId = <String, LeaguePlayer>{
      for (final p in state.players)
        p.id: p.copyWith(
          points: 0,
          matchesPlayed: 0,
          goalsFor: 0,
          goalsAgainst: 0,
        ),
    };

    for (final f in state.fixtures) {
      if (!f.isPlayed) continue;
      final p1 = byId[f.player1Id];
      final p2 = byId[f.player2Id];
      if (p1 == null || p2 == null) continue; // defensive

      final p1Win = f.score1 > f.score2;
      final p2Win = f.score2 > f.score1;

      byId[f.player1Id] = p1.copyWith(
        matchesPlayed: p1.matchesPlayed + 1,
        goalsFor: p1.goalsFor + f.score1,
        goalsAgainst: p1.goalsAgainst + f.score2,
        points: p1.points + (p1Win ? 1 : 0),
      );
      byId[f.player2Id] = p2.copyWith(
        matchesPlayed: p2.matchesPlayed + 1,
        goalsFor: p2.goalsFor + f.score2,
        goalsAgainst: p2.goalsAgainst + f.score1,
        points: p2.points + (p2Win ? 1 : 0),
      );
    }

    final ranked = _sortByRanking(byId.values.toList());
    return state.copyWith(players: ranked);
  }

  /// Sort by ranking: Points DESC → GoalDifference DESC → GoalsFor DESC →
  /// (giữ thứ tự gốc — tên alphabet) cho deterministic.
  List<LeaguePlayer> _sortByRanking(List<LeaguePlayer> players) {
    final sorted = [...players];
    sorted.sort((a, b) {
      final byPoints = b.points.compareTo(a.points);
      if (byPoints != 0) return byPoints;
      final byDiff = b.goalDifference.compareTo(a.goalDifference);
      if (byDiff != 0) return byDiff;
      final byFor = b.goalsFor.compareTo(a.goalsFor);
      if (byFor != 0) return byFor;
      return a.name.compareTo(b.name);
    });
    return sorted;
  }

  String _slug(String input) {
    final cleaned = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return cleaned.replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
