import 'package:flutter/material.dart';

/// 앱 전체에서 쓰는 캐릭터 정의
class AvatarDef {
  final String id;           // ex) "molar"
  final String displayName;  // ex) "어금니몬"
  final String asset;        // ex) "assets/images/molar.png"
  const AvatarDef({required this.id, required this.displayName, required this.asset});
}

class AvatarRegistry {
  // ✅ /images 폴더의 파일명과 캐릭터 이름을 1:1 매핑
  static const List<AvatarDef> _all = [
    AvatarDef(id: 'molar',  displayName: '어금니몬',  asset: 'assets/images/molar.png'),
    AvatarDef(id: 'upper',  displayName: '앞니몬',    asset: 'assets/images/upper.png'),
    AvatarDef(id: 'lower',  displayName: '아랫니몬',  asset: 'assets/images/lower.png'),
    AvatarDef(id: 'canine', displayName: '송곳니몬',  asset: 'assets/images/canine.png'),
    AvatarDef(id: 'cavity', displayName: '케비티몬',  asset: 'assets/images/cavity.png'),
  ];

  static List<AvatarDef> get all => _all;

  static AvatarDef byId(String id) =>
      _all.firstWhere((a) => a.id == id, orElse: () => _all.first);

  static String displayNameOf(String id) => byId(id).displayName;

  static String assetOf(String id) => byId(id).asset;

  /// UI 편의: 캐릭터 이름 칩
  static Widget nameChip(String id, ColorScheme cs) {
    final name = displayNameOf(id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(.08),
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(name, style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
    );
  }
}
