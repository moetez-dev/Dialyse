import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/presentation/providers/auth_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PfaDialyseApp()));
}

class PfaDialyseApp extends ConsumerWidget {
  const PfaDialyseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the GoRouter auth guard in sync with the Riverpod auth state.
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next is AuthAuthenticated) {
        AppRouter.auth.update(isLoggedIn: true, user: next.user);
      } else {
        AppRouter.auth.update(isLoggedIn: false, user: null);
      }
    });

    return MaterialApp.router(
      title: 'PFA Dialyse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
    );
  }
}
