import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cash_config.dart';

/// Lưu/đọc mức tiền Chơi điểm gần nhất (tiền/ván + tiền/lỗ 10) để auto-fill
/// Setup screen lần sau — mỗi quán mức cược khác nhau, ít đổi.
class CashConfigStorage {
  CashConfigStorage._();

  static const _storageKey = 'cash_config_v1';

  static Future<CashConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return CashConfig.fromJson(map);
    } catch (_) {
      await clear();
      return null;
    }
  }

  static Future<void> save(CashConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(config.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
