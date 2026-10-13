import 'package:flutter/material.dart';

import '../../domain/entities/live_monitoring_entity.dart';
import 'surveillance_formatting.dart';

/// Django blue-600 (#2563EB).
const Color kSurveillanceBlue = Color(0xFF2563EB);
const Color kTextInk = Color(0xFF111827);
const Color kGray500 = Color(0xFF6B7280);
const Color kGray600 = Color(0xFF4B5563);

/// "Connexion active" pill from surveillance.html:
/// `bg-green-50 border border-green-300 rounded-xl` with a pulsing green dot.
class ActiveConnectionPill extends StatefulWidget {
  const ActiveConnectionPill({super.key});

  @override
  State<ActiveConnectionPill> createState() => _ActiveConnectionPillState();
}

class _ActiveConnectionPillState extends State<ActiveConnectionPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), // green-50
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF86EFAC)), // green-300
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 1.0, end: 0.35).animate(_controller),
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF22C55E), // green-500
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Connexion active',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF15803D), // green-700
            ),
          ),
        ],
      ),
    );
  }
}

/// The 5 KPI cards of surveillance.html:
/// Sessions actives / Machines / Alertes critiques / Avertissements /
/// Patients stables (with the same value colors: red-600, yellow-500, green-600).
class LiveKpiGrid extends StatelessWidget {
  final SurveillanceLiveEntity data;

  const LiveKpiGrid({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth >= 900
            ? 5
            : constraints.maxWidth >= 640
            ? 3
            : 2;
        const spacing = 12.0;
        final tileWidth =
            (constraints.maxWidth - spacing * (perRow - 1)) / perRow;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _KpiTile(
              width: tileWidth,
              title: 'Sessions actives',
              value: '${data.sessions.length}',
            ),
            _KpiTile(
              width: tileWidth,
              title: 'Machines',
              value: '${data.sessions.length}',
            ),
            _KpiTile(
              width: tileWidth,
              title: 'Alertes critiques',
              value: '${data.criticalAlerts}',
              valueColor: const Color(0xFFDC2626), // red-600
            ),
            _KpiTile(
              width: tileWidth,
              title: 'Avertissements',
              value: '${data.warningAlerts}',
              valueColor: const Color(0xFFEAB308), // yellow-500
            ),
            _KpiTile(
              width: tileWidth,
              title: 'Patients stables',
              value: '${data.stablePatients}',
              valueColor: const Color(0xFF16A34A), // green-600
            ),
          ],
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final Color? valueColor;

  const _KpiTile({
    required this.width,
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, color: kGray500)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: valueColor ?? kTextInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// One white session card from surveillance.html: "Patient : X" +
/// "Machine : Y" + a divider + Débit sang / PA / PTM / PV / Volume UF.
class LiveSessionCard extends StatelessWidget {
  final LiveSessionEntity session;

  const LiveSessionCard({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Patient : ${session.patient ?? '—'}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kTextInk,
            ),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text: 'Machine : ',
              style: const TextStyle(fontSize: 15, color: kGray600),
              children: [
                TextSpan(
                  text: _machine,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          _ValueRow(
            label: 'Débit sang',
            value: session.debitSang,
            unit: 'ml/min',
          ),
          _ValueRow(label: 'PA', value: session.pa, unit: 'mmHg'),
          _ValueRow(label: 'PTM', value: session.ptm, unit: 'mmHg'),
          _ValueRow(label: 'PV', value: session.pv, unit: 'mmHg'),
          _ValueRow(label: 'Volume UF', value: session.volumeUF, unit: 'ml'),
        ],
      ),
    );
  }

  String get _machine => session.machine ?? '—';
}

class _ValueRow extends StatelessWidget {
  final String label;
  final num? value;
  final String unit;

  const _ValueRow({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, color: kGray600),
            ),
          ),
          Text.rich(
            TextSpan(
              text: value?.toString() ?? '--',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: kTextInk,
              ),
              children: [
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Color-coded alert card from surveillance.html (HIGH = red, otherwise
/// yellow) with the niveau, time and an "Acquitter" button.
class LiveAlertCard extends StatelessWidget {
  final LiveAlertEntity alert;
  final VoidCallback? onAck;

  const LiveAlertCard({super.key, required this.alert, this.onAck});

  @override
  Widget build(BuildContext context) {
    final isHigh = alert.isHigh;
    final Color borderColor = isHigh
        ? const Color(0xFFF87171)
        : const Color(0xFFFDE047); // red-400 / yellow-300
    final Color bgColor = isHigh
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFFEFCE8); // red-50 / yellow-50
    final Color textColor = isHigh
        ? const Color(0xFFB91C1C)
        : const Color(0xFFA16207); // red-700 / yellow-700

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  alert.niveau.isEmpty ? '—' : alert.niveau,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              Text(
                formatLiveTime(alert.timestamp),
                style: const TextStyle(fontSize: 12, color: kGray500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alert.message,
            style: const TextStyle(fontSize: 14, color: kGray600),
          ),
          const SizedBox(height: 10),
          if (onAck != null)
            OutlinedButton(
              onPressed: onAck,
              style: OutlinedButton.styleFrom(
                foregroundColor: kGray600,
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                minimumSize: const Size(0, 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text('Acquitter', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xFFE5E7EB)),
    boxShadow: const [
      BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1)),
    ],
  );
}

/// Width helper so session cards go 1-up on phones and 2-up on larger screens.
double sessionTileWidth(double maxWidth) {
  return maxWidth >= 640 ? (maxWidth - 12) / 2 : maxWidth;
}
