import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../domain/entities/seance_detail_entity.dart';
import '../providers/seances_planning_provider.dart';

/// Flutter counterpart of `seances/templates/pre_session.html`.
class PreSessionPage extends ConsumerStatefulWidget {
  final String sessionId;

  const PreSessionPage({super.key, required this.sessionId});

  @override
  ConsumerState<PreSessionPage> createState() => _PreSessionPageState();
}

class _PreSessionPageState extends ConsumerState<PreSessionPage> {
  final _formKey = GlobalKey<FormState>();
  final _weightCtrl = TextEditingController();
  final _bpCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _hrCtrl = TextEditingController();
  final _satCtrl = TextEditingController();

  late final Map<String, TextEditingController> _seuilCtrls;
  int _debit = 60;
  bool _hydrated = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _seuilCtrls = {for (final key in _seuilKeys) key: TextEditingController()};
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _bpCtrl.dispose();
    _tempCtrl.dispose();
    _hrCtrl.dispose();
    _satCtrl.dispose();
    for (final c in _seuilCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(SeanceDetailEntity detail) {
    if (_hydrated) return;
    _hydrated = true;
    final pre = detail.preMeasurements;
    if (pre?.weight != null && (pre!.weight ?? 0) > 0) {
      _weightCtrl.text = _fmt(pre.weight!);
    }
    if (pre?.bloodPressure != null && pre!.bloodPressure!.isNotEmpty) {
      _bpCtrl.text = pre.bloodPressure!;
    }
    if (pre?.temperature != null && (pre!.temperature ?? 0) > 0) {
      _tempCtrl.text = _fmt(pre.temperature!);
    }
    if (pre?.heartRate != null && (pre!.heartRate ?? 0) > 0) {
      _hrCtrl.text = '${pre.heartRate}';
    }
    if (pre?.saturation != null && (pre!.saturation ?? 0) > 0) {
      _satCtrl.text = _fmt(pre.saturation!);
    }
    _debit = detail.debit;
    final t = detail.thresholds;
    _seuilCtrls['blood_flow_min']!.text = _fmt(t.bloodFlowMin);
    _seuilCtrls['blood_flow_max']!.text = _fmt(t.bloodFlowMax);
    _seuilCtrls['blood_flow_critical_low']!.text = _fmt(t.bloodFlowCriticalLow);
    _seuilCtrls['blood_flow_critical_high']!.text = _fmt(
      t.bloodFlowCriticalHigh,
    );
    _seuilCtrls['arterial_pressure_min']!.text = _fmt(t.arterialPressureMin);
    _seuilCtrls['arterial_pressure_max']!.text = _fmt(t.arterialPressureMax);
    _seuilCtrls['arterial_pressure_critical_low']!.text = _fmt(
      t.arterialPressureCriticalLow,
    );
    _seuilCtrls['arterial_pressure_critical_high']!.text = _fmt(
      t.arterialPressureCriticalHigh,
    );
    _seuilCtrls['venous_pressure_min']!.text = _fmt(t.venousPressureMin);
    _seuilCtrls['venous_pressure_max']!.text = _fmt(t.venousPressureMax);
    _seuilCtrls['venous_pressure_critical_low']!.text = _fmt(
      t.venousPressureCriticalLow,
    );
    _seuilCtrls['venous_pressure_critical_high']!.text = _fmt(
      t.venousPressureCriticalHigh,
    );
    _seuilCtrls['tmp_min']!.text = _fmt(t.tmpMin);
    _seuilCtrls['tmp_max']!.text = _fmt(t.tmpMax);
    _seuilCtrls['tmp_critical_low']!.text = _fmt(t.tmpCriticalLow);
    _seuilCtrls['tmp_critical_high']!.text = _fmt(t.tmpCriticalHigh);
    _seuilCtrls['uf_rate_min']!.text = _fmt(t.ufRateMin);
    _seuilCtrls['uf_rate_max']!.text = _fmt(t.ufRateMax);
    _seuilCtrls['uf_rate_critical_high']!.text = _fmt(t.ufRateCriticalHigh);
    _seuilCtrls['uf_volume_min']!.text = _fmt(t.ufVolumeMin);
    _seuilCtrls['uf_volume_max']!.text = _fmt(t.ufVolumeMax);
    _seuilCtrls['uf_volume_critical_high']!.text = _fmt(t.ufVolumeCriticalHigh);
    _seuilCtrls['heparin_min']!.text = _fmt(t.heparinMin);
    _seuilCtrls['heparin_max']!.text = _fmt(t.heparinMax);
    _seuilCtrls['heparin_critical_high']!.text = _fmt(t.heparinCriticalHigh);
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
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e is ApiException ? e.message : e.toString(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (detail) {
          _hydrate(detail);
          if (!detail.isPlanned) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cette séance ne peut pas être démarrée '
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
                  'Démarrer une séance',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Configuration et vérifications avant le démarrage',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                _InfoCard(detail: detail),
                const SizedBox(height: 16),
                _MachineConfigCard(
                  controllers: _seuilCtrls,
                  debit: _debit,
                  onDebitChanged: (v) => setState(() => _debit = v),
                ),
                const SizedBox(height: 16),
                _PreVitalsCard(
                  weightCtrl: _weightCtrl,
                  bpCtrl: _bpCtrl,
                  tempCtrl: _tempCtrl,
                  hrCtrl: _hrCtrl,
                  satCtrl: _satCtrl,
                ),
                const SizedBox(height: 20),
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
                        onPressed: _submitting ? null : () => _submit(detail),
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
                            : const Text('Lancer la séance'),
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

  Future<void> _submit(SeanceDetailEntity detail) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final thresholds = SeanceThresholds(
        bloodFlowMin: _num(_seuilCtrls['blood_flow_min']!),
        bloodFlowMax: _num(_seuilCtrls['blood_flow_max']!),
        bloodFlowCriticalLow: _num(_seuilCtrls['blood_flow_critical_low']!),
        bloodFlowCriticalHigh: _num(_seuilCtrls['blood_flow_critical_high']!),
        arterialPressureMin: _num(_seuilCtrls['arterial_pressure_min']!),
        arterialPressureMax: _num(_seuilCtrls['arterial_pressure_max']!),
        arterialPressureCriticalLow: _num(
          _seuilCtrls['arterial_pressure_critical_low']!,
        ),
        arterialPressureCriticalHigh: _num(
          _seuilCtrls['arterial_pressure_critical_high']!,
        ),
        venousPressureMin: _num(_seuilCtrls['venous_pressure_min']!),
        venousPressureMax: _num(_seuilCtrls['venous_pressure_max']!),
        venousPressureCriticalLow: _num(
          _seuilCtrls['venous_pressure_critical_low']!,
        ),
        venousPressureCriticalHigh: _num(
          _seuilCtrls['venous_pressure_critical_high']!,
        ),
        tmpMin: _num(_seuilCtrls['tmp_min']!),
        tmpMax: _num(_seuilCtrls['tmp_max']!),
        tmpCriticalLow: _num(_seuilCtrls['tmp_critical_low']!),
        tmpCriticalHigh: _num(_seuilCtrls['tmp_critical_high']!),
        ufRateMin: _num(_seuilCtrls['uf_rate_min']!),
        ufRateMax: _num(_seuilCtrls['uf_rate_max']!),
        ufRateCriticalHigh: _num(_seuilCtrls['uf_rate_critical_high']!),
        ufVolumeMin: _num(_seuilCtrls['uf_volume_min']!),
        ufVolumeMax: _num(_seuilCtrls['uf_volume_max']!),
        ufVolumeCriticalHigh: _num(_seuilCtrls['uf_volume_critical_high']!),
        heparinMin: _num(_seuilCtrls['heparin_min']!),
        heparinMax: _num(_seuilCtrls['heparin_max']!),
        heparinCriticalHigh: _num(_seuilCtrls['heparin_critical_high']!),
        debit: _debit,
      );

      await ref
          .read(seancesRepositoryProvider)
          .startSession(
            sessionId: widget.sessionId,
            weight: double.parse(_weightCtrl.text.replaceAll(',', '.')),
            bloodPressure: _bpCtrl.text.trim(),
            temperature: double.parse(_tempCtrl.text.replaceAll(',', '.')),
            heartRate: int.parse(_hrCtrl.text.trim()),
            saturation: double.parse(_satCtrl.text.replaceAll(',', '.')),
            debit: _debit,
            thresholds: thresholds,
          );

      ref.invalidate(seanceDetailProvider(widget.sessionId));
      await ref.read(seancesPlanningProvider.notifier).refresh();
      if (!mounted) return;
      context.go(AppRouter.seances);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Séance démarrée avec succès')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString())),
      );
    }
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  static double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  static const _seuilKeys = [
    'blood_flow_min',
    'blood_flow_max',
    'blood_flow_critical_low',
    'blood_flow_critical_high',
    'arterial_pressure_min',
    'arterial_pressure_max',
    'arterial_pressure_critical_low',
    'arterial_pressure_critical_high',
    'venous_pressure_min',
    'venous_pressure_max',
    'venous_pressure_critical_low',
    'venous_pressure_critical_high',
    'tmp_min',
    'tmp_max',
    'tmp_critical_low',
    'tmp_critical_high',
    'uf_rate_min',
    'uf_rate_max',
    'uf_rate_critical_high',
    'uf_volume_min',
    'uf_volume_max',
    'uf_volume_critical_high',
    'heparin_min',
    'heparin_max',
    'heparin_critical_high',
  ];
}

class _InfoCard extends StatelessWidget {
  final SeanceDetailEntity detail;

  const _InfoCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      title: 'Informations de la séance',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _MiniInfo('Patient', detail.patientFullName),
          _MiniInfo(
            'Machine',
            detail.machineId.isEmpty ? '—' : detail.machineId,
          ),
          _MiniInfo('Durée prévue', '${detail.duration}h'),
        ],
      ),
    );
  }
}

