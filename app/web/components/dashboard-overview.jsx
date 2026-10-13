'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { apiRequest } from './api';

const labels = [
  ['active_sessions', 'Séances en cours', '◷'],
  ['available_machines', 'Générateurs disponibles', '▤'],
  ['active_alerts', 'Alertes ouvertes', '△'],
  ['patients_count', 'Patients suivis', '＋'],
  ['today_sessions', 'Séances aujourd’hui', '▦'],
];

export function DashboardOverview() {
  const [kpis, setKpis] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    apiRequest('/api/dashboard/')
      .then((payload) => setKpis(payload.kpis || {}))
      .catch((cause) => setError(cause.message || 'Impossible de charger les indicateurs.'));
  }, []);

  return (
    <section>
      <div className="page-heading">
        <div><p className="eyebrow">VUE D’ENSEMBLE</p><h1>Tableau de bord</h1><p className="muted">État actuel de l’activité de dialyse.</p></div>
        <Link className="button button-primary" href="/monitoring/surveillance/">Voir la surveillance</Link>
      </div>
      {error && <div className="notice notice-error" role="alert">{error}</div>}
      <div className="kpi-grid">
        {labels.map(([key, label, icon]) => (
          <article className="kpi-card" key={key}>
            <span className="kpi-icon" aria-hidden="true">{icon}</span>
            <p>{label}</p>
            <strong>{kpis ? (kpis[key] ?? 0) : '—'}</strong>
          </article>
        ))}
      </div>
      <div className="dashboard-callout">
        <div><p className="eyebrow">MONITORING</p><h2>Consultez les séances en direct</h2><p className="muted">Mesures, alertes et état de validation transmis par les générateurs.</p></div>
        <Link className="button button-secondary" href="/monitoring/surveillance/">Ouvrir la surveillance <span aria-hidden="true">→</span></Link>
      </div>
    </section>
  );
}
