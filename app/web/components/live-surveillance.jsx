'use client';

import { useEffect, useState } from 'react';
import { apiRequest } from './api';

function Metric({ label, value, unit }) {
  return <div className="metric"><span>{label}</span><strong>{value ?? '—'}{value != null && unit ? <small> {unit}</small> : null}</strong></div>;
}

export function LiveSurveillance() {
  const [snapshot, setSnapshot] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    let alive = true;
    async function refresh() {
      try {
        const data = await apiRequest('/api/monitoring/live/');
        if (alive) { setSnapshot(data); setError(''); }
      } catch (cause) {
        if (alive) setError(cause.message || 'Impossible de charger les mesures.');
      }
    }
    refresh();
    const timer = window.setInterval(refresh, 10000);
    return () => { alive = false; window.clearInterval(timer); };
  }, []);

  return (
    <section>
      <div className="page-heading">
        <div><p className="eyebrow">SUIVI EN DIRECT</p><h1>Surveillance</h1><p className="muted">Mesures des séances actives et alertes récentes.</p></div>
        <span className="live-pill"><i /> Temps réel · actualisation 10 s</span>
      </div>
      {error && <div className="notice notice-error" role="alert">{error}</div>}
      <div className="section-heading"><h2>Séances actives</h2><span>{snapshot?.sessions?.length ?? 0} en cours</span></div>
      {snapshot?.sessions?.length ? (
        <div className="session-grid">
          {snapshot.sessions.map((session) => (
            <article className="session-card" key={session.seance_id}>
              <div className="session-card-heading"><div><span className="eyebrow">{session.machine || 'Générateur'}</span><h3>{session.patient || 'Patient'}</h3></div><span className="status-badge status-live">En cours</span></div>
              <div className="metric-grid">
                <Metric label="Débit sanguin" value={session.Debit_sang} unit="ml/min" />
                <Metric label="PA" value={session.PA} unit="mmHg" />
                <Metric label="PV" value={session.PV} unit="mmHg" />
                <Metric label="PTM" value={session.PTM} unit="mmHg" />
                <Metric label="UF" value={session.Volume_UF} unit="ml" />
                <Metric label="Heparine" value={session.Heparine} unit="UI/h" />
              </div>
              <p className="card-footnote">Dernière mesure : {session.timestamp ? new Date(session.timestamp).toLocaleTimeString('fr-FR') : 'en attente'}</p>
            </article>
          ))}
        </div>
      ) : (
        <div className="empty-card"><span className="empty-icon">◷</span><strong>Aucune mesure de séance active</strong><p>Les mesures apparaîtront ici dès qu’une séance en cours transmettra ses données.</p></div>
      )}
      <div className="section-heading alerts-heading"><h2>Alertes ouvertes</h2><span>{snapshot?.alerts?.length ?? 0}</span></div>
      <div className="alerts-list">
        {snapshot?.alerts?.length ? snapshot.alerts.map((alert) => (
          <article className="alert-row" key={alert.id}>
            <span className={(alert.niveau || '').toLowerCase().includes('high') ? 'alert-indicator alert-critical' : 'alert-indicator'} />
            <div><strong>{alert.niveau || 'Alerte'}</strong><p>{alert.message}</p></div>
            <time>{alert.timestamp ? new Date(alert.timestamp).toLocaleString('fr-FR') : ''}</time>
          </article>
        )) : <div className="empty-inline">Aucune alerte ouverte.</div>}
      </div>
      <p className="updated-at">Dernière actualisation : {snapshot?.last_update ? new Date(snapshot.last_update).toLocaleTimeString('fr-FR') : '—'}</p>
    </section>
  );
}
