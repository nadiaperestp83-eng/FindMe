import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';
import '../../../controllers/circles_controller.dart';

Future<void> showCreateCircleSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _CreateCircleSheetBody(),
  );
}

class _CreateCircleSheetBody extends StatefulWidget {
  const _CreateCircleSheetBody();

  @override
  State<_CreateCircleSheetBody> createState() =>
      _CreateCircleSheetBodyState();
}

class _CreateCircleSheetBodyState extends State<_CreateCircleSheetBody> {
  final _controller = TextEditingController();
  final _circlesController = Get.find<CirclesController>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await _circlesController.createCircle(_controller.text);
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('Novo círculo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Um círculo é permanente — família, amigos ou o grupo que você '
            'quiser acompanhar em tempo real.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Ex: Família'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          Obx(() {
            final error = _circlesController.errorMessage.value;
            if (error == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                error,
                style: const TextStyle(color: AppColors.pending, fontSize: 13),
              ),
            );
          }),
          Obx(
            () => SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _circlesController.isCreating.value ? null : _submit,
                child: _circlesController.isCreating.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Criar círculo'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
