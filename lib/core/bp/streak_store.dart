// lib/core/bp/streak_store.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chicachew/core/bp/bp_store.dart';

class StreakStore {
  static const _kLast = 'streak_last';
  static const _kDays = 'streak_days';
  static const _kBest = 'streak_best';

  /// 오늘 최초 체크 시 BP 보너스 지급
  /// 기본: 일일 +3BP, 7일마다 +20BP 추가
  static Future<int> updateTodayAndBonus() async {
    final p = await SharedPreferences.getInstance();
    final today = DateUtils.dateOnly(DateTime.now());
    final todayStr = today.toIso8601String().substring(0, 10);

    final lastStr = p.getString(_kLast);
    int days = p.getInt(_kDays) ?? 0;

    if (lastStr == todayStr) {
      return days == 0 ? 1 : days;
    }

    if (lastStr != null) {
      final last = DateTime.tryParse(lastStr);
      final diff = last == null ? 999 : today.difference(DateUtils.dateOnly(last)).inDays;
      days = (diff == 1) ? days + 1 : 1;
    } else {
      days = 1;
    }

    await p.setString(_kLast, todayStr);
    await p.setInt(_kDays, days);
    final best = p.getInt(_kBest) ?? 0;
    if (days > best) await p.setInt(_kBest, days);

    int bonus = 3;
    if (days % 7 == 0) bonus += 20;
    await BpStore.add(bonus, note: '스트릭 ${days}일차 보너스');
    return days;
  }

  static Future<(int days, int best)> info() async {
    final p = await SharedPreferences.getInstance();
    return (p.getInt(_kDays) ?? 0, p.getInt(_kBest) ?? 0);
  }
}
