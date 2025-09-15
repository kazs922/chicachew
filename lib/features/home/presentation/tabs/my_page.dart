// lib/features/mypage/presentation/my_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 현재 프로필 접근을 위해 추가
import 'package:chicachew/core/storage/local_store.dart';
import 'package:chicachew/core/storage/profile.dart';
import 'package:chicachew/core/storage/active_profile_store.dart';

/// ────────────────────────────────────────────────────────────────────────────
/// 캐릭터 매핑 (이 파일 안에서 바로 사용)
/// id ↔ displayName ↔ asset 경로
/// ────────────────────────────────────────────────────────────────────────────
class _Avatar {
  final String id;
  final String name;
  final String asset;
  const _Avatar({required this.id, required this.name, required this.asset});
}

const List<_Avatar> kAvatars = [
  _Avatar(id: 'molar',  name: '어금니몬',  asset: 'assets/images/molar.png'),
  _Avatar(id: 'upper',  name: '앞니몬',    asset: 'assets/images/upper.png'),
  _Avatar(id: 'lower',  name: '아랫니몬',  asset: 'assets/images/lower.png'),
  _Avatar(id: 'canine', name: '송곳니몬',  asset: 'assets/images/canine.png'),
  _Avatar(id: 'cavity', name: '케비티몬',  asset: 'assets/images/cavity.png'),
];

_Avatar _byId(String id) =>
    kAvatars.firstWhere((a) => a.id == id, orElse: () => kAvatars.first);

/// 이름 칩 UI
Widget _nameChip(String text, ColorScheme cs) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: cs.primary.withOpacity(.08),
      border: Border.all(color: cs.outlineVariant),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 마이페이지 (4개 섹션) — 활성 프로필 정보 표시 & 수정 후 갱신
