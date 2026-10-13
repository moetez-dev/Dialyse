import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../domain/entities/patient_entity.dart';
import '../../domain/repositories/patient_repository.dart';
import '../providers/patients_provider.dart';

const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
const _dialysisTypes = [
  'Hémodialyse',
  'Dialyse péritonéale',
  'Transplantation rénale',
];

/// Create / edit patient form. Mirrors Django Web add_patient + edit_patient.
class PatientFormPage extends ConsumerStatefulWidget {
  final PatientEntity? initial;

  const PatientFormPage({super.key, this.initial});

  bool get isEditing => initial != null;

  @override
  ConsumerState<PatientFormPage> createState() => _PatientFormPageState();
}

class _PatientFormPageState extends ConsumerState<PatientFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _emergency;
  late final TextEditingController _history;
  DateTime? _dob;
  String _bloodGroup = 'A+';
  String _dialysisType = 'Hémodialyse';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _firstName = TextEditingController(text: p?.firstName ?? '');
    _lastName = TextEditingController(text: p?.lastName ?? '');
    _phone = TextEditingController(text: p?.telephone ?? '');
    _address = TextEditingController(text: p?.adresse ?? '');
    _emergency = TextEditingController(text: p?.contactUrgence ?? '');
    _history = TextEditingController(text: p?.antecedentsMedicaux ?? '');
    if (p?.dateOfBirth != null && p!.dateOfBirth!.isNotEmpty) {
      _dob = DateTime.tryParse(p.dateOfBirth!);
    }
    if (p != null) {
      if (_bloodGroups.contains(p.groupeSanguin)) {
        _bloodGroup = p.groupeSanguin;
      }
      if (_dialysisTypes.contains(p.typeDeDialyse)) {
        _dialysisType = p.typeDeDialyse;
      }
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _address.dispose();
    _emergency.dispose();
    _history.dispose();
    super.dispose();
  }

  String get _dobIso {
    final d = _dob;
    if (d == null) return '';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 40),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Date de naissance',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La date de naissance est obligatoire')),
      );
      return;
    }

    final payload = PatientWritePayload(
      firstName: _firstName.text,
      lastName: _lastName.text,
      dateOfBirth: _dobIso,
      telephone: _phone.text,
      adresse: _address.text,
      contactUrgence: _emergency.text,
      antecedentsMedicaux: _history.text,
      groupeSanguin: _bloodGroup,
      typeDeDialyse: _dialysisType,
    );

    setState(() => _saving = true);
    try {
      if (widget.isEditing) {
        await updatePatientProfile(ref, widget.initial!.id, payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil modifié avec succès')),
        );
        context.pop(true);
      } else {
        final created =
            await ref.read(patientsProvider.notifier).createPatient(payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient ajouté avec succès')),
        );
        context.go(AppRouter.patientDetailRoute(created.id));
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _firstName,
                    label: 'Prénom',
                    icon: Icons.person_outline,
                    requiredField: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    controller: _lastName,
                    label: 'Nom',
                    icon: Icons.person_outline,
                    requiredField: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDob,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date de naissance *',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                ),
                child: Text(
                  _dob == null
                      ? 'Sélectionner une date'
                      : '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}',
                  style: TextStyle(
                    color: _dob == null
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF111827),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _field(
              controller: _phone,
              label: 'Téléphone',
              icon: Icons.phone_outlined,
              requiredField: true,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _bloodGroup,
              decoration: const InputDecoration(
                labelText: 'Groupe sanguin *',
                prefixIcon: Icon(Icons.water_drop_outlined),
              ),
              items: _bloodGroups
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _bloodGroup = v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _dialysisType,
              decoration: const InputDecoration(
                labelText: 'Type de dialyse',
                prefixIcon: Icon(Icons.local_hospital_outlined),
              ),
              items: _dialysisTypes
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _dialysisType = v);
              },
            ),
            const SizedBox(height: 12),
            _field(
              controller: _address,
              label: 'Adresse',
              icon: Icons.place_outlined,
              requiredField: true,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _emergency,
              label: "Contact d'urgence",
              icon: Icons.emergency_outlined,
              requiredField: true,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _history,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Antécédents médicaux',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: _saving
                  ? 'Enregistrement...'
                  : (widget.isEditing ? 'Enregistrer' : 'Ajouter le patient'),
              icon: Icons.save_rounded,
              backgroundColor: const Color(0xFF2563EB),
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool requiredField = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        prefixIcon: Icon(icon),
      ),
      validator: requiredField
          ? (v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null
          : null,
    );
  }
}

/// Loads patient detail then opens [PatientFormPage] in edit mode.
class PatientEditLoader extends ConsumerWidget {
  final int patientId;

  const PatientEditLoader({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(patientDetailProvider(patientId));
    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Modifier le patient')),
        body: Center(child: Text(e.toString())),
      ),
      data: (detail) => PatientFormPage(initial: detail.patient),
    );
  }
}
