import 'dart:convert';

import 'league_group.dart';
import 'league_player.dart';
import 'match_fixture.dart';

enum LeagueStatus { setup, inProgress, finished }

enum LeaguePhase { roundRobin, groupStage, knockout }

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
    this.groupSize = 0,
    List<LeaguePlayer> players = const [],
    List<LeagueGroup> groups = const [],
    List<MatchFixture> fixtures = const [],
    this.startedAt,
    this.finishedAt,
  }) : players = List.unmodifiable(players),
       groups = List.unmodifiable(groups),
       fixtures = List.unmodifiable(fixtures);

  factory LeagueState.initial() => LeagueState();

  /// Id rỗng cho state khởi tạo (chưa start tournament). Engine luôn gán id
  /// non-empty khi `startTournament` chạy.
  final String id;
  final String name;
  final LeagueStatus status;
  final LeaguePhase phase;
  final int groupSize;
  final List<LeaguePlayer> players;
  final List<LeagueGroup> groups;
  final List<MatchFixture> fixtures;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  bool get isFinished => status == LeagueStatus.finished;
  bool get usesGroupStage => groups.isNotEmpty;
  String get displayName => name.trim().isEmpty ? 'Giải đấu' : name.trim();

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
    return finalFixture != null &&
        finalFixture.isPlayed &&
        finalFixture.score1 != finalFixture.score2;
  }

  String get phaseLabel {
    if (!usesGroupStage) return 'Vòng tròn';
    return switch (phase) {
      LeaguePhase.groupStage => 'Vòng bảng',
      LeaguePhase.knockout => 'Knockout',
      LeaguePhase.roundRobin => 'Vòng tròn',
    };
  }

  MatchFixture? get finalFixture {
    if (knockoutFixtures.isEmpty) return null;
    final sorted = [...knockoutFixtures]
      ..sort((a, b) => b.roundIndex.compareTo(a.roundIndex));
    final highestRound = sorted.first.roundIndex;
    final candidates = sorted
        .where((f) => f.roundIndex == highestRound)
        .toList();
    return candidates.length == 1 ? candidates.first : null;
  }

  String? get championId {
    final f = finalFixture;
    if (f == null || !f.isPlayed || f.score1 == f.score2) return null;
    return f.score1 > f.score2 ? f.player1Id : f.player2Id;
  }

  String? get runnerUpId {
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
    int? groupSize,
    List<LeaguePlayer>? players,
    List<LeagueGroup>? groups,
    List<MatchFixture>? fixtures,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    return LeagueState(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      groupSize: groupSize ?? this.groupSize,
      players: players ?? this.players,
      groups: groups ?? this.groups,
      fixtures: fixtures ?? this.fixtures,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'status': status.name,
    'phase': phase.name,
    'groupSize': groupSize,
    'players': players.map((p) => p.toJson()).toList(),
    'groups': groups.map((g) => g.toJson()).toList(),
    'fixtures': fixtures.map((f) => f.toJson()).toList(),
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
