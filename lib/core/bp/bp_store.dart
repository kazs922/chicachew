// lib/core/bp/bp_store.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// BP 이벤트(히스토리) 모델
class BpEvent {
  final String type;      // 'award','bonus','spend','item_add','unlock','reset'
  final int delta;        // BP 증감(소비는 음수)
  final String ts;        // ISO8601
  final String? contentId;
  final String? note;

  BpEvent({required this.type, required this.delta, required this.ts, this.contentId, this.note});

  Map<String, dynamic> toJson() => {
    'type': type,
    'delta': delta,
    'ts': ts,
    'contentId': contentId,
    'note': note,
  };

  factory BpEvent.fromJson(Map<String, dynamic> j) => BpEvent(
    type: j['type'] as String,
    delta: (j['delta'] as num).toInt(),
    ts: j['ts'] as String,
    contentId: j['contentId'] as String?,
    note: j['note'] as String?,
  );
}

class BpStore {
  static const _kTotal = 'bp_total';
  static const _kDoneIds = 'bp_done_ids';
  static const _kInventory = 'bp_inventory';
  static const _kLedger = 'bp_ledger'; // StringList(JSON)

  /// 총 BP
  static Future<int> total() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kTotal) ?? 0;
  }

  /// 완료 중복 방지 체크
  static Future<bool> hasCompleted(String contentId) async {
    final p = await SharedPreferences.getInstance();
    final done = p.getStringList(_kDoneIds) ?? const [];
    return done.contains(contentId);
  }

  /// 최초 1회만 적립 + 히스토리 기록
  static Future<int> awardIfFirst(String contentId, int delta) async {
    final p = await SharedPreferences.getInstance();
    final done = p.getStringList(_kDoneIds) ?? <String>[];
    if (!done.contains(contentId)) {
      done.add(contentId);
      await p.setStringList(_kDoneIds, done);
      final next = (p.getInt(_kTotal) ?? 0) + delta;
      await p.setInt(_kTotal, next);
      await _pushEvent(BpEvent(
        type: 'award',
        delta: delta,
        ts: DateTime.now().toIso8601String(),
        contentId: contentId,
        note: '콘텐츠 완료 적립',
      ));
      return next;
    }
    return p.getInt(_kTotal) ?? 0;
  }

  /// 임의 보너스(스트릭 등)
  static Future<int> add(int delta, {String? note}) async {
    final p = await SharedPreferences.getInstance();
    final next = (p.getInt(_kTotal) ?? 0) + delta;
    await p.setInt(_kTotal, next);
    await _pushEvent(BpEvent(
      type: 'bonus',
      delta: delta,
      ts: DateTime.now().toIso8601String(),
      note: note ?? '보너스',
    ));
    return next;
  }

  /// BP 지불(성공 시 true) + 히스토리 기록
  static Future<bool> spendIfEnough(int cost, {String? note}) async {
    final p = await SharedPreferences.getInstance();
    final cur = (p.getInt(_kTotal) ?? 0);
    if (cur < cost) return false;
    await p.setInt(_kTotal, cur - cost);
    await _pushEvent(BpEvent(
      type: 'spend',
      delta: -cost,
      ts: DateTime.now().toIso8601String(),
      note: note ?? '구매',
    ));
    return true;
  }

  /// 인벤토리
  static Future<List<String>> inventory() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_kInventory) ?? const [];
  }

  static Future<void> addItem(String itemId, {String? note}) async {
    final p = await SharedPreferences.getInstance();
    final inv = p.getStringList(_kInventory) ?? <String>[];
    if (!inv.contains(itemId)) {
      inv.add(itemId);
      await p.setStringList(_kInventory, inv);
      await _pushEvent(BpEvent(
        type: 'item_add',
        delta: 0,
        ts: DateTime.now().toIso8601String(),
        contentId: itemId,
        note: note ?? '아이템 획득',
      ));
    }
  }

  /// 레슨/콘텐츠 해금 표식
  static Future<void> unlock(String lessonId, {String? note}) async {
    await addItem('unlock_$lessonId', note: note ?? '레슨 해금');
    await _pushEvent(BpEvent(
      type: 'unlock',
      delta: 0,
      ts: DateTime.now().toIso8601String(),
      contentId: lessonId,
      note: '레슨 해금',
    ));
  }

  /// 히스토리(최신순)
  static Future<List<BpEvent>> ledger() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_kLedger) ?? const [];
    final list = <BpEvent>[];
    for (final s in raw) {
      try { list.add(BpEvent.fromJson(jsonDecode(s))); } catch (_) {}
    }
    list.sort((a, b) => b.ts.compareTo(a.ts));
    return list;
  }

  static Future<void> _pushEvent(BpEvent e) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_kLedger) ?? <String>[];
    raw.add(jsonEncode(e.toJson()));
    await p.setStringList(_kLedger, raw);
  }

  /// (개발용) 전체 초기화
  static Future<void> resetAll() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kTotal);
    await p.remove(_kDoneIds);
    await p.remove(_kInventory);
    await p.remove(_kLedger);
    await _pushEvent(BpEvent(
      type: 'reset',
      delta: 0,
      ts: DateTime.now().toIso8601String(),
      note: '개발용 리셋',
    ));
  }
}
