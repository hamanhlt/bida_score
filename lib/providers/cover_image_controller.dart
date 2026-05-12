import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/cover_image_storage.dart';

/// Seed cho [coverImageProvider] — override ở `main.dart` sau khi load từ
/// SharedPreferences. Null = chưa set ảnh tuỳ chỉnh → màn chính dùng
/// banner mặc định `assets/banner.jpg`.
final coverImageSeedProvider = Provider<Uint8List?>((_) => null);

/// Bytes ảnh bìa tuỳ chỉnh. Null → banner mặc định.
///
/// Cold start: load từ disk qua [coverImageSeedProvider].
/// Trong session: [CoverImageNotifier.set]/[CoverImageNotifier.clearCustom]
/// cập nhật state in-memory + ghi disk.
final coverImageProvider =
    NotifierProvider<CoverImageNotifier, Uint8List?>(CoverImageNotifier.new);

class CoverImageNotifier extends Notifier<Uint8List?> {
  @override
  Uint8List? build() => ref.read(coverImageSeedProvider);

  /// Đặt ảnh bìa mới (bytes đã được resize bởi ImagePicker). Persist fire-and-forget.
  void set(Uint8List bytes) {
    state = bytes;
    unawaited(CoverImageStorage.save(bytes));
  }

  /// Xoá ảnh tuỳ chỉnh → quay về banner mặc định.
  void clearCustom() {
    state = null;
    unawaited(CoverImageStorage.clear());
  }
}
