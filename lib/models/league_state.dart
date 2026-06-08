import 'dart:convert';

import 'league_group.dart';
import 'league_player.dart';
import 'match_fixture.dart';

enum LeagueStatus { setup, inProgress, finished }

enum LeaguePhase { roundRobin, groupStage, knockout }

/// Thể thức giải đấu.
/// - [roundRobin]: vòng tròn 1 lần.
/// - [groupKnockout]: vòng bảng + knockout.
/// - [doubleElim]: đấu nhánh kép (Winners + Losers + Grand Final).
enum LeagueFormat { roundRobin, groupKnockout, doubleElim }

/// State của 1 giải đấu — immutable, copyWith.
///
/// [id] unique theo từng giải (sinh ở `LeagueEngine.startTournament`).
/// Dùng làm khoá ở `active_leagues_v1` để app có thể giữ nhiều giải đang
/// chơi cùng lúc, switch giữa chúng không mất tỷ số đã nhập.
///
/// [players] luôn sort theo thứ hạng (Points DESC → GoalDifference DESC →
/// GoalsFor DESC) sau mỗi lần recalculate — UI render trực tiếp.
class LeagueState {
  LeagueState({
    this.id = '',
    this.name = '',
    this.status = LeagueStatus.setup,
    this.phase = LeaguePhase.roundRobin,
    this.format = LeagueFormat.roundRobin,
    this.groupSize = 0,
    List<LeaguePlayer> players = const [],
    List<LeagueGroup> groups = const [],
    List<MatchFixture> fixtures = const [],
    List<String> knockoutByePlayerIds = const [],
    this.startedAt,
    this.finishedAt,
  }) : players = List.unmodifiable(players),
       groups = List.unmodifiable(groups),
       fixtures = List.unmodifiable(fixtures),
       knockoutByePlayerIds = List.unmodifiable(knockoutByePlayerIds);

  factory LeagueState.initial() => LeagueState();

  /// Id rỗng cho state khởi tạo (chưa start tournament). Engine luôn gán id
  /// non-empty khi `startTournament` chạy.
  final String id;
  final String name;
  final LeagueStatus status;
  final LeaguePhase phase;
  final LeagueFormat format;
  final int groupSize;
  final List<LeaguePlayer> players;
  final List<LeagueGroup> groups;
  final List<MatchFixture> fixtures;
  final List<String> knockoutByePlayerIds;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  bool get isFinished => status == LeagueStatus.finished;
  bool get usesGroupStage => groups.isNotEmpty;
  bool get usesDoubleElim => format == LeagueFormat.doubleElim;
  String get displayName => name.trim().isEmpty ? 'Giải đấu' : name.trim();

  /// Trận thuộc nhánh thắng.
  List<MatchFixture> get winnersFixtures => fixtures
      .where((f) => f.bracketSide == BracketSide.winners)
      .toList(growable: false);

  /// Trận thuộc nhánh thua.
  List<MatchFixture> get losersFixtures => fixtures
      .where((f) => f.bracketSide == BracketSide.losers)
      .toList(growable: false);

  /// Trận chung kết tổng (đơn). null nếu chưa tạo / không phải doubleElim.
  MatchFixture? get grandFinalFixture {
    for (final f in fixtures) {
      if (f.bracketSide == BracketSide.grandFinal) return f;
    }
    return null;
  }

  /// True khi cả WB Final + LB Final đã đá và GF đã đá xong.
  bool get doubleElimComplete {
    final gf = grandFinalFixture;
    if (gf == null) return false;
    return gf.isPlayed && gf.score1 != gf.score2;
  }

  int get matchesTotal => fixtures.length;
  int get matchesPlayed => fixtures.where((f) => f.isPlayed).length;
  int get groupMatchesTotal => groupFixtures.length;
  int get groupMatchesPlayed => groupFixtures.where((f) => f.isPlayed).length;
  int get knockoutMatchesTotal => knockoutFixtures.length;
  int get knockoutMatchesPlayed =>
      knockoutFixtures.where((f) => f.isPlayed).length;

  List<MatchFixture> get groupFixtures => fixtures
      .where((f) => f.stage == MatchStage.group)
      .toList(growable: false);

  List<MatchFixture> get knockoutFixtures => fixtures
      .where((f) => f.stage == MatchStage.knockout)
      .toList(growable: false);

  bool get groupStageComplete =>
      groupFixtures.isNotEmpty && groupMatchesPlayed == groupMatchesTotal;

