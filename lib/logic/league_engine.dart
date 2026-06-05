import 'dart:math';

import '../models/league_group.dart';
import '../models/league_player.dart';
import '../models/league_state.dart';
import '../models/match_fixture.dart';

/// Engine pure functions cho Chế độ giải đấu.
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
  static const _minGroupSize = 2;
  static const _maxScore = 999;

  static List<int> validGroupSizesFor(int playerCount) {
    if (playerCount < _minPlayers || playerCount > _maxPlayers) {
      return const [];
    }
    final sizes = <int>[];
    for (var size = _minGroupSize; size <= playerCount; size++) {
      final groupCount = groupCountFor(playerCount, size);
      if (groupCount == 0) continue;
      sizes.add(size);
    }
    return sizes;
  }

  static int groupCountFor(int playerCount, int groupSize) {
    if (playerCount < _minPlayers || groupSize < _minGroupSize) return 0;
    final groupCount = playerCount ~/ groupSize;
    if (groupCount < 2) return 0;
    if (!_isPowerOfTwo(groupCount)) return 0;
    final remainder = playerCount % groupSize;
    if (remainder >= groupCount) return 0;
    return groupCount;
  }

  static List<int> plannedGroupSizesFor(int playerCount, int groupSize) {
    final groupCount = groupCountFor(playerCount, groupSize);
    if (groupCount == 0) return const [];
    final sizes = List<int>.filled(groupCount, groupSize);
    final remainder = playerCount % groupSize;
    for (var i = 0; i < remainder; i++) {
      sizes[i] += 1;
    }
    return sizes;
  }

  /// Khởi tạo giải đấu: validate tên, sinh lịch round-robin (mỗi cặp gặp đúng
  /// 1 lần) hoặc vòng bảng + knockout. Trả `LeagueState` với
  /// `status = inProgress`.
  ///
  /// Throw [ArgumentError] khi:
  /// - Số người chơi < [_minPlayers] hoặc > [_maxPlayers].
  /// - Có tên trùng (case-insensitive sau trim).
  /// - [groupSize] không chia được thành số bảng hợp lệ cho knockout.
  LeagueState startTournament(
    List<String> rawNames, {
    String tournamentName = '',
    int? groupSize,
  }) {
    final names = rawNames
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    if (names.length < _minPlayers) {
      throw ArgumentError('Giải đấu cần ít nhất $_minPlayers người chơi.');
    }
    if (names.length > _maxPlayers) {
      throw ArgumentError('Giải đấu hỗ trợ tối đa $_maxPlayers người chơi.');
    }
    final lower = names.map((n) => n.toLowerCase()).toSet();
    if (lower.length != names.length) {
      throw ArgumentError('Tên người chơi phải khác nhau.');
    }

    final players = <LeaguePlayer>[
      for (var i = 0; i < names.length; i++)
        LeaguePlayer(id: 'lp_${i + 1}_${_slug(names[i])}', name: names[i]),
    ];

    final startedAt = DateTime.now();
    final name = tournamentName.trim();
    if (groupSize == null) {
      final fixtures = _generateFixtures(players);
      return LeagueState(
        id: _generateLeagueId(startedAt),
        name: name,
        status: LeagueStatus.inProgress,
        phase: LeaguePhase.roundRobin,
        players: _sortByRanking(players),
        fixtures: fixtures,
        startedAt: startedAt,
      );
    }

    _validateGroupSize(names.length, groupSize);
    final groups = _generateGroups(players, groupSize);
    final fixtures = _generateGroupFixtures(groups, players);
    return LeagueState(
      id: _generateLeagueId(startedAt),
      name: name,
      status: LeagueStatus.inProgress,
      phase: LeaguePhase.groupStage,
      groupSize: groupSize,
      players: _sortByRanking(players),
      groups: groups,
      fixtures: fixtures,
      startedAt: startedAt,
    );
  }

  /// Sinh id unique cho giải đấu: timestamp microsec (base36) + 6 hex random.
  /// Đủ unique cho mọi use case của app (user không có khả năng tạo 2 giải
  /// cùng microsecond).
  String _generateLeagueId(DateTime at) {
    final ts = at.microsecondsSinceEpoch.toRadixString(36);
    final rand = (_rng ?? Random())
        .nextInt(0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0');
    return 'lg_${ts}_$rand';
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
    final currentFixture = state.fixtures[idx];
    _validateEditableFixture(state, currentFixture);
    if (currentFixture.stage == MatchStage.knockout && score1 == score2) {
      throw ArgumentError('Trận knockout cần có người thắng.');
    }

    if (state.status != LeagueStatus.inProgress) return state;

    final newFixtures = [...state.fixtures];
    newFixtures[idx] = newFixtures[idx].copyWith(
      score1: score1,
      score2: score2,
      isPlayed: true,
    );

    final next = state.copyWith(fixtures: newFixtures);
    if (!state.usesGroupStage) {
      return _recalculateLeaderboard(next);
    }
    return _syncGroupKnockout(next);
  }

  /// Xác nhận chốt vòng bảng và sinh nhánh knockout.
  ///
  /// Tách riêng khỏi [updateScore] để sau khi nhập trận cuối vòng bảng, UI có
  /// thể hỏi lại người chơi trước khi khoá quyền sửa tỷ số vòng bảng.
  LeagueState startKnockout(LeagueState state) {
    if (state.status != LeagueStatus.inProgress) return state;
    if (!state.usesGroupStage) {
      throw ArgumentError('Giải này không có vòng bảng.');
    }
    if (state.phase == LeaguePhase.knockout) return state;
    if (state.phase != LeaguePhase.groupStage) {
      throw ArgumentError('Chỉ có thể vào knockout sau vòng bảng.');
    }

    final recalculated = _recalculateLeaderboard(
      state,
      fixtures: state.groupFixtures,
    );
    if (!recalculated.groupStageComplete) {
      throw ArgumentError('Cần nhập đủ tỷ số vòng bảng trước.');
    }
    if (recalculated.knockoutFixtures.isNotEmpty) {
      return recalculated.copyWith(phase: LeaguePhase.knockout);
    }
    return _startKnockout(recalculated);
  }

  /// Xoá kết quả 1 trận (`isPlayed = false`, score reset 0). Recalculate.
  /// Throw [ArgumentError] nếu fixtureId không tồn tại — contract đồng nhất
  /// với [updateScore].
  LeagueState clearScore(LeagueState state, String fixtureId) {
    final idx = state.fixtures.indexWhere((f) => f.id == fixtureId);
    if (idx < 0) {
      throw ArgumentError('Không tìm thấy trận $fixtureId.');
    }
    final currentFixture = state.fixtures[idx];
    _validateEditableFixture(state, currentFixture);
    if (state.status != LeagueStatus.inProgress) return state;

    final newFixtures = [...state.fixtures];
    newFixtures[idx] = newFixtures[idx].copyWith(
      score1: 0,
      score2: 0,
      isPlayed: false,
    );

    final next = state.copyWith(fixtures: newFixtures);
    if (!state.usesGroupStage) {
      return _recalculateLeaderboard(next);
    }
    return _syncGroupKnockout(next);
  }

  /// Chốt giải. Bảng xếp hạng cuối cùng dùng kết quả hiện tại của state
  /// (đã được recalculate sau mỗi updateScore).
  LeagueState finishTournament(LeagueState state) {
    if (state.status != LeagueStatus.inProgress) return state;
    if (state.usesGroupStage && !state.knockoutComplete) {
      throw ArgumentError('Cần hoàn thành trận chung kết knockout.');
    }
    return state.copyWith(
      status: LeagueStatus.finished,
      finishedAt: DateTime.now(),
    );
  }

  LeagueState resetTournament() => LeagueState.initial();

  // ────────────────────────── internals ──────────────────────────

  void _validateGroupSize(int playerCount, int groupSize) {
    if (!validGroupSizesFor(playerCount).contains(groupSize)) {
      throw ArgumentError(
        'Số người mỗi bảng chưa hợp lệ. Cần tạo được 2/4/8 bảng '
        'để lấy top 2 vào knockout.',
      );
    }
  }

  List<LeagueGroup> _generateGroups(List<LeaguePlayer> players, int groupSize) {
    final groups = <LeagueGroup>[];
    final sizes = plannedGroupSizesFor(players.length, groupSize);
    var start = 0;
    for (var groupIndex = 0; groupIndex < sizes.length; groupIndex++) {
      final slice = players.skip(start).take(sizes[groupIndex]).toList();
      start += sizes[groupIndex];
      groups.add(
        LeagueGroup(
          id: 'grp_${groupIndex + 1}',
          name: 'Bảng ${_groupLetter(groupIndex)}',
          playerIds: slice.map((p) => p.id).toList(),
        ),
      );
    }
    return groups;
  }

  List<MatchFixture> _generateGroupFixtures(
    List<LeagueGroup> groups,
    List<LeaguePlayer> players,
  ) {
    final byId = {for (final p in players) p.id: p};
    final fixtures = <MatchFixture>[];
    for (final group in groups) {
      final groupPlayers = [
        for (final id in group.playerIds)
          if (byId[id] != null) byId[id]!,
      ];
      for (var i = 0; i < groupPlayers.length; i++) {
        for (var j = i + 1; j < groupPlayers.length; j++) {
          fixtures.add(
            MatchFixture(
              id: 'mf_${fixtures.length + 1}',
              player1Id: groupPlayers[i].id,
              player2Id: groupPlayers[j].id,
              stage: MatchStage.group,
              groupId: group.id,
            ),
          );
        }
      }
    }
    fixtures.shuffle(_rng ?? Random());
    return fixtures;
  }

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
  /// Duyệt các fixture có `isPlayed == true` và cộng dồn.
  LeagueState _recalculateLeaderboard(
    LeagueState state, {
    Iterable<MatchFixture>? fixtures,
  }) {
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

    for (final f in fixtures ?? state.fixtures) {
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

  LeagueState _syncGroupKnockout(LeagueState state) {
    final recalculated = _recalculateLeaderboard(
      state,
      fixtures: state.groupFixtures,
    );
    if (recalculated.phase == LeaguePhase.groupStage) {
      return recalculated;
    }
    if (recalculated.phase == LeaguePhase.knockout) {
      return _advanceKnockoutIfNeeded(recalculated);
    }
    return recalculated;
  }

  LeagueState _startKnockout(LeagueState state) {
    final firstRound = _createFirstKnockoutRound(state);
    return state.copyWith(
      phase: LeaguePhase.knockout,
      fixtures: [...state.fixtures, ...firstRound],
    );
  }

  List<MatchFixture> _createFirstKnockoutRound(LeagueState state) {
    final winners = <LeaguePlayer>[];
    final runnersUp = <LeaguePlayer>[];
    for (final group in state.groups) {
      final ranking = state.playersInGroup(group);
      if (ranking.length < 2) {
        throw StateError('${group.name} không đủ 2 người đi tiếp.');
      }
      winners.add(ranking[0]);
      runnersUp.add(ranking[1]);
    }

    final participantCount = winners.length + runnersUp.length;
    final roundName = _roundName(participantCount);
    final fixtures = <MatchFixture>[];
    for (var i = 0; i < winners.length; i++) {
      final runner = runnersUp[winners.length - 1 - i];
      fixtures.add(
        MatchFixture(
          id: 'ko_1_${i + 1}',
          player1Id: winners[i].id,
          player2Id: runner.id,
          stage: MatchStage.knockout,
          roundIndex: 1,
          roundName: roundName,
        ),
      );
    }
    return fixtures;
  }

  LeagueState _advanceKnockoutIfNeeded(LeagueState state) {
    if (state.knockoutFixtures.isEmpty) return state;
    final currentRoundIndex = state.knockoutFixtures
        .map((f) => f.roundIndex)
        .reduce(max);
    final currentRound = state.knockoutFixtures
        .where((f) => f.roundIndex == currentRoundIndex)
        .toList();
    if (currentRound.any((f) => !f.isPlayed)) return state;
    if (currentRound.length == 1) return state;

    final winners = currentRound.map(_winnerId).toList();
    final nextRoundIndex = currentRoundIndex + 1;
    final nextRoundName = _roundName(winners.length);
    final nextFixtures = <MatchFixture>[];
    for (var i = 0; i < winners.length; i += 2) {
      nextFixtures.add(
        MatchFixture(
          id: 'ko_${nextRoundIndex}_${(i ~/ 2) + 1}',
          player1Id: winners[i],
          player2Id: winners[i + 1],
          stage: MatchStage.knockout,
          roundIndex: nextRoundIndex,
          roundName: nextRoundName,
        ),
      );
    }
    return state.copyWith(fixtures: [...state.fixtures, ...nextFixtures]);
  }

  void _validateEditableFixture(LeagueState state, MatchFixture fixture) {
    if (!state.usesGroupStage) return;
    if (state.phase == LeaguePhase.knockout &&
        fixture.stage == MatchStage.group) {
      throw ArgumentError('Không thể sửa vòng bảng sau khi đã vào knockout.');
    }
    if (fixture.stage != MatchStage.knockout) return;
    final hasLaterRound = state.knockoutFixtures.any(
      (f) => f.roundIndex > fixture.roundIndex,
    );
    if (hasLaterRound) {
      throw ArgumentError('Không thể sửa vòng trước sau khi vòng sau đã tạo.');
    }
  }

  String _winnerId(MatchFixture fixture) {
    if (!fixture.isPlayed || fixture.score1 == fixture.score2) {
      throw StateError('Trận knockout chưa có người thắng.');
    }
    return fixture.score1 > fixture.score2
        ? fixture.player1Id
        : fixture.player2Id;
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

  String _roundName(int participantCount) {
    return switch (participantCount) {
      2 => 'Chung kết',
      4 => 'Bán kết',
      8 => 'Tứ kết',
      16 => 'Vòng 1/8',
      _ => 'Knockout',
    };
  }

  String _groupLetter(int index) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (index >= 0 && index < letters.length) return letters[index];
    return '${index + 1}';
  }

  static bool _isPowerOfTwo(int value) {
    return value > 0 && (value & (value - 1)) == 0;
  }

  String _slug(String input) {
    final cleaned = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return cleaned.replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
