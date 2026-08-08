// ATENÇÃO: este arquivo é um SNIPPET de referência, não um arquivo para
// substituir a rota existente do QuickStep. Copie as 3 entradas de
// GetPage abaixo para dentro da lista `getPages` que já existe no seu
// `app_pages.dart` / `app_routes.dart` original, ajustando os imports.
//
// Exemplo de uso na navegação:
//
//   Get.toNamed(AppRoutes.circles);
//
//   Get.toNamed(AppRoutes.circleDetail, arguments: circleModel);
//
//   Get.toNamed(
//     AppRoutes.liveMap,
//     arguments: LiveMapArgs(
//       circleId: circle.id,
//       circleName: circle.name,
//       membersById: circleDetailController.membersById,
//     ),
//   );

import 'package:get/get.dart';

import '../bindings/app_bindings.dart';
import '../screens/circles/circle_detail_screen.dart';
import '../screens/circles/circles_list_screen.dart';
import '../screens/circles/pending_invites_screen.dart';
import '../screens/map/live_map_screen.dart';

abstract class AppRoutes {
  static const circles = '/circles';
  static const pendingInvites = '/circles/invites';
  static const circleDetail = '/circles/detail';
  static const liveMap = '/circles/live-map';
}

final circlesModuleRoutes = <GetPage>[
  GetPage(
    name: AppRoutes.circles,
    page: () => const CirclesListScreen(),
    binding: CirclesBinding(),
  ),
  GetPage(
    name: AppRoutes.pendingInvites,
    page: () => const PendingInvitesScreen(),
    binding: CirclesBinding(),
  ),
  GetPage(
    name: AppRoutes.circleDetail,
    page: () => const CircleDetailScreen(),
    binding: CircleDetailBinding(),
  ),
  GetPage(
    name: AppRoutes.liveMap,
    page: () => const LiveMapScreen(),
    binding: LiveMapBinding(),
  ),
];
