class ProfileModel {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  const ProfileModel({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: map['id'] as String,
      username: map['username'] as String,
      displayName: map['display_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
    );
  }
}
