/// 프로필 데이터 모델
class Profile {
  final String name;
  final String avatar;
  final int brushCount;

  Profile({
    required this.name,
    required this.avatar,
    this.brushCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'avatar': avatar,
    'brushCount': brushCount,
  };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    name: json['name'] ?? '',
    avatar: json['avatar'] ?? 'canine', // 기본값
    brushCount: json['brushCount'] ?? 0,
  );
}
