// 📍 lib/features/home/presentation/tabs/education_page.dart (전체 파일)

import 'package:flutter/material.dart';
import 'package:chicachew/core/bp/bp_store.dart';
import 'package:go_router/go_router.dart';

// ✨ [수정] 새로 만든 공용 데이터 파일을 import 합니다.
import 'package:chicachew/features/edu/edu_data.dart';

// ✨ [삭제] 이 파일에 있던 EduItem, QuizItem 등 모든 데이터 클래스와 목록을 삭제했습니다.
//         이제 모든 데이터는 edu_data.dart 파일에서 관리됩니다.

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
/// EducationPage (튜토리얼 + 아이 + 보호자)
/// ─────────────────────────────────────────────────────────────────
class EducationPage extends StatefulWidget {
  const EducationPage({super.key});

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

  // ✨ [추가] BP가 업데이트될 때 화면을 갱신하기 위한 함수
  void _refreshBp() {
    setState(() {});
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
            onStartTutorial: () => context.push('/guide'),
          ),
          // ✨ [수정] BP 갱신 함수를 전달합니다.
          _KidSection(onBpUpdated: _refreshBp),
          _ParentSection(onBpUpdated: _refreshBp),
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
  final VoidCallback onBpUpdated;
  const _KidSection({required this.onBpUpdated});

  @override
  Widget build(BuildContext context) {
    // ✨ [수정] 공용 데이터인 eduSeed를 사용합니다.
    final items = eduSeed.where((e) => e.audience == Audience.kid).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _KidHeaderCard(),
        const SizedBox(height: 8),
        ...items.map((it) => _EduCard(item: it, onBpUpdated: onBpUpdated)).toList(),
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
  final VoidCallback onBpUpdated;
  const _ParentSection({required this.onBpUpdated});

  @override
  Widget build(BuildContext context) {
    // ✨ [수정] 공용 데이터인 eduSeed를 사용합니다.
    final items = eduSeed.where((e) => e.audience == Audience.parent).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _ParentHeaderCard(),
        const SizedBox(height: 8),
        ...items.map((it) => _EduCard(item: it, onBpUpdated: onBpUpdated)).toList(),
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
  final VoidCallback onBpUpdated;
  const _EduCard({required this.item, required this.onBpUpdated});

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
          ).then((result) {
            // 상세 페이지에서 BP가 업데이트되었다는 신호를 받으면, 화면을 갱신
            if (result == 'bp_updated') {
              onBpUpdated();
            }
          });
        },
      ),
    );
  }
}

/// 디테일 페이지 (텍스트/퀴즈)
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
          MediaType.image => _buildText(it),
        // ✨ [수정] 공용 함수인 dailyKidQuiz를 사용합니다.
          MediaType.quiz => isKidQuizDaily ? _buildDailyQuiz(it) : _buildQuiz(it),
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: FilledButton(
            onPressed: () async {
              const added = 10;
              String awardingId = it.id;
              if (it.id == 'kid_quiz_daily') {
                // ✨ [수정] 공용 함수인 todayKey를 사용합니다.
                awardingId = '${it.id}_${todayKey()}';
              }
              final already = await BpStore.hasCompleted(awardingId);
              final total = await BpStore.awardIfFirst(awardingId, added);
              if (!mounted) return;

              final msg = already
                  ? '이미 완료한 자료예요. 현재 누적: BP $total'
                  : '완료! +$added BP (총 BP $total)';
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              // ✨ [수정] BP가 업데이트되었다는 신호('bp_updated')와 함께 이전 페이지로 돌아갑니다.
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

  Widget _buildDailyQuiz(EduItem it) {
    // ✨ [수정] 공용 함수인 dailyKidQuiz를 사용합니다.
    final quiz = dailyKidQuiz(count: 3);
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