// 📍 lib/core/storage/profile.dart (수정 완료)

class Profile {
  final String name;
  final String avatar;
  final int brushCount;
  final DateTime? birthDate; // ✅ [추가] 생년월일 필드

  Profile({
    required this.name,
    required this.avatar,
    this.brushCount = 0,
    this.birthDate, // ✅ [추가] 생성자에 추가
  });

  Profile copyWith({
    String? name,
    String? avatar,
    int? brushCount,
    DateTime? birthDate, // ✅ [추가] copyWith에 추가
  }) {
    return Profile(
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      brushCount: brushCount ?? this.brushCount,
      birthDate: birthDate ?? this.birthDate, // ✅ [추가] copyWith에 추가
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'avatar': avatar,
    'brushCount': brushCount,
    // ✅ [추가] Json으로 저장 시 birthDate를 문자열로 변환
    'birthDate': birthDate?.toIso8601String(),
  };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    name: json['name'] ?? '',
    avatar: json['avatar'] ?? 'canine',
    brushCount: json['brushCount'] ?? 0,
    // ✅ [추가] Json에서 읽어올 때 문자열을 DateTime으로 변환
    birthDate: json['birthDate'] == null
        ? null
        : DateTime.tryParse(json['birthDate']),
  );
}