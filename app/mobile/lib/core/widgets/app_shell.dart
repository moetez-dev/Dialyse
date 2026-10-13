import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/domain/entities/user_entity.dart';
import '../../features/authentication/presentation/providers/auth_provider.dart';
import '../routes/app_router.dart';

/// Shared scaffold for all authenticated pages. Mirrors Django
/// `templates/base.html` + `templates/partials/navbar.html` +
/// `templates/partials/sidebar.html`.
class AppShell extends ConsumerWidget {
  final String title;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;
  final Color? backgroundColor;

  const AppShell({
    super.key,
    this.title = 'Dialyse Manager',
    this.actions,
    required this.body,
    this.floatingActionButton,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;

    final showDrawer = user == null || !user.firstLogin;

    return Scaffold(
      backgroundColor: backgroundColor ?? const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 8,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE5E7EB)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.monitor_heart_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Dialyse Manager',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Centre de dialyse - Suivi en temps réel',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF4B5563),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (user != null)
            InkWell(
              onTap: () => context.go(AppRouter.profile),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 18,
                      color: Color(0xFF4B5563),
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 90),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            user.username,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user.role,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF4B5563),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ...?actions,
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: () async {
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) context.go(AppRouter.login);
            },
            icon: const Icon(
              Icons.logout_rounded,
              size: 20,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
      drawer: showDrawer ? const _DjangoDrawer() : null,
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}

/// Mirrors `templates/partials/sidebar.html` role rules exactly.
class _DjangoDrawer extends ConsumerWidget {
  const _DjangoDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final currentPath = GoRouterState.of(context).uri.path;

    final items = _NavItem.allVisibleFor(user);

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeader(user: user),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  for (final item in items)
                    _DrawerTile(
                      item: item,
                      selected: _isSelected(currentPath, item.route),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            _LogoutTile(ref: ref),
          ],
        ),
      ),
    );
  }

  static bool _isSelected(String currentPath, String route) {
    if (route == AppRouter.surveillance) return currentPath == route;
    if (route == AppRouter.monitoring) {
      return currentPath == route || currentPath == AppRouter.dashboard;
    }
    return currentPath == route || currentPath.startsWith('$route/');
  }
}

class _DrawerHeader extends StatelessWidget {
  final UserEntity? user;

  const _DrawerHeader({this.user});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        context.go(AppRouter.profile);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.username ?? 'Utilisateur',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.role ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;

  const _DrawerTile({required this.item, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF2563EB) : const Color(0xFF374151);
    final bg = selected ? const Color(0xFFEFF6FF) : Colors.transparent;

    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        context.go(item.route);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(item.icon, size: 20, color: item.color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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

class _LogoutTile extends StatelessWidget {
  final WidgetRef ref;

  const _LogoutTile({required this.ref});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        Navigator.of(context).pop();
        await ref.read(authStateProvider.notifier).logout();
        if (context.mounted) context.go(AppRouter.login);
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.logout_rounded, size: 20, color: Color(0xFF6B7280)),
            SizedBox(width: 12),
            Text(
              'Déconnexion',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final String route;
  final IconData icon;
  final Color color;
  final bool Function(UserEntity? user) visible;

  const _NavItem({
    required this.label,
    required this.route,
    required this.icon,
    required this.color,
    required this.visible,
  });

  /// Exact order and visibility from `templates/partials/sidebar.html`.
  static List<_NavItem> allVisibleFor(UserEntity? user) {
    return [
      const _NavItem(
        label: 'Dashboard',
        route: AppRouter.monitoring,
        icon: Icons.home_outlined,
        color: Color(0xFF6366F1),
        visible: _isAdmin,
      ),
      const _NavItem(
        label: 'Gestion des appareils',
        route: AppRouter.devices,
        icon: Icons.videocam_outlined,
        color: Color(0xFF15803D),
        visible: _isAdmin,
      ),
      const _NavItem(
        label: 'Surveillance',
        route: AppRouter.surveillance,
        icon: Icons.favorite_outline,
        color: Color(0xFF6B7280),
        visible: _always,
      ),
      const _NavItem(
        label: 'Historique des alertes',
        route: AppRouter.alertsHistory,
        icon: Icons.notifications_active_outlined,
        color: Color(0xFFEF4444),
        visible: _always,
      ),
      const _NavItem(
        label: 'Patients',
        route: AppRouter.patients,
        icon: Icons.people_alt_outlined,
        color: Color(0xFF6B7280),
        visible: _always,
      ),
      const _NavItem(
        label: 'Machines',
        route: AppRouter.machines,
        icon: Icons.waves,
        color: Color(0xFF6B7280),
        visible: _isNotDoctor,
      ),
      const _NavItem(
        label: 'Séances',
        route: AppRouter.seances,
        icon: Icons.calendar_today_outlined,
        color: Color(0xFF6B7280),
        visible: _always,
      ),
      const _NavItem(
        label: 'Historique des séances',
        route: AppRouter.seancesHistory,
        icon: Icons.calendar_month_outlined,
        color: Color(0xFF3B82F6),
        visible: _always,
      ),
      const _NavItem(
        label: 'Docteurs',
        route: AppRouter.doctors,
        icon: Icons.medical_services_outlined,
        color: Color(0xFF6B7280),
        visible: _isAdmin,
      ),
      const _NavItem(
        label: 'Infirmiers',
        route: AppRouter.nurses,
        icon: Icons.person_outline,
        color: Color(0xFF6B7280),
        visible: _isNotNurse,
      ),
    ].where((item) => item.visible(user)).toList();
  }

  static bool _always(UserEntity? user) => true;

  static bool _isAdmin(UserEntity? user) => user?.isAdmin ?? false;

  static bool _isNotDoctor(UserEntity? user) =>
      user == null ? true : !user.isDoctor;

  static bool _isNotNurse(UserEntity? user) =>
      user == null ? true : !user.isNurse;
}