// ─────────────────────────────────────────────────────────────────────────────
class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  String? _activeName;
  String? _activeAvatarId;
  String _activeHand = 'right'; // SharedPreferences: hand_idx{n}
  bool _loading = true;

  String get _handLabel => _activeHand == 'left' ? '왼손' : '오른손';

  @override
  void initState() {
    super.initState();
    _loadActiveSummary();
  }

  Future<void> _loadActiveSummary() async {
    final store = LocalStore();
    final profiles = await store.getProfiles();
    final idx = await ActiveProfileStore.getIndex() ?? -1;

    if (idx >= 0 && idx < profiles.length) {
      final p = profiles[idx];
      final sp = await SharedPreferences.getInstance();
      final hand = sp.getString('hand_idx$idx') ?? 'right';
      if (!mounted) return;
      setState(() {
        _activeName = p.name;
        _activeAvatarId = p.avatar; // id (ex. canine)
        _activeHand = hand;
        _loading = false;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _activeName = null;
        _activeAvatarId = null;
        _activeHand = 'right';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final subtitle = _activeName == null || _activeAvatarId == null
        ? '프로필을 먼저 추가해 주세요'
        : '${_activeName!} · ${_byId(_activeAvatarId!).name} · $_handLabel';

    final leading = _activeAvatarId == null
        ? CircleAvatar(
      backgroundColor: cs.primary.withOpacity(.15),
      child: const Icon(Icons.person),
    )
        : CircleAvatar(
      backgroundColor: cs.primary.withOpacity(.15),
      backgroundImage: AssetImage(_byId(_activeAvatarId!).asset),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 1) 프로필 관리 (활성 요약 표시)
          _SectionCard(
            child: ListTile(
              leading: leading,
              title: const Text('프로필 관리'),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileManagePage()),
                );
                if (changed == true) {
                  await _loadActiveSummary();
                }
              },
            ),
          ),
          const SizedBox(height: 12),

          // 2) 리마인더 설정
          _SectionCard(
            child: ListTile(
              leading: Icon(Icons.alarm, color: cs.primary),
              title: const Text('리마인더 설정'),
              subtitle: const Text('아침 · 점심 · 저녁 알림 시간/ON·OFF'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReminderSettingsPage()),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3) 앱 설정
          _SectionCard(
            child: ListTile(
              leading: Icon(Icons.settings, color: cs.primary),
              title: const Text('앱 설정'),
              subtitle: const Text('소리·진동 · 테마 · 글자 크기'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppSettingsPage()),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 4) 고객지원 & 앱 정보
          _SectionCard(
            child: ListTile(
              leading: Icon(Icons.support_agent, color: cs.primary),
              title: const Text('고객지원 & 앱 정보'),
              subtitle: const Text('문의하기 · FAQ · 버전'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupportAboutPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 공통 카드 컨테이너
class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ① 프로필 관리 (활성 프로필 로드/편집/저장)
// ─────────────────────────────────────────────────────────────────────────────
class ProfileManagePage extends StatefulWidget {
  const ProfileManagePage({super.key});
  @override
  State<ProfileManagePage> createState() => _ProfileManagePageState();
}

class _ProfileManagePageState extends State<ProfileManagePage> {
  final _nameCtrl = TextEditingController();
  String _hand = 'right';       // 'left' / 'right' (per profile idx in SP)
  String _avatarId = 'canine';  // 기본: 송곳니몬

  bool _loading = true;
  int _activeIdx = -1;
  List<Profile> _profiles = const [];

  String get _uKey => _activeIdx >= 0 ? 'idx$_activeIdx' : 'idx-1';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final store = LocalStore();
    final profiles = await store.getProfiles();
    final idx = await ActiveProfileStore.getIndex() ?? -1;

    if (idx >= 0 && idx < profiles.length) {
      final me = profiles[idx];
      final sp = await SharedPreferences.getInstance();
      final hand = sp.getString('hand_$_uKey') ??
          sp.getString('hand_idx$idx') ?? // 과거 키 호환
          'right';

      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _activeIdx = idx;
        _nameCtrl.text = me.name;
        _avatarId = me.avatar; // id 저장되어 있어야 함
        _hand = hand;
        _loading = false;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _activeIdx = -1;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_activeIdx < 0 || _activeIdx >= _profiles.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('활성 프로필이 없습니다. 홈에서 먼저 프로필을 추가하세요.')),
      );
      return;
    }

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 입력해주세요')),
      );
      return;
    }

    // 1) 프로필 리스트 갱신
    final store = LocalStore();
    final fresh = await store.getProfiles(); // 혹시 변경됐을 수 있어 다시 로드
    if (_activeIdx >= fresh.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 인덱스가 유효하지 않습니다.')),
      );
      return;
    }
    final old = fresh[_activeIdx];

    // Profile 생성 방식은 모델에 맞게 조정 (brushCount 보존)
    final updatedItem = Profile(
      name: name,
      avatar: _avatarId,
      brushCount: old.brushCount,
    );

    final updatedList = [...fresh];
    updatedList[_activeIdx] = updatedItem;
    await store.saveProfiles(updatedList);

    // 2) 주손 저장 (프로필별)
    final sp = await SharedPreferences.getInstance();
    await sp.setString('hand_$_uKey', _hand);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('프로필이 저장되었습니다.')),
    );
    Navigator.pop(context, true); // 변경됨 신호
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final current = _byId(_avatarId);

    return Scaffold(
      appBar: AppBar(title: const Text('프로필 관리')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_activeIdx < 0
          ? _EmptyProfileHint()
          : ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // 현재 선택 캐릭터 미리보기 + 이름 칩
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: cs.primary.withOpacity(.15),
                  child: ClipOval(
                    child: Image.asset(
                      current.asset,
                      width: 72, height: 72, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.pets, size: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _nameChip(current.name, cs),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 닉네임
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '닉네임',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // 주손
          InputDecorator(
            decoration: const InputDecoration(
              labelText: '주손(좌/우)',
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _hand,
                items: const [
                  DropdownMenuItem(value: 'left',  child: Text('왼손')),
                  DropdownMenuItem(value: 'right', child: Text('오른손')),
                ],
                onChanged: (v) => setState(() => _hand = v ?? 'right'),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 캐릭터 선택 (이미지+이름 그리드)
          Text('캐릭터 선택', style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .9,
            ),
            itemCount: kAvatars.length,
            itemBuilder: (context, i) {
              final a = kAvatars[i];
              final selected = a.id == _avatarId;
              return _AvatarTile(
                avatar: a,
                selected: selected,
                onTap: () => setState(() => _avatarId = a.id),
              );
            },
          ),

          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: const Text('저장'),
          ),
        ],
      )),
    );
  }
}