class _MachineConfigCard extends StatelessWidget {
  final Map<String, TextEditingController> controllers;
  final int debit;
  final ValueChanged<int> onDebitChanged;

  const _MachineConfigCard({
    required this.controllers,
    required this.debit,
    required this.onDebitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      title: 'Configuration de la machine',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final cfg in _paramConfigs) ...[
            _SeuilParamBlock(config: cfg, controllers: controllers),
            const SizedBox(height: 12),
          ],
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Niveau de surveillance — Débit d\'image',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pré-configuré par le médecin · L\'infirmier peut ajuster '
            'selon l\'état du patient au lancement',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 12),
          _DebitOption(
            value: 20,
            selected: debit,
            title: 'Critique',
            subtitle: '1 image / 20 s',
            color: const Color(0xFFDC2626),
            onTap: () => onDebitChanged(20),
          ),
          const SizedBox(height: 8),
          _DebitOption(
            value: 30,
            selected: debit,
            title: 'Modéré',
            subtitle: '1 image / 30 s',
            color: const Color(0xFFF97316),
            onTap: () => onDebitChanged(30),
          ),
          const SizedBox(height: 8),
          _DebitOption(
            value: 60,
            selected: debit,
            title: 'Normal',
            subtitle: '1 image / 60 s',
            color: const Color(0xFF16A34A),
            onTap: () => onDebitChanged(60),
          ),
        ],
      ),
    );
  }
}

