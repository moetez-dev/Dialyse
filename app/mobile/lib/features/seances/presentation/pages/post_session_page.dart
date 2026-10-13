import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../domain/entities/seance_detail_entity.dart';
import '../providers/seances_planning_provider.dart';

/// Flutter counterpart of `seances/templates/post_session.html`.
/// API stores: weight, blood_pressure, temperature, heart_rate, saturation,
/// complications (same as Django PostSessionForm + seance.complications).
class PostSessionPage extends ConsumerStatefulWidget {
  final String sessionId;

  const PostSessionPage({super.key, required this.sessionId});

  @override
  ConsumerState<PostSessionPage> createState() => _PostSessionPageState();
}

class _PostSessionPageState extends ConsumerState<PostSessionPage> {
  final _formKey = GlobalKey<FormState>();
  final _weightCtrl = TextEditingController();
  final _hrCtrl = TextEditingController();
  final _bpSysCtrl = TextEditingController();
  final _bpDiaCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _satCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();

  final Set<String> _complications = {};
  bool _hydrated = false;
  bool _submitting = false;

  static const _options = [
    'Hypotension',
    'Crampes musculaires',
    'Nausées/Vomissements',
    'Céphalées',
    'Douleurs thoraciques',
    'Frissons',
    'Saignement au point de ponction',
    'Autre',
  ];

  @override
  void dispose() {
    _weightCtrl.dispose();
    _hrCtrl.dispose();
    _bpSysCtrl.dispose();
    _bpDiaCtrl.dispose();
    _tempCtrl.dispose();
    _satCtrl.dispose();
    _otherCtrl.dispose();
    super.dispose();
  }

  void _hydrate(SeanceDetailEntity detail) {
    if (_hydrated) return;
    _hydrated = true;
    final post = detail.postMeasurements;
    if (post?.weight != null && (post!.weight ?? 0) > 0) {
      _weightCtrl.text = post.weight!.toString();
    }
    if (post?.heartRate != null && (post!.heartRate ?? 0) > 0) {
      _hrCtrl.text = '${post.heartRate}';
    }
    if (post?.temperature != null && (post!.temperature ?? 0) > 0) {
      _tempCtrl.text = post.temperature!.toString();
    }
    if (post?.saturation != null && (post!.saturation ?? 0) > 0) {
      _satCtrl.text = post.saturation!.toString();
    }
    final bp = post?.bloodPressure ?? '';
    if (bp.contains('/')) {
      final parts = bp.split('/');
      _bpSysCtrl.text = parts[0].trim();
      _bpDiaCtrl.text = parts.length > 1 ? parts[1].trim() : '';
    }
  }

  String get _complicationsText {
    final selected = _complications.where((c) => c != 'Autre').toList();
    if (_complications.contains('Autre') && _otherCtrl.text.trim().isNotEmpty) {
      selected.add('Autre: ${_otherCtrl.text.trim()}');
    }
    return selected.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(seanceDetailProvider(widget.sessionId));

    return AppShell(
      actions: [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(AppRouter.seances),
        ),
      ],
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(e is ApiException ? e.message : e.toString())),
        data: (detail) {
          _hydrate(detail);
          if (!detail.isInProgress) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cette séance ne peut pas être terminée '
                      '(statut: ${detail.status}).',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      text: 'Retour au planning',
                      onPressed: () => context.go(AppRouter.seances),
                    ),
                  ],
                ),
              ),
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Fin de séance - Valeurs post-dialyse',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enregistrez les données du patient après la séance',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                _SummaryBanner(detail: detail),
                const SizedBox(height: 16),
                _Section(
                  title: 'Paramètres vitaux post-séance',
                  child: Column(
                    children: [
                      _Field(
                        label: 'Poids post-dialyse (kg) *',
                        controller: _weightCtrl,
                        helper:
                            'Le poids après la séance permet de calculer la perte de poids',
                        decimal: true,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        label: 'Fréquence cardiaque (bpm) *',
                        controller: _hrCtrl,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        label: 'Tension artérielle systolique (mmHg) *',
                        controller: _bpSysCtrl,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        label: 'Tension artérielle diastolique (mmHg) *',
                        controller: _bpDiaCtrl,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        label: 'Température (°C) *',
                        controller: _tempCtrl,
                        decimal: true,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        label: 'Saturation (%) *',
                        controller: _satCtrl,
                        decimal: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Complications éventuelles',
                  subtitle:
                      'Cochez les complications survenues pendant la séance :',
                  child: Column(
                    children: [
                      for (final option in _options)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            option,
                            style: const TextStyle(fontSize: 14),
                          ),
                          value: _complications.contains(option),
                          activeColor: const Color(0xFF2563EB),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _complications.add(option);
                              } else {
                                _complications.remove(option);
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      if (_complications.contains('Autre')) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _otherCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Précisez les autres complications',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      if (_complications.isEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: const Text(
                            '✓ Aucune complication signalée',
                            style: TextStyle(
                              color: Color(0xFF166534),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Validation de la séance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'En validant ce formulaire, vous confirmez que toutes '
                        'les informations saisies sont exactes et que la séance '
                        's\'est déroulée conformément aux procédures.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => context.go(AppRouter.seances),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFFE5E7EB),
                          foregroundColor: const Color(0xFF1F2937),
                          side: BorderSide.none,
                        ),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Valider la séance'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final bp = '${_bpSysCtrl.text.trim()}/${_bpDiaCtrl.text.trim()}';
      await ref
          .read(seancesRepositoryProvider)
          .endSession(
            sessionId: widget.sessionId,
            weight: double.parse(_weightCtrl.text.replaceAll(',', '.')),
            bloodPressure: bp,
            temperature: double.parse(_tempCtrl.text.replaceAll(',', '.')),
            heartRate: int.parse(_hrCtrl.text.trim()),
            saturation: double.parse(_satCtrl.text.replaceAll(',', '.')),
            complications: _complicationsText,
          );
      ref.invalidate(seanceDetailProvider(widget.sessionId));
      await ref.read(seancesPlanningProvider.notifier).refresh();
      if (!mounted) return;
      context.go(AppRouter.seances);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Séance terminée avec succès')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString())),
      );
    }
  }
}

class _SummaryBanner extends StatelessWidget {
  final SeanceDetailEntity detail;

  const _SummaryBanner({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Color(0xFF1E3A8A)),
              SizedBox(width: 8),
              Text(
                'Résumé de la séance',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _row('Patient', detail.patientFullName),
          _row('Heure de début', detail.startHour ?? '—'),
          _row('Durée', '${detail.duration}h00'),
          _row('Machine', detail.machineId.isEmpty ? '—' : detail.machineId),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _Section({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? helper;
  final bool decimal;

  const _Field({
    required this.label,
    required this.controller,
    this.helper,
    this.decimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Champ requis';
        if (decimal) {
          if (double.tryParse(v.replaceAll(',', '.')) == null) {
            return 'Nombre invalide';
          }
        } else if (int.tryParse(v.trim()) == null) {
          return 'Nombre invalide';
        }
        return null;
      },
    );
  }
}
