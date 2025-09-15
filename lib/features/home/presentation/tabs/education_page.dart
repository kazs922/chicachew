// lib/features/edu/presentation/education_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:chicachew/core/bp/bp_store.dart';

/// ─────────────────────────────────────────────────────────────────
/// 모델
/// ─────────────────────────────────────────────────────────────────
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
  final Audience audience; // 아이/보호자
  final String category;   // habit/floss/mouthwash/nutrition/growth/emergency/orthodontics/dental_visit
  final String title;
  final int? durationSec;  // optional
  final MediaType media;
  final String body;       // text or image desc
  final List<QuizItem>? quiz; // (아이 정적 퀴즈 용; '일일 퀴즈'는 동적 생성)

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

/// ─────────────────────────────────────────────────────────────────
/// 아이(6–8세) 퀴즈 풀 & 오늘의 퀴즈 선택 유틸
/// ─────────────────────────────────────────────────────────────────
final List<QuizItem> _kidQuizPool = [
  QuizItem(
    q: '치약은 어느 정도가 좋아요?',
    options: ['칫솔 가득', '콩알만큼', '안 써요'],
    answerIndex: 1,
  ),
  QuizItem(
    q: '양치는 몇 분이 좋아요?',
    options: ['30초', '1분', '2분'],
    answerIndex: 2,
  ),
  QuizItem(
    q: '칫솔은 어떻게 움직여요?',
    options: ['힘껏 세게', '작게 동그랗게', '빨리 쓱쓱'],
    answerIndex: 1,
  ),
  QuizItem(
    q: '가글은 어떻게 해야 해요?',
    options: ['삼키기', '뱉기', '물 많이 마시기'],
    answerIndex: 1,
  ),
  QuizItem(
    q: '양치 후 물 헹굼은?',
    options: ['아예 안 하기', '가볍게 한 번', '세 번 이상'],
    answerIndex: 1,
  ),
  QuizItem(
    q: '달콤한 음료는 어떻게 마실까요?',
    options: ['자주 조금씩', '식사와 함께/물 자주', '잠들기 전에'],
    answerIndex: 1,
  ),
  QuizItem(
    q: '칫솔 힘은 어느 정도가 좋아요?',
    options: ['아플 만큼 세게', '부드럽게', '아예 닿지 않게'],
    answerIndex: 1,
  ),
  QuizItem(
    q: '혀도 닦아야 하나요?',
    options: ['네, 가볍게', '아니요', '아플 때만'],
    answerIndex: 0,
  ),
  QuizItem(
    q: '치실은 언제 쓰면 좋을까요?',
    options: ['양치 후', '아침만', '안 써요'],
    answerIndex: 0,
  ),
  QuizItem(
    q: '칫솔은 얼마나 자주 바꿔요?',
    options: ['3개월마다', '1년마다', '안 바꿔요'],
    answerIndex: 0,
  ),
  QuizItem(
    q: '치약은 삼켜도 되나요?',
    options: ['조금은 괜찮아요', '삼키지 않아요', '많이 삼켜요'],
    answerIndex: 1,
  ),
  QuizItem(
    q: '이를 닦을 때 순서는?',
    options: ['아무렇게나', '앞/안/씹는 면 골고루', '윗니만'],
    answerIndex: 1,
  ),
];

String _todayKey() {
  final d = DateUtils.dateOnly(DateTime.now());
  return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}

/// 날짜 기반 시드로 오늘의 퀴즈 N개 선택(중복 없음, 당일 고정)
List<QuizItem> _dailyKidQuiz({int count = 3}) {
  final pool = List<QuizItem>.from(_kidQuizPool);
  if (pool.length <= count) return pool;
  final d = DateUtils.dateOnly(DateTime.now());
  final seed = d.millisecondsSinceEpoch; // 날짜 시드
  final rnd = Random(seed);
  for (int i = pool.length - 1; i > 0; i--) {
    final j = rnd.nextInt(i + 1);
    final tmp = pool[i];
    pool[i] = pool[j];
    pool[j] = tmp;
  }
  return pool.take(count).toList();
}