class _SeuilParamConfig {
  final String label;
  final String unit;
  final String minKey;
  final String maxKey;
  final String? critLowKey;
  final String critHighKey;

  const _SeuilParamConfig({
    required this.label,
    required this.unit,
    required this.minKey,
    required this.maxKey,
    this.critLowKey,
    required this.critHighKey,
  });
}

const _paramConfigs = [
  _SeuilParamConfig(
    label: 'Débit sanguin',
    unit: 'mL/min',
    minKey: 'blood_flow_min',
    maxKey: 'blood_flow_max',
    critLowKey: 'blood_flow_critical_low',
    critHighKey: 'blood_flow_critical_high',
  ),
  _SeuilParamConfig(
    label: 'Pression artérielle',
    unit: 'mmHg',
    minKey: 'arterial_pressure_min',
    maxKey: 'arterial_pressure_max',
    critLowKey: 'arterial_pressure_critical_low',
    critHighKey: 'arterial_pressure_critical_high',
  ),
  _SeuilParamConfig(
    label: 'Pression veineuse',
    unit: 'mmHg',
    minKey: 'venous_pressure_min',
    maxKey: 'venous_pressure_max',
    critLowKey: 'venous_pressure_critical_low',
    critHighKey: 'venous_pressure_critical_high',
  ),
  _SeuilParamConfig(
    label: 'PTM',
    unit: 'mmHg',
    minKey: 'tmp_min',
    maxKey: 'tmp_max',
    critLowKey: 'tmp_critical_low',
    critHighKey: 'tmp_critical_high',
  ),
  _SeuilParamConfig(
    label: 'Taux UF',
    unit: 'mL/h',
    minKey: 'uf_rate_min',
    maxKey: 'uf_rate_max',
    critHighKey: 'uf_rate_critical_high',
  ),
  _SeuilParamConfig(
    label: 'Volume UF',
    unit: 'mL',
    minKey: 'uf_volume_min',
    maxKey: 'uf_volume_max',
    critHighKey: 'uf_volume_critical_high',
  ),
  _SeuilParamConfig(
    label: 'Héparine',
    unit: 'UI/h',
    minKey: 'heparin_min',
    maxKey: 'heparin_max',
    critHighKey: 'heparin_critical_high',
  ),
];

