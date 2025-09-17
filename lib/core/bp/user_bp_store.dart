// 📍 lib/core/bp/user_bp_store.dart (전체 파일)

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserBpStore {
  static const _kTotal = 'user_bp_total';
  static const _kLog = 'user_bp_log';
  static const _kCompleted = 'user_bp_completed';

  static String _key(String userKey, String field) => '${field}_$userKey';

  static Future<int> total(String userKey) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_key(userKey, _kTotal)) ?? 0;
  }

  static Future<void> add(String userKey, int amount, {String? note}) async {
    final p = await SharedPreferences.getInstance();
    final current = await total(userKey);
    await p.setInt(_key(userKey, _kTotal), current + amount);
  }

  // ✨ [추가] 교육/퀴즈 완료 여부를 확인하는 함수
  static Future<bool> hasCompleted(String userKey, String contentId) async {
    final p = await SharedPreferences.getInstance();
    final completed = p.getStringList(_key(userKey, _kCompleted)) ?? [];
    return completed.contains(contentId);
  }

  // ✨ [추가] 처음 완료한 콘텐츠에 대해서만 BP를 지급하는 함수
  static Future<int> awardIfFirst(String userKey, String contentId, int amount) async {
    final p = await SharedPreferences.getInstance();
    final completed = p.getStringList(_key(userKey, _kCompleted)) ?? [];

    if (completed.contains(contentId)) {
      return await total(userKey); // 이미 완료했다면 현재 점수만 반환
    }

    await add(userKey, amount, note: '콘텐츠 완료: $contentId');
    completed.add(contentId);
    await p.setStringList(_key(userKey, _kCompleted), completed);
    return await total(userKey);
  }
}