// 📍 lib/core/storage/profile.dart (전체 파일)

class Profile {
  final String name;
  final String avatar;
  final int brushCount;

  Profile({
    required this.name,
    required this.avatar,
    this.brushCount = 0,
  });

  // ✨ [추가] copyWith 메서드. 기존 값은 유지하고 원하는 값만 변경하여 새 Profile 객체를 만듭니다.
  Profile copyWith({
    String? name,
    String? avatar,
    int? brushCount,
  }) {
    return Profile(
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      brushCount: brushCount ?? this.brushCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'avatar': avatar,
    'brushCount': brushCount,
  };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    name: json['name'] ?? '',
    avatar: json['avatar'] ?? 'canine',
    brushCount: json['brushCount'] ?? 0,
  );
}