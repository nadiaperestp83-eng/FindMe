import 'dart:convert';
import 'dart:typed_data';

/// Protocolo BLE de proximidade do FindMe.
///
/// Dois estágios, por causa do limite de tamanho do pacote de
/// advertisement BLE (~20-31 bytes úteis, não cabe um UUID completo +
/// localização):
///
/// 1) ANÚNCIO (Periférico): cada aparelho anuncia [serviceUuid] +
///    um ID CURTO de 4 bytes (hash do seu user_id) — só isso cabe.
/// 2) CONEXÃO GATT (depois que um Central reconhece o serviço): troca
///    o payload completo (user_id inteiro + lat/lng + bateria +
///    horário) via characteristic, que aceita bem mais bytes.
///
/// IMPORTANTE: troque esses UUIDs por outros gerados por você antes de
/// ir pra produção de verdade (esses aqui são só um exemplo consistente
/// pra o app funcionar; UUID duplicado com outro app na mesma área BLE
/// causaria falso-positivo de "achei um FindMe por perto").
class BleProtocol {
  BleProtocol._();

  /// Identifica "isso é um FindMe" pros scanners saberem filtrar.
  static const String serviceUuid = 'd4a7b3e0-0001-4f6e-8f2a-0123456789ab';

  /// Characteristic usada pra trocar o payload completo após conectar.
  static const String locationCharacteristicUuid =
      'd4a7b3e0-0002-4f6e-8f2a-0123456789ab';

  /// Deriva um ID curto (4 bytes) e determinístico a partir do user_id
  /// completo (uuid do Supabase) — é o que vai no advertisement, já que
  /// o uuid inteiro (36 caracteres) não cabe no pacote.
  ///
  /// Hash simples FNV-1a de 32 bits — sem depender de nenhum pacote de
  /// criptografia externo, só pra ter um identificador curto e estável.
  static Uint8List shortIdFromUserId(String userId) {
    const int fnvOffsetBasis = 0x811c9dc5;
    const int fnvPrime = 0x01000193;

    int hash = fnvOffsetBasis;
    for (final byte in utf8.encode(userId)) {
      hash ^= byte;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }

    final bytes = ByteData(4)..setUint32(0, hash, Endian.big);
    return bytes.buffer.asUint8List();
  }

  /// Versão em hex do short id, útil pra comparar/logar.
  static String shortIdHex(String userId) {
    final bytes = shortIdFromUserId(userId);
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Payload completo trocado via GATT depois que dois aparelhos se
/// reconhecem e conectam. 29 bytes: 16 (uuid) + 4 (lat) + 4 (lng) +
/// 1 (bateria) + 4 (timestamp, segundos desde epoch).
class BleLocationPayload {
  const BleLocationPayload({
    required this.userId,
    required this.lat,
    required this.lng,
    required this.batteryLevel,
    required this.timestamp,
  });

  final String userId;
  final double lat;
  final double lng;
  final int batteryLevel; // 0-100
  final DateTime timestamp;

  /// Serializa pra bytes, pronto pra escrever na characteristic.
  Uint8List encode() {
    final uuidBytes = _uuidToBytes(userId);
    final data = ByteData(29);

    for (var i = 0; i < 16; i++) {
      data.setUint8(i, uuidBytes[i]);
    }
    data.setFloat32(16, lat, Endian.big);
    data.setFloat32(20, lng, Endian.big);
    data.setUint8(24, batteryLevel.clamp(0, 100));
    data.setUint32(
      25,
      timestamp.toUtc().millisecondsSinceEpoch ~/ 1000,
      Endian.big,
    );

    return data.buffer.asUint8List();
  }

  /// Lê os bytes recebidos de volta pra um payload utilizável.
  static BleLocationPayload? decode(List<int> bytes) {
    if (bytes.length < 29) return null;

    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final uuidBytes = bytes.sublist(0, 16);
    final lat = data.getFloat32(16, Endian.big);
    final lng = data.getFloat32(20, Endian.big);
    final battery = data.getUint8(24);
    final epochSeconds = data.getUint32(25, Endian.big);

    return BleLocationPayload(
      userId: _bytesToUuid(uuidBytes),
      lat: lat,
      lng: lng,
      batteryLevel: battery,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        epochSeconds * 1000,
        isUtc: true,
      ),
    );
  }

  static Uint8List _uuidToBytes(String uuid) {
    final hex = uuid.replaceAll('-', '');
    final bytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  static String _bytesToUuid(List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}
