import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';

enum GeofenceTrigger { arrives, leaves }

enum GeofenceFrequency { once, always }

GeofenceTrigger geofenceTriggerFromString(String v) =>
    v == 'arrives' ? GeofenceTrigger.arrives : GeofenceTrigger.leaves;

GeofenceFrequency geofenceFrequencyFromString(String v) =>
    v == 'always' ? GeofenceFrequency.always : GeofenceFrequency.once;

class GeofenceAlertModel {
  const GeofenceAlertModel({
    required this.id,
    required this.targetUserId,
    required this.label,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    required this.trigger,
    required this.frequency,
    required this.enabled,
    this.lastTriggeredAt,
  });

  final String id;
  final String targetUserId;
  final String label;
  final double lat;
  final double lng;
  final double radiusMeters;
  final GeofenceTrigger trigger;
  final GeofenceFrequency frequency;
  final bool enabled;
  final DateTime? lastTriggeredAt;

  factory GeofenceAlertModel.fromMap(Map<String, dynamic> map) {
    return GeofenceAlertModel(
      id: map['id'] as String,
      targetUserId: map['target_user_id'] as String,
      label: map['label'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      radiusMeters: (map['radius_meters'] as num).toDouble(),
      trigger: geofenceTriggerFromString(map['trigger_type'] as String),
      frequency: geofenceFrequencyFromString(map['frequency'] as String),
      enabled: map['enabled'] as bool,
      lastTriggeredAt: map['last_triggered_at'] != null
          ? DateTime.parse(map['last_triggered_at'] as String)
          : null,
    );
  }
}

/// Só CRUD dos alertas — a detecção de "entrou/saiu" do raio acontece no
/// HomeController, comparando com as posições que já chegam via Realtime.
/// Sem isso rodar em segundo plano ainda (ver nota no schema.sql).
class GeofenceRepository {
  final _client = SupabaseConfig.client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Usuário não autenticado.');
    return id;
  }

  Future<List<GeofenceAlertModel>> listMyAlerts() async {
    final rows = await _client
        .from('geofence_alerts')
        .select()
        .eq('owner_id', _uid)
        .eq('enabled', true);
    return (rows as List)
        .map((r) => GeofenceAlertModel.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> createAlert({
    required String targetUserId,
    required String label,
    required double lat,
    required double lng,
    double radiusMeters = 150,
    required GeofenceTrigger trigger,
    required GeofenceFrequency frequency,
  }) async {
    await _client.from('geofence_alerts').insert({
      'owner_id': _uid,
      'target_user_id': targetUserId,
      'label': label,
      'lat': lat,
      'lng': lng,
      'radius_meters': radiusMeters,
      'trigger_type':
          trigger == GeofenceTrigger.arrives ? 'arrives' : 'leaves',
      'frequency':
          frequency == GeofenceFrequency.always ? 'always' : 'once',
    });
  }

  Future<void> markTriggered(String alertId) async {
    await _client
        .from('geofence_alerts')
        .update({
          'last_triggered_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', alertId);
  }

  Future<void> disable(String alertId) async {
    await _client
        .from('geofence_alerts')
        .update({'enabled': false}).eq('id', alertId);
  }

  Future<void> deleteAlert(String alertId) async {
    await _client.from('geofence_alerts').delete().eq('id', alertId);
  }
}
