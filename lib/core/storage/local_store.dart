import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chicachew/core/storage/profile.dart'; // ✅ Profile 모델 불러오기

/// SharedPreferences 로컬 저장소
class LocalStore {
  static const _profilesKey = 'profiles';

  /// 프로필 리스트 저장
  Future<void> saveProfiles(List<Profile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final list = profiles.map((p) => p.toJson()).toList();
    await prefs.setString(_profilesKey, jsonEncode(list));
  }

  /// 프로필 리스트 불러오기
  Future<List<Profile>> getProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    if (raw == null) return [];
    try {
      final data = jsonDecode(raw);
      if (data is List) {
        return data
            .map((e) => Profile.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 프로필 전체 삭제
  Future<void> clearProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profilesKey);
  }

  /// 프로필 존재 여부 확인
  Future<bool> hasProfiles() async {
    final profiles = await getProfiles();
    return profiles.isNotEmpty;
  }
}
