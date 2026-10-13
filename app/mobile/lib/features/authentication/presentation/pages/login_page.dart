import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/app_router.dart';
import '../providers/auth_provider.dart';

/// Django web blue-600 (#2563EB) — the primary button / brand color.
const Color _djangoBlue = Color(0xFF2563EB);
const Color _gray600 = Color(0xFF4B5563);
const Color _gray300 = Color(0xFFD1D5DB);
const Color _gray400 = Color(0xFF9CA3AF);
const Color _red50 = Color(0xFFFEF2F2);
const Color _red800 = Color(0xFF991B1B);

/// Flutter counter-part of Django `accounts/templates/login.html`.
/// Password reset is hidden until a JSON API exists (web form is CSRF HTML).
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      ref
          .read(authStateProvider.notifier)
          .login(_usernameController.text.trim(), _passwordController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next is AuthAuthenticated) {
        // Django: first_login → profile, else → surveillance.
        context.go(AppRouter.postLoginRoute(next.user));
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEFF6FF),
              Color(0xFFE0E7FF),
            ], // blue-50 → indigo-100
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: _buildLoginForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    final authState = ref.watch(authStateProvider);
    final isLoading = authState is AuthLoading;
    final errorMessage = authState is AuthError ? authState.message : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: _djangoBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt, size: 26, color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Dialyse Manager',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Système de gestion des patients en dialyse',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _gray600),
            ),
            const SizedBox(height: 24),
            const _FieldLabel('Nom d\'utilisateur'),
            const SizedBox(height: 6),
            _DjangoTextField(
              controller: _usernameController,
              hint: 'Nom d\'utilisateur',
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Veuillez saisir votre nom d\'utilisateur'
                  : null,
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Mot de passe'),
            const SizedBox(height: 6),
            _DjangoTextField(
              controller: _passwordController,
              hint: 'Mot de passe',
              obscureText: true,
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Veuillez saisir votre mot de passe'
                  : null,
            ),
            const SizedBox(height: 8),
            if (errorMessage != null) ...[
              const SizedBox(height: 4),
              _ErrorBox(message: errorMessage),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: isLoading ? null : _submitLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _djangoBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _djangoBlue.withValues(alpha: 0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Se connecter',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small gray label above a field (Django `text-sm` label).
class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF374151),
      ),
    );
  }
}

/// Plain bordered input matching Django's
/// `border rounded-md px-3 py-2 focus:ring-2 focus:ring-blue-500`.
class _DjangoTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final String? Function(String?)? validator;

  const _DjangoTextField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _gray400, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _gray300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _gray300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _djangoBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
        ),
      ),
      validator: validator,
    );
  }
}

/// Django's red authentication box: `bg-red-50 text-red-800 p-3 rounded-md`.
class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _red50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: _red800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: _red800),
            ),
          ),
        ],
      ),
    );
  }
}
