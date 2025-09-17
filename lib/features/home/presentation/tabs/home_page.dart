// 📍 lib/features/home/presentation/tabs/home_page.dart (전체 파일)

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chicachew/core/storage/local_store.dart';
import 'package:chicachew/core/storage/profile.dart';
import 'package:chicachew/core/storage/active_profile_store.dart';

import 'package:chicachew/core/bp/user_bp_store.dart';
import 'package:chicachew/core/bp/user_streak_store.dart';

import 'package:chicachew/features/home/presentation/tabs/education_page.dart';
// ✨ [수정] 새로 만든 공용 데이터 파일을 import 합니다.
import 'package:chicachew/features/edu/edu_data.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Profile> profiles = [];
  int _activeIdx = -1;
  int _bp = 0;
  int _streakDays = 0;
  bool _mBrush3 = false;
  bool _mTimes3 = false;
  bool _mMouthwash = false;

  String get _uKey => _activeIdx >= 0 ? 'idx$_activeIdx' : 'idx-1';

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  Future<void> _reloadAll() async {
    await _loadProfiles();
    await _loadStatus();
    await _loadMissions();
  }

  Future<void> _openProfileAdd() async {
    final added = await context.push<bool>('/profile/add');
    if (added == true) {
      await _loadProfiles();
      if (profiles.isNotEmpty) {
        final last = profiles.length - 1;
        await ActiveProfileStore.setIndex(last);
        if (!mounted) return;
        setState(() => _activeIdx = last);
        await _loadStatus();
        await _loadMissions();
      }
    }
  }

  Future<void> _loadProfiles() async {
    final store = LocalStore();
    final loaded = await store.getProfiles();

    int? savedIdx = await ActiveProfileStore.getIndex();
    int nextIdx = -1;
    if (loaded.isNotEmpty) {
      if (savedIdx == null || savedIdx < 0 || savedIdx >= loaded.length) {
        nextIdx = 0;
        await ActiveProfileStore.setIndex(0);
      } else {
        nextIdx = savedIdx;
      }
    }

    if (!mounted) return;
    setState(() {
      profiles = loaded;
      _activeIdx = nextIdx;
    });
  }

  Future<void> _selectProfile(int index) async {
    if (index < 0 || index >= profiles.length) return;
    await ActiveProfileStore.setIndex(index);
    if (!mounted) return;
    setState(() => _activeIdx = index);
    await _loadStatus();
    await _loadMissions();

    final who = profiles[index].name;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('현재 사용자: $who')),
    );
  }

  Future<void> _loadStatus() async {
    final bp = (_activeIdx >= 0) ? await UserBpStore.total(_uKey) : 0;
    final (days, _) = (_activeIdx >= 0)
        ? await UserStreakStore.info(_uKey)
        : (0, null);

    if (!mounted) return;
    setState(() {
      _bp = bp;
      _streakDays = days ?? 0;
    });
  }

  String _todayKey() {
    final d = DateUtils.dateOnly(DateTime.now());
    return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  String _missionKey(String id, {String? day}) {
    final k = day ?? _todayKey();
    return 'mission_${_uKey}_$k$id';
  }

  Future<void> _loadMissions() async {
    final p = await SharedPreferences.getInstance();
    final k = _todayKey();
    if (!mounted) return;
    setState(() {
      _mBrush3 = p.getBool(_missionKey('brush3', day: k)) ?? false;
      _mTimes3 = p.getBool(_missionKey('times3', day: k)) ?? false;
      _mMouthwash = p.getBool(_missionKey('mouth', day: k)) ?? false;
    });
  }

  Future<void> _toggleMission(String id, bool value, {int reward = 2}) async {
    if (_activeIdx < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 사용할 프로필을 선택해주세요')),
      );
      return;
    }

    final p = await SharedPreferences.getInstance();
    final k = _todayKey();
    final key = _missionKey(id, day: k);
    final prev = p.getBool(key) ?? false;

    if (!prev && value) {
      await p.setBool(key, true);
      await UserBpStore.add(_uKey, reward, note: '오늘의 미션:$id');
      await UserStreakStore.markToday(_uKey);
      await _loadStatus();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('+$reward BP 적립! (오늘의 미션: $id)')),
      );
    } else {
      await p.setBool(key, value);
    }

    if (!mounted) return;
    setState(() {
      if (id == 'brush3') _mBrush3 = value;
      if (id == 'times3') _mTimes3 = value;
      if (id == 'mouth') _mMouthwash = value;
    });
  }

  String getCharacter(int weekday) {
    switch (weekday) {
      case 1: return "canine";
      case 2: return "molar";
      case 3: return "upper";
      case 4: return "lower";
      case 5: return "canine";
      case 6: return "molar";
      case 7: return "upper";
      default: return "canine";
    }
  }

  String getMent(int hour) {
    if (hour < 12) return "굿모닝! 양치로 상쾌하게 하루 시작~";
    if (hour < 18) return "오후에도 깨끗한 치아를 지켜요!";
    return "잠들기 전 양치! 오늘도 수고했어요";
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateString = "${now.month}월 ${now.day}일";
    final textScale = MediaQuery.of(context).textScaleFactor;
    final cellExtent = textScale > 1.2 ? 126.0 : 112.0;

    final activeName = (_activeIdx >= 0 && _activeIdx < profiles.length)
        ? profiles[_activeIdx].name
        : null;

    return RefreshIndicator(
      onRefresh: _reloadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text(dateString,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (activeName != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    avatar: const Icon(Icons.person, size: 18),
                    label: Text(activeName),
                  ),
                ),
              Chip(
                avatar: const Icon(Icons.brush_outlined, size: 18),
                label: Text('BP $_bp'),
              ),
              const SizedBox(width: 8),
              // Chip(
              //   avatar: const Icon(Icons.local_fire_department_outlined, size: 18),
              //   label: Text('연속 $_streakDays일'),
              // ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDeco(Colors.blue),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('프로필',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _openProfileAdd,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('프로필 추가'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 130,
                  child: profiles.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("등록된 프로필이 없습니다."),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _openProfileAdd,
                          icon: const Icon(Icons.add),
                          label: const Text('첫 프로필 만들기'),
                        ),
                      ],
                    ),
                  )
                      : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: profiles.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 20),
                    itemBuilder: (context, index) {
                      final profile = profiles[index];
                      final isActive = index == _activeIdx;

                      return GestureDetector(
                        onTap: () => _selectProfile(index),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: isActive
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: [
                                  if (isActive)
                                    BoxShadow(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(.18),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: ProfileCircle(
                                progress: profile.brushCount,
                                avatar: profile.avatar,
                                size: 120,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              profile.name,
                              style: TextStyle(
                                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: _cardDeco(Colors.grey),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  "assets/images/${getCharacter(now.weekday)}.png",
                  width: 160, height: 160, fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    getMent(now.hour),
                    key: ValueKey(now.hour ~/ 6),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          final characters = ['molar', 'canine', 'upper', 'lower'];
                          final randomCharacter = characters[Random().nextInt(characters.length)];
                          context.push('/live_brush', extra: randomCharacter);
                        },
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('양치 시작'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // ✨ [수정] 공용 데이터인 eduSeed를 사용하도록 변경합니다.
                          final dailyQuizItem = eduSeed.firstWhere(
                                  (e) => e.id == 'kid_quiz_daily',
                              orElse: () => EduItem(
                                  id: 'not_found',
                                  audience: Audience.kid,
                                  category: 'habit',
                                  title: '퀴즈를 찾을 수 없어요',
                                  media: MediaType.text,
                                  body: '오류가 발생했습니다.'
                              )
                          );

                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => EduDetailPage(item: dailyQuizItem)),
                          );
                        },
                        icon: const Icon(Icons.quiz_outlined),
                        label: const Text('오늘의 퀴즈'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('오늘의 미션',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                const SizedBox(height: 8),
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    mainAxisExtent: cellExtent,
                  ),
                  children: [
                    _missionTile(
                      icon: Icons.timer_outlined,
                      title: '양치 3분',
                      reward: 2,
                      selected: _mBrush3,
                      onTap: () => _toggleMission('brush3', !_mBrush3, reward: 2),
                    ),
                    _missionTile(
                      icon: Icons.repeat,
                      title: '하루 3번',
                      reward: 1,
                      selected: _mTimes3,
                      onTap: () => _toggleMission('times3', !_mTimes3, reward: 1),
                    ),
                    _missionTile(
                      icon: Icons.water_drop_outlined,
                      title: '가글',
                      reward: 1,
                      selected: _mMouthwash,
                      onTap: () => _toggleMission('mouth', !_mMouthwash, reward: 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _missionTile({
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
    required int reward,
  }) {
    final color = selected ? Colors.teal : Colors.grey.shade300;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.teal.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.teal : Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: selected ? Colors.teal : Colors.grey[700]),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.1),
            ),
            const SizedBox(height: 2),
            Text('+$reward BP',
                style: TextStyle(fontSize: 11, height: 1.1, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDeco(Color base) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: base.withOpacity(0.08),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

class ProfileCircle extends StatelessWidget {
  final int progress;
  final String avatar;
  final double size;

  const ProfileCircle({
    super.key,
    required this.progress,
    required this.avatar,
    this.size = 150,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ProfilePainter(progress),
      child: Center(
        child: ClipOval(
          child: Image.asset(
            "assets/images/$avatar.png",
            width: size * 0.7,
            height: size * 0.7,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _ProfilePainter extends CustomPainter {
  final int progress;
  _ProfilePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = Colors.grey.shade300;

    for (int i = 0; i < 3; i++) {
      canvas.drawArc(rect.deflate(3), -pi / 2 + i * (2 * pi / 3), 2 * pi / 3, false, bg);
    }

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = Colors.blueAccent;

    for (int i = 0; i < progress.clamp(0, 3); i++) {
      canvas.drawArc(rect.deflate(3), -pi / 2 + i * (2 * pi / 3), 2 * pi / 3, false, fg);
    }
  }

  @override
  bool shouldRepaint(covariant _ProfilePainter old) => old.progress != progress;
}