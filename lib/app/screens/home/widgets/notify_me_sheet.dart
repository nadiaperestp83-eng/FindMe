import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/home_controller.dart';
import '../../../data/repositories/geofence_repository.dart';
import '../../theme/app_theme.dart';

Future<void> showNotifyMeSheet(
  BuildContext context, {
  required String targetUserId,
  required String targetLabel,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _NotifyMeSheetBody(
      targetUserId: targetUserId,
      targetLabel: targetLabel,
    ),
  );
}

class _NotifyMeSheetBody extends StatefulWidget {
  const _NotifyMeSheetBody({
    required this.targetUserId,
    required this.targetLabel,
  });

  final String targetUserId;
  final String targetLabel;

  @override
  State<_NotifyMeSheetBody> createState() => _NotifyMeSheetBodyState();
}

class _NotifyMeSheetBodyState extends State<_NotifyMeSheetBody> {
  final _controller = Get.find<HomeController>();

  GeofenceTrigger _trigger = GeofenceTrigger.leaves;
  bool _useMyPosition = false; // false = posição da pessoa, true = minha
  GeofenceFrequency _frequency = GeofenceFrequency.once;
  bool _saving = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    final ok = await _controller.createAlert(
      targetUserId: widget.targetUserId,
      useMyPosition: _useMyPosition,
      trigger: _trigger,
      frequency: _frequency,
    );
    setState(() => _saving = false);
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text('Notify Me',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Text(widget.targetLabel,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Só funciona com o app aberto por enquanto.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),

            _SectionLabel('QUANDO'),
            _OptionTile(
              label: '${widget.targetLabel} chega',
              selected: _trigger == GeofenceTrigger.arrives,
              onTap: () => setState(() => _trigger = GeofenceTrigger.arrives),
            ),
            _OptionTile(
              label: '${widget.targetLabel} sai',
              selected: _trigger == GeofenceTrigger.leaves,
              onTap: () => setState(() => _trigger = GeofenceTrigger.leaves),
            ),

            const SizedBox(height: 16),
            _SectionLabel('LOCAL'),
            _OptionTile(
              label: 'Posição atual de ${widget.targetLabel}',
              selected: !_useMyPosition,
              onTap: () => setState(() => _useMyPosition = false),
            ),
            _OptionTile(
              label: 'Minha posição atual',
              selected: _useMyPosition,
              onTap: () => setState(() => _useMyPosition = true),
            ),

            const SizedBox(height: 16),
            _SectionLabel('FREQUÊNCIA'),
            _OptionTile(
              label: 'Só uma vez',
              selected: _frequency == GeofenceFrequency.once,
              onTap: () => setState(() => _frequency = GeofenceFrequency.once),
            ),
            _OptionTile(
              label: 'Sempre',
              selected: _frequency == GeofenceFrequency.always,
              onTap: () => setState(() => _frequency = GeofenceFrequency.always),
            ),

            const SizedBox(height: 20),
            Obx(() {
              final error = _controller.errorMessage.value;
              if (error == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(error,
                    style: const TextStyle(color: AppColors.pending, fontSize: 13)),
              );
            }),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Adicionar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              ),
            ),
            if (selected)
              const Icon(Icons.check, color: AppColors.live, size: 20),
          ],
        ),
      ),
    );
  }
}