/// ─────────────────────────────────────────────────────────────────
/// 더미 데이터 (아이: 쉬운 가이드 + ‘오늘의 퀴즈’, 보호자: 텍스트만)
/// ─────────────────────────────────────────────────────────────────
final _eduSeed = <EduItem>[
  // ── 아이(6–8세) — 우선순위 3개 먼저 배치: [치아가 빠져요] → [양치 고수되기] → [치과 가야할까요?]
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
      QuizItem(
        q: '넘어져서 이가 부러졌거나 많이 흔들려요!',
        options: ['그냥 참는다', '어른에게 말하고 치과에 간다', '내가 직접 뽑는다'],
        answerIndex: 1,
      ),
      QuizItem(
        q: '피가 10분 넘게 멈추지 않아요',
        options: ['집에서 계속 기다린다', '치과에 간다', '빨대로 피를 빨아본다'],
        answerIndex: 1,
      ),
      QuizItem(
        q: '조금 흔들리는 유치(아프지 않아요)',
        options: ['살살 흔들며 기다린다', '세게 잡아당겨 뽑는다', '양치를 멈춘다'],
        answerIndex: 0,
      ),
      QuizItem(
        q: '새(영구)이가 보이는데 유치가 안 빠져요',
        options: ['어른에게 말하고 치과 상담', '그냥 몇 달 더 기다림', '손으로 계속 밀어낸다'],
        answerIndex: 0,
      ),
    ],
  ),

  // 기존 아이용 안내
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
  // ✅ 오늘의 퀴즈 (매일 다른 문제)
  EduItem(
    id: 'kid_quiz_daily', // 실제 적립은 'kid_quiz_daily_YYYYMMDD'로 처리
    audience: Audience.kid,
    category: 'habit',
    title: '오늘의 퀴즈',
    media: MediaType.quiz,
    durationSec: 60,
    body: '오늘 배운 내용으로 3문제를 풀어봐요!',
  ),

  // ── 보호자(퀴즈 없음)
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

/// ─────────────────────────────────────────────────────────────────
/// 아이콘 유틸
/// ─────────────────────────────────────────────────────────────────
IconData _iconForCategory(String c) {
  switch (c) {
    case 'floss': return Icons.device_hub_outlined;
    case 'mouthwash': return Icons.water_drop_outlined;
    case 'nutrition': return Icons.restaurant_outlined;
    case 'growth': return Icons.timeline_outlined;
    case 'emergency': return Icons.emergency_share_outlined;
    case 'orthodontics': return Icons.hardware_outlined;
    case 'habit': return Icons.psychology_alt_outlined;
    case 'dental_visit': return Icons.local_hospital_outlined;
    default: return Icons.menu_book_outlined;
  }
}

/// ─────────────────────────────────────────────────────────────────
/// EducationPage (튜토리얼 + 아이 + 보호자) — 아이에만 퀴즈, 보호자는 텍스트만
/// ─────────────────────────────────────────────────────────────────
class EducationPage extends StatefulWidget {
  final VoidCallback? onStartTutorial;
  const EducationPage({super.key, this.onStartTutorial});

  @override
  State<EducationPage> createState() => _EducationPageState();
}

class _EducationPageState extends State<EducationPage> with TickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('교육 자료'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '양치가이드'),
            Tab(text: '아이(6–8세)'),
            Tab(text: '보호자'),
          ],
        ),
        actions: [
          // 상단 BP 배지
          FutureBuilder<int>(
            future: BpStore.total(),
            builder: (c, s) {
              final bp = s.data ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: const Icon(Icons.brush_outlined, size: 18),
                  label: Text('BP $bp'),
                ),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _BrushGuideTutorialOnly(
            onStartTutorial: widget.onStartTutorial ?? ()
            => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('튜토리얼 라우팅을 연결해주세요.')),
            ),
          ),
          _KidSection(),
          _ParentSection(),
        ],
      ),
    );
  }
}

/// 튜토리얼 카드
class _BrushGuideTutorialOnly extends StatelessWidget {
  final VoidCallback onStartTutorial;
  const _BrushGuideTutorialOnly({required this.onStartTutorial});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.school_outlined, size: 36),
                    const SizedBox(width: 12),
                    Expanded(child: Text('튜토리얼 가이드', style: Theme.of(context).textTheme.titleLarge)),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('13구역 순서/자세/힘 조절을 애니메이션으로 익혀요', style: Theme.of(context).textTheme.bodyMedium),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: onStartTutorial, child: const Text('가이드 보기')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 아이 섹션(헤더 + 리스트)
class _KidSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = _eduSeed.where((e) => e.audience == Audience.kid).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _KidHeaderCard(),
        const SizedBox(height: 8),
        ...items.map((it) => _EduCard(item: it)).toList(),
      ],
    );
  }
}

class _KidHeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.teal.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const ListTile(
        leading: Icon(Icons.child_care_outlined, size: 36),
        title: Text('6–8세 아이를 위한 쉬운 양치 가이드'),
        subtitle: Text('• 2분 타이머로 게임처럼!\n• 작게 동그랗게, 부드럽게\n• 순서(13구역)만 지켜도 성공!\n• 오늘은 “오늘의 퀴즈”도 있어요'),
      ),
    );
  }
}

/// 보호자 섹션(퀴즈 없음)
class _ParentSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = _eduSeed.where((e) => e.audience == Audience.parent).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _ParentHeaderCard(),
        const SizedBox(height: 8),
        ...items.map((it) => _EduCard(item: it)).toList(),
      ],
    );
  }
}

