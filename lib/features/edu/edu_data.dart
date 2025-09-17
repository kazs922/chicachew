// 📍 lib/features/edu/edu_data.dart (새로운 파일)

import 'dart:math';
import 'package:flutter/material.dart';

// (기존 education_page.dart에 있던 모든 데이터 클래스와 목록을 이곳으로 이동)

enum Audience { kid, parent }
enum MediaType { text, image, quiz }

class QuizItem {
  final String q;
  final List<String> options;
  final int answerIndex;
  QuizItem({required this.q, required this.options, required this.answerIndex});
}

class EduItem {
  final String id;
  final Audience audience;
  final String category;
  final String title;
  final int? durationSec;
  final MediaType media;
  final String body;
  final List<QuizItem>? quiz;

  EduItem({
    required this.id,
    required this.audience,
    required this.category,
    required this.title,
    required this.media,
    required this.body,
    this.durationSec,
    this.quiz,
  });
}

final List<QuizItem> kidQuizPool = [
  QuizItem(q: '치약은 어느 정도가 좋아요?', options: ['칫솔 가득', '콩알만큼', '안 써요'], answerIndex: 1),
  QuizItem(q: '양치는 몇 분이 좋아요?', options: ['30초', '1분', '2분'], answerIndex: 2),
  QuizItem(q: '칫솔은 어떻게 움직여요?', options: ['힘껏 세게', '작게 동그랗게', '빨리 쓱쓱'], answerIndex: 1),
  QuizItem(q: '가글은 어떻게 해야 해요?', options: ['삼키기', '뱉기', '물 많이 마시기'], answerIndex: 1),
  QuizItem(q: '양치 후 물 헹굼은?', options: ['아예 안 하기', '가볍게 한 번', '세 번 이상'], answerIndex: 1),
  QuizItem(q: '달콤한 음료는 어떻게 마실까요?', options: ['자주 조금씩', '식사와 함께/물 자주', '잠들기 전에'], answerIndex: 1),
  QuizItem(q: '칫솔 힘은 어느 정도가 좋아요?', options: ['아플 만큼 세게', '부드럽게', '아예 닿지 않게'], answerIndex: 1),
  QuizItem(q: '혀도 닦아야 하나요?', options: ['네, 가볍게', '아니요', '아플 때만'], answerIndex: 0),
  QuizItem(q: '치실은 언제 쓰면 좋을까요?', options: ['양치 후', '아침만', '안 써요'], answerIndex: 0),
  QuizItem(q: '칫솔은 얼마나 자주 바꿔요?', options: ['3개월마다', '1년마다', '안 바꿔요'], answerIndex: 0),
  QuizItem(q: '치약은 삼켜도 되나요?', options: ['조금은 괜찮아요', '삼키지 않아요', '많이 삼켜요'], answerIndex: 1),
  QuizItem(q: '이를 닦을 때 순서는?', options: ['아무렇게나', '앞/안/씹는 면 골고루', '윗니만'], answerIndex: 1),
];

String todayKey() {
  final d = DateUtils.dateOnly(DateTime.now());
  return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}

List<QuizItem> dailyKidQuiz({int count = 3}) {
  final pool = List<QuizItem>.from(kidQuizPool);
  if (pool.length <= count) return pool;
  final d = DateUtils.dateOnly(DateTime.now());
  final seed = d.millisecondsSinceEpoch;
  final rnd = Random(seed);
  for (int i = pool.length - 1; i > 0; i--) {
    final j = rnd.nextInt(i + 1);
    final tmp = pool[i];
    pool[i] = pool[j];
    pool[j] = tmp;
  }
  return pool.take(count).toList();
}

