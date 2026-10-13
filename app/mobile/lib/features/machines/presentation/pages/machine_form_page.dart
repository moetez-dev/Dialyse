import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../domain/repositories/machine_repository.dart';
import '../providers/machines_provider.dart';

/// Create machine form — mirrors Django `ajout_machine` (Admin only).
class MachineFormPage extends ConsumerStatefulWidget {
  const MachineFormPage({super.key});

  @override
  ConsumerState<MachineFormPage> createState() => _MachineFormPageState();
}

class _MachineFormPageState extends ConsumerState<MachineFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _machineId = TextEditingController();
  final _model = TextEditingController();
  final _location = TextEditingController();
  final _manufacturer = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _machineId.dispose();
    _model.dispose();
    _location.dispose();
    _manufacturer.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final created = await ref.read(machinesProvider.notifier).createMachine(
            MachineCreatePayload(
              machineId: _machineId.text,
              model: _model.text,
              location: _location.text,
              manufacturer: _manufacturer.text,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Machine ajoutée avec succès')),
      );
      context.go(AppRouter.machineDetailRoute(created.id));
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
    return AppShell(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _machineId,
              decoration: const InputDecoration(
                labelText: 'ID machine *',
                prefixIcon: Icon(Icons.qr_code_2_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _model,
              decoration: const InputDecoration(
                labelText: 'Modèle *',
                prefixIcon: Icon(Icons.precision_manufacturing_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Salle / emplacement *',
                prefixIcon: Icon(Icons.meeting_room_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _manufacturer,
              decoration: const InputDecoration(
                labelText: 'Fabricant',
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: _saving ? 'Enregistrement...' : 'Ajouter la machine',
              icon: Icons.add_rounded,
              backgroundColor: const Color(0xFF2563EB),
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