class _SeuilParamBlock extends StatelessWidget {
  final _SeuilParamConfig config;
  final Map<String, TextEditingController> controllers;

  const _SeuilParamBlock({required this.config, required this.controllers});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${config.label} (${config.unit})',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const _Badge(
            label: 'Normal',
            color: Color(0xFF166534),
            bg: Color(0xFFDCFCE7),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _NumField(
                  label: 'Min',
                  controller: controllers[config.minKey]!,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NumField(
                  label: 'Max',
                  controller: controllers[config.maxKey]!,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _Badge(
            label: 'Critique',
            color: Color(0xFF991B1B),
            bg: Color(0xFFFEE2E2),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (config.critLowKey != null) ...[
                Expanded(
                  child: _NumField(
                    label: 'Seuil bas',
                    controller: controllers[config.critLowKey!]!,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _NumField(
                  label: 'Seuil haut',
                  controller: controllers[config.critHighKey]!,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreVitalsCard extends StatelessWidget {
  final TextEditingController weightCtrl;
  final TextEditingController bpCtrl;
  final TextEditingController tempCtrl;
  final TextEditingController hrCtrl;
  final TextEditingController satCtrl;

  const _PreVitalsCard({
    required this.weightCtrl,
    required this.bpCtrl,
    required this.tempCtrl,
    required this.hrCtrl,
    required this.satCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      title: 'Valeurs pré-séance',
      subtitle:
          'Enregistrez les paramètres vitaux du patient avant le début de la séance',
      child: Column(
        children: [
          _ReqField(
            label: 'Poids (kg) *',
            controller: weightCtrl,
            isDecimal: true,
          ),
          const SizedBox(height: 12),
          _ReqField(
            label: 'Tension artérielle (ex: 120/80) *',
            controller: bpCtrl,
            isDecimal: false,
            hint: '120/80',
          ),
          const SizedBox(height: 12),
          _ReqField(
            label: 'Température (°C) *',
            controller: tempCtrl,
            isDecimal: true,
          ),
          const SizedBox(height: 12),
          _ReqField(
            label: 'Fréquence cardiaque (bpm) *',
            controller: hrCtrl,
            isDecimal: false,
          ),
          const SizedBox(height: 12),
          _ReqField(
            label: 'Saturation (%) *',
            controller: satCtrl,
            isDecimal: true,
          ),
        ],
      ),
    );
  }
}

class _DebitOption extends StatelessWidget {
  final int value;
  final int selected;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _DebitOption({
    required this.value,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? color : const Color(0xFFE5E7EB),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(Icons.sensors, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            if (active)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Actif',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _WhiteCard({required this.title, this.subtitle, required this.child});

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

class _MiniInfo extends StatelessWidget {
  final String label;
  final String value;

  const _MiniInfo(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _Badge({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _NumField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Requis';
        if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Invalide';
        return null;
      },
    );
  }
}

class _ReqField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isDecimal;
  final String? hint;

  const _ReqField({
    required this.label,
    required this.controller,
    required this.isDecimal,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: isDecimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : (hint != null ? TextInputType.text : TextInputType.number),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Champ requis';
        if (hint != null) return null;
        if (isDecimal) {
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
