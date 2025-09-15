import 'package:shared_preferences/shared_preferences.dart';

class UserBpStore {
  static String _kTotal(String u) => 'bp_total_u_$u';

  static Future<int> total(String userKey) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kTotal(userKey)) ?? 0;
  }

  static Future<void> add(String userKey, int delta, {String? note}) async {
    final p = await SharedPreferences.getInstance();
    final cur = p.getInt(_kTotal(userKey)) ?? 0;
    await p.setInt(_kTotal(userKey), cur + delta);
    // (원하면 적립 로그도 별도 키로 관리 가능)
  }

  static Future<void> clear(String userKey) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kTotal(userKey));
  }
}
