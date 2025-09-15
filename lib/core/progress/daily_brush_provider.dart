import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyBrushProvider extends ChangeNotifier {
  static const _kKeyDate = 'daily_brush_date';
  static const _kKeyCount = 'daily_brush_count';
  static const int maxPerDay = 3;

  DateTime _today = _dateOnly(DateTime.now());
  int _count = 0;

  int get count => _count;
  int get left => (maxPerDay - _count).clamp(0, maxPerDay);

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final saved = sp.getString(_kKeyDate);
    final savedDate = saved == null ? null : DateTime.tryParse(saved);
    final savedCount = sp.getInt(_kKeyCount) ?? 0;

    final today = _dateOnly(DateTime.now());
    _today = today;

    if (savedDate != null && _dateOnly(savedDate) == today) {
      _count = savedCount.clamp(0, maxPerDay);
    } else {
      _count = 0; // 새로운 하루
      await _persist(sp);
    }
    notifyListeners();
  }

  Future<void> completeOne() async {
    if (_count >= maxPerDay) return;
    _count++;
    final sp = await SharedPreferences.getInstance();
    await _persist(sp);
    notifyListeners();
  }

  Future<void> _persist(SharedPreferences sp) async {
    await sp.setString(_kKeyDate, _today.toIso8601String());
    await sp.setInt(_kKeyCount, _count);
  }
}
