import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/staff_provider.dart';

class DoctorsPage extends ConsumerStatefulWidget {
  const DoctorsPage({super.key});

  @override
  ConsumerState<DoctorsPage> createState() => _DoctorsPageState();
}

class _DoctorsPageState extends ConsumerState<DoctorsPage> {
  final _search = TextEditingController();
  String _role = '';
  String _status = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _apply() {
    ref.read(doctorsProvider.notifier).setFilters(
          DoctorsFilters(
            search: _search.text,
            role: _role,
            status: _status,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(doctorsProvider);
    return AppShell(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push<bool>(
            AppRouter.doctorCreateRoute,
          );
          if (created == true) {
            ref.read(doctorsProvider.notifier).refresh();
          }
        },
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Ajouter'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Rechercher un medecin...',
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
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Tous')),
                      DropdownMenuItem(value: 'doctor', child: Text('Docteur')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (v) {
                      setState(() => _role = v ?? '');
                      _apply();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Statut',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Tous')),
                      DropdownMenuItem(value: 'active', child: Text('Actif')),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactif'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _status = v ?? '');
                      _apply();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(doctorsProvider.notifier).refresh(),
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
                                ref.read(doctorsProvider.notifier).refresh(),
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
                      'Docteurs (${result.total}) · Actifs ${result.active} · Admins ${result.admins}',
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
                          'Aucun medecin trouve.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...result.items.map(
                        (d) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(d.displayName),
                            subtitle: Text(
                              '${d.role} · ${d.specialite.isEmpty ? 'Generaliste' : d.specialite}\n${d.email}',
                            ),
                            isThreeLine: true,
                            trailing: Text(
                              d.statusLabel,
                              style: TextStyle(
                                color: d.etat
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () => context.push(
                              AppRouter.doctorDetailRoute(d.id),
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
