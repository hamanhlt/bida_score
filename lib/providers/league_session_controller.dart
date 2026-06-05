import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/league_session.dart';
import '../services/league_session_storage.dart';

/// Seed cho [leagueSessionControllerProvider] — preload session từ disk
/// ở `main.dart`.
final leagueSessionSeedProvider = Provider<LeagueSessionData?>((_) => null);

/// Quản lý view mode + currentId của League shell. Auto-persist.
final leagueSessionControllerProvider =
    NotifierProvider<LeagueSessionController, LeagueSessionData>(
      LeagueSessionController.new,
    );

class LeagueSessionController extends Notifier<LeagueSessionData> {
  @override
  LeagueSessionData build() {
    listenSelf((_, next) {
      unawaited(LeagueSessionStorage.save(next));
    });
    return ref.read(leagueSessionSeedProvider) ?? LeagueSessionData.initial();
  }

  /// Quay về list view, clear currentId.
  void goToList() {
    state = const LeagueSessionData(
      viewMode: LeagueViewMode.list,
      currentId: null,
    );
  }

  /// Mở 1 giải có sẵn (id) → routing sẽ thấy status=inProgress hoặc
  /// finished tuỳ league state.
  void openCurrent(String id) {
    state = LeagueSessionData(
      viewMode: LeagueViewMode.current,
      currentId: id,
    );
  }

  /// Tạo giải mới: viewMode=current, currentId=null → routing thấy
  /// LeagueState.status=setup → LeagueSetupScreen.
  void openNewSetup() {
    state = const LeagueSessionData(
      viewMode: LeagueViewMode.current,
      currentId: null,
    );
  }
}
