import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

import '../../core/supabase_config.dart';
import '../../data/models/circle_models.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/user_location_model.dart';
import '../../data/repositories/circle_repository.dart';
import '../../data/repositories/geofence_repository.dart';
import '../../data/repositories/route_history_repository.dart';
import '../../data/services/location_broadcast_service.dart';
import '../../data/services/realtime_location_listener_service.dart';

/// Controller único da tela pós-login (estilo Find My). Substitui
/// CirclesController + CircleDetailController + LiveMapController — não
/// tem mais tela de "Círculos" separada, então tudo mora num lugar só.
class HomeController extends GetxController {
  HomeController({
    CircleRepository? circleRepository,
    RealtimeLocationListenerService? realtimeService,
    GeofenceRepository? geofenceRepository,
    RouteHistoryRepository? routeHistoryRepository,
  })  : _circleRepository = circleRepository ?? CircleRepository(),
        _realtimeService =
            realtimeService ?? RealtimeLocationListenerService(),
        _geofenceRepository = geofenceRepository ?? GeofenceRepository(),
        _routeHistoryRepository =
            routeHistoryRepository ?? RouteHistoryRepository();

  final CircleRepository _circleRepository;
  final RealtimeLocationListenerService _realtimeService;
  final GeofenceRepository _geofenceRepository;
  final RouteHistoryRepository _routeHistoryRepository;
  final _broadcastService = LocationBroadcastService.instance;

  final locations = <String, UserLocationModel>{}.obs;
  final markers = <Marker>{}.obs;
  final sharedMembers = <CircleMemberModel>[].obs;
  final pendingInvites = <CircleMemberModel>[].obs;
  final isSharingMyLocation = false.obs;
  final isLoadingPeople = false.obs;
  final isInviting = false.obs;
  final errorMessage = RxnString();

  /// Alertas de "chegou/saiu" ativos do usuário atual (Notify Me).
  final alerts = <GeofenceAlertModel>[].obs;

  /// Estado local (em memória) de "dentro do raio" por alerta — só
  /// existe enquanto o app está aberto, por isso a detecção é
  /// foreground-only por enquanto.
  final Map<String, bool> _wasInsideGeofence = {};

  /// Posição do GPS local, sempre buscada ao abrir o mapa — independe
  /// de "Compartilhar" estar ligado. É o que garante o pino "Você"
  /// aparecer mesmo se o usuário nunca compartilhou com ninguém.
  final myPosition = Rxn<Position>();

  /// Trajeto percorrido hoje (trilha azul no mapa). Persistido no Hive
  /// a cada ponto novo — reabrir o app no mesmo dia continua o traçado
  /// de onde parou.
  final routePoints = <LatLng>[].obs;
  final polylines = <Polyline>{}.obs;

  bool _cameraCenteredOnce = false;
  StreamSubscription<Position>? _positionSub;
  Timer? _routeHeartbeatTimer;
  RealtimeChannel? _inviteChannel;

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

