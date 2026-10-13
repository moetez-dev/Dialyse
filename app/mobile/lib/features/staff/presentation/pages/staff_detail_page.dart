import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/staff_provider.dart';

class StaffDetailPage extends ConsumerWidget {
  final int staffId;
  final bool isDoctor;

  const StaffDetailPage({
    super.key,
    required this.staffId,
    required this.isDoctor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = isDoctor
        ? ref.watch(doctorDetailProvider(staffId))
        : ref.watch(nurseDetailProvider(staffId));

    return AppShell(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e is ApiException ? e.message : e.toString()),
              CustomButton(
                text: 'Reessayer',
                onPressed: () => isDoctor
                    ? ref.invalidate(doctorDetailProvider(staffId))
                    : ref.invalidate(nurseDetailProvider(staffId)),
              ),
            ],
          ),
        ),
        data: (member) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              member.displayName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${member.role} · ${member.statusLabel}',
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            _tile(Icons.mail_outline, 'Email', member.email),
            _tile(Icons.phone_outlined, 'Telephone', member.phone),
            _tile(Icons.home_outlined, 'Adresse', member.address),
            if (isDoctor)
              _tile(
                Icons.medical_services_outlined,
                'Specialite',
                member.specialite.isEmpty ? 'Generaliste' : member.specialite,
              ),
            if (member.bio.isNotEmpty)
              _tile(Icons.description_outlined, 'Bio', member.bio),
            if (member.formation.isNotEmpty)
              _tile(Icons.school_outlined, 'Formation', member.formation),
            if (member.experience.isNotEmpty)
              _tile(Icons.work_outline, 'Experience', member.experience),
          ],
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String label, String value) {
    final display = value.trim().isEmpty ? '—' : value;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF2563EB)),
        title: Text(label, style: const TextStyle(fontSize: 12)),
        subtitle: Text(
          display,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
      ),
    );
  }
}
