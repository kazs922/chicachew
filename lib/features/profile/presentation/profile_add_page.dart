// 📍 lib/features/profile/presentation/profile_add_page.dart (수정 완료)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:chicachew/core/storage/active_profile_store.dart'; // ✅ ActiveProfileStore 추가
import 'package:chicachew/core/storage/local_store.dart';
import 'package:chicachew/core/storage/profile.dart';

class ProfileAddPage extends StatefulWidget {
  const ProfileAddPage({super.key});
  @override
  State<ProfileAddPage> createState() => _ProfileAddPageState();
}

/// 내부 전용 캐릭터 목록 (현재 앱과 동일하게 유지)
class _Avatar {
  final String id;     // 저장용 id (ex. "canine")
  final String name;   // 표시 이름
  final String asset;  // assets 경로
  const _Avatar({required this.id, required this.name, required this.asset});
}

const List<_Avatar> _avatars = [
  _Avatar(id: 'canine', name: '송곳니몬', asset: 'assets/images/canine.png'),
  _Avatar(id: 'upper',  name: '앞니몬',   asset: 'assets/images/upper.png'),
  _Avatar(id: 'lower',  name: '아랫니몬', asset: 'assets/images/lower.png'),
  _Avatar(id: 'cavity', name: '케비티몬', asset: 'assets/images/cavity.png'),
  _Avatar(id: 'molar',  name: '어금니몬', asset: 'assets/images/molar.png'),
];

class _ProfileAddPageState extends State<ProfileAddPage>
    with TickerProviderStateMixin {
  // 폼 표시 여부 (처음엔 빈 상태)
  bool _showForm = false;

  // 입력값
  final _nameController = TextEditingController();
  String _selectedAvatarId = 'canine';

  // 생년월일(선택)
  int? _year, _month, _day;

  // 유틸
  _Avatar get _selected =>
      _avatars.firstWhere((a) => a.id == _selectedAvatarId, orElse: () => _avatars.first);

  List<int> get _yearItems {
    final now = DateTime.now().year;
    // 아이 대상 넉넉히 최근 20년 + 여유
    return List<int>.generate(25, (i) => now - i);
  }
  List<int> get _monthItems => List<int>.generate(12, (i) => i + 1);
  List<int> get _dayItems {
    final y = _year ?? DateTime.now().year;
    final m = _month ?? 1;
    final days = DateUtils.getDaysInMonth(y, m);
    return List<int>.generate(days, (i) => i + 1);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요')),
      );
      return;
    }

    final store = LocalStore();
    final current = await store.getProfiles();

    // ✅ [수정] 선택된 연/월/일을 DateTime 객체로 변환합니다.
    DateTime? birthDate;
    if (_year != null && _month != null && _day != null) {
      birthDate = DateTime(_year!, _month!, _day!);
    }

    // ✅ [수정] Profile 객체 생성 시 birthDate를 포함합니다.
    final newProfile = Profile(
      name: name,
      avatar: _selectedAvatarId,
      birthDate: birthDate,
    );

    final updatedProfiles = [...current, newProfile];
    await store.saveProfiles(updatedProfiles);

    // ✅ [추가] 새로 만든 프로필을 활성 프로필로 설정합니다.
    await ActiveProfileStore.setIndex(updatedProfiles.length - 1);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('프로필이 등록되었어요! (${_selected.name})')),
    );

    if (context.canPop()) {
      context.pop(true); // 호출부에서 await 후 목록 리로드
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('자녀 프로필'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 상단 안내 (빈상태 전용 문구)
            AnimatedCrossFade(
              crossFadeState: _showForm
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 260),
              firstChild: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('자녀의 프로필을 등록해주세요.',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    SizedBox(height: 8),
                    Text('자녀 이름, 생년월일, 캐릭터를 선택하면 맞춤 가이드를 제공할 수 있어요.\n'
                        '나중에 마이페이지에서 언제든지 수정할 수 있습니다.'),
                  ],
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // ──────────────────────────────────────────────────────────────
            // 섹션(폼) : 버튼을 누르면 같은 화면에서 펼쳐짐
            // ──────────────────────────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              child: !_showForm
                  ? const SizedBox.shrink()
                  : Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 미리보기
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: size.width * 0.16,
                            backgroundColor: cs.primary.withOpacity(.12),
                            child: ClipOval(
                              child: Image.asset(
                                _selected.asset,
                                width: size.width * 0.28,
                                height: size.width * 0.28,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                const Icon(Icons.pets, size: 48),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(.08),
                              border: Border.all(color: cs.outlineVariant),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _selected.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 캐릭터 선택
                    Text('캐릭터 선택',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface)),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: .9,
                      ),
                      itemCount: _avatars.length,
                      itemBuilder: (context, i) {
                        final a = _avatars[i];
                        final selected = a.id == _selectedAvatarId;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedAvatarId = a.id;
                          }),
                          child: Container(
                            decoration: BoxDecoration(
                              color: selected
                                  ? cs.primary.withOpacity(.12)
                                  : cs.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? cs.primary
                                    : cs.outlineVariant,
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
                            padding:
                            const EdgeInsets.fromLTRB(8, 10, 8, 10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius:
                                          BorderRadius.circular(10),
                                          child: Image.asset(
                                            a.asset,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.pets,
                                                size: 28),
                                          ),
                                        ),
                                      ),
                                      if (selected)
                                        Positioned(
                                          right: 6,
                                          top: 6,
                                          child: Container(
                                            padding:
                                            const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: cs.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(Icons.check,
                                                size: 14,
                                                color: cs.onPrimary),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  a.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // 이름
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '이름',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),

                    const SizedBox(height: 12),

                    // 생년월일 (선택)
                    Text('생년월일',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _year,
                            items: _yearItems
                                .map((y) => DropdownMenuItem(
                              value: y,
                              child: Text('$y년'),
                            ))
                                .toList(),
                            onChanged: (v) => setState(() {
                              _year = v;
                              if (_month != null && _day != null) {
                                final max = DateUtils.getDaysInMonth(
                                    _year!, _month!);
                                if (_day! > max) _day = max;
                              }
                            }),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: '연도',
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _month,
                            items: _monthItems
                                .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text('$m월'),
                            ))
                                .toList(),
                            onChanged: (v) => setState(() {
                              _month = v;
                              if (_year != null && _day != null) {
                                final max = DateUtils.getDaysInMonth(
                                    _year!, _month!);
                                if (_day! > max) _day = max;
                              }
                            }),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: '월',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _day,
                            items: (_month == null && _year == null
                                ? <int>[]
                                : _dayItems)
                                .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text('$d일'),
                            ))
                                .toList(),
                            onChanged: (v) => setState(() => _day = v),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: '일',
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 저장 버튼
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save),
                        label: const Text('프로필 저장'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (!_showForm)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => setState(() => _showForm = true),
                  child: const Text('자녀 추가'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}