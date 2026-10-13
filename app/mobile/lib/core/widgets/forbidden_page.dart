import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/providers/auth_provider.dart';
import '../routes/app_router.dart';
import 'app_shell.dart';
import 'custom_button.dart';

class ForbiddenPage extends ConsumerWidget {
  const ForbiddenPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;
    final home = user == null
        ? AppRouter.login
        : AppRouter.postLoginRoute(user);

    return AppShell(
      title: 'Accès refusé',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 56,
                color: Color(0xFFB91C1C),
              ),
              const SizedBox(height: 16),
              const Text(
                '403 — Accès refusé',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Votre rôle ne permet pas d’ouvrir cette page. '
                'Cela correspond aux droits du tableau de bord Django.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Retour',
                icon: Icons.arrow_back_rounded,
                backgroundColor: const Color(0xFF2563EB),
                onPressed: () => context.go(home),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
