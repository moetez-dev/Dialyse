import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../providers/staff_provider.dart';

class NursesPage extends ConsumerStatefulWidget {
  const NursesPage({super.key});

  @override
  ConsumerState<NursesPage> createState() => _NursesPageState();
}

class _NursesPageState extends ConsumerState<NursesPage> {
  final _search = TextEditingController();
  String _status = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _apply() {
    ref.read(nursesProvider.notifier).setFilters(
          NursesFilters(search: _search.text, status: _status),
        );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(nursesProvider);
    final auth = ref.watch(authStateProvider);
    final isAdmin =
        auth is AuthAuthenticated ? auth.user.isAdmin : false;

    return AppShell(
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await context.push<bool>(
                  AppRouter.nurseCreateRoute,
                );
                if (created == true) {
                  ref.read(nursesProvider.notifier).refresh();
                }
              },
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Ajouter'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Rechercher un infirmier...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), _apply);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Statut',
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('Tous')),
                DropdownMenuItem(value: 'active', child: Text('Actif')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactif')),
              ],
              onChanged: (v) {
                setState(() => _status = v ?? '');
                _apply();
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(nursesProvider.notifier).refresh(),
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(e is ApiException ? e.message : e.toString()),
                          CustomButton(
                            text: 'Reessayer',
                            onPressed: () =>
                                ref.read(nursesProvider.notifier).refresh(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                data: (result) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  children: [
                    Text(
                      'Infirmiers (${result.total}) · Actifs ${result.active}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (result.items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Aucun infirmier trouve.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...result.items.map(
                        (n) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(n.displayName),
                            subtitle: Text('${n.email}\n${n.phone}'),
                            isThreeLine: true,
                            trailing: Text(
                              n.statusLabel,
                              style: TextStyle(
                                color: n.etat
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () => context.push(
                              AppRouter.nurseDetailRoute(n.id),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
