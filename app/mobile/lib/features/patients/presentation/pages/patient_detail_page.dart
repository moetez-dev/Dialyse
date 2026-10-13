import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../domain/entities/patient_session_entity.dart';
import '../providers/patients_provider.dart';
import '../widgets/patient_formatting.dart';
import '../widgets/status_badge.dart';

/// Patient dossier screen. Mirrors the Django `Patient_Profile.html`.
class PatientDetailPage extends ConsumerWidget {
  final int patientId;

  const PatientDetailPage({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(patientDetailProvider(patientId));

    return AppShell(
      actions: [
        detailAsync.maybeWhen(
          data: (detail) => IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final updated = await context.push<bool>(
                AppRouter.patientEditRoute(patientId),
                extra: detail.patient,
              );
              if (updated == true) {
                ref.invalidate(patientDetailProvider(patientId));
                ref.invalidate(patientsProvider);
              }
            },
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(patientDetailProvider(patientId));
            await ref.read(patientDetailProvider(patientId).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: _DetailErrorState(
                  error: error,
                  onRetry: () =>
                      ref.invalidate(patientDetailProvider(patientId)),
                ),
              ),
            ],
          ),
        ),
        data: (detail) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(patientDetailProvider(patientId));
            await ref.read(patientDetailProvider(patientId).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _DossierHeader(
                patientName: detail.patient.fullName,
                dialysisType: detail.patient.typeDeDialyse,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final updated = await context.push<bool>(
                      AppRouter.patientEditRoute(patientId),
                      extra: detail.patient,
                    );
                    if (updated == true) {
                      ref.invalidate(patientDetailProvider(patientId));
                      ref.invalidate(patientsProvider);
                    }
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifier le profil'),
                ),
              ),
              const SizedBox(height: 16),
              const _SectionTitle('Informations générales'),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      _InfoTile(
                        background: const Color(0xFFEFF6FF),
                        icon: Icons.calendar_today_rounded,
                        iconColor: const Color(0xFF2563EB),
                        label: 'Date de naissance',
                        value: formatDateDdMmAaaa(detail.patient.dateOfBirth),
                      ),
                      _InfoTile(
                        background: const Color(0xFFFEF2F2),
                        icon: Icons.water_drop_outlined,
                        iconColor: const Color(0xFFEF4444),
                        label: 'Groupe sanguin',
                        value: detail.patient.groupeSanguin.isEmpty
                            ? '—'
                            : detail.patient.groupeSanguin,
                      ),
                      _InfoTile(
                        background: const Color(0xFFF5F3FF),
                        icon: Icons.person_outline,
                        iconColor: const Color(0xFFA855F7),
                        label: 'Âge',
                        value: '${detail.patient.age} ans',
                      ),
                      _InfoTile(
                        background: const Color(0xFFECFEFF),
                        icon: Icons.local_hospital_outlined,
                        iconColor: const Color(0xFF0891B2),
                        label: 'Type de dialyse',
                        value: detail.patient.typeDeDialyse.isEmpty
                            ? '—'
                            : detail.patient.typeDeDialyse,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _SectionTitle('Contact'),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      _InfoTile(
                        background: const Color(0xFFEFF6FF),
                        icon: Icons.phone_outlined,
                        iconColor: const Color(0xFF2563EB),
                        label: 'Téléphone',
                        value: detail.patient.hasPhone
                            ? detail.patient.telephone
                            : '—',
                      ),
                      _InfoTile(
                        background: const Color(0xFFECFDF5),
                        icon: Icons.place_outlined,
                        iconColor: const Color(0xFF16A34A),
                        label: 'Adresse',
                        value: detail.patient.adresse.trim().isEmpty
                            ? '—'
                            : detail.patient.adresse,
                      ),
                      _InfoTile(
                        background: const Color(0xFFFFF7ED),
                        icon: Icons.emergency_outlined,
                        iconColor: const Color(0xFFF97316),
                        label: "Contact d'urgence",
                        value: detail.patient.hasContactUrgence
                            ? detail.patient.contactUrgence
                            : '—',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _SectionTitle('Antécédents médicaux'),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        color: Color(0xFF2563EB),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          detail.patient.hasAntecedents
                              ? detail.patient.antecedentsMedicaux
                              : 'Non renseigné',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF111827),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _SectionTitle('Historique des séances de dialyse'),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: detail.recentSessions.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aucune séance de dialyse enregistrée pour ce patient.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      )
                    : Column(
                        children: detail.recentSessions
                            .map(
                              (session) => _SessionTile(
                                session: session,
                                onOpen: () => context.push(
                                  AppRouter.sessionDetailRoute(session.id),
                                ),
                                onSurveillance: session.status == 'en cours'
                                    ? () => context.push(AppRouter.surveillance)
                                    : null,
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: Color(0xFF111827),
      ),
    );
  }
}

class _DossierHeader extends StatelessWidget {
  final String patientName;
  final String dialysisType;

  const _DossierHeader({
    required this.patientName,
    required this.dialysisType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBEAFE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            patientName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dialysisType.isEmpty ? 'Dossier patient' : dialysisType,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final Color background;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoTile({
    required this.background,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final PatientSessionEntity session;
  final VoidCallback onOpen;
  final VoidCallback? onSurveillance;

  const _SessionTile({
    required this.session,
    required this.onOpen,
    this.onSurveillance,
  });

  @override
  Widget build(BuildContext context) {
    final weightLine = _weightLine();
    final bpLine = _bpLine();

    return InkWell(
      onTap: onOpen,
      child: Container(
        decoration: const BoxDecoration(
          border: BorderDirectional(
            bottom: BorderSide(color: Color(0xFFF1F5F9)),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 15,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            formatSessionDate(session.sessionDate),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (session.startHour != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              session.startHour!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Durée: ${session.duration}h00 · Machine: ${session.machineId ?? 'Non assignée'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      if (weightLine != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          weightLine,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                      if (bpLine != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          bpLine,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                StatusBadge(status: session.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: Text(
                    session.hasRapport || session.status == 'terminée'
                        ? 'Voir le rapport'
                        : 'Voir la séance',
                  ),
                ),
                if (onSurveillance != null)
                  TextButton.icon(
                    onPressed: onSurveillance,
                    icon: const Icon(Icons.monitor_heart_outlined, size: 16),
                    label: const Text('Surveillance'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _weightLine() {
    if (session.preWeight == null && session.postWeight == null) return null;
    final pre = session.preWeight?.toStringAsFixed(1) ?? '—';
    final post = session.postWeight?.toStringAsFixed(1) ?? '—';
    return 'Poids: $pre → $post kg';
  }

  String? _bpLine() {
    if ((session.preBloodPressure == null ||
            session.preBloodPressure!.isEmpty) &&
        (session.postBloodPressure == null ||
            session.postBloodPressure!.isEmpty)) {
      return null;
    }
    final pre = (session.preBloodPressure?.isNotEmpty ?? false)
        ? session.preBloodPressure!
        : '—';
    final post = (session.postBloodPressure?.isNotEmpty ?? false)
        ? session.postBloodPressure!
        : '—';
    return 'Tension: $pre → $post';
  }
}

class _DetailErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _DetailErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : error.toString();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
        const SizedBox(height: 12),
        const Text(
          "Impossible de charger le dossier du patient",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        CustomButton(
          text: 'Réessayer',
          icon: Icons.refresh_rounded,
          backgroundColor: const Color(0xFF2563EB),
          onPressed: onRetry,
        ),
      ],
    );
  }
}