class _EmptyProfileHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.person_off, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('활성 프로필이 없습니다.\n홈에서 먼저 프로필을 추가해 주세요.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// 캐릭터 타일 (이미지 + 이름)
class _AvatarTile extends StatelessWidget {
  final _Avatar avatar;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarTile({
    required this.avatar,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? cs.primary.withOpacity(.12) : cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  avatar.asset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.pets, size: 28),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              avatar.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ② 리마인더 설정 (아침/점심/저녁) — 로컬 알림 연동 포인트 포함
// ─────────────────────────────────────────────────────────────────────────────
class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key});
  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  bool morningOn = true, noonOn = false, nightOn = true;
  TimeOfDay morning = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay noon = const TimeOfDay(hour: 12, minute: 30);
  TimeOfDay night = const TimeOfDay(hour: 22, minute: 30);

  Future<void> _pick(TimeOfDay current, ValueChanged<TimeOfDay> onPicked) async {
    final res = await showTimePicker(context: context, initialTime: current);
    if (res != null) onPicked(res);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('리마인더 설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _ReminderRow(
            title: '아침',
            on: morningOn,
            time: fmt(morning),
            onToggle: (v) => setState(() => morningOn = v),
            onPick: () => _pick(morning, (t) => setState(() => morning = t)),
          ),
          const Divider(height: 1),
          _ReminderRow(
            title: '점심',
            on: noonOn,
            time: fmt(noon),
            onToggle: (v) => setState(() => noonOn = v),
            onPick: () => _pick(noon, (t) => setState(() => noon = t)),
          ),
          const Divider(height: 1),
          _ReminderRow(
            title: '저녁',
            on: nightOn,
            time: fmt(night),
            onToggle: (v) => setState(() => nightOn = v),
            onPick: () => _pick(night, (t) => setState(() => night = t)),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              // TODO: 저장 + flutter_local_notifications로 스케줄 예약/해제
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('리마인더가 저장되었습니다.'),
                  backgroundColor: cs.primary,
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  final String title;
  final bool on;
  final String time;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPick;

  const _ReminderRow({
    required this.title,
    required this.on,
    required this.time,
    required this.onToggle,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.notifications_active, color: cs.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(time),
      trailing: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          TextButton(onPressed: onPick, child: const Text('시간 변경')),
          Switch(value: on, onChanged: onToggle),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ③ 앱 설정 (소리/진동, 테마, 글자 크기)
// ─────────────────────────────────────────────────────────────────────────────
class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});
  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  bool haptics = true;
  String themeMode = 'light'; // light / dark / system
  double textScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('앱 설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SwitchListTile(
            value: haptics,
            onChanged: (v) => setState(() => haptics = v),
            title: const Text('알림 소리/진동'),
            subtitle: const Text('리마인더 및 기타 알림에 적용'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.color_lens, color: cs.primary),
            title: const Text('테마'),
            subtitle: Text(
              themeMode == 'light' ? '라이트' : (themeMode == 'dark' ? '다크' : '시스템'),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final selected = await showModalBottomSheet<String>(
                context: context,
                showDragHandle: true,
                builder: (_) => const _ThemePickerSheet(),
              );
              if (selected != null) setState(() => themeMode = selected);
              // TODO: 실제 ThemeMode 반영 (in MaterialApp)
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.text_fields, color: cs.primary),
            title: const Text('글자 크기'),
            subtitle: Text('${(textScale * 100).round()}%'),
            trailing: SizedBox(
              width: 140,
              child: Slider(
                value: textScale,
                onChanged: (v) => setState(() => textScale = v),
                min: 0.8,
                max: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              // TODO: SharedPreferences 등에 저장 후 앱 반영
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('앱 설정이 저장되었습니다.')),
              );
              Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet({super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _ThemeRow(value: 'light', label: '라이트'),
          _ThemeRow(value: 'dark', label: '다크'),
          _ThemeRow(value: 'system', label: '시스템'),
          SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  final String value, label;
  const _ThemeRow({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      onTap: () => Navigator.pop(context, value),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ④ 고객지원 & 앱 정보
// ─────────────────────────────────────────────────────────────────────────────
class SupportAboutPage extends StatelessWidget {
  const SupportAboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('고객지원 & 앱 정보')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ListTile(
            leading: Icon(Icons.email, color: cs.primary),
            title: const Text('문의하기'),
            subtitle: const Text('support@chicachew.app'),
            onTap: () {
              // TODO: url_launcher로 mailto: 오픈
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.help_center, color: cs.primary),
            title: const Text('FAQ'),
            onTap: () {
              // TODO: FAQ 화면/웹뷰 연결
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.description, color: cs.primary),
            title: const Text('개인정보 처리방침 · 이용약관'),
            onTap: () {
              // TODO: 정책 화면/웹뷰 연결
            },
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('앱 정보'),
            subtitle: Text('버전 1.0.0'),
          ),
        ],
      ),
    );
  }
}
