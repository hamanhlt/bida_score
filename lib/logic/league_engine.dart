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
  static const _maxScore = 999;
  static const List<int> groupSizeOptions = [2, 3, 4, 5, 6];

  static List<int> validGroupSizesFor(int playerCount) {
    if (playerCount < _minPlayers || playerCount > _maxPlayers) {
      return const [];
    }
    return groupSizeOptions;
  }

  static int groupCountFor(int playerCount, int groupSize) {
    if (playerCount < _minPlayers ||
        playerCount > _maxPlayers ||
        !groupSizeOptions.contains(groupSize)) {
      return 0;
    }
    final groupCount = playerCount ~/ groupSize;
    if (groupCount < 2) return 0;
    return groupCount;
  }

  static List<int> plannedGroupSizesFor(int playerCount, int groupSize) {
    final groupCount = groupCountFor(playerCount, groupSize);
    if (groupCount == 0) return const [];
    final sizes = List<int>.filled(groupCount, groupSize);
    final remainder = playerCount % groupSize;
    for (var i = 0; i < remainder; i++) {
      sizes[i % sizes.length] += 1;
    }
    return sizes;
  }

  static bool canStartGroupKnockout(int playerCount, int groupSize) {
    final sizes = plannedGroupSizesFor(playerCount, groupSize);
    return sizes.length >= 2 && sizes.every((size) => size >= 2);
  }

  /// Khởi tạo giải đấu: validate tên, sinh lịch round-robin (mỗi cặp gặp đúng
  /// 1 lần) hoặc vòng bảng + knockout. Trả `LeagueState` với
  /// `status = inProgress`.
  ///
  /// 3 chế độ:
  /// - [manualGroups] != null: bảng chia tay (mỗi sublist = 1 bảng theo
  ///   thứ tự). Tên trong cùng sublist và xuyên sublist đều phải unique.
  /// - [groupSize] != null: auto-distribute N người vào các bảng đều nhau.
  /// - Không có hai cái trên: round-robin (mỗi người gặp nhau 1 lần).
  ///
  /// Throw [ArgumentError] khi:
  /// - Số người chơi < [_minPlayers] hoặc > [_maxPlayers].
  /// - Có tên trùng (case-insensitive sau trim).
  /// - [groupSize] không tạo được tối thiểu 2 bảng, mỗi bảng đủ top 2.
  /// - [manualGroups] có bảng < 2 người hoặc tổng số bảng < 2.
  LeagueState startTournament(
    List<String> rawNames, {
    String tournamentName = '',
    int? groupSize,
    List<List<String>>? manualGroups,
  }) {
    final startedAt = DateTime.now();
    final tournamentDisplayName = tournamentName.trim();

    // Manual groups: bypass flat-names logic — payload chia bảng đã sẵn.
    if (manualGroups != null) {
      return _startManualGroupTournament(
        manualGroups,
        startedAt,
        tournamentDisplayName,
      );
    }

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

    if (groupSize == null) {
      final fixtures = _generateFixtures(players);
      return LeagueState(
        id: _generateLeagueId(startedAt),
        name: tournamentDisplayName,
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
      name: tournamentDisplayName,
      status: LeagueStatus.inProgress,
      phase: LeaguePhase.groupStage,
      groupSize: groupSize,
      players: _sortByRanking(players),
      groups: groups,
      fixtures: fixtures,
      startedAt: startedAt,
    );
  }

  LeagueState _startManualGroupTournament(
    List<List<String>> rawGroups,
    DateTime startedAt,
    String tournamentDisplayName,
  ) {
    // Trim + lọc rỗng per-group.
    final trimmedGroups = rawGroups
        .map(
          (g) => g
              .map((n) => n.trim())
              .where((n) => n.isNotEmpty)
              .toList(growable: false),
        )
        .toList(growable: false);

    if (trimmedGroups.length < 2) {
      throw ArgumentError('Cần ít nhất 2 bảng.');
    }
    if (trimmedGroups.any((g) => g.length < 2)) {
      throw ArgumentError(
        'Mỗi bảng cần ít nhất 2 người để lấy top 2 vào knockout.',
      );
    }
    final allNames = [for (final g in trimmedGroups) ...g];
    if (allNames.length < _minPlayers) {
      throw ArgumentError('Giải đấu cần ít nhất $_minPlayers người chơi.');
    }
    if (allNames.length > _maxPlayers) {
      throw ArgumentError('Giải đấu hỗ trợ tối đa $_maxPlayers người chơi.');
    }
    final lower = allNames.map((n) => n.toLowerCase()).toSet();
    if (lower.length != allNames.length) {
      throw ArgumentError('Tên người chơi phải khác nhau.');
    }

    // Sinh players + map từng tên về player id để xếp vào group.
    final players = <LeaguePlayer>[
      for (var i = 0; i < allNames.length; i++)
        LeaguePlayer(
          id: 'lp_${i + 1}_${_slug(allNames[i])}',
          name: allNames[i],
        ),
    ];
    var cursor = 0;
    final groups = <LeagueGroup>[];
    for (var gi = 0; gi < trimmedGroups.length; gi++) {
      final size = trimmedGroups[gi].length;
      final slice = players.skip(cursor).take(size).toList();
      cursor += size;
      groups.add(
        LeagueGroup(
          id: 'grp_${gi + 1}',
          name: 'Bảng ${_groupLetter(gi)}',
          playerIds: slice.map((p) => p.id).toList(),
        ),
      );
    }

    final fixtures = _generateGroupFixtures(groups, players);
    return LeagueState(
      id: _generateLeagueId(startedAt),
      name: tournamentDisplayName,
      status: LeagueStatus.inProgress,
      phase: LeaguePhase.groupStage,
      groupSize: 0, // manual: kích thước không đồng đều
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
    if (state.usesDoubleElim) {
      return updateScoreDoubleElim(state, fixtureId, score1, score2);
    }
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
    if (state.usesDoubleElim) {
      return clearScoreDoubleElim(state, fixtureId);
    }
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
    if (state.usesDoubleElim && !state.doubleElimComplete) {
      throw ArgumentError('Cần hoàn thành Chung kết tổng.');
    }
    if (state.usesGroupStage && !state.knockoutComplete) {
      throw ArgumentError('Cần hoàn thành trận chung kết knockout.');
    }
    return state.copyWith(
      status: LeagueStatus.finished,
      finishedAt: DateTime.now(),
    );
  }

  LeagueState resetTournament() => LeagueState.initial();

  // ─────────── Double Elimination ───────────

  static const _doubleElimSizes = [8, 16, 32];

  /// Số người chơi hợp lệ cho double-elim (power of 2, tối thiểu 8).
  static List<int> get doubleElimSizes => _doubleElimSizes;

  /// Khởi tạo giải đấu nhánh kép. N phải là 8, 16, hoặc 32.
  ///
  /// Sinh trước TOÀN BỘ bracket (nhánh thắng + nhánh thua + GF) với placeholder cho slot
  /// player chưa biết. Khi 1 trận kết thúc, engine fill player vào các
  /// fixture phụ thuộc qua `sourceWinnerOfP*Id` / `sourceLoserOfP*Id`.
  LeagueState startDoubleElim(
    List<String> rawNames, {
    String tournamentName = '',
  }) {
    final names = rawNames
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    if (!_doubleElimSizes.contains(names.length)) {
      throw ArgumentError(
        'Đấu nhánh cần tối thiểu 8 người và hỗ trợ 8/16/32 người '
        '(hiện ${names.length}).',
      );
    }
    final lower = names.map((n) => n.toLowerCase()).toSet();
    if (lower.length != names.length) {
      throw ArgumentError('Tên người chơi phải khác nhau.');
    }

    final players = <LeaguePlayer>[
      for (var i = 0; i < names.length; i++)
        LeaguePlayer(id: 'lp_${i + 1}_${_slug(names[i])}', name: names[i]),
    ];

    final n = players.length;
    final m = _log2(n); // số vòng WB
    // Luật app: chỉ lượt 1-2 của nhánh thắng còn "2 mạng". Từ lượt 3
    // trở đi, ai thua bị loại luôn; nhánh thua sau đó chạy single-elim.
    final lbRoundCount = m;
    final fixtures = <MatchFixture>[];

    // WB R1: real players.
    final wbR1Count = n ~/ 2;
    for (var i = 0; i < wbR1Count; i++) {
      fixtures.add(
        MatchFixture(
          id: 'wb_r1_m${i + 1}',
          player1Id: players[2 * i].id,
          player2Id: players[2 * i + 1].id,
          stage: MatchStage.knockout,
          bracketSide: BracketSide.winners,
          roundIndex: 1,
          roundName: _wbRoundName(1, m),
        ),
      );
    }

    // WB R2..Rm: placeholder, sources = winners của 2 trận WB round trước.
    for (var r = 2; r <= m; r++) {
      final count = 1 << (m - r);
      for (var i = 0; i < count; i++) {
        fixtures.add(
          MatchFixture(
            id: 'wb_r${r}_m${i + 1}',
            player1Id: '',
            player2Id: '',
            stage: MatchStage.knockout,
            bracketSide: BracketSide.winners,
            roundIndex: r,
            roundName: _wbRoundName(r, m),
            sourceWinnerOfP1Id: 'wb_r${r - 1}_m${2 * i + 1}',
            sourceWinnerOfP2Id: 'wb_r${r - 1}_m${2 * i + 2}',
          ),
        );
      }
    }

    // LB R1: pair WB R1 losers tuần tự.
    final lbR1Count = wbR1Count ~/ 2;
    for (var i = 0; i < lbR1Count; i++) {
      fixtures.add(
        MatchFixture(
          id: 'lb_r1_m${i + 1}',
          player1Id: '',
          player2Id: '',
          stage: MatchStage.knockout,
          bracketSide: BracketSide.losers,
          roundIndex: 1,
          roundName: lbRoundCount == 1 ? 'LB Chung kết' : 'LB R1',
          sourceLoserOfP1Id: 'wb_r1_m${2 * i + 1}',
          sourceLoserOfP2Id: 'wb_r1_m${2 * i + 2}',
        ),
      );
    }

    // LB R2 nhận loser của WB R2. Từ LB R3 trở đi chỉ lấy winner nội bộ LB.
    for (var lbR = 2; lbR <= lbRoundCount; lbR++) {
      final count = lbR == 2 ? lbR1Count : 1 << (m - lbR);
      final isLBFinal = lbR == lbRoundCount;
      final roundName = isLBFinal ? 'LB Bán kết' : 'LB R$lbR';
      for (var i = 0; i < count; i++) {
        if (lbR == 2) {
          fixtures.add(
            MatchFixture(
              id: 'lb_r${lbR}_m${i + 1}',
              player1Id: '',
              player2Id: '',
              stage: MatchStage.knockout,
              bracketSide: BracketSide.losers,
              roundIndex: lbR,
              roundName: roundName,
              sourceWinnerOfP1Id: 'lb_r${lbR - 1}_m${i + 1}',
              sourceLoserOfP2Id: 'wb_r2_m${i + 1}',
            ),
          );
        } else {
          fixtures.add(
            MatchFixture(
              id: 'lb_r${lbR}_m${i + 1}',
              player1Id: '',
              player2Id: '',
              stage: MatchStage.knockout,
              bracketSide: BracketSide.losers,
              roundIndex: lbR,
              roundName: roundName,
              sourceWinnerOfP1Id: 'lb_r${lbR - 1}_m${2 * i + 1}',
              sourceWinnerOfP2Id: 'lb_r${lbR - 1}_m${2 * i + 2}',
            ),
          );
        }
      }
    }

    // Grand Final.
    fixtures.add(
      MatchFixture(
        id: 'gf_1',
        player1Id: '',
        player2Id: '',
        stage: MatchStage.knockout,
        bracketSide: BracketSide.grandFinal,
        roundIndex: m + lbRoundCount + 1,
        roundName: 'Chung kết tổng',
        sourceWinnerOfP1Id: 'wb_r${m}_m1',
        sourceWinnerOfP2Id: 'lb_r${lbRoundCount}_m1',
      ),
    );

    final startedAt = DateTime.now();
    return LeagueState(
      id: _generateLeagueId(startedAt),
      name: tournamentName.trim(),
      status: LeagueStatus.inProgress,
      format: LeagueFormat.doubleElim,
      phase: LeaguePhase.knockout,
      players: players,
      fixtures: fixtures,
      startedAt: startedAt,
    );
  }

  /// Cập nhật tỷ số trong double-elim + cascade fill các slot phụ thuộc.
  /// Trận knockout không cho phép hoà.
  LeagueState updateScoreDoubleElim(
    LeagueState state,
    String fixtureId,
    int score1,
    int score2,
  ) {
    if (score1 < 0 || score2 < 0) {
      throw ArgumentError('Tỷ số phải ≥ 0.');
    }
    if (score1 > _maxScore || score2 > _maxScore) {
      throw ArgumentError('Tỷ số tối đa $_maxScore.');
    }
    if (score1 == score2) {
      throw ArgumentError('Trận knockout cần có người thắng.');
    }
    final idx = state.fixtures.indexWhere((f) => f.id == fixtureId);
    if (idx < 0) {
      throw ArgumentError('Không tìm thấy trận $fixtureId.');
    }
    final fixture = state.fixtures[idx];
    if (!fixture.isReady) {
      throw ArgumentError('Trận chưa đủ người chơi.');
    }
    if (state.status != LeagueStatus.inProgress) return state;

    final oldWinnerId = fixture.isPlayed
        ? (fixture.score1 > fixture.score2
              ? fixture.player1Id
              : fixture.player2Id)
        : null;
    final oldLoserId = fixture.isPlayed
        ? (fixture.score1 > fixture.score2
              ? fixture.player2Id
              : fixture.player1Id)
        : null;
    final winnerId = score1 > score2 ? fixture.player1Id : fixture.player2Id;
    final loserId = score1 > score2 ? fixture.player2Id : fixture.player1Id;

    var newFixtures = [...state.fixtures];
    newFixtures[idx] = fixture.copyWith(
      score1: score1,
      score2: score2,
      isPlayed: true,
    );

    if (fixture.isPlayed &&
        (oldWinnerId != winnerId || oldLoserId != loserId)) {
      newFixtures = _invalidateDescendants(newFixtures, fixtureId);
    }
    final cascaded = _cascadeDoubleElim(
      newFixtures,
      finishedFixtureId: fixtureId,
      winnerId: winnerId,
      loserId: loserId,
    );

    return state.copyWith(fixtures: cascaded);
  }

  /// Xoá tỷ số trong double-elim + invalidate (clear slot + isPlayed) các
  /// fixture phụ thuộc đệ quy.
  LeagueState clearScoreDoubleElim(LeagueState state, String fixtureId) {
    final idx = state.fixtures.indexWhere((f) => f.id == fixtureId);
    if (idx < 0) {
      throw ArgumentError('Không tìm thấy trận $fixtureId.');
    }
    if (state.status != LeagueStatus.inProgress) return state;
    var fixtures = [...state.fixtures];
    fixtures[idx] = fixtures[idx].copyWith(
      score1: 0,
      score2: 0,
      isPlayed: false,
    );
    fixtures = _invalidateDescendants(fixtures, fixtureId);
    return state.copyWith(fixtures: fixtures);
  }

  /// Fill lại slot ở các fixture phụ thuộc khi 1 trận có kết quả. Nếu slot
  /// đổi người chơi thì kết quả cũ của fixture đó và các con phải bị xoá.
  List<MatchFixture> _cascadeDoubleElim(
    List<MatchFixture> fixtures, {
    required String finishedFixtureId,
    required String winnerId,
    required String loserId,
  }) {
    final next = [...fixtures];
    for (var i = 0; i < next.length; i++) {
      var f = next[i];
      if (f.id == finishedFixtureId) continue;
      var p1 = f.player1Id;
      var p2 = f.player2Id;
      if (f.sourceWinnerOfP1Id == finishedFixtureId) {
        p1 = winnerId;
      } else if (f.sourceLoserOfP1Id == finishedFixtureId) {
        p1 = loserId;
      }
      if (f.sourceWinnerOfP2Id == finishedFixtureId) {
        p2 = winnerId;
      } else if (f.sourceLoserOfP2Id == finishedFixtureId) {
        p2 = loserId;
      }
      if (p1 != f.player1Id || p2 != f.player2Id) {
        next[i] = f.copyWith(
          player1Id: p1,
          player2Id: p2,
          score1: 0,
          score2: 0,
          isPlayed: false,
        );
        _invalidateDescendantsInPlace(next, f.id);
      }
    }
    return next;
  }

  /// Clear (set isPlayed=false + xoá player slot do source thay đổi) các
  /// fixture có source link tới [sourceId]. Đệ quy xuống các con.
  List<MatchFixture> _invalidateDescendants(
    List<MatchFixture> fixtures,
    String sourceId,
  ) {
    var changed = false;
    final next = [...fixtures];
    for (var i = 0; i < next.length; i++) {
      final f = next[i];
      if (f.id == sourceId) continue;
      final isDep =
          f.sourceWinnerOfP1Id == sourceId ||
          f.sourceLoserOfP1Id == sourceId ||
          f.sourceWinnerOfP2Id == sourceId ||
          f.sourceLoserOfP2Id == sourceId;
      if (!isDep) continue;
      var p1 = f.player1Id;
      var p2 = f.player2Id;
      if (f.sourceWinnerOfP1Id == sourceId || f.sourceLoserOfP1Id == sourceId) {
        p1 = '';
      }
      if (f.sourceWinnerOfP2Id == sourceId || f.sourceLoserOfP2Id == sourceId) {
        p2 = '';
      }
      next[i] = f.copyWith(
        player1Id: p1,
        player2Id: p2,
        score1: 0,
        score2: 0,
        isPlayed: false,
      );
      changed = true;
      // Recurse: nếu fixture này từng có người chơi, các fixture con của
      // NÓ cũng cần invalidate.
      _invalidateDescendantsInPlace(next, f.id);
    }
    return changed ? next : fixtures;
  }

  void _invalidateDescendantsInPlace(List<MatchFixture> fixtures, String src) {
    for (var i = 0; i < fixtures.length; i++) {
      final f = fixtures[i];
      if (f.id == src) continue;
      final isDep =
          f.sourceWinnerOfP1Id == src ||
          f.sourceLoserOfP1Id == src ||
          f.sourceWinnerOfP2Id == src ||
          f.sourceLoserOfP2Id == src;
      if (!isDep) continue;
      var p1 = f.player1Id;
      var p2 = f.player2Id;
      if (f.sourceWinnerOfP1Id == src || f.sourceLoserOfP1Id == src) p1 = '';
      if (f.sourceWinnerOfP2Id == src || f.sourceLoserOfP2Id == src) p2 = '';
      if (p1 == f.player1Id && p2 == f.player2Id && !f.isPlayed) continue;
      fixtures[i] = f.copyWith(
        player1Id: p1,
        player2Id: p2,
        score1: 0,
        score2: 0,
        isPlayed: false,
      );
      _invalidateDescendantsInPlace(fixtures, f.id);
    }
  }

  String _wbRoundName(int round, int totalRounds) {
    if (round == totalRounds) return 'WB Chung kết';
    if (round == totalRounds - 1) return 'WB Bán kết';
    if (round == totalRounds - 2) return 'WB Tứ kết';
    return 'WB R$round';
  }

  int _log2(int n) {
    var v = n, c = 0;
    while (v > 1) {
      v >>= 1;
      c++;
    }
    return c;
  }

  /// Tính lại stats + thứ hạng cho state hiện có. Dùng khi load từ disk
  /// để áp dụng tiebreaker mới nhất (nếu engine đổi). KHÔNG đụng fixtures,
  /// chỉ sort lại `state.players` và refresh stats.
  LeagueState recalculate(LeagueState state) {
    if (state.fixtures.isEmpty || state.players.isEmpty) return state;
    // Double-elim không có aggregate ranking — bracket tự đại diện.
    if (state.usesDoubleElim) return state;
    if (state.usesGroupStage) {
      return _syncGroupKnockout(state);
    }
    return _recalculateLeaderboard(state);
  }

  // ────────────────────────── internals ──────────────────────────

  void _validateGroupSize(int playerCount, int groupSize) {
    if (!groupSizeOptions.contains(groupSize)) {
      throw ArgumentError('Số người mỗi bảng cần chọn từ 2 đến 6.');
    }
    final sizes = plannedGroupSizesFor(playerCount, groupSize);
    if (sizes.length < 2) {
      throw ArgumentError('Cần tạo ít nhất 2 bảng để đấu knockout.');
    }
    if (sizes.any((size) => size < 2)) {
      throw ArgumentError(
        'Mỗi bảng cần ít nhất 2 người để lấy top 2 vào knockout.',
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

    final ranked = _sortByRanking(
      byId.values.toList(),
      fixtures: fixtures ?? state.fixtures,
    );
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
      fixtures: [...state.fixtures, ...firstRound.fixtures],
      knockoutByePlayerIds: firstRound.byePlayerIds,
    );
  }

  _KnockoutRoundPlan _createFirstKnockoutRound(LeagueState state) {
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
    final fullBracket = _isPowerOfTwo(participantCount);
    final targetCount = _highestPowerOfTwoAtMost(participantCount);
    final fixtureCount = fullBracket
        ? participantCount ~/ 2
        : participantCount - targetCount;
    final byeCount = participantCount - fixtureCount * 2;
    final byePlayers = <LeaguePlayer>[];
    final playPlayers = <LeaguePlayer>[];
    if (fullBracket) {
      playPlayers.addAll([...winners, ...runnersUp]);
    } else {
      final topSeeds = [...winners, ...runnersUp];
      byePlayers.addAll(topSeeds.take(byeCount));
      final byeIds = byePlayers.map((p) => p.id).toSet();
      playPlayers
        ..addAll(winners.where((p) => !byeIds.contains(p.id)))
        ..addAll(
          runnersUp.where((p) => !byeIds.contains(p.id)).toList().reversed,
        );
    }
    final roundName = fullBracket ? _roundName(participantCount) : 'Play-off';
    final fixtures = <MatchFixture>[];
    for (var i = 0; i < fixtureCount; i++) {
      fixtures.add(
        MatchFixture(
          id: 'ko_1_${i + 1}',
          player1Id: playPlayers[i].id,
          player2Id: playPlayers[playPlayers.length - 1 - i].id,
          stage: MatchStage.knockout,
          roundIndex: 1,
          roundName: roundName,
        ),
      );
    }
    return _KnockoutRoundPlan(
      fixtures: fixtures,
      byePlayerIds: byePlayers.map((p) => p.id).toList(),
    );
  }

  LeagueState _advanceKnockoutIfNeeded(LeagueState state) {
    if (state.knockoutFixtures.isEmpty) return state;
    final currentRoundIndex = state.knockoutFixtures
        .map((f) => f.roundIndex)
        .reduce(max);
    // Loại bỏ trận tranh 3-4 khi tìm "vòng hiện tại" cần generate vòng kế.
    // Trận tranh 3-4 sống ở cùng roundIndex với chung kết nhưng KHÔNG quyết
    // định ai đi tiếp — nó là leaf, đặc biệt.
    final currentRound = state.knockoutFixtures
        .where(
          (f) =>
              f.roundIndex == currentRoundIndex &&
              f.roundName != _thirdPlaceRoundName,
        )
        .toList();
    if (currentRound.any((f) => !f.isPlayed)) return state;
    if (currentRound.length == 1) return state;

    final winners = currentRound.map(_winnerId).toList();
    final hasFirstRoundByes =
        currentRoundIndex == 1 && state.knockoutByePlayerIds.isNotEmpty;
    final nextPlayers = hasFirstRoundByes
        ? [...state.knockoutByePlayerIds, ...winners]
        : winners;
    final nextRoundIndex = currentRoundIndex + 1;
    final nextRoundName = _roundName(nextPlayers.length);
    final nextFixtures = <MatchFixture>[];
    for (var i = 0; i < nextPlayers.length ~/ 2; i++) {
      final player1Id = hasFirstRoundByes ? nextPlayers[i] : nextPlayers[i * 2];
      final player2Id = hasFirstRoundByes
          ? nextPlayers[nextPlayers.length - 1 - i]
          : nextPlayers[i * 2 + 1];
      nextFixtures.add(
        MatchFixture(
          id: 'ko_${nextRoundIndex}_${i + 1}',
          player1Id: player1Id,
          player2Id: player2Id,
          stage: MatchStage.knockout,
          roundIndex: nextRoundIndex,
          roundName: nextRoundName,
        ),
      );
    }
    // Khi vòng hiện tại là bán kết thực sự (2 trận sinh ra final 2 người)
    // → thêm trận tranh 3-4 giữa 2 người thua. Skip khi có bye ở R1 vì
    // luồng đó không đảm bảo có đúng 2 "thua bán kết" cùng cấp.
    if (nextPlayers.length == 2 &&
        currentRound.length == 2 &&
        !hasFirstRoundByes) {
      final losers = currentRound
          .map((f) => f.score1 > f.score2 ? f.player2Id : f.player1Id)
          .toList();
      nextFixtures.add(
        MatchFixture(
          id: 'ko_${nextRoundIndex}_3rd',
          player1Id: losers[0],
          player2Id: losers[1],
          stage: MatchStage.knockout,
          roundIndex: nextRoundIndex,
          roundName: _thirdPlaceRoundName,
        ),
      );
    }
    return state.copyWith(
      fixtures: [...state.fixtures, ...nextFixtures],
      knockoutByePlayerIds: hasFirstRoundByes
          ? const []
          : state.knockoutByePlayerIds,
    );
  }

  static const _thirdPlaceRoundName = 'Tranh 3-4';

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

  /// Sort by ranking với tiebreaker:
  /// 1. Points DESC.
  /// 2. **Head-to-head wins** giữa các player cùng điểm (Copeland: đếm số
  ///    trận thắng đối đầu trong tier). Khi tied (Condorcet cycle, vd 3
  ///    người mỗi người 1 thắng 1 thua trong tier) → bỏ mini-table và
  ///    nhảy thẳng xuống overall, KHÔNG dùng mini-GD/mini-GF vì chúng
  ///    không đại diện cho pairwise.
  /// 3. Overall GoalDifference DESC.
  /// 4. Overall GoalsFor DESC.
  /// 5. Tên alphabet (deterministic fallback).
  ///
  /// H2H chỉ tính trên fixtures `isPlayed` và giữa các player tied. Hai
  /// player khác bảng (không gặp nhau) sẽ có mini-stats 0-0 → fall through
  /// sang overall tiebreaker. Cùng bảng + gặp nhau → mini-stats có nghĩa.
  List<LeaguePlayer> _sortByRanking(
    List<LeaguePlayer> players, {
    Iterable<MatchFixture>? fixtures,
  }) {
    // Group players theo tier điểm (mỗi tier = tied trên Points).
    final byPoints = <int, List<LeaguePlayer>>{};
    for (final p in players) {
      byPoints.putIfAbsent(p.points, () => []).add(p);
    }
    final pointTiers = byPoints.keys.toList()..sort((a, b) => b.compareTo(a));

    final result = <LeaguePlayer>[];
    for (final pts in pointTiers) {
      final tier = byPoints[pts]!;
      if (tier.length == 1) {
        result.add(tier.first);
        continue;
      }
      result.addAll(_sortTier(tier, fixtures));
    }
    return result;
  }

  List<LeaguePlayer> _sortTier(
    List<LeaguePlayer> tier,
    Iterable<MatchFixture>? fixtures,
  ) {
    final tierIds = tier.map((p) => p.id).toSet();
    // Mini-stats chỉ từ fixtures giữa các player tied.
    final mini = <String, _MiniStats>{for (final p in tier) p.id: _MiniStats()};
    if (fixtures != null) {
      for (final f in fixtures) {
        if (!f.isPlayed) continue;
        if (!tierIds.contains(f.player1Id) || !tierIds.contains(f.player2Id)) {
          continue;
        }
        final s1 = mini[f.player1Id]!;
        final s2 = mini[f.player2Id]!;
        s1.goalsFor += f.score1;
        s1.goalsAgainst += f.score2;
        s2.goalsFor += f.score2;
        s2.goalsAgainst += f.score1;
        if (f.score1 > f.score2) s1.points += 1;
        if (f.score2 > f.score1) s2.points += 1;
      }
    }

    final sorted = [...tier];
    sorted.sort((a, b) {
      final ma = mini[a.id]!;
      final mb = mini[b.id]!;
      // Copeland: số trận thắng đối đầu trong tier. 2 người tied + 1 trận
      // → người thắng có mini-points=1, người thua=0. 3+ người Condorcet
      // cycle → tất cả bằng nhau, fall through xuống overall.
      final byMiniPts = mb.points.compareTo(ma.points);
      if (byMiniPts != 0) return byMiniPts;
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

  int _highestPowerOfTwoAtMost(int value) {
    var result = 1;
    while (result * 2 <= value) {
      result *= 2;
    }
    return result;
  }

  String _slug(String input) {
    final cleaned = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return cleaned.replaceAll(RegExp(r'^_+|_+$'), '');
  }
}

class _KnockoutRoundPlan {
  const _KnockoutRoundPlan({
    required this.fixtures,
    required this.byePlayerIds,
  });

  final List<MatchFixture> fixtures;
  final List<String> byePlayerIds;
}

/// Stats nội bộ cho H2H mini-table — accumulator khi sort tier tied points.
class _MiniStats {
  int points = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
}
