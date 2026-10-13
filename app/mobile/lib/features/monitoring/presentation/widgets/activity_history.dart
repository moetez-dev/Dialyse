import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/monitoring_provider.dart';
import 'monitoring_formatting.dart';
import '../../domain/entities/monitoring_dashboard_entity.dart';

/// "Historique login / logout" card. Reproduces the Django dashboard table and
/// its filters (day, search q, role, username sorting, login sorting and the
/// "En cours" toggle) adapted to a mobile column layout. Rows show the same
/// data as the web table: status dot, username/email, role badge, login time
/// and logout time (or a green "En cours" pill).
class ActivityHistory extends ConsumerStatefulWidget {
  const ActivityHistory({super.key});

  @override
  ConsumerState<ActivityHistory> createState() => _ActivityHistoryState();
}

class _ActivityHistoryState extends ConsumerState<ActivityHistory> {
  final _searchController = TextEditingController();
  String _day = '';
  String _role = '';
  String _sort = '-login_at';
  bool _ongoingOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _apply() {
    ref
        .read(monitoringDashboardProvider.notifier)
        .setFilters(
          MonitoringFilters(
            day: _day,
            q: _searchController.text.trim(),
            role: _role,
            sort: _sort,
            status: _ongoingOnly ? 'ongoing' : '',
          ),
        );
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day.isEmpty ? now : (DateTime.tryParse(_day) ?? now),
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _day =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
    _apply();
  }

  void _toggleSort(String value) {
    setState(() => _sort = value);
    _apply();
  }

  void _toggleOngoing() {
    setState(() => _ongoingOnly = !_ongoingOnly);
    _apply();
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(monitoringDashboardProvider);
    final activity = switch (dataAsync) {
      AsyncData<MonitoringDashboardEntity>(:final value) => value.activity,
      _ => const <ActivityEntryEntity>[],
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Historique login / logout',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Dernières connexions des utilisateurs.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),
          _buildFilters(),
          const SizedBox(height: 12),
          if (activity.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 28,
                      color: Color(0xFF9CA3AF),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Aucun historique pour le moment.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            )
          else
            ...activity.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ActivityRow(entry: entry),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Chercher...',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.trim().isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _apply();
                            setState(() {});
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onSubmitted: (_) {
                  _apply();
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _role.isEmpty ? null : _role,
              hint: const Text('Rôle'),
              items: const [
                DropdownMenuItem(value: '', child: Text('Tous')),
                DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                DropdownMenuItem(value: 'Docteur', child: Text('Docteur')),
                DropdownMenuItem(value: 'Infirmier', child: Text('Infirmier')),
              ],
              onChanged: (v) {
                setState(() => _role = v ?? '');
                _apply();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _FilterChip(
              label: 'A→Z',
              selected: _sort == 'username',
              onTap: () => _toggleSort('username'),
            ),
            const SizedBox(width: 4),
            _FilterChip(
              label: 'Z→A',
              selected: _sort == '-username',
              onTap: () => _toggleSort('-username'),
            ),
            const SizedBox(width: 4),
            _FilterChip(
              label: 'Login ↑',
              selected: _sort == 'login_at',
              onTap: () => _toggleSort('login_at'),
            ),
            const SizedBox(width: 4),
            _FilterChip(
              label: 'Login ↓',
              selected: _sort == '-login_at',
              onTap: () => _toggleSort('-login_at'),
            ),
            const Spacer(),
            // Day filter
            _FilterChip(
              label: _day.isEmpty ? 'Jour' : _day.substring(5),
              icon: Icons.calendar_today_outlined,
              selected: _day.isNotEmpty,
              onTap: _pickDay,
              onClear: _day.isEmpty
                  ? null
                  : () {
                      setState(() => _day = '');
                      _apply();
                    },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: _toggleOngoing,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _ongoingOnly ? const Color(0xFFDCFCE7) : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _ongoingOnly
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _ongoingOnly
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _ongoingOnly ? 'En cours ✓' : 'En cours',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _ongoingOnly
                          ? const Color(0xFF166534)
                          : const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF3B82F6) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: const Color(0xFF6B7280)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF374151),
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onClear,
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityEntryEntity entry;

  const _ActivityRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isOngoing ? const Color(0xFFFAFAFA) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: entry.isOngoing
                  ? const Color(0xFF10B981)
                  : const Color(0xFFD1D5DB),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.username,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoleBadge(role: entry.role),
                  ],
                ),
                if (entry.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _TimeCell(
            icon: Icons.login_rounded,
            value: formatTime(entry.loginAt),
          ),
          const SizedBox(width: 12),
          if (entry.isOngoing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                  SizedBox(width: 4),
                  Text(
                    'En cours',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            )
          else
            _TimeCell(
              icon: Icons.logout_rounded,
              value: formatTime(entry.logoutAt),
            ),
        ],
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  final IconData icon;
  final String value;

  const _TimeCell({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF6B7280)),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
        ),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final roleLower = role.toLowerCase();
    final (Color bg, Color fg) = switch (roleLower) {
      'docteur' => (const Color(0xFFEDE9FE), const Color(0xFF6D28D9)),
      'infirmier' => (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
      _ => (const Color(0xFFF3F4F6), const Color(0xFF374151)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        role.isEmpty ? '—' : role,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
