import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/widgets/app_shell.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/machines_provider.dart';
import '../widgets/machine_card.dart';

/// Machines screen mirroring Django `machines.html`:
/// KPI cards (Total, PrÃªtes, Maintenance, Hors Service, RÃ©servÃ©es),
/// search + status + location filters, white machine cards with
/// status dot/badge, info rows, and "DÃ©tails"/"Config" actions.
class MachinesPage extends ConsumerStatefulWidget {
  const MachinesPage({super.key});

  @override
  ConsumerState<MachinesPage> createState() => _MachinesPageState();
}

class _MachinesPageState extends ConsumerState<MachinesPage> {
  final _searchController = TextEditingController();
  String _selectedStatus = '';
  String _selectedLocation = '';
  final _statusOptions = const [
    'Prete',
    'Maintenance',
    'Hors Service',
    'Reserve',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref
        .read(machinesProvider.notifier)
        .setFilters(
          search: _searchController.text,
          status: _selectedStatus,
          location: _selectedLocation,
        );
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedStatus = '';
      _selectedLocation = '';
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final machinesAsync = ref.watch(machinesProvider);
    final notifier = ref.read(machinesProvider.notifier);
    final auth = ref.watch(authStateProvider);
    final user = auth is AuthAuthenticated ? auth.user : null;
    final isAdmin = user?.isAdmin ?? false;

    final kpis = machinesAsync.asData?.value.kpis;
    final total = kpis?.total ?? 0;
    final pretes = kpis?.pretes ?? 0;
    final maintenance = kpis?.maintenance ?? 0;
    final horsService = kpis?.horsService ?? 0;
    final reserve = kpis?.reserve ?? 0;
    final locationOptions = machinesAsync.asData?.value.locations ?? const <String>[];

    return AppShell(
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRouter.machineCreateRoute),
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouvelle machine'),
            )
          : null,
      actions: [
        if (_searchController.text.isNotEmpty ||
            _selectedStatus.isNotEmpty ||
            _selectedLocation.isNotEmpty)
          IconButton(
            tooltip: 'Effacer les filtres',
            icon: const Icon(Icons.filter_list_off_rounded),
            onPressed: _clearFilters,
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KPI Cards
          _buildKpiSection(total, pretes, maintenance, horsService, reserve),
          const SizedBox(height: 12),

          // Search + Filters
          _buildSearchAndFilters(locationOptions),

          // Machine list
          Expanded(
            child: RefreshIndicator(
              onRefresh: notifier.refresh,
              child: machinesAsync.when(
                loading: () => const _CenteredScrollable(
                  child: Padding(
                    padding: EdgeInsets.only(top: 64),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (error, _) => _CenteredScrollable(
                  child: _ErrorState(error: error, onRetry: notifier.refresh),
                ),
                data: (result) => result.machines.isEmpty
                    ? _CenteredScrollable(
                        child: _EmptyState(
                          hasSearch:
                              _searchController.text.trim().isNotEmpty ||
                              _selectedStatus.isNotEmpty ||
                              _selectedLocation.isNotEmpty,
                          onReset: _clearFilters,
                        ),
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        children: result.machines
                            .map(
                              (m) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: MachineCard(
                                  machine: m,
                                  onTap: () => context.push(
                                    AppRouter.machineDetailRoute(m.id),
                                  ),
                                  onConfigTap: () => context.push(
                                    AppRouter.machineConfigRoute(m.id),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSection(
    int total,
    int pretes,
    int maintenance,
    int horsService,
    int reserve,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  'Total Machines',
                  total,
                  Icons.waves_outlined,
                  AppColors.primary,
                  'Toutes les machines',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  'PrÃªtes',
                  pretes,
                  Icons.check_circle_outline_rounded,
                  const Color(0xFF10B981),
                  'PrÃªtes Ã  l\'usage',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  'Maintenance',
                  maintenance,
                  Icons.settings_outlined,
                  const Color(0xFF3B82F6),
                  'Actuellement indisponibles',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  'Hors Service',
                  horsService,
                  Icons.error_outline_rounded,
                  AppColors.danger,
                  'Ã€ vÃ©rifier',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  'RÃ©servÃ©es',
                  reserve,
                  Icons.bookmark_outline_rounded,
                  const Color(0xFFF59E0B),
                  'RÃ©servÃ©es / Inactives',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(List<String> locationOptions) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher une machine...',
              prefixIcon: const Icon(Icons.search, size: 22),
              suffixIcon: _searchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
                        setState(() {});
                      },
                    ),
            ),
            onSubmitted: (_) => _applyFilters(),
          ),
          const SizedBox(height: 12),
          // Status + Location filters
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('status-$_selectedStatus'),
                  initialValue: _selectedStatus.isEmpty
                      ? null
                      : _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Statut',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Tous les statuts'),
                    ),
                    ..._statusOptions.map(
                      (s) => DropdownMenuItem(value: s, child: Text(s)),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedStatus = v ?? '');
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('location-$_selectedLocation'),
                  initialValue: _selectedLocation.isEmpty
                      ? null
                      : _selectedLocation,
                  decoration: const InputDecoration(
                    labelText: 'Salle',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Toutes les salles'),
                    ),
                    ...locationOptions.map(
                      (s) => DropdownMenuItem(value: s, child: Text(s)),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedLocation = v ?? '');
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color iconColor;
  final String subtitle;

  const _KpiCard(
    this.title,
    this.value,
    this.icon,
    this.iconColor,
    this.subtitle,
  );

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
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
          const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
          const SizedBox(height: 12),
          const Text(
            "Impossible de charger la liste des machines",
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
            text: 'RÃ©essayer',
            icon: Icons.refresh_rounded,
            backgroundColor: const Color(0xFF2563EB),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

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
          const Icon(Icons.waves_outlined, size: 48, color: Color(0xFFF59E0B)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEFCE8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Text(
              'Aucun rÃ©sultat trouvÃ© pour votre recherche.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF854D0E)),
            ),
          ),
          if (hasSearch) ...[
            const SizedBox(height: 16),
            CustomButton(
              text: 'RÃ©initialiser les filtres',
              icon: Icons.filter_list_off_rounded,
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

