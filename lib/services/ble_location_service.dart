import 'dart:async';
import 'dart:typed_data';

import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'
    hide CharacteristicProperties;
import 'package:permission_handler/permission_handler.dart';

import 'ble_protocol.dart';

/// Um FindMe detectado por perto via BLE, com dados completos (depois
/// da conexão GATT) ou só o ID curto (antes de conectar).
class NearbyDevice {
  const NearbyDevice({
    required this.shortId,
    this.payload,
    required this.rssi,
    required this.lastSeen,
  });

  final String shortId;
  final BleLocationPayload? payload;
  final int rssi;
  final DateTime lastSeen;
}

/// Serviço BLE de proximidade: o celular funciona como Periférico
/// (hospeda um servidor GATT e anuncia) e como Central (escaneia e
/// conecta em outros FindMe por perto) ao mesmo tempo.
///
/// Restrito a pessoas do círculo: só lê a characteristic de LOCALIZAÇÃO
/// depois de confirmar (via characteristic de IDENTIDADE, lida
/// primeiro) que o ID curto bate com alguém do círculo — estranhos
/// nunca chegam a ter a localização lida.
///
/// AVISO: a API exata do callback de leitura do `ble_peripheral`
/// (setReadRequestCallback) foi escrita com base na documentação do
/// pacote, sem poder testar ao vivo — se a assinatura do callback não
/// bater exatamente, é o primeiro lugar a olhar no erro de compilação.
class BleLocationService {
  BleLocationService({
    required this.myUserId,
    required this.getMyPayload,
    required this.isKnownShortId,
  });

  /// user_id do usuário logado.
  final String myUserId;

  /// Devolve o payload ATUAL (posição/bateria) na hora de responder uma
  /// leitura — assim sempre manda o dado mais recente.
  final BleLocationPayload Function() getMyPayload;

  /// Diz se um short id detectado é de alguém do círculo. Se não for,
  /// o serviço nem lê a characteristic de localização.
  final bool Function(String shortIdHex) isKnownShortId;

  final _nearbyController = StreamController<NearbyDevice>.broadcast();
  final Map<String, NearbyDevice> _nearbyCache = {};

  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _isRunning = false;

  Stream<NearbyDevice> get nearbyStream => _nearbyController.stream;
  Map<String, NearbyDevice> get nearbyCache => Map.unmodifiable(_nearbyCache);

  /// Pede as permissões de BLE em runtime. Chame antes de start().
  Future<bool> ensurePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every(
      (status) => status.isGranted || status.isLimited,
    );
  }

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    await _startPeripheralServer();
    await _startScanning();
  }

  Future<void> stop() async {
    _isRunning = false;
    await _scanSub?.cancel();
    _scanSub = null;
    await FlutterBluePlus.stopScan();
    await BlePeripheral.stopAdvertising();
  }

  // -------------------------------------------------------------------
  // PERIFÉRICO: hospeda o serviço GATT com 2 characteristics (identidade
  // curta + localização completa) e anuncia o serviço.
  // -------------------------------------------------------------------
  Future<void> _startPeripheralServer() async {
    await BlePeripheral.initialize();

    await BlePeripheral.addService(
      BleService(
        uuid: BleProtocol.serviceUuid,
        primary: true,
        characteristics: [
          BleCharacteristic(
            uuid: BleProtocol.identityCharacteristicUuid,
            properties: [CharacteristicProperties.read.index],
            value: null,
            permissions: [AttributePermissions.readable.index],
          ),
          BleCharacteristic(
            uuid: BleProtocol.locationCharacteristicUuid,
            properties: [CharacteristicProperties.read.index],
            value: null,
            permissions: [AttributePermissions.readable.index],
          ),
        ],
      ),
    );

    BlePeripheral.setReadRequestCallback((
      deviceId,
      characteristicId,
      offset,
      value,
    ) {
      final upperId = characteristicId.toLowerCase();
      if (upperId == BleProtocol.identityCharacteristicUuid.toLowerCase()) {
        return ReadRequestResult(
          value: BleProtocol.shortIdFromUserId(myUserId),
        );
      }
      if (upperId == BleProtocol.locationCharacteristicUuid.toLowerCase()) {
        return ReadRequestResult(value: getMyPayload().encode());
      }
      return ReadRequestResult(value: Uint8List(0));
    });

    await BlePeripheral.startAdvertising(
      services: [BleProtocol.serviceUuid],
      localName: 'FindMe',
    );
  }

  // -------------------------------------------------------------------
  // CENTRAL: escaneia por [BleProtocol.serviceUuid]. Ao encontrar,
  // conecta, lê a IDENTIDADE primeiro; só lê a LOCALIZAÇÃO se for
  // alguém do círculo.
  // -------------------------------------------------------------------
  Future<void> _startScanning() async {
    await FlutterBluePlus.startScan(
      withServices: [Guid(BleProtocol.serviceUuid)],
      continuousUpdates: true,
      timeout: const Duration(hours: 1),
    );

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        _connectAndIdentify(result);
      }
    });
  }

  Future<void> _connectAndIdentify(ScanResult result) async {
    final device = result.device;
    try {
      if (device.isDisconnected) {
        await device.connect(timeout: const Duration(seconds: 8));
      }
      // MTU padrão do BLE (23 bytes) não cabe o payload de localização
      // (29 bytes) — pede um MTU maior antes de ler.
      await device.requestMtu(185);

      final services = await device.discoverServices();
      final service = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() == BleProtocol.serviceUuid,
        orElse: () => throw StateError('Serviço FindMe não encontrado.'),
      );

      final identityChar = service.characteristics.firstWhere(
        (c) =>
            c.uuid.toString().toLowerCase() ==
            BleProtocol.identityCharacteristicUuid,
      );
      final identityBytes = await identityChar.read();
      final shortIdHex = Uint8List.fromList(identityBytes)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

      _nearbyCache[shortIdHex] = NearbyDevice(
        shortId: shortIdHex,
        payload: _nearbyCache[shortIdHex]?.payload,
        rssi: result.rssi,
        lastSeen: DateTime.now(),
      );

      // Não é ninguém do círculo -> desconecta sem ler a localização.
      if (!isKnownShortId(shortIdHex)) {
        await device.disconnect();
        return;
      }

      final locationChar = service.characteristics.firstWhere(
        (c) =>
            c.uuid.toString().toLowerCase() ==
            BleProtocol.locationCharacteristicUuid,
      );
      final locationBytes = await locationChar.read();
      final payload = BleLocationPayload.decode(locationBytes);

      if (payload != null) {
        final nearby = NearbyDevice(
          shortId: shortIdHex,
          payload: payload,
          rssi: result.rssi,
          lastSeen: DateTime.now(),
        );
        _nearbyCache[shortIdHex] = nearby;
        _nearbyController.add(nearby);
      }
    } catch (_) {
      // Silencioso: falha pontual de conexão BLE é comum (sinal fraco,
      // aparelho se afastou no meio do processo) — o próximo resultado
      // de scan tenta de novo sozinho.
    } finally {
      await device.disconnect();
    }
  }

  Future<void> dispose() async {
    await stop();
    await _nearbyController.close();
  }
}
