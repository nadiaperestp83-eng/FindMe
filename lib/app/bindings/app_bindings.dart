import 'package:get/get.dart';

import '../../data/models/circle_models.dart';
import '../controllers/circle_detail_controller.dart';
import '../controllers/circles_controller.dart';
import '../controllers/live_map_controller.dart';

class CirclesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CirclesController>(() => CirclesController());
  }
}

/// Espera Get.arguments = CircleModel (passe o círculo clicado na lista).
class CircleDetailBinding extends Bindings {
  @override
  void dependencies() {
    final circle = Get.arguments as CircleModel;
    Get.lazyPut<CircleDetailController>(
      () => CircleDetailController(circle: circle),
    );
  }
}

/// Espera Get.arguments = LiveMapArgs (veja live_map_screen.dart).
class LiveMapBinding extends Bindings {
  @override
  void dependencies() {
    final args = Get.arguments as LiveMapArgs;
    Get.lazyPut<LiveMapController>(
      () => LiveMapController(
        circleId: args.circleId,
        circleName: args.circleName,
        membersById: args.membersById,
      ),
    );
  }
}

class LiveMapArgs {
  const LiveMapArgs({
    required this.circleId,
    required this.circleName,
    this.membersById = const {},
  });

  final String circleId;
  final String circleName;
  final Map<String, CircleMemberModel> membersById;
}
