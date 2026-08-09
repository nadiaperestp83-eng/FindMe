class UserLocationModel {
  final String userId;
  final double lat;
  final double lng;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final double? altitude;
  final int? batteryLevel;
  final String source; // gps | network | ble_relay
  final DateTime updatedAt;

  const UserLocationModel({
    required this.userId,
    required this.lat,
    required this.lng,
    required this.source,
    required this.updatedAt,
    this.accuracy,
    this.speed,
    this.heading,
    this.altitude,
    this.batteryLevel,
  });

  factory UserLocationModel.fromMap(Map<String, dynamic> map) {
    return UserLocationModel(
      userId: map['user_id'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      batteryLevel: (map['battery_level'] as num?)?.toInt(),
      source: map['source'] as String? ?? 'gps',
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Payload pronto para upsert. lat/lng viram a coluna "position"
  /// automaticamente via GENERATED COLUMN no banco (ver schema.sql).
  Map<String, dynamic> toUpsertMap() {
    return {
      'user_id': userId,
      'lat': lat,
      'lng': lng,
      if (accuracy != null) 'accuracy': accuracy,
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
      if (altitude != null) 'altitude': altitude,
      if (batteryLevel != null) 'battery_level': batteryLevel,
      'source': source,
    };
  }
}
