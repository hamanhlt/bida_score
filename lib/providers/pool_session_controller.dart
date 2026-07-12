import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pool_session.dart';
import '../services/pool_session_storage.dart';

/// Seed cho [poolSessionControllerProvider] — preload session từ disk ở
/// `main.dart`.
final poolSessionSeedProvider = Provider<PoolSessionData?>((_) => null);

/// Quản lý view mode + currentId của Pool shell. Auto-persist.
final poolSessionControllerProvider =
    NotifierProvider<PoolSessionController, PoolSessionData>(
      PoolSessionController.new,
    );

class PoolSessionController extends Notifier<PoolSessionData> {
  @override
  PoolSessionData build() {
    listenSelf((_, next) {
      unawaited(PoolSessionStorage.save(next));
    });
    return ref.read(poolSessionSeedProvider) ?? PoolSessionData.initial();
  }

  /// Quay về list view, clear currentId.
  void goToList() {
    state = const PoolSessionData(
      viewMode: PoolViewMode.list,
      currentId: null,
    );
  }

  /// Mở 1 trận có sẵn (id) → routing thấy status=inProgress/finished tuỳ state.
  void openCurrent(String id) {
    state = PoolSessionData(
      viewMode: PoolViewMode.current,
      currentId: id,
    );
  }

  /// Tạo trận mới: viewMode=current, currentId=null → routing thấy
  /// NineBallState.status=setup → NineBallSetupScreen.
  void openNewSetup() {
    state = const PoolSessionData(
      viewMode: PoolViewMode.current,
      currentId: null,
    );
  }
}
