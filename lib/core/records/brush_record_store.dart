// 📍 lib/core/records/brush_record_store.dart (전체 파일)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 아침, 점심, 저녁을 구분하는 enum
enum BrushSlot { morning, noon, night }

// 단일 양치 기록을 저장하는 데이터 클래스
class BrushRecord {
  final DateTime timestamp;
  final List<double> scores;
  final int durationSec;

  BrushRecord({
    required this.timestamp,
    required this.scores,
    required this.durationSec,
  });

  // 점수 평균을 0~1 사이 값으로 계산
  double get avgScore => scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;

  // 시간대에 따라 slot 결정
  BrushSlot get slot {
    final hour = timestamp.hour;
    if (hour < 12) return BrushSlot.morning;
    if (hour < 18) return BrushSlot.noon;
    return BrushSlot.night;
  }

  // 데이터를 JSON 형태로 변환 (저장용)
  Map<String, dynamic> toJson() => {
    'ts': timestamp.toIso8601String(),
    'scores': scores,
    'secs': durationSec,
  };

  // JSON 형태에서 데이터로 변환 (불러오기용)
  factory BrushRecord.fromJson(Map<String, dynamic> json) => BrushRecord(
    timestamp: DateTime.parse(json['ts']),
    scores: List<double>.from(json['scores']),
    durationSec: json['secs'],
  );
}

// 사용자별 양치 기록을 관리하는 클래스
class BrushRecordStore {
  // 특정 사용자의 모든 기록을 불러오는 함수
  static Future<List<BrushRecord>> getRecords(String userKey) async {
    final p = await SharedPreferences.getInstance();
    final jsonString = p.getString('records_$userKey');
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => BrushRecord.fromJson(json)).toList();
  }

  // 특정 사용자에게 새로운 기록을 추가하는 함수
  static Future<void> addRecord(String userKey, BrushRecord record) async {
    final p = await SharedPreferences.getInstance();
    final records = await getRecords(userKey);
    records.add(record);
    // 시간순으로 정렬
    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final List<Map<String, dynamic>> jsonList = records.map((r) => r.toJson()).toList();
    await p.setString('records_$userKey', jsonEncode(jsonList));
  }

  // 특정 사용자의 오늘 양치 횟수를 반환하는 함수
  static Future<int> getTodayBrushCount(String userKey) async {
    final records = await getRecords(userKey);
    final todayKey = dayKey(DateTime.now());
    return records.where((r) => dayKey(r.timestamp) == todayKey).length;
  }

  // 날짜를 YYYY-MM-DD 형식의 문자열로 변환
  static String dayKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}