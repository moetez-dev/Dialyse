import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import 'custom_button.dart';

class PageLoading extends StatelessWidget {
  const PageLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class PageEmpty extends StatelessWidget {
  final String message;

  const PageEmpty({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
      ),
    );
  }
}

class PageError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const PageError({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;
    final isForbidden = api?.statusCode == 403;
    final isAuth = api?.statusCode == 401;
    final title = isForbidden
        ? '403 — Accès refusé'
        : isAuth
        ? 'Session expirée'
        : 'Impossible de charger';
    final message = api?.message ?? error.toString();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isForbidden ? Icons.lock_outline_rounded : Icons.error_outline,
            size: 40,
            color: const Color(0xFFB91C1C),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: 'Réessayer',
            onPressed: onRetry,
            backgroundColor: const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }
}
