import 'package:flutter/services.dart' show DartPluginRegistrant;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';

import '../core/supabase_config.dart';

/// Mantém o envio de localização pro Supabase rodando mesmo com o app
/// fechado/minimizado, via foreground service do Android (notificação
/// persistente obrigatória, exigida pelo próprio sistema operacional).
///
/// Controlado direto pelo botão Compartilhar/Cancelar da tela de Mapa:
/// - Compartilhar -> start() -> notificação aparece, serviço roda.
/// - Cancelar -> stop() -> notificação some, serviço para na hora.
class BackgroundLocationService {
  BackgroundLocationService._();

  static const _notificationChannelId = 'findme_location_channel';
  static const _notificationId = 888;

  /// Chamado uma vez, cedo, no main.dart. Só CONFIGURA o serviço —
  /// não inicia o rastreamento ainda (autoStart: false). O rastreamento
  /// só começa quando o usuário aperta "Compartilhar" (ver start()).
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onServiceStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _notificationChannelId,
        initialNotificationTitle: 'FindMe',
        initialNotificationContent: 'Compartilhando sua localização',
        foregroundServiceNotificationId: _notificationId,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onServiceStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  static Future<void> start() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }

  /// Para o serviço na hora — notificação some, rastreamento em segundo
  /// plano é interrompido imediatamente (botão "Cancelar").
  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  static Future<bool> isRunning() async {
    return FlutterBackgroundService().isRunning();
  }

  /// Roda num ISOLATE separado do app principal — por isso precisa
  /// reinicializar dotenv e Supabase aqui dentro, mesmo que o app já
  /// tenha feito isso na tela principal. Isolates não compartilham
  /// memória entre si.
  @pragma('vm:entry-point')
  static void _onServiceStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    await dotenv.load(fileName: "assets/dotenv/.env");
    await SupabaseConfig.initialize();

    if (service is AndroidServiceInstance) {
      service.on('stopService').listen((event) {
        service.stopSelf();
      });
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((position) async {
      final userId = SupabaseConfig.currentUser?.id;
      if (userId == null) return;

      try {
        await SupabaseConfig.client.from('locations').upsert({
          'user_id': userId,
          'lat': position.latitude,
          'lng': position.longitude,
          'accuracy': position.accuracy,
          'speed': position.speed,
          'heading': position.heading,
          'altitude': position.altitude,
          'source': 'gps',
        }, onConflict: 'user_id');
      } catch (_) {
        // Silencioso de propósito: a próxima leitura de posição tenta
        // de novo sozinha, não vale a pena parar o serviço por isso.
      }

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'FindMe',
          content: 'Compartilhando sua localização',
        );
      }
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    return true;
  }
}
