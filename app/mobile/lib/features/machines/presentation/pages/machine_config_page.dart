import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/page_states.dart';
import '../../../devices/presentation/providers/devices_provider.dart';
import '../../domain/entities/machine_detail_entity.dart';
import '../../domain/repositories/machine_repository.dart';
import '../providers/machines_provider.dart';

/// Configure machine — mirrors Django `configurer_machine.html`.
class MachineConfigPage extends ConsumerStatefulWidget {
  final int machineId;

  const MachineConfigPage({super.key, required this.machineId});

  @override
  ConsumerState<MachineConfigPage> createState() => _MachineConfigPageState();
}

class _MachineConfigPageState extends ConsumerState<MachineConfigPage> {
  bool _initialized = false;
  bool _saving = false;
  String _status = 'Prete';
  late TextEditingController _model;
  late TextEditingController _location;
  late TextEditingController _manufacturer;
  String? _raspiDbId; // null = unchanged sentinel via flag
  bool _raspiTouched = false;

  @override
  void initState() {
    super.initState();
    _model = TextEditingController();
    _location = TextEditingController();
    _manufacturer = TextEditingController();
  }

  @override
  void dispose() {
    _model.dispose();
    _location.dispose();
    _manufacturer.dispose();
    super.dispose();
  }

  void _hydrate(MachineDetailEntity detail) {
    if (_initialized) return;
    final m = detail.machine;
    _status = m.status.isEmpty ? 'Prete' : m.status;
    _model.text = m.model;
    _location.text = m.location;
    _manufacturer.text = m.manufacturer;
    _raspiDbId = m.raspi?.id;
    _initialized = true;
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await configureMachineProfile(
        ref,
        widget.machineId,
        MachineConfigurePayload(
          status: _status,
          model: _model.text,
          location: _location.text,
          manufacturer: _manufacturer.text,
          raspiDbId: _raspiTouched ? (_raspiDbId ?? '') : null,
        ),
      );
      ref.invalidate(devicesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration mise à jour')),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(machineDetailProvider(widget.machineId));

    return AppShell(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => PageError(
          error: e,
          onRetry: () => ref.invalidate(machineDetailProvider(widget.machineId)),
        ),
        data: (detail) {
          _hydrate(detail);
          final choices = detail.statusChoices.isEmpty
              ? const ['Prete', 'Reserve', 'Maintenance', 'Hors Service']
              : detail.statusChoices;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                detail.machine.machineId,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: choices.contains(_status) ? _status : choices.first,
                decoration: const InputDecoration(
                  labelText: 'Statut',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: choices
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _status = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _model,
                decoration: const InputDecoration(
                  labelText: 'Modèle',
                  prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Emplacement',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _manufacturer,
                decoration: const InputDecoration(
                  labelText: 'Fabricant',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _raspiDbId,
                decoration: const InputDecoration(
                  labelText: 'Raspberry Pi assigné',
                  prefixIcon: Icon(Icons.developer_board_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Aucun / désassigner'),
                  ),
                  ...detail.raspiOptions.map(
                    (r) => DropdownMenuItem<String?>(
                      value: r.id,
                      child: Text(
                        r.assignedMachineId == null ||
                                r.assignedMachineId == detail.machine.machineId
                            ? r.raspiId
                            : '${r.raspiId} (→ ${r.assignedMachineId})',
                      ),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    _raspiTouched = true;
                    _raspiDbId = v;
                  });
                },
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: _saving ? 'Enregistrement...' : 'Enregistrer',
                icon: Icons.save_rounded,
                backgroundColor: const Color(0xFF2563EB),
                onPressed: _saving ? null : _submit,
              ),
            ],
          );
        },
      ),
    );
  }
}
