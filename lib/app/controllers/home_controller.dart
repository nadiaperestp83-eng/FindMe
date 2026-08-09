import 'dart:async';

import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/supabase_config.dart';
import '../../data/models/circle_models.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/user_location_model.dart';
import '../../data/repositories/circle_repository.dart';
import '../../data/services/location_broadcast_service.dart';
import '../../data/services/realtime_location_listener_service.dart';

/// Controller único da tela pós-login (estilo Find My). Substitui
/// CirclesController + CircleDetailController + LiveMapController — não
/// tem mais tela de "Círculos" separada, então tudo mora num lugar só.
class HomeController extends GetxController {
  HomeController({
    CircleRepository? circleRepository,
    RealtimeLocationListenerService? realtimeService,
  })  : _circleRepository = circleRepository ?? CircleRepository(),
        _realtimeService =
            realtimeService ?? RealtimeLocationListenerService();

  final CircleRepository _circleRepository;
  final RealtimeLocationListenerService _realtimeService;
  final _broadcastService = LocationBroadcastService.instance;

  final locations = <String, UserLocationModel>{}.obs;
  final markers = <Marker>{}.obs;
  final sharedMembers = <CircleMemberModel>[].obs;
  final pendingInvites = <CircleMemberModel>[].obs;
  final isSharingMyLocation = false.obs;
  final isLoadingPeople = false.obs;
  final isInviting = false.obs;
  final errorMessage = RxnString();

  StreamSubscription<Map<String, UserLocationModel>>? _sub;
  GoogleMapController? _mapController;

  String get myUserId => SupabaseConfig.currentUser?.id ?? '';

  @override
  void onInit() {
    super.onInit();
    isSharingMyLocation.value = _broadcastService.isBroadcasting;
    _startListening();
    loadPeople();
  }

  Future<void> _startListening() async {
    try {
      await _realtimeService.listenToAllMyCircles();
      _sub = _realtimeService.locationsStream.listen(_onLocationsUpdated);
    } catch (_) {
      errorMessage.value = 'Não foi possível conectar ao tempo real.';
    }
  }

  Future<void> loadPeople() async {
    try {
      isLoadingPeople.value = true;
      final shared = await _circleRepository.listAllSharedMembers();
      final invites = await _circleRepository.listMyPendingInvites();
      sharedMembers.assignAll(shared);
      pendingInvites.assignAll(invites);
    } catch (_) {
      // Silencioso de propósito: a tela de mapa não deve travar por
      // causa da lista de pessoas falhar em carregar.
    } finally {
      isLoadingPeople.value = false;
    }
  }

  void _onLocationsUpdated(Map<String, UserLocationModel> data) {
    locations.assignAll(data);
    markers.assignAll(
      data.values.map((loc) {
        final isMe = loc.userId == myUserId;
        final profile = _profileFor(loc.userId);
        final label = isMe
            ? 'Você'
            : (profile?.displayName ?? profile?.username ?? 'Pessoa');
        return Marker(
          markerId: MarkerId(loc.userId),
          position: LatLng(loc.lat, loc.lng),
          infoWindow: InfoWindow(
            title: label,
            snippet: formatLastSeen(loc.updatedAt),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isMe ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueOrange,
          ),
        );
      }).toSet(),
    );
  }

  ProfileModel? _profileFor(String userId) {
    for (final m in sharedMembers) {
      if (m.userId == userId) return m.profile;
    }
    return null;
  }

  String labelFor(String userId) {
    if (userId == myUserId) return 'Você';
    final profile = _profileFor(userId);
    return profile?.displayName ?? profile?.username ?? 'Pessoa';
  }

  String formatLastSeen(DateTime updatedAt) {
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

  /// Convida alguém por username. Cria um círculo automático por baixo
  /// dos panos se o usuário ainda não tiver nenhum — sem UI de círculo.
  Future<bool> invitePerson(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return false;
    try {
      isInviting.value = true;
      errorMessage.value = null;
      final circleId = await _circleRepository.ensureDefaultCircle();
      await _circleRepository.inviteByUsername(
        circleId: circleId,
        username: trimmed,
      );
      await loadPeople();
      return true;
    } catch (_) {
      errorMessage.value = 'Usuário não encontrado ou já convidado.';
      return false;
    } finally {
      isInviting.value = false;
    }
  }

  Future<void> acceptInvite(CircleMemberModel invite) async {
    await _circleRepository.acceptInvite(invite.circleId);
    pendingInvites.removeWhere((i) => i.circleId == invite.circleId);
    await loadPeople();
  }

  Future<void> declineInvite(CircleMemberModel invite) async {
    await _circleRepository.declineInvite(invite.circleId);
    pendingInvites.removeWhere((i) => i.circleId == invite.circleId);
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
    super.onClose();
  }
}
