// 📍 lib/core/records/brush_record_store.dart (디버깅용)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BrushSlot { morning, noon, night }

class BrushRecord {
  final DateTime timestamp;
  final List<double> scores;
  final int durationSec;

  BrushRecord({
    required this.timestamp,
    required this.scores,
    required this.durationSec,
  });

  double get avgScore => scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;

  BrushSlot get slot {
    final hour = timestamp.hour;
    if (hour < 12) return BrushSlot.morning;
    if (hour < 18) return BrushSlot.noon;
    return BrushSlot.night;
  }

  Map<String, dynamic> toJson() => {
    'ts': timestamp.toIso8601String(),
    'scores': scores,
    'secs': durationSec,
  };

  factory BrushRecord.fromJson(Map<String, dynamic> json) {
    // ✨ [디버그] 어떤 데이터에서 오류가 나는지 확인하기 위해 로그를 추가합니다.
    debugPrint('--> [DEBUG] Parsing Record: $json');
    try {
      final scoresList = json['scores'] as List;
      final scores = scoresList.map((s) => (s as num).toDouble()).toList();

      return BrushRecord(
        timestamp: DateTime.parse(json['ts']),
        scores: scores,
        durationSec: json['secs'],
      );
    } catch (e) {
      debugPrint('--> [DEBUG] FAILED to parse BrushRecord. Error: $e');
      return BrushRecord(
        timestamp: DateTime.now(),
        scores: [],
        durationSec: 0,
      );
    }
  }
}

class BrushRecordStore {
  static Future<List<BrushRecord>> getRecords(String userKey) async {
    final p = await SharedPreferences.getInstance();
    final jsonString = p.getString('records_$userKey');

    // ✨ [디버그] 저장된 원본 데이터를 확인하기 위해 로그를 추가합니다.
    debugPrint('--> [DEBUG] Raw JSON data for $userKey: $jsonString');

    if (jsonString == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => BrushRecord.fromJson(json)).where((record) => record.scores.isNotEmpty).toList();
    } catch (e) {
      debugPrint("Error parsing records for $userKey, clearing data: $e");
      await p.remove('records_$userKey');
      return [];
    }
  }

  static Future<void> addRecord(String userKey, BrushRecord record) async {
    final p = await SharedPreferences.getInstance();
    final records = await getRecords(userKey);
    records.add(record);
    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final List<Map<String, dynamic>> jsonList = records.map((r) => r.toJson()).toList();
    await p.setString('records_$userKey', jsonEncode(jsonList));
  }

  static Future<int> getTodayBrushCount(String userKey) async {
    final records = await getRecords(userKey);
    final todayKey = dayKey(DateTime.now());
    return records.where((r) => dayKey(r.timestamp) == todayKey).length;
  }

  static String dayKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}