import 'package:get/get.dart';

import '../../data/models/circle_models.dart';
import '../../data/repositories/circle_repository.dart';

class CirclesController extends GetxController {
  CirclesController({CircleRepository? repository})
      : _repository = repository ?? CircleRepository();

  final CircleRepository _repository;

  final circles = <CircleModel>[].obs;
  final pendingInvites = <CircleMemberModel>[].obs;
  final isLoading = false.obs;
  final isCreating = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<void> loadAll() async {
    await Future.wait([loadCircles(), loadPendingInvites()]);
  }

  Future<void> loadCircles() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;
      final result = await _repository.listMyCircles();
      circles.assignAll(result);
    } catch (_) {
      errorMessage.value = 'Não foi possível carregar seus círculos.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadPendingInvites() async {
    try {
      final result = await _repository.listMyPendingInvites();
      pendingInvites.assignAll(result);
    } catch (_) {
      // Convites pendentes são complementares; falha aqui não bloqueia a tela.
    }
  }

  Future<bool> createCircle(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      errorMessage.value = 'Dê um nome para o círculo.';
      return false;
    }
    try {
      isCreating.value = true;
      errorMessage.value = null;
      final circle = await _repository.createCircle(trimmed);
      circles.insert(0, circle);
      return true;
    } catch (_) {
      errorMessage.value = 'Não foi possível criar o círculo. Tente de novo.';
      return false;
    } finally {
      isCreating.value = false;
    }
  }

  Future<void> acceptInvite(CircleMemberModel invite) async {
    await _repository.acceptInvite(invite.circleId);
    pendingInvites.removeWhere((i) => i.circleId == invite.circleId);
    await loadCircles();
  }

  Future<void> declineInvite(CircleMemberModel invite) async {
    await _repository.declineInvite(invite.circleId);
    pendingInvites.removeWhere((i) => i.circleId == invite.circleId);
  }
}
