import 'package:get/get.dart';

import '../../data/models/circle_models.dart';
import '../../data/repositories/circle_repository.dart';

class CircleDetailController extends GetxController {
  CircleDetailController({
    required this.circle,
    CircleRepository? repository,
  }) : _repository = repository ?? CircleRepository();

  final CircleModel circle;
  final CircleRepository _repository;

  final members = <CircleMemberModel>[].obs;
  final isLoading = false.obs;
  final isInviting = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadMembers();
  }

  Future<void> loadMembers() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;
      final result = await _repository.listMembers(circle.id);
      members.assignAll(result);
    } catch (_) {
      errorMessage.value = 'Não foi possível carregar os membros.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> inviteByUsername(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return false;
    try {
      isInviting.value = true;
      errorMessage.value = null;
      await _repository.inviteByUsername(
        circleId: circle.id,
        username: trimmed,
      );
      await loadMembers();
      return true;
    } catch (_) {
      errorMessage.value = 'Usuário não encontrado ou já convidado.';
      return false;
    } finally {
      isInviting.value = false;
    }
  }

  Future<void> leaveCircle() async {
    await _repository.leaveCircle(circle.id);
  }

  /// Mapa userId -> CircleMemberModel, útil para rotular marcadores no mapa
  /// sem precisar de outra consulta ao banco.
  Map<String, CircleMemberModel> get membersById => {
        for (final m in members) m.userId: m,
      };
}
