import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:quickstep_app/app/routes/circles_module_routes.dart';
import 'package:quickstep_app/app/theme/app_theme.dart';
import 'package:quickstep_app/auth_wrapper.dart';
import 'package:quickstep_app/core/supabase_config.dart';
import 'package:quickstep_app/services/background_location_service.dart';
import 'package:quickstep_app/services/hive_service.dart';
import 'package:quickstep_app/utils/colors.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  //Initializing flutter hive database
  await Hive.initFlutter();

  //Opening database of the saved walks
  await Future.wait([
    Hive.openBox(Boxes.selfMadeWalksBox),
    Hive.openBox(Boxes.activitiesBox),
    Hive.openBox(Boxes.authBox),
    Hive.openBox(Boxes.dailyRouteBox),
    Hive.openBox(Boxes.nearbyDevicesBox),
  ]);

  //Initialising dotenv variables
  await dotenv.load(fileName: "assets/dotenv/.env");

  // Inicializa o Supabase (substitui o backend Node.js/Socket.io).
  // Precisa rodar depois do dotenv.load, já que lê SUPABASE_URL e
  // SUPABASE_ANON_KEY do assets/dotenv/.env.
  await SupabaseConfig.initialize();

  // Configura (mas não LIGA) o foreground service de localização em
  // segundo plano. Só começa a rastrear quando o usuário aperta
  // "Compartilhar" na tela de Mapa (ver BackgroundLocationService.start()).
  await BackgroundLocationService.initialize();

  //Running flutter application
  runApp(const AppWidget());
}

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 850),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Quick Step Application',
          color: primary,
          theme: AppTheme.light,
          home: child,
          // Rotas de Círculos/Mapa ao vivo (Get.toNamed usado dentro de
          // lib/app/screens/circles/... e lib/app/screens/map/...).
          // AuthWrapper continua controlando login/logout diretamente
          // por widget, sem rota nomeada — não precisa de authModuleRoutes.
          getPages: circlesModuleRoutes,
        );
      },
      child: const AuthWrapper(),
    );
  }
}
