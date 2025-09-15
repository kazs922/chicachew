import 'package:flutter/foundation.dart';

/// 하루 3번 슬롯
enum BrushSlot { morning, noon, night }

/// (선택) 전역 dayKey가 필요하면 유지하세요. 사용 안 하면 삭제해도 됩니다.
DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

/// 싱글턴: 리포트/라이브브러쉬가 함께 쓰는 기록 스토어
class BrushRecordStore extends ChangeNotifier {
  BrushRecordStore._();
  static final BrushRecordStore instance = BrushRecordStore._();

  /// ✅ 추가: 외부에서 호출할 수 있는 정적 dayKey
  static DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 날짜별 완료 슬롯
  final Map<DateTime, Set<BrushSlot>> _records = {};

  Set<BrushSlot> slotsOn(DateTime day) =>
      _records[BrushRecordStore.dayKey(day)] ?? {};

  void _setSlots(DateTime day, Set<BrushSlot> next) {
    _records[BrushRecordStore.dayKey(day)] = next;
    notifyListeners();
  }

  /// 특정 슬롯 on/off
  void mark(DateTime day, BrushSlot slot, bool done) {
    final key = BrushRecordStore.dayKey(day);
    final cur = {...(_records[key] ?? <BrushSlot>{})};
    if (done) {
      cur.add(slot);
    } else {
      cur.remove(slot);
    }
    _setSlots(key, cur);
    // TODO: Firestore 저장 연동 지점
  }

  /// 현재 시각을 아침/점심/저녁으로 자동 분류해서 완료 처리
  void completeNow({DateTime? when}) {
    final t = when ?? DateTime.now();
    final slot = _autoSlot(t);
    mark(t, slot, true);
  }

  /// 월 이동 시 서버/DB에서 불러오고 메모리에 반영하는 훅
  Future<void> loadMonth(DateTime month) async {
    // TODO: Firestore에서 month 범위(1일 00:00 ~ 말일 23:59)만 읽어와 _records 갱신
    // 현재는 데모이므로 noop
    notifyListeners();
  }

  /// 시간대 기준 자동 매핑 (원하면 경계 조정)
  BrushSlot _autoSlot(DateTime t) {
    final h = t.hour;
    if (h >= 5 && h < 11) return BrushSlot.morning; // 05~10:59
    if (h >= 11 && h < 17) return BrushSlot.noon;   // 11~16:59
    return BrushSlot.night;                         // 17~04:59
  }
}
