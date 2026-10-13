import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/patients_provider.dart';
import '../widgets/patient_card.dart';

/// Patients screen. Mirrors the Django `patient.html` page:
/// KPI card "Patients Totaux", live search (`?search=`), white patient cards
/// with a "Voir le dossier" action, empty / loading / error states and
/// pull-to-refresh.
class PatientsPage extends ConsumerStatefulWidget {
  const PatientsPage({super.key});

  @override
  ConsumerState<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends ConsumerState<PatientsPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(patientsProvider.notifier).search(value);
    });
  }

  Future<void> _resetSearch() {
    _debounce?.cancel();
    _searchController.clear();
    return ref.read(patientsProvider.notifier).search('');
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsProvider);
    final notifier = ref.read(patientsProvider.notifier);

    return AppShell(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push<bool>(AppRouter.patientCreateRoute);
          if (created == true && context.mounted) {
            ref.read(patientsProvider.notifier).refresh();
          }
        },
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Nouveau patient'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchBar(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: notifier.refresh,
              child: patientsAsync.when(
                loading: () => const _CenteredScrollable(
                  child: Padding(
                    padding: EdgeInsets.only(top: 64),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (error, _) => _CenteredScrollable(
                  child: _ErrorState(error: error, onRetry: notifier.refresh),
                ),
                data: (result) => result.isEmpty
                    ? _CenteredScrollable(
                        child: _EmptyState(
                          hasSearch: _searchController.text.trim().isNotEmpty,
                          onReset: _resetSearch,
                        ),
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Patients',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Liste des patients',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _PatientsTotalCard(total: result.totalCount),
                          const SizedBox(height: 16),
                          for (final patient in result.patients)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: PatientCard(
                                patient: patient,
                                onTap: () => context.push(
                                  AppRouter.patientDetailRoute(patient.id),
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

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Rechercher un patient...',
          prefixIcon: const Icon(Icons.search, size: 22),
          suffixIcon: _searchController.text.trim().isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _resetSearch,
                ),
        ),
      ),
    );
  }
}

class _PatientsTotalCard extends StatelessWidget {
  final int total;

  const _PatientsTotalCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Patients Totaux',
                  style: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Sous suivi',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFCFFAFE), // cyan-100
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              size: 22,
              color: Color(0xFF0891B2), // cyan-600
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : error.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
          const SizedBox(height: 12),
          const Text(
            "Impossible de charger la liste des patients",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: 'Réessayer',
            icon: Icons.refresh_rounded,
            backgroundColor: const Color(0xFF2563EB), // blue-600
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Matches Django's empty message:
/// yellow box "Aucun résultat trouvé pour votre recherche."
class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onReset;

  const _EmptyState({required this.hasSearch, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.people_outline_rounded,
            size: 48,
            color: Color(0xFFF59E0B),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEFCE8), // yellow-50
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)), // yellow-200
            ),
            child: const Text(
              'Aucun résultat trouvé pour votre recherche.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF854D0E)), // yellow-800
            ),
          ),
          if (hasSearch) ...[
            const SizedBox(height: 16),
            CustomButton(
              text: 'Réinitialiser la recherche',
              icon: Icons.search_off_rounded,
              backgroundColor: const Color(0xFF2563EB),
              onPressed: onReset,
            ),
          ],
        ],
      ),
    );
  }
}

class _CenteredScrollable extends StatelessWidget {
  final Widget child;

  const _CenteredScrollable({required this.child});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [child],
    );
  }
}
