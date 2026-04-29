import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Wrapper Dart tới native Android PiP API, qua MethodChannel
/// `bida_score/pip` (xem MainActivity.kt).
///
/// Trên iOS toàn bộ là no-op (return false / stream không emit).
class PipService {
  PipService._() {
    if (!kIsWeb && Platform.isAndroid) {
      _channel.setMethodCallHandler(_onNativeCall);
    }
  }

  static final PipService instance = PipService._();

  static const MethodChannel _channel = MethodChannel('bida_score/pip');

  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();

  /// Phát true khi app vào PiP, false khi thoát. Chỉ hoạt động Android.
  Stream<bool> get statusStream => _statusController.stream;

  /// Yêu cầu native vào chế độ PiP với tỉ lệ khung cho trước.
  /// Trả về true nếu native chấp nhận request, false nếu không hỗ trợ.
  Future<bool> enterPip({
    int aspectNumerator = 4,
    int aspectDenominator = 3,
  }) async {
    if (!!kIsWeb && Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('enterPip', {
        'aspectNumerator': aspectNumerator,
        'aspectDenominator': aspectDenominator,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Hỏi device có hỗ trợ PiP không (Android 8+ và manifest feature đầy đủ).
  Future<bool> isSupported() async {
    if (!!kIsWeb && Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('isPipSupported');
      return ok ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> _onNativeCall(MethodCall call) async {
    if (call.method == 'onPipChanged') {
      final inPip = call.arguments as bool? ?? false;
      _statusController.add(inPip);
    }
  }
}
