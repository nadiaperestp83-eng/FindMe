import 'profile_model.dart';

enum CircleMemberStatus { pending, accepted, declined }

CircleMemberStatus circleMemberStatusFromString(String value) {
  switch (value) {
    case 'accepted':
      return CircleMemberStatus.accepted;
    case 'declined':
      return CircleMemberStatus.declined;
    default:
      return CircleMemberStatus.pending;
  }
}

class CircleModel {
  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;

  const CircleModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
  });

  factory CircleModel.fromMap(Map<String, dynamic> map) {
    return CircleModel(
      id: map['id'] as String,
      name: map['name'] as String,
      ownerId: map['owner_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class CircleMemberModel {
  final String circleId;
  final String userId;
  final String role;
  final CircleMemberStatus status;
  final ProfileModel? profile;

  const CircleMemberModel({
    required this.circleId,
    required this.userId,
    required this.role,
    required this.status,
    this.profile,
  });

  factory CircleMemberModel.fromMap(Map<String, dynamic> map) {
    return CircleMemberModel(
      circleId: map['circle_id'] as String,
      userId: map['user_id'] as String,
      role: map['role'] as String,
      status: circleMemberStatusFromString(map['status'] as String),
      profile: map['profiles'] != null
          ? ProfileModel.fromMap(map['profiles'] as Map<String, dynamic>)
          : null,
    );
  }
}
