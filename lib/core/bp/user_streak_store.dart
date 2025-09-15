import 'package:shared_preferences/shared_preferences.dart';

class UserStreakStore {
  static String _kDays(String u) => 'streak_days_u_$u';
  static String _kLast(String u) => 'streak_last_u_$u';

  static String _todayYmd() {
    final d = DateTime.now();
    return '${d.year}${d.month.toString().padLeft(2,'0')}${d.day.toString().padLeft(2,'0')}';
  }

  static Future<(int days, String? lastYmd)> info(String u) async {
    final p = await SharedPreferences.getInstance();
    return (p.getInt(_kDays(u)) ?? 0, p.getString(_kLast(u)));
  }

  static Future<void> markToday(String u) async {
    final p = await SharedPreferences.getInstance();
    final today = _todayYmd();
    final last  = p.getString(_kLast(u));
    int days    = p.getInt(_kDays(u)) ?? 0;

    if (last == today) return; // 이미 오늘 반영

    DateTime parseYmd(String ymd) => DateTime(
      int.parse(ymd.substring(0,4)),
      int.parse(ymd.substring(4,6)),
      int.parse(ymd.substring(6,8)),
    );

    if (last != null) {
      final lastDate = parseYmd(last);
      final yday     = DateTime.now().subtract(const Duration(days: 1));
      final cont = lastDate.year == yday.year &&
          lastDate.month == yday.month &&
          lastDate.day == yday.day;
      days = cont ? days + 1 : 1;
    } else {
      days = 1;
    }

    await p.setInt(_kDays(u), days);
    await p.setString(_kLast(u), today);
  }
}