class _ParentHeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.indigo.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const ListTile(
        leading: Icon(Icons.family_restroom_outlined, size: 36),
        title: Text('보호자 코칭 포인트'),
        subtitle: Text('• 45° 각도, 짧은 스트로크, 압력은 가볍게\n• 앱 순서(13구역)로 습관 고정\n• 간식/음료 타이밍 관리 + 정기검진'),
      ),
    );
  }
}

/// 공용 카드 + 디테일 이동
class _EduCard extends StatelessWidget {
  final EduItem item;
  const _EduCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(_iconForCategory(item.category)),
        title: Text(item.title),
        subtitle: Text(
          '#${item.category}${item.durationSec!=null ? " · ${(item.durationSec!/60).toStringAsFixed(1)}분" : ""}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => EduDetailPage(item: item)),
          ).then((res) {
            if (res == 'bp_updated') {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('BP 갱신됨')));
            }
          });
        },
      ),
    );
  }
}

/// 디테일 페이지 (텍스트/퀴즈) — 아이만 퀴즈, 보호자는 항상 텍스트
class EduDetailPage extends StatefulWidget {
  final EduItem item;
  const EduDetailPage({super.key, required this.item});

  @override
  State<EduDetailPage> createState() => _EduDetailPageState();
}

class _EduDetailPageState extends State<EduDetailPage> {
  int _currentQuiz = 0;
  int _score = 0;
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final isKidQuizDaily = (it.id == 'kid_quiz_daily');

    return Scaffold(
      appBar: AppBar(title: Text(it.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (it.media) {
          MediaType.text => _buildText(it),
          MediaType.image => _buildText(it), // 이미지 뷰어로 교체 예정
          MediaType.quiz => isKidQuizDaily ? _buildDailyQuiz(it) : _buildQuiz(it), // 아이만 퀴즈
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: FilledButton(
            onPressed: () async {
              // ✅ BP 적립: 오늘 퀴즈는 날짜별로 다른 ID로 적립 가능
              const added = 10;
              String awardingId = it.id;
              if (it.id == 'kid_quiz_daily') {
                awardingId = '${it.id}_${_todayKey()}'; // ex) kid_quiz_daily_YYYYMMDD
              }
              final already = await BpStore.hasCompleted(awardingId);
              final total = await BpStore.awardIfFirst(awardingId, added);
              if (!mounted) return;

              final msg = already
                  ? '이미 완료한 자료예요. 현재 누적: BP $total'
                  : '완료! +$added BP (총 BP $total)';
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              Navigator.pop(context, 'bp_updated');
            },
            child: const Text('완료'),
          ),
        ),
      ),
    );
  }

  Widget _buildText(EduItem it) {
    return SingleChildScrollView(
      child: Text(it.body, style: const TextStyle(fontSize: 16, height: 1.5)),
    );
  }

  /// 고정 퀴즈(치과 가야할까요?)
  Widget _buildQuiz(EduItem it) {
    final quiz = it.quiz ?? [];
    if (quiz.isEmpty) return const Center(child: Text('퀴즈가 없습니다.'));
    final q = quiz[_currentQuiz];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('문제 ${_currentQuiz+1}/${quiz.length}', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Text(q.q, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ...List.generate(q.options.length, (i) {
          return RadioListTile<int>(
            value: i,
            groupValue: _selectedIndex,
            title: Text(q.options[i]),
            onChanged: (v) => setState(()=> _selectedIndex = v),
          );
        }),
        const Spacer(),
        _navButtons(total: quiz.length, answerIndex: q.answerIndex),
      ],
    );
  }

  /// ✅ 오늘의 퀴즈(날짜 시드로 매일 3문제)
  Widget _buildDailyQuiz(EduItem it) {
    final quiz = _dailyKidQuiz(count: 3);
    final q = quiz[_currentQuiz];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('오늘의 퀴즈 ${_currentQuiz+1}/${quiz.length}', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Text(q.q, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ...List.generate(q.options.length, (i) {
          return RadioListTile<int>(
            value: i,
            groupValue: _selectedIndex,
            title: Text(q.options[i]),
            onChanged: (v) => setState(()=> _selectedIndex = v),
          );
        }),
        const Spacer(),
        _navButtons(total: quiz.length, answerIndex: q.answerIndex),
      ],
    );
  }

  Widget _navButtons({required int total, required int answerIndex}) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _currentQuiz == 0 ? null : () {
              setState(() {
                _currentQuiz--;
                _selectedIndex = null;
              });
            },
            child: const Text('이전'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: _selectedIndex == null ? null : () {
              final correct = _selectedIndex == answerIndex;
              if (correct) _score++;
              if (_currentQuiz < total - 1) {
                setState(() {
                  _currentQuiz++;
                  _selectedIndex = null;
                });
              } else {
                final percent = ((_score / total) * 100).round();
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('퀴즈 결과'),
                    content: Text('정답: $_score/$total · $percent점'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
                    ],
                  ),
                );
              }
            },
            child: Text(_currentQuiz < total - 1 ? '다음' : '결과보기'),
          ),
        ),
      ],
    );
  }
}
