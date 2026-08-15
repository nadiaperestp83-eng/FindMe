import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'
    hide CharacteristicProperties;
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:location/location.dart' as loc;

/// Monitora os 3 sinais que decidem se o "modo de proximidade" (BLE)
/// consegue funcionar: internet, GPS/Localização e Bluetooth.
///
/// Hierarquia (conforme combinado):
/// - Com internet: tudo normal, BLE é só um extra.
/// - Sem internet, mas com GPS ligado: o BLE ainda tem chance de achar
///   gente por perto.
/// - Sem internet E sem GPS: BLE fica "engessado" (Android trava scan
///   de BLE sem localização ativa) — é aí que o banner aparece.
class ConnectivityGuardController extends GetxController {
  final hasInternet = true.obs;
  final isLocationOn = true.obs;
  final isBluetoothOn = true.obs;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<ServiceStatus>? _locationStatusSub;
  StreamSubscription<BluetoothAdapterState>? _bluetoothSub;

  /// true = mostra o banner "Sem conexão e localização desativada".
  bool get showOfflineProximityBanner =>
      !hasInternet.value && !isLocationOn.value;

  @override
  void onInit() {
    super.onInit();
    _checkInitialState();

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      hasInternet.value = results.any((r) => r != ConnectivityResult.none);
    });

    _locationStatusSub = Geolocator.getServiceStatusStream().listen((status) {
      isLocationOn.value = status == ServiceStatus.enabled;
    });

    _bluetoothSub = FlutterBluePlus.adapterState.listen((state) {
      isBluetoothOn.value = state == BluetoothAdapterState.on;
    });
  }

  Future<void> _checkInitialState() async {
    final results = await Connectivity().checkConnectivity();
    hasInternet.value = results.any((r) => r != ConnectivityResult.none);
    isLocationOn.value = await Geolocator.isLocationServiceEnabled();
    isBluetoothOn.value =
        await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;
  }

  /// Popup NATIVO de 1 toque pra ligar o GPS (via pacote `location`,
  /// já dependência do projeto — é ele que tem esse recurso, geolocator
  /// sozinho só abre a tela de configurações, sem popup de 1 toque).
  Future<void> requestEnableLocation() async {
    final location = loc.Location();
    await location.requestService();
  }

  /// Popup NATIVO de 1 toque pra ligar o Bluetooth.
  Future<void> requestEnableBluetooth() async {
    await FlutterBluePlus.turnOn();
  }

  @override
  void onClose() {
    _connectivitySub?.cancel();
    _locationStatusSub?.cancel();
    _bluetoothSub?.cancel();
    super.onClose();
  }
}
