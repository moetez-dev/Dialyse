import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/staff_provider.dart';

enum StaffKind { doctor, nurse }

class StaffFormPage extends ConsumerStatefulWidget {
  final StaffKind kind;

  const StaffFormPage({super.key, required this.kind});

  @override
  ConsumerState<StaffFormPage> createState() => _StaffFormPageState();
}

class _StaffFormPageState extends ConsumerState<StaffFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _specialite = TextEditingController();
  bool _saving = false;

  bool get _isDoctor => widget.kind == StaffKind.doctor;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _specialite.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final result = _isDoctor
          ? await ref.read(doctorsProvider.notifier).create(
                username: _name.text.trim(),
                email: _email.text.trim(),
                specialite: _specialite.text.trim(),
                phone: _phone.text.trim(),
              )
          : await ref.read(nursesProvider.notifier).create(
                username: _name.text.trim(),
                email: _email.text.trim(),
                phone: _phone.text.trim(),
              );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Compte cree'),
          content: Text(
            'Mot de passe temporaire :\n${result.temporaryPassword}\n\n'
            'Communiquez-le a l utilisateur (first login).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) context.pop(true);
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
              controller: _name,
              decoration: InputDecoration(
                labelText: _isDoctor ? 'Nom complet *' : 'Nom *',
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email *',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telephone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            if (_isDoctor) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _specialite,
                decoration: const InputDecoration(
                  labelText: 'Specialite',
                  prefixIcon: Icon(Icons.medical_services_outlined),
                ),
              ),
            ],
            const SizedBox(height: 24),
            CustomButton(
              text: _saving ? 'Creation...' : 'Creer le compte',
              icon: Icons.save_rounded,
              backgroundColor: const Color(0xFF2563EB),
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
