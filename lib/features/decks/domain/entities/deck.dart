class AppDeck {
  final String id;
  final String name;
  final String? bio;
  final String userId;
  final String color;
  final String icon;
  final String? coverImageUrl;
  final int createdAt;

  const AppDeck({
    required this.id,
    required this.name,
    this.bio,
    required this.userId,
    required this.color,
    required this.icon,
    this.coverImageUrl,
    required this.createdAt,
  });
}