    _startMyPositionStream();
    _startListening();
    loadPeople();
    _loadAlerts();
    _listenForInviteChanges();
  }

  /// Escuta mudanças em circle_members que me afetam (novo convite
  /// recebido, ou alguém aceitando um convite que eu mandei) e recarrega
  /// a lista de pessoas automaticamente — sem isso, só via pull-to-refresh
  /// manual dava pra ver um convite novo chegando.
  void _listenForInviteChanges() {
    _inviteChannel = SupabaseConfig.client
        .channel('circle_members-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'circle_members',
          callback: (payload) => _onCircleMembersChange(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'circle_members',
          callback: (payload) => _onCircleMembersChange(payload.newRecord),
        )
        .subscribe();
  }

  void _onCircleMembersChange(Map<String, dynamic> record) {
    final affectedUserId = record['user_id'] as String?;
    final invitedBy = record['invited_by'] as String?;
    if (affectedUserId == myUserId || invitedBy == myUserId) {
      loadPeople();
    }
  }

  Future<void> _loadAlerts() async {
    try {
      final result = await _geofenceRepository.listMyAlerts();
      alerts.assignAll(result);
    } catch (_) {
      // Silencioso: alertas são um extra, não devem travar o mapa.
    }
  }

  /// Pede permissão e começa a escutar a posição continuamente — antes
  /// era uma busca única (getCurrentPosition), o que bastava pro pino
  /// "Você" mas não dava pra desenhar a trilha percorrida. Isso NÃO
  /// envia nada pro Supabase (quem faz isso é o LocationBroadcastService,
  /// ligado só quando "Compartilhar" está ativo) — é só local + Hive.
  Future<void> _startMyPositionStream() async {
    try {
      await _broadcastService.ensurePermissions();

      // Carrega o trajeto de hoje já salvo, se o app foi reaberto no
      // mesmo dia — o traçado continua de onde parou.
      routePoints.assignAll(_routeHistoryRepository.loadToday());
      _rebuildPolylines();

      // Fallback rápido: mostra a última posição conhecida enquanto o
      // GPS "esquenta" pra dar a primeira leitura precisa.
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        myPosition.value = lastKnown;
        _rebuildMarkers();
      }

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(
        _onMyPositionUpdate,
        onError: (_) {
          errorMessage.value = 'Sinal de GPS perdido.';
        },
      );

      // O stream acima só dispara quando a posição MUDA (distanceFilter).
      // Parado no mesmo lugar, nunca chega ponto novo — e sem pontos
      // novos, a timeline não tem como saber "quanto tempo" você ficou
      // parado. Esse heartbeat registra um ponto a cada 5 min mesmo sem
      // movimento, só pra manter a linha do tempo com dado contínuo.
      _routeHeartbeatTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) {
          final pos = myPosition.value;
          if (pos != null) {
            _routeHistoryRepository
                .appendPoint(LatLng(pos.latitude, pos.longitude));
          }
        },
      );
    } catch (e) {
      errorMessage.value =
          'Não foi possível obter sua localização: ${e.toString()}';
    }
  }

  void _onMyPositionUpdate(Position position) {
    myPosition.value = position;
    _rebuildMarkers();

    final point = LatLng(position.latitude, position.longitude);
    routePoints.add(point);
    _rebuildPolylines();
    _routeHistoryRepository.appendPoint(point);

    if (!_cameraCenteredOnce && _mapController != null) {
      _cameraCenteredOnce = true;
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(point, 15));
    }
  }

  void _rebuildPolylines() {
    if (routePoints.length < 2) {
      polylines.clear();
      return;
    }
    polylines.assignAll({
      Polyline(
        polylineId: const PolylineId('my-route-today'),
        points: routePoints.toList(),
        color: AppColors.live,
        width: 4,
      ),
    });
  }

  Future<void> _startListening() async {
    try {
      await _realtimeService.listenToAllMyCircles();
      _sub = _realtimeService.locationsStream.listen(_onLocationsUpdated);
    } catch (e) {
      errorMessage.value = 'Não foi possível conectar ao tempo real: ${e.toString()}';
    }
  }

  Future<void> loadPeople() async {
    try {
      isLoadingPeople.value = true;
      final shared = await _circleRepository.listAllSharedMembers();
      final invites = await _circleRepository.listMyPendingInvites();
      sharedMembers.assignAll(shared);
      pendingInvites.assignAll(invites);
    } catch (e) {
      // Antes isso era silencioso "de propósito" — mas isso escondeu um
      // bug real (consulta ambígua no Supabase) por várias rodadas.
      // Agora qualquer erro aqui aparece, mesmo que a tela de mapa
      // continue funcionando normalmente.
      errorMessage.value = 'Não foi possível carregar as pessoas: ${e.toString()}';
    } finally {
      isLoadingPeople.value = false;
    }
  }

  void _onLocationsUpdated(Map<String, UserLocationModel> data) {
    locations.assignAll(data);
    _rebuildMarkers();
    _checkGeofences();
  }

  /// Compara a posição atual de cada pessoa observada com o ponto salvo
  /// em cada alerta e dispara quando detecta a transição certa (entrou
  /// ou saiu do raio). Só roda enquanto o app está aberto — é o que foi
  /// combinado por enquanto (sem serviço de segundo plano ainda).
  void _checkGeofences() {
    for (final alert in alerts) {
      final loc = locations[alert.targetUserId];
      if (loc == null) continue;

      final distanceMeters = Geolocator.distanceBetween(
        alert.lat,
        alert.lng,
        loc.lat,
        loc.lng,
      );
      final isInside = distanceMeters <= alert.radiusMeters;
      final wasInside = _wasInsideGeofence[alert.id];
      _wasInsideGeofence[alert.id] = isInside;

      // Primeira leitura: só grava o estado inicial, não dispara nada
      // (evita alerta falso assim que o alerta é criado/carregado).
      if (wasInside == null) continue;

      final justArrived = !wasInside && isInside;
      final justLeft = wasInside && !isInside;

      final shouldFire = (alert.trigger == GeofenceTrigger.arrives && justArrived) ||
          (alert.trigger == GeofenceTrigger.leaves && justLeft);

      if (!shouldFire) continue;

      final personName = labelFor(alert.targetUserId);
      final verb = alert.trigger == GeofenceTrigger.arrives ? 'chegou em' : 'saiu de';
      Get.snackbar(
        'Notify Me',
        '$personName $verb ${alert.label}',
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 6),
      );

      _geofenceRepository.markTriggered(alert.id);
      if (alert.frequency == GeofenceFrequency.once) {
        _geofenceRepository.disable(alert.id);
        alerts.removeWhere((a) => a.id == alert.id);
      }
    }
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
    } catch (e) {
      errorMessage.value = e is StateError
          ? e.message
          : 'Não foi possível convidar: ${e.toString()}';
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

  /// Cria um alerta de Notify Me. [useMyPosition] decide se o ponto
  /// observado é a posição atual da PESSOA (useMyPosition: false) ou a
  /// MINHA posição atual (useMyPosition: true) — mesma escolha que a
  /// tela "Notify Me" da Apple oferece.
  Future<bool> createAlert({
    required String targetUserId,
    required bool useMyPosition,
    required GeofenceTrigger trigger,
    required GeofenceFrequency frequency,
  }) async {
    try {
      double? lat;
      double? lng;
      String label;

      if (useMyPosition) {
        final mine = locations[myUserId] ?? _syntheticMyLocation();
        if (mine == null) {
          errorMessage.value = 'Sua posição atual ainda não está disponível.';
          return false;
        }
        lat = mine.lat;
        lng = mine.lng;
        label = 'sua posição atual';
      } else {
        final theirs = locations[targetUserId];
        if (theirs == null) {
          errorMessage.value =
              'A posição de ${labelFor(targetUserId)} ainda não está disponível.';
          return false;
        }
        lat = theirs.lat;
        lng = theirs.lng;
        label = 'a posição atual de ${labelFor(targetUserId)}';
      }

      await _geofenceRepository.createAlert(
        targetUserId: targetUserId,
        label: label,
        lat: lat,
        lng: lng,
        trigger: trigger,
        frequency: frequency,
      );
      await _loadAlerts();
      return true;
    } catch (e) {
      errorMessage.value = 'Não foi possível criar o alerta: ${e.toString()}';
      return false;
    }
  }

  /// Fallback pra "minha posição" quando eu não estou compartilhando
  /// (sem linha na tabela locations) — usa o GPS local (myPosition).
  UserLocationModel? _syntheticMyLocation() {
    final pos = myPosition.value;
    if (pos == null) return null;
    return UserLocationModel(
      userId: myUserId,
      lat: pos.latitude,
      lng: pos.longitude,
      source: 'gps',
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> deleteAlert(String alertId) async {
    await _geofenceRepository.deleteAlert(alertId);
    alerts.removeWhere((a) => a.id == alertId);
  }

  void onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    final pos = myPosition.value;
    if (pos != null && !_cameraCenteredOnce) {
      _cameraCenteredOnce = true;
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
    _positionSub?.cancel();
    _routeHeartbeatTimer?.cancel();
    if (_inviteChannel != null) {
      SupabaseConfig.client.removeChannel(_inviteChannel!);
    }
    _realtimeService.dispose();
    super.onClose();
  }
}