final List<EduItem> eduSeed = [
  EduItem(
    id: 'kid_baby_tooth_falls_01',
    audience: Audience.kid,
    category: 'growth',
    title: '치아가 빠져요: 걱정하지 마요!',
    media: MediaType.text,
    durationSec: 60,
    body: '''
• 6–12살 사이엔 유치가 "흔들흔들 → 빠짐"이 자연스러워요
• 손을 깨끗이 씻고, 부드럽게 "앞뒤로 살짝"만 움직여요
• 억지로 “쑥!” 뽑지 않기(피가 많이 나요)
• 빠지면 깨끗한 거즈/휴지로 5–10분 꾹 눌러요
• 오늘은 딱딱한 음식/빨대는 잠깐 쉬어요
• 양치는 빠진 자리만 살살, 나머지는 평소처럼
• 삼켰다면? 보통은 괜찮아요. 그래도 보호자에게 꼭 말해요
''',
  ),
  EduItem(
    id: 'kid_master_brush_01',
    audience: Audience.kid,
    category: 'habit',
    title: '양치 고수되기',
    media: MediaType.text,
    durationSec: 60,
    body: '''
• 2분 타이머 스타트! (앱 13구역 순서대로)
• 칫솔은 연필 잡듯, 작게 동그라미
• 어금니 깊숙이, 혀도 살짝
• 치약은 콩알만큼, 삼키지 않기
• 하루 한 번, 치실막대 "부드럽게"
• 오늘도 BP(Brush Points) 챙기기!
''',
  ),
  EduItem(
    id: 'kid_need_dentist_quiz_01',
    audience: Audience.kid,
    category: 'emergency',
    title: '치과 가야할까요? (퀴즈)',
    media: MediaType.quiz,
    durationSec: 60,
    body: '언제 치과에 가야 하는지 맞혀봐요!',
    quiz: [
      QuizItem(q: '넘어져서 이가 부러졌거나 많이 흔들려요!', options: ['그냥 참는다', '어른에게 말하고 치과에 간다', '내가 직접 뽑는다'], answerIndex: 1),
      QuizItem(q: '피가 10분 넘게 멈추지 않아요', options: ['집에서 계속 기다린다', '치과에 간다', '빨대로 피를 빨아본다'], answerIndex: 1),
      QuizItem(q: '조금 흔들리는 유치(아프지 않아요)', options: ['살살 흔들며 기다린다', '세게 잡아당겨 뽑는다', '양치를 멈춘다'], answerIndex: 0),
      QuizItem(q: '새(영구)이가 보이는데 유치가 안 빠져요', options: ['어른에게 말하고 치과 상담', '그냥 몇 달 더 기다림', '손으로 계속 밀어낸다'], answerIndex: 0),
    ],
  ),
  EduItem(
    id: 'kid_brush_steps_01',
    audience: Audience.kid,
    category: 'habit',
    title: '양치 2분! 이렇게 하면 쉬워요',
    media: MediaType.text,
    durationSec: 60,
    body: '''
• 윗니/아랫니 앞·안·씹는 면을 골고루 (총 2분)
• 칫솔은 살짝 기울여 작게 동그라미
• 힘 세게 X! 부드럽게 쓱쓱
• 치약은 콩알만큼, 삼키지 않아요
• 양치 후 물은 한 번만 살짝 헹구기
''',
  ),
  EduItem(
    id: 'kid_order_13zones',
    audience: Audience.kid,
    category: 'habit',
    title: '13구역 순서 게임',
    media: MediaType.text,
    durationSec: 45,
    body: '''
• 앱에서 나오는 순서대로 따라가요
• 다음 구역으로 갈 때 “딩!” 소리에 맞춰 이동
• 모두 채우면 오늘의 별★을 받아요!
''',
  ),
  EduItem(
    id: 'kid_quiz_daily',
    audience: Audience.kid,
    category: 'habit',
    title: '오늘의 퀴즈',
    media: MediaType.quiz,
    durationSec: 60,
    body: '오늘 배운 내용으로 3문제를 풀어봐요!',
  ),
  EduItem(
    id: 'parent_brush_technique_68',
    audience: Audience.parent,
    category: 'habit',
    title: '6–8세 양치 코칭 요령(기본 자세)',
    media: MediaType.text,
    durationSec: 90,
    body: '''
• 칫솔 각도: 잇몸선에 45°로 가볍게 대고 짧은 스트로크
• 순서 습관화: 앱 13구역 순서대로 매번 동일하게
• 압력: 잇몸이 아플 정도의 압력은 금지, 부드럽게
• 시간: 총 2분(구역별 타이머 활용)
• 마무리: 혀/볼 안쪽도 가볍게 스위핑
''',
  ),
  EduItem(
    id: 'parent_paste_amount',
    audience: Audience.parent,
    category: 'nutrition',
    title: '치약 사용량 & 헹굼 팁',
    media: MediaType.text,
    durationSec: 60,
    body: '''
• 치약량: 콩알(pea-size) 정도
• 삼키지 않도록 지도, 가볍게 1회 헹굼 권장
• 가글/헹굼 후 즉시 간식/음료는 피하기
''',
  ),
  EduItem(
    id: 'parent_floss_pick',
    audience: Audience.parent,
    category: 'floss',
    title: '치실/치실막대 시작하기',
    media: MediaType.text,
    durationSec: 75,
    body: '''
• 치실막대부터 시작: 아이가 잡기 쉬워요
• C자 형태로 치아 옆면을 감싸 부드럽게 위아래
• 피가 조금 비치면 압력 과도 여부와 염증 여부 관찰
''',
  ),
  EduItem(
    id: 'parent_snack_timing',
    audience: Audience.parent,
    category: 'nutrition',
    title: '간식 타이밍 & 음료 습관',
    media: MediaType.text,
    durationSec: 75,
    body: '''
• 간식은 식사와 묶어 횟수 줄이기(치아 노출 시간 단축)
• 달콤한 음료 대신 물 습관화
• 취침 전에는 반드시 양치 후 물만
''',
  ),
  EduItem(
    id: 'parent_visit_routine',
    audience: Audience.parent,
    category: 'dental_visit',
    title: '정기 검진 루틴 잡기',
    media: MediaType.text,
    durationSec: 60,
    body: '''
• 정기 점검 일정 고정(예: 방학 시작 전)
• 구강위생 상태/홈메우기/치아 배열 변화 점검
''',
  ),
  EduItem(
    id: 'parent_emergency_knockout',
    audience: Audience.parent,
    category: 'emergency',
    title: '외상 응급: 치아가 빠졌다면',
    media: MediaType.text,
    durationSec: 60,
    body: '''
• 영구치 추정 시 우유/생리식염수에 담아 신속히 치과 방문
• 유치 의심 시 무리한 재위치는 피하고 출혈/통증 먼저 조절
''',
  ),
];