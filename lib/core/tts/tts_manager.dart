import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../features/brush_guide/application/story_director.dart' show Speaker;

class TtsManager {
  TtsManager._();
  static final TtsManager instance = TtsManager._();

  final FlutterTts _tts = FlutterTts();
  bool _inited = false;

  // 치카츄: 남자 3 + 여자 1을 순환
  final List<Map<String, String>> _poolChMale = [];
  final List<Map<String, String>> _poolChFemale = [];
  int _roundRobinIdx = 0;

  // 캐비티몬: 저음 남성 1
  Map<String, String>? _cavityVoice;

  // ===== 초기화 =====
  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);

    // iOS: 무음 스위치/다른 소리와 믹스 허용
    try {
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );
    } catch (_) {}

    await _scanVoices();
  }

  Future<void> dispose() async {
    try { await _tts.stop(); } catch (_) {}
  }

  // ===== 퍼블릭 API =====
  Future<void> speak(String text, {Speaker speaker = Speaker.narrator, bool interrupt = true}) async {
    await init();
    if (interrupt) {
      try { await _tts.stop(); } catch (_) {}
    }

    // 1) 화자별 보이스 선택
    final voice = _pickVoice(speaker);
    if (voice != null) {
      try { await _tts.setVoice({"name": voice["name"]!, "locale": voice["locale"]!}); } catch (_) {}
    }

    // 2) 화자별 톤(피치/속도)
    await _applyTone(speaker);

    // 3) 발화
    try { await _tts.speak(text); } catch (_) {}
  }

  // ===== 내부: 보이스 스캔 & 분류 =====
  Future<void> _scanVoices() async {
    List<dynamic>? raw;
    try {
      final v = await _tts.getVoices; // 플랫폼별 map 스키마가 조금씩 다름
      raw = (v as List?) ?? const [];
    } catch (_) {
      raw = const [];
    }
    if (raw.isEmpty) return;

    final kor = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map) {
        final name = '${e["name"] ?? e["VoiceName"] ?? ""}';
        final locale = '${e["locale"] ?? e["Locale"] ?? ""}'.toLowerCase();
        if (locale.startsWith('ko')) {
          final gender = (e["gender"] ?? e["Gender"] ?? '').toString().toLowerCase();
          kor.add({"name": name, "locale": locale, "gender": gender});
        }
      }
    }

    // 분류
    final male = <Map<String, String>>[];
    final female = <Map<String, String>>[];

    // 이름 기반 힌트(엔진별로 성별키가 없을 때 대비)
    final maleHints = [
      'male','man','minsu','minsik','minsoo','jinho','hyun','seojun','jun','tae','yong','dae','won','ho','seung'
    ];
    final femaleHints = [
      'female','woman','yuna','yuri','sora','mijin','nari','yejin','hana','minji','eun','ara','soyeon','jiyun'
    ];

    String _guess(Map<String,dynamic> m) {
      final g = (m['gender'] ?? '').toString().toLowerCase();
      if (g.contains('male')) return 'male';
      if (g.contains('female')) return 'female';
      final n = (m['name'] ?? '').toString().toLowerCase();
      if (maleHints.any((h) => n.contains(h))) return 'male';
      if (femaleHints.any((h) => n.contains(h))) return 'female';
      // Android Google TTS ko-kr-x-??? 패턴: 성별 표기 없으면 랜덤 분산
      return (n.hashCode % 2 == 0) ? 'male' : 'female';
    }

    for (final m in kor) {
      final g = _guess(m);
      final v = {"name": m["name"].toString(), "locale": m["locale"].toString()};
      if (g == 'male') male.add(v); else female.add(v);
    }

    // 치카츄 풀 구성: 남 3, 여 1 (없으면 가능한 만큼만)
    _poolChMale
      ..clear()
      ..addAll(male.take(3));
    _poolChFemale
      ..clear()
      ..addAll(female.take(1));

    // ── 캐비티몬: 남성 선호(가능하면 deep/low/bass/male 이름), 없으면 남성 아무거나, 그것도 없으면 여성 1개
    Map<String, String>? cavity;
    if (male.isNotEmpty) {
      cavity = male.firstWhere(
            (v) {
          final n = (v['name'] ?? '').toLowerCase();
          return n.contains('deep') || n.contains('low') || n.contains('bass') || n.contains('male');
        },
        orElse: () => male.first, // 남성 리스트가 비어있지 않으므로 non-null
      );
    } else if (female.isNotEmpty) {
      cavity = female.first;
    } else {
      cavity = null;
    }
    _cavityVoice = cavity;

    if (kDebugMode) {
      debugPrint('[TTS] Korean voices=${kor.length}  male=${male.length}  female=${female.length}');
      debugPrint('[TTS] chikachu male pool=${_poolChMale.map((e)=>e['name']).toList()}');
      debugPrint('[TTS] chikachu female pool=${_poolChFemale.map((e)=>e['name']).toList()}');
      debugPrint('[TTS] cavity voice=${_cavityVoice?['name']}');
    }
  }

  Map<String,String>? _pickVoice(Speaker s) {
    switch (s) {
      case Speaker.chikachu:
      // 남3 + 여1 라운드로빈
        final cycle = [..._poolChMale, ..._poolChFemale];
        if (cycle.isEmpty) return null;
        final v = cycle[_roundRobinIdx % cycle.length];
        _roundRobinIdx++;
        return v;

      case Speaker.cavitymon:
        return _cavityVoice;

      case Speaker.narrator:
      // 내레이터는 굳이 고정 안 함(기본 보이스 사용)
        return null;
    }
  }

  Future<void> _applyTone(Speaker s) async {
    switch (s) {
      case Speaker.chikachu:
        await _tts.setPitch(1.14);       // 밝고 경쾌
        await _tts.setSpeechRate(0.52);
        break;
      case Speaker.cavitymon:
        await _tts.setPitch(0.9);        // 낮고 위협적인 톤
        await _tts.setSpeechRate(0.47);
        break;
      case Speaker.narrator:
        await _tts.setPitch(1.0);
        await _tts.setSpeechRate(0.5);
        break;
    }
  }
}
