import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/datasources/profile_remote_datasource.dart';

final profileRemoteDatasourceProvider = Provider<ProfileRemoteDatasource>((ref) {
  return ProfileRemoteDatasource(ref.watch(apiClientProvider));
});

/// Editable profile + password — mirrors Django `profile.html`.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _specialite;
  late final TextEditingController _oldPassword;
  late final TextEditingController _newPassword;
  late final TextEditingController _confirmPassword;
  bool _hydrated = false;
  bool _saving = false;
  bool _firstLogin = false;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController();
    _email = TextEditingController();
    _address = TextEditingController();
    _specialite = TextEditingController();
    _oldPassword = TextEditingController();
    _newPassword = TextEditingController();
    _confirmPassword = TextEditingController();
  }

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _specialite.dispose();
    _oldPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _hydrate(UserEntity user) {
    if (_hydrated) return;
    _phone.text = user.phone ?? '';
    _email.text = user.email ?? '';
    _address.text = user.address ?? '';
    _specialite.text = user.specialite ?? '';
    _firstLogin = user.firstLogin;
    _hydrated = true;
  }

  Future<void> _submit(UserEntity current) async {
    if (!_formKey.currentState!.validate()) return;

    final newPass = _newPassword.text.trim();
    final confirm = _confirmPassword.text.trim();
    if (newPass.isNotEmpty && newPass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas')),
      );
      return;
    }

    if (_firstLogin && newPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vous devez changer votre mot de passe pour continuer',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final ds = ref.read(profileRemoteDatasourceProvider);
      final updated = await ds.updateProfile(
        ProfileUpdatePayload(
          phone: _firstLogin ? null : _phone.text.trim(),
          email: _firstLogin ? null : _email.text.trim(),
          address: _firstLogin ? null : _address.text.trim(),
          specialite: _firstLogin ? null : _specialite.text.trim(),
          oldPassword: _oldPassword.text,
          newPassword: newPass.isEmpty ? null : newPass,
        ),
      );
      await ref.read(authStateProvider.notifier).applyUser(updated);
      if (!mounted) return;
      setState(() {
        _firstLogin = updated.firstLogin;
        _oldPassword.clear();
        _newPassword.clear();
        _confirmPassword.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.firstLogin
                ? 'Profil mis a jour'
                : (newPass.isNotEmpty
                    ? 'Mot de passe / profil mis a jour'
                    : 'Profil mis a jour avec succes'),
          ),
        ),
      );
      if (!updated.firstLogin && current.firstLogin) {
        context.go(AppRouter.surveillance);
      }
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
    final authState = ref.watch(authStateProvider);
    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: Text('Non connecte')));
    }
    final user = authState.user;
    _hydrate(user);

    return AppShell(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Mon Profil',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user.username,
              style: const TextStyle(fontSize: 15, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 4),
            Text(
              user.role,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            if (_firstLogin) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: const Text(
                  'Premiere connexion : changez votre mot de passe pour acceder a l application.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (!_firstLogin) ...[
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'Telephone',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Adresse',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              if (user.isDoctor) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _specialite,
                  decoration: const InputDecoration(
                    labelText: 'Specialite',
                    prefixIcon: Icon(Icons.medical_services_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Changer le mot de passe (optionnel)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              const Text(
                'Nouveau mot de passe',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextFormField(
              controller: _oldPassword,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Ancien mot de passe',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) {
                if (_firstLogin || _newPassword.text.isNotEmpty) {
                  if (v == null || v.isEmpty) return 'Obligatoire';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPassword,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _firstLogin
                    ? 'Nouveau mot de passe *'
                    : 'Nouveau mot de passe',
                prefixIcon: const Icon(Icons.lock_reset_outlined),
              ),
              validator: (v) {
                if (_firstLogin) {
                  if (v == null || v.length < 6) {
                    return 'Au moins 6 caracteres';
                  }
                } else if (v != null && v.isNotEmpty && v.length < 6) {
                  return 'Au moins 6 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPassword,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmer le mot de passe',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: _saving
                  ? 'Enregistrement...'
                  : (_firstLogin
                      ? 'Changer le mot de passe'
                      : 'Enregistrer'),
              icon: Icons.save_rounded,
              backgroundColor: const Color(0xFF2563EB),
              onPressed: _saving ? null : () => _submit(user),
            ),
            const SizedBox(height: 12),
            CustomButton(
              text: 'Se deconnecter',
              backgroundColor: AppColors.danger,
              icon: Icons.logout_rounded,
              onPressed: () async {
                await ref.read(authStateProvider.notifier).logout();
                if (context.mounted) context.go(AppRouter.login);
              },
            ),
          ],
        ),
      ),
    );
  }
}
