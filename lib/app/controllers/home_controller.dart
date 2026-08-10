import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_theme.dart';

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

  /// Posição do GPS local, sempre buscada ao abrir o mapa — independe
  /// de "Compartilhar" estar ligado. É o que garante o pino "Você"
  /// aparecer mesmo se o usuário nunca compartilhou com ninguém.
  final myPosition = Rxn<Position>();

  StreamSubscription<Map<String, UserLocationModel>>? _sub;
  GoogleMapController? _mapController;

  String get myUserId => SupabaseConfig.currentUser?.id ?? '';

  @override
  void onInit() {
    super.onInit();
    isSharingMyLocation.value = _broadcastService.isBroadcasting;

    // Antes, erros ficavam só guardados em errorMessage sem nenhum
    // feedback visual — o usuário via o mapa parado, sem saber por quê.
    // Agora qualquer erro (permissão negada, GPS indisponível, etc.)
    // aparece como um snackbar.
    ever<String?>(errorMessage, (msg) {
      if (msg == null) return;
      Get.snackbar(
        'Algo deu errado',
        msg,
        backgroundColor: AppColors.pending,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
      );
    });

    _loadMyCurrentPosition();
    _startListening();
    loadPeople();
  }

  /// Pede permissão e busca a posição atual do GPS, só pra mostrar no
  /// próprio mapa — isso NÃO envia nada pro Supabase (quem faz isso é
  /// o LocationBroadcastService, ligado só quando "Compartilhar" está
  /// ativo). Antes, o pino "Você" só existia depois de compartilhar,
  /// o que deixava o mapa vazio pra quem nunca tinha apertado o botão.
  Future<void> _loadMyCurrentPosition() async {
    try {
      await _broadcastService.ensurePermissions();

      // Fallback rápido: se já tem uma posição conhecida (de antes), usa
      // ela imediatamente enquanto busca uma nova mais precisa — evita
      // ficar com o mapa parado enquanto espera o GPS "esquentar".
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        myPosition.value = lastKnown;
        _rebuildMarkers();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      myPosition.value = position;
      _rebuildMarkers();
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            15,
          ),
        );
      }
    } catch (e) {
      errorMessage.value =
          'Não foi possível obter sua localização: ${e.toString()}';
    }
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
    _rebuildMarkers();
  }

  void _rebuildMarkers() {
    final Set<Marker> result = {};

    // Pessoas com localização no Supabase — inclui eu mesmo, SE eu
    // estiver compartilhando (só nesse caso existe uma linha minha
    // na tabela locations).
    for (final loc in locations.values) {
      final isMe = loc.userId == myUserId;
      final profile = _profileFor(loc.userId);
      final label = isMe
          ? 'Você'
          : (profile?.displayName ?? profile?.username ?? 'Pessoa');
      result.add(
        Marker(
          markerId: MarkerId(loc.userId),
          position: LatLng(loc.lat, loc.lng),
          infoWindow: InfoWindow(
            title: label,
            snippet: formatLastSeen(loc.updatedAt),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isMe ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueOrange,
          ),
        ),
      );
    }

    // Se eu NÃO estiver compartilhando (sem linha minha no Supabase),
    // uso a posição do GPS local só pra desenhar meu próprio pino —
    // ninguém mais recebe isso, é só visual, no meu próprio mapa.
    if (!locations.containsKey(myUserId) && myPosition.value != null) {
      final pos = myPosition.value!;
      result.add(
        Marker(
          markerId: const MarkerId('me-local'),
          position: LatLng(pos.latitude, pos.longitude),
          infoWindow: const InfoWindow(title: 'Você'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }

    markers.assignAll(result);
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
    final pos = myPosition.value;
    if (pos != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15),
      );
    }
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
