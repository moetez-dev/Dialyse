import 'package:flutter/material.dart';

import '../../domain/entities/patient_entity.dart';
import 'patient_formatting.dart';

/// Matches the Django `patient.html` card: gradient header (from-blue-50 to
/// cyan-50) with name + chips, body rows for Téléphone / Contact d'urgence /
/// Adresse, and a full-width blue "Voir le dossier" action.
class PatientCard extends StatelessWidget {
  final PatientEntity patient;
  final VoidCallback? onTap;

  const PatientCard({super.key, required this.patient, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Téléphone',
                    value: patient.hasPhone ? patient.telephone : '—',
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.people_outline_rounded,
                    label: "Contact d'urgence",
                    value: patient.hasContactUrgence
                        ? patient.contactUrgence
                        : '—',
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.place_outlined,
                    label: 'Adresse',
                    value: patient.adresse.trim().isEmpty
                        ? '—'
                        : patient.adresse,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB), // blue-600
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onTap,
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 20),
                  label: const Text('Voir le dossier'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF6FF), Color(0xFFECFEFF)], // blue-50 → cyan-50
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            patient.fullName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A), // slate-900
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Né(e) le ${formatDateDdMmAaaa(patient.dateOfBirth)}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475569), // slate-600
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                label: 'Groupe sanguin',
                value: patient.groupeSanguin.isEmpty
                    ? '—'
                    : patient.groupeSanguin,
              ),
              _Chip(
                label: 'Dialyse',
                value: patient.typeDeDialyse.isEmpty
                    ? '—'
                    : patient.typeDeDialyse,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;

  const _Chip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)), // ring-slate-200
      ),
      child: Text.rich(
        TextSpan(
          text: '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF334155), // slate-700
          ),
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF2563EB), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B), // slate-500
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF374151), // gray-700
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
