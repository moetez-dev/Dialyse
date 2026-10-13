import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../machines/domain/entities/machine_detail_entity.dart';
import '../../../machines/domain/entities/machine_entity.dart';
import '../providers/devices_provider.dart';

/// Admin "Gestion des appareils" — Django `/machines/raspi/`.
/// Lists Raspberry Pi devices from machine `raspi` / `raspi_options` JSON
/// and assigns via `PATCH /api/machines/<id>/` (`raspi_db_id`).
/// Creating a new RaspiDevice is not available on the REST API.
class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(devicesProvider);
    final notifier = ref.read(devicesProvider.notifier);

    return AppShell(
      actions: [
        IconButton(
          tooltip: 'Actualiser',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: notifier.refresh,
        ),
      ],
      body: RefreshIndicator(
        color: const Color(0xFF2563EB),
        onRefresh: notifier.refresh,
        child: async.when(
          loading: () => const _Scrollable(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => _Scrollable(
            child: _ErrorState(error: error, onRetry: notifier.refresh),
          ),
          data: (data) => _DevicesBody(data: data),
        ),
      ),
    );
  }
}

class _DevicesBody extends ConsumerWidget {
  final DevicesSnapshot data;

  const _DevicesBody({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = data.raspiOptions;
    final assignedCount = options.where((o) => o.isAssigned).length;
    final freeCount = options.length - assignedCount;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Gestion des appareils',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Raspberry Pi enregistrés (données machines). '
          'L’ajout d’un nouvel appareil se fait uniquement depuis Django Admin / la page web.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Kpi(
                label: 'Appareils',
                value: '${options.length}',
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Kpi(
                label: 'Assignés',
                value: '$assignedCount',
                color: const Color(0xFF16A34A),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Kpi(
                label: 'Libres',
                value: '$freeCount',
                color: const Color(0xFFD97706),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (data.machines.isEmpty)
          const _InfoBox(
            text:
                'Aucune machine en base : impossible de charger raspi_options. '
                'Créez une machine (Admin) puis réessayez.',
          )
        else if (options.isEmpty)
          const _InfoBox(
            text:
                'Aucun Raspberry Pi n’est encore enregistré côté serveur. '
                'Utilisez « Gestion des appareils » sur le site Django pour en ajouter.',
          )
        else
          for (final option in options) ...[
            _DeviceCard(
              option: option,
              machines: data.machines,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _DeviceCard extends ConsumerStatefulWidget {
  final RaspiOptionEntity option;
  final List<MachineEntity> machines;

  const _DeviceCard({required this.option, required this.machines});

  @override
  ConsumerState<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends ConsumerState<_DeviceCard> {
  int? _selectedMachinePk;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final option = widget.option;
    final assignedLabel = option.assignedMachineId;
    final assignedPk = option.assignedMachinePk ??
        _pkForMachineId(option.assignedMachineId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.videocam_outlined, color: Color(0xFF15803D)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  option.raspiId,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _pill(
                option.isAssigned ? 'Assigné' : 'Libre',
                option.isAssigned
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEF3C7),
                option.isAssigned
                    ? const Color(0xFF166534)
                    : const Color(0xFFB45309),
              ),
            ],
          ),
          if (option.description != null &&
              option.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              option.description!,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            assignedLabel == null || assignedLabel.isEmpty
                ? 'Machine : non assigné'
                : 'Machine : $assignedLabel',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _selectedMachinePk,
            decoration: const InputDecoration(
              labelText: 'Assigner à une machine',
            ),
            items: [
              for (final m in widget.machines)
                DropdownMenuItem(
                  value: m.id,
                  child: Text(
                    m.raspi == null || m.raspi!.id == option.id
                        ? m.machineId
                        : '${m.machineId} (déjà ${m.raspi!.raspiId})',
                  ),
                ),
            ],
            onChanged: _busy
                ? null
                : (v) => setState(() => _selectedMachinePk = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy || _selectedMachinePk == null
                      ? null
                      : () => _assign(_selectedMachinePk!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_busy ? '…' : 'Assigner'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy || assignedPk == null
                      ? null
                      : () => _unassign(assignedPk),
                  child: const Text('Libérer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int? _pkForMachineId(String? machineId) {
    if (machineId == null || machineId.isEmpty) return null;
    for (final m in widget.machines) {
      if (m.machineId == machineId) return m.id;
    }
    return null;
  }

  Future<void> _assign(int machinePk) async {
    setState(() => _busy = true);
    try {
      await ref.read(devicesProvider.notifier).assign(
            raspiDbId: widget.option.id,
            machinePk: machinePk,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appareil assigné')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Assignation impossible',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unassign(int machinePk) async {
    setState(() => _busy = true);
    try {
      await ref.read(devicesProvider.notifier).unassign(machinePk: machinePk);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appareil libéré')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ApiException ? e.message : 'Libération impossible',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Kpi({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;

  const _InfoBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
      ),
    );
  }
}

class _Scrollable extends StatelessWidget {
  final Widget child;

  const _Scrollable({required this.child});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [child],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : error.toString();
    return Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        CustomButton(
          text: 'Réessayer',
          onPressed: onRetry,
          backgroundColor: const Color(0xFF2563EB),
        ),
      ],
    );
  }
}
