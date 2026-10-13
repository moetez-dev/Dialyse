'use client';

/* Tableau de bord — réservé à l'administration.
 *
 * Les indicateurs sont ceux que /api/dashboard/ calcule réellement ; aucun
 * chiffre n'est inventé ni codé en dur. La version précédente utilisait des
 * classes (`kpi-grid`, `kpi-card`, `dashboard-callout`…) sans aucune règle,
 * et des pictogrammes typographiques à la place du jeu d'icônes. */

import Link from 'next/link';
import { useEffect, useState } from 'react';

import { apiRequest } from './api';
import { Icon } from './icons';
import { Button, Card, PageHeader, StatCard } from './ui';

const KPIS = [
  { key: 'active_sessions', label: 'Séances en cours', icon: 'monitor-heart', tone: 'brand' },
  { key: 'today_sessions', label: "Séances aujourd'hui", icon: 'calendar', tone: 'neutral' },
  { key: 'active_alerts', label: 'Alertes ouvertes', icon: 'alert-triangle', tone: 'crit' },
  { key: 'available_machines', label: 'Générateurs disponibles', icon: 'waves', tone: 'ok' },
  { key: 'patients_count', label: 'Patients suivis', icon: 'users', tone: 'neutral' },
];

export function DashboardOverview() {
  const [kpis, setKpis] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    let alive = true;
    apiRequest('/api/dashboard/')
      .then((payload) => alive && setKpis(payload.kpis || {}))
      .catch((cause) => {
        if (!alive) return;
        setError(
          cause.status === 403
            ? "Le tableau de bord est réservé à l'administration."
            : cause.message || 'Le chargement des indicateurs a échoué.',
        );
      });
    return () => {
      alive = false;
    };
  }, []);

  const total = kpis?.total_machines;

  return (
    <section>
      <PageHeader
        title="Tableau de bord"
        subtitle="État courant de l'activité de l'unité."
        actions={
          <Button as={Link} href="/monitoring/surveillance/" variant="primary">
            <Icon name="monitor-heart" className="h-4 w-4" />
            Voir la surveillance
          </Button>
        }
      />

      {error && (
        <div
          role="alert"
          className="mb-5 flex items-start gap-2.5 rounded-lg border border-critical/30 bg-critical-soft p-3.5 text-sm text-body"
        >
          <span className="mt-0.5 shrink-0 text-critical">
            <Icon name="alert-circle" className="h-4 w-4" />
          </span>
          <span>{error}</span>
        </div>
      )}

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {KPIS.map((kpi) => (
          <StatCard
            key={kpi.key}
            label={kpi.label}
            icon={kpi.icon}
            tone={kpi.tone}
            value={kpis ? (kpis[kpi.key] ?? 0) : null}
            hint={
              kpi.key === 'available_machines' && total != null
                ? `sur ${total} générateur${total === 1 ? '' : 's'}`
                : undefined
            }
          />
        ))}
      </div>

      <div className="mt-8">
        <Card title="Séances en direct">
          <p className="max-w-prose text-sm leading-relaxed text-body-soft">
            Les paramètres relevés par les générateurs, les alertes de seuil et
            l'état de validation de chaque séance se consultent depuis l'écran
            de surveillance.
          </p>
          <div className="mt-4">
            <Button as={Link} href="/monitoring/surveillance/">
              Ouvrir la surveillance
            </Button>
          </div>
        </Card>
      </div>
    </section>
  );
}
