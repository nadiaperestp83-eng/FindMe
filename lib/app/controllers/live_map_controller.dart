import 'dart:async';

import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/supabase_config.dart';
import '../../data/models/circle_models.dart';
import '../../data/models/user_location_model.dart';
import '../../data/services/location_broadcast_service.dart';
import '../../data/services/realtime_location_listener_service.dart';

class LiveMapController extends GetxController {
  LiveMapController({
    required this.circleId,
    required this.circleName,
    this.membersById = const {},
  });

  final String circleId;
  final String circleName;

  /// userId -> CircleMemberModel (com profile), passado pela tela de
  /// detalhe do círculo para rotular os marcadores sem nova query.
  final Map<String, CircleMemberModel> membersById;

  final _realtimeService = RealtimeLocationListenerService();
  final _broadcastService = LocationBroadcastService.instance;

  final locations = <String, UserLocationModel>{}.obs;
  final markers = <Marker>{}.obs;
  final isSharingMyLocation = false.obs;
  final errorMessage = RxnString();

  StreamSubscription<Map<String, UserLocationModel>>? _sub;
  GoogleMapController? _mapController;

  String get myUserId => SupabaseConfig.currentUser?.id ?? '';

  @override
  void onInit() {
    super.onInit();
    isSharingMyLocation.value =
        LocationBroadcastService.instance.isBroadcasting;
    _startListening();
  }

  Future<void> _startListening() async {
    try {
      await _realtimeService.listenToCircle(circleId);
      _sub = _realtimeService.locationsStream.listen(_onLocationsUpdated);
    } catch (_) {
      errorMessage.value = 'Não foi possível conectar ao tempo real.';
    }
  }

  void _onLocationsUpdated(Map<String, UserLocationModel> data) {
    locations.assignAll(data);
    markers.assignAll(
      data.values.map((loc) {
        final isMe = loc.userId == myUserId;
        final label = isMe
            ? 'Você'
            : (membersById[loc.userId]?.profile?.displayName ??
                membersById[loc.userId]?.profile?.username ??
                'Membro');
        return Marker(
          markerId: MarkerId(loc.userId),
          position: LatLng(loc.lat, loc.lng),
          infoWindow: InfoWindow(
            title: label,
            snippet: _formatLastSeen(loc.updatedAt),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isMe
                ? BitmapDescriptor.hueAzure
                : BitmapDescriptor.hueOrange,
          ),
        );
      }).toSet(),
    );
  }

  String _formatLastSeen(DateTime updatedAt) {
    final diff = DateTime.now().toUtc().difference(updatedAt.toUtc());
    if (diff.inSeconds < 60) return 'agora mesmo';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    return 'há ${diff.inHours} h';
  }

  Future<void> toggleMyLocationSharing() async {
    try {
      if (isSharingMyLocation.value) {
        await _broadcastService.stop();
        isSharingMyLocation.value = false;
      } else {
        await _broadcastService.start();
        isSharingMyLocation.value = true;
      }
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  void onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  Future<void> focusOn(String userId) async {
    final loc = locations[userId];
    if (loc == null || _mapController == null) return;
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(loc.lat, loc.lng), 16),
    );
  }

  @override
  void onClose() {
    _sub?.cancel();
    _realtimeService.dispose();
    // Nota: o broadcast NÃO é interrompido aqui de propósito — ele deve
    // seguir em segundo plano mesmo com o mapa fechado (isso é resolvido
    // de verdade na Etapa 2, com o foreground service Android). Se quiser
    // que o envio pare ao sair desta tela, chame stop() aqui.
    super.onClose();
  }
}
