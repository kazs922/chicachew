import 'package:shared_preferences/shared_preferences.dart';

class ActiveProfileStore {
  static const _kActiveIdx = 'active_profile_idx';

  static Future<int?> getIndex() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kActiveIdx);
  }

  static Future<void> setIndex(int idx) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kActiveIdx, idx);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kActiveIdx);
  }
}