  bool get knockoutComplete {
    final finalFixture = this.finalFixture;
    if (finalFixture == null ||
        !finalFixture.isPlayed ||
        finalFixture.score1 == finalFixture.score2) {
      return false;
    }
    // Nếu có trận tranh 3-4 → phải đá xong cả 2 mới coi knockout hoàn tất.
    final third = thirdPlaceFixture;
    if (third != null && (!third.isPlayed || third.score1 == third.score2)) {
      return false;
    }
    return true;
  }

  String get phaseLabel {
    if (usesDoubleElim) return 'Đấu nhánh';
    if (!usesGroupStage) return 'Vòng tròn';
    return switch (phase) {
      LeaguePhase.groupStage => 'Vòng bảng',
      LeaguePhase.knockout => 'Knockout',
      LeaguePhase.roundRobin => 'Vòng tròn',
    };
  }

  MatchFixture? get finalFixture {
    if (knockoutFixtures.isEmpty) return null;
    // Bỏ qua trận tranh 3-4 (sống cùng roundIndex với chung kết).
    final candidates = knockoutFixtures
        .where((f) => f.roundName != _thirdPlaceRoundName)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.roundIndex.compareTo(a.roundIndex));
    final highestRound = candidates.first.roundIndex;
    final atHighest = candidates
        .where((f) => f.roundIndex == highestRound)
        .toList();
    return atHighest.length == 1 ? atHighest.first : null;
  }

  /// Trận tranh hạng 3 (nếu có) — sinh ra khi bán kết kết thúc.
  MatchFixture? get thirdPlaceFixture {
    for (final f in knockoutFixtures) {
      if (f.roundName == _thirdPlaceRoundName) return f;
    }
    return null;
  }

  String? get thirdPlaceWinnerId {
    final f = thirdPlaceFixture;
    if (f == null || !f.isPlayed || f.score1 == f.score2) return null;
    return f.score1 > f.score2 ? f.player1Id : f.player2Id;
  }

  String? get fourthPlaceId {
    final f = thirdPlaceFixture;
    if (f == null || !f.isPlayed || f.score1 == f.score2) return null;
    return f.score1 > f.score2 ? f.player2Id : f.player1Id;
  }

  LeaguePlayer? get thirdPlacePlayer => playerById(thirdPlaceWinnerId);
  LeaguePlayer? get fourthPlacePlayer => playerById(fourthPlaceId);

  static const _thirdPlaceRoundName = 'Tranh 3-4';

  String? get championId {
    if (usesDoubleElim) {
      final gf = grandFinalFixture;
      if (gf == null || !gf.isPlayed || gf.score1 == gf.score2) return null;
      return gf.score1 > gf.score2 ? gf.player1Id : gf.player2Id;
    }
    final f = finalFixture;
    if (f == null || !f.isPlayed || f.score1 == f.score2) return null;
    return f.score1 > f.score2 ? f.player1Id : f.player2Id;
  }

  String? get runnerUpId {
    if (usesDoubleElim) {
      final gf = grandFinalFixture;
      if (gf == null || !gf.isPlayed || gf.score1 == gf.score2) return null;
      return gf.score1 > gf.score2 ? gf.player2Id : gf.player1Id;
    }
    final f = finalFixture;
    if (f == null || !f.isPlayed || f.score1 == f.score2) return null;
    return f.score1 > f.score2 ? f.player2Id : f.player1Id;
  }

  LeaguePlayer? get championPlayer => playerById(championId);
  LeaguePlayer? get runnerUpPlayer => playerById(runnerUpId);

  LeaguePlayer? playerById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<LeaguePlayer> playersInGroup(LeagueGroup group) {
    final ids = group.playerIds.toSet();
    return players.where((p) => ids.contains(p.id)).toList(growable: false);
  }

  LeagueState copyWith({
    String? id,
    String? name,
    LeagueStatus? status,
    LeaguePhase? phase,
    LeagueFormat? format,
    int? groupSize,
    List<LeaguePlayer>? players,
    List<LeagueGroup>? groups,
    List<MatchFixture>? fixtures,
    List<String>? knockoutByePlayerIds,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    return LeagueState(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      format: format ?? this.format,
      groupSize: groupSize ?? this.groupSize,
      players: players ?? this.players,
      groups: groups ?? this.groups,
      fixtures: fixtures ?? this.fixtures,
      knockoutByePlayerIds: knockoutByePlayerIds ?? this.knockoutByePlayerIds,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'status': status.name,
    'phase': phase.name,
    'format': format.name,
    'groupSize': groupSize,
    'players': players.map((p) => p.toJson()).toList(),
    'groups': groups.map((g) => g.toJson()).toList(),
    'fixtures': fixtures.map((f) => f.toJson()).toList(),
    'knockoutByePlayerIds': knockoutByePlayerIds,
    'startedAt': startedAt?.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
  };

  factory LeagueState.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String?;
    // Missing field (legacy/empty save) → default setup.
    // Field present nhưng giá trị lạ → throw, KHÔNG silently coerce
    // (tránh user mất dữ liệu in-progress khi tương lai rename enum).
    final LeagueStatus status;
    if (statusName == null) {
      status = LeagueStatus.setup;
    } else {
      status = LeagueStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => throw FormatException(
          'LeagueState.fromJson: unknown status "$statusName".',
        ),
      );
    }
    final phase = _parsePhase(json['phase']);
    final format = _parseFormat(json['format'], json);
    final startedAt = _parseDate(json['startedAt']);
    // Backward compat: payload cũ chưa có `id` → suy id từ startedAt để
    // không vỡ history và active leagues đã lưu từ phiên trước.
    // `id` tolerant: phải là String non-empty mới dùng; mọi giá trị
    // khác (null / int / sai type / empty string) → fallback _legacyId.
    final rawIdValue = json['id'];
    final id = (rawIdValue is String && rawIdValue.isNotEmpty)
        ? rawIdValue
        : _legacyId(startedAt, json);
    return LeagueState(
      id: id,
      name: json['name'] as String? ?? '',
      status: status,
      phase: phase,
      format: format,
      groupSize: json['groupSize'] as int? ?? 0,
      players: (json['players'] as List<dynamic>? ?? const [])
          .map((e) => LeaguePlayer.fromJson(e as Map<String, dynamic>))
          .toList(),
      groups: (json['groups'] as List<dynamic>? ?? const [])
          .map((e) => LeagueGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
      fixtures: (json['fixtures'] as List<dynamic>? ?? const [])
          .map((e) => MatchFixture.fromJson(e as Map<String, dynamic>))
          .toList(),
      knockoutByePlayerIds:
          (json['knockoutByePlayerIds'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(),
      startedAt: startedAt,
      finishedAt: _parseDate(json['finishedAt']),
    );
  }

  static LeaguePhase _parsePhase(Object? raw) {
    if (raw == null) return LeaguePhase.roundRobin;
    final name = raw as String;
    return LeaguePhase.values.firstWhere(
      (p) => p.name == name,
      orElse: () =>
          throw FormatException('LeagueState.fromJson: unknown phase "$name".'),
    );
  }

  /// Format có thể thiếu ở payload legacy → suy từ field khác: có `groups`
  /// → groupKnockout, có `fixtures` với bracketSide != none → doubleElim,
  /// còn lại → roundRobin.
  static LeagueFormat _parseFormat(Object? raw, Map<String, dynamic> json) {
    if (raw is String) {
      for (final f in LeagueFormat.values) {
        if (f.name == raw) return f;
      }
    }
    final groups = json['groups'] as List<dynamic>? ?? const [];
    if (groups.isNotEmpty) return LeagueFormat.groupKnockout;
    final fixtures = json['fixtures'] as List<dynamic>? ?? const [];
    for (final f in fixtures) {
      if (f is Map<String, dynamic>) {
        final b = f['bracketSide'];
        if (b is String && b != BracketSide.none.name) {
          return LeagueFormat.doubleElim;
        }
      }
    }
    return LeagueFormat.roundRobin;
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw);
  }

  /// Sinh id ổn định cho payload thiếu `id`. Ưu tiên `startedAt` nếu có
  /// (deterministic across loads). Nếu null, dùng hash của payload còn
  /// lại để tránh nhiều legacy entry collapse vào cùng `lg_legacy_unknown`
  /// (sẽ bị upsert/remove nhầm chéo).
  static String _legacyId(DateTime? startedAt, Map<String, dynamic> json) {
    if (startedAt != null) {
      return 'lg_legacy_${startedAt.microsecondsSinceEpoch}';
    }
    // Hash phần content còn lại (loại bỏ id rỗng để hash đối xứng giữa
    // các lần encode/decode).
    final stable = Map<String, dynamic>.from(json)..remove('id');
    return 'lg_legacy_${jsonEncode(stable).hashCode.toRadixString(36)}';
  }
}
