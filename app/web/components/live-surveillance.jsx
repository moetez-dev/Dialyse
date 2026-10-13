'use client';

/* Surveillance temps réel — l'écran d'accueil du personnel soignant.
 *
 * Reprend la mise en page du gabarit Django : une carte par séance active
 * avec ses paramètres, puis le fil des alertes ouvertes. La version
 * précédente s'appuyait sur des classes (`session-card`, `metric-grid`,
 * `status-badge`…) dépourvues de toute règle : l'écran s'affichait en texte
 * brut. */

import { useEffect, useRef, useState } from 'react';

import { apiRequest } from './api';
import { Icon } from './icons';
import { Card, EmptyState, PageHeader, StatusBadge } from './ui';

const REFRESH_MS = 10000;

function Metric({ label, value, unit }) {
  return (
    <div className="rounded-lg bg-surface-sunken px-3 py-2.5">
      <p className="text-xs text-body-faint">{label}</p>
      <p className="mt-0.5 text-lg font-semibold tabular-nums text-body">
        {value ?? '—'}
        {value != null && unit && (
          <span className="ml-1 text-xs font-normal text-body-faint">{unit}</span>
        )}
      </p>
    </div>
  );
}

/* Le message enregistré en base répète déjà la gravité, pastille comprise :
   « 🔴 CRITIQUE — Pression artérielle très bas : … ». Affiché à côté de la
   pastille de statut, le niveau apparaissait trois fois sur la même ligne. */
const PREFIXE_GRAVITE =
  /^[\s\u{2600}-\u{27BF}\u{FE0F}\u{1F300}-\u{1FAFF}]*(CRITIQUE|ALERTE|ATTENTION|INFO)\s*[—:-]\s*/iu;

function messageAlerte(message) {
  return (message || '').replace(PREFIXE_GRAVITE, '').trim() || 'Alerte';
}

function heure(value) {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.valueOf()) ? null : date.toLocaleTimeString('fr-FR');
}

export function LiveSurveillance() {
  const [snapshot, setSnapshot] = useState(null);
  const [error, setError] = useState('');
  const [stale, setStale] = useState(false);
  const lastOk = useRef(null);

  useEffect(() => {
    let alive = true;

    async function refresh() {
      try {
        const data = await apiRequest('/api/monitoring/live/');
        if (!alive) return;
        setSnapshot(data);
        setError('');
        setStale(false);
        lastOk.current = Date.now();
      } catch (cause) {
        if (!alive) return;
        // Un flux interrompu doit se voir : sans cela, des mesures figées
        // sont indiscernables de mesures stables.
        setStale(true);
        setError(
          cause.status === 403
            ? "Votre rôle n'a pas accès à la surveillance."
            : cause.message || 'Le flux de mesures est interrompu.',
        );
      }
    }

    refresh();
    const timer = window.setInterval(refresh, REFRESH_MS);
    return () => {
      alive = false;
      window.clearInterval(timer);
    };
  }, []);

  const sessions = snapshot?.sessions || [];
  const alerts = snapshot?.alerts || [];

  return (
    <section>
      <PageHeader
        title="Surveillance"
        subtitle="Mesures des séances en cours et alertes ouvertes."
        actions={
          <span
            className={`inline-flex items-center gap-2 rounded-full px-3 py-1.5 text-xs font-medium ${
              stale ? 'bg-critical-soft text-critical' : 'bg-stable-soft text-stable'
            }`}
          >
            <span
              className={`h-1.5 w-1.5 rounded-full ${
                stale ? 'bg-critical' : 'animate-pulse bg-stable'
              }`}
            />
            {stale ? 'Flux interrompu' : `Temps réel · ${REFRESH_MS / 1000} s`}
          </span>
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

      <div className="mb-3 flex items-baseline justify-between">
        <h2 className="font-medium text-body">Séances en cours</h2>
        <span className="text-sm text-body-faint">
          {sessions.length} séance{sessions.length === 1 ? '' : 's'}
        </span>
      </div>

      {sessions.length > 0 ? (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {sessions.map((session) => (
            <article
              key={session.seance_id}
              className="rounded-card border border-line bg-surface"
            >
              <header className="flex items-start justify-between gap-3 border-b border-line px-5 py-4">
                <div className="min-w-0">
                  <p className="truncate font-medium text-body">
                    {session.patient || 'Patient'}
                  </p>
                  <p className="mt-0.5 text-xs text-body-faint">
                    {session.machine || 'Générateur non renseigné'}
                  </p>
                </div>
                <StatusBadge value="en cours" kind="seance" dot />
              </header>

              <div className="grid grid-cols-2 gap-2 p-4 sm:grid-cols-3">
                <Metric label="Débit sanguin" value={session.Debit_sang} unit="ml/min" />
                <Metric label="PA" value={session.PA} unit="mmHg" />
                <Metric label="PV" value={session.PV} unit="mmHg" />
                <Metric label="PTM" value={session.PTM} unit="mmHg" />
                <Metric label="UF" value={session.Volume_UF} unit="ml" />
                <Metric label="Héparine" value={session.Heparine} unit="UI/h" />
              </div>

              <footer className="border-t border-line px-5 py-3 text-xs text-body-faint">
                Dernière mesure&nbsp;: {heure(session.timestamp) || 'en attente'}
              </footer>
            </article>
          ))}
        </div>
      ) : (
        <EmptyState
          icon="monitor-heart"
          title="Aucune séance en cours"
          body="Les mesures apparaîtront ici dès qu'une séance transmettra ses paramètres."
        />
      )}

      <div className="mt-8">
        <Card
          title="Alertes ouvertes"
          actions={
            <span className="text-sm text-body-faint">
              {alerts.length} alerte{alerts.length === 1 ? '' : 's'}
            </span>
          }
          padded={false}
        >
          {alerts.length > 0 ? (
            <ul className="divide-y divide-line">
              {alerts.map((alert) => (
                <li key={alert.id} className="flex items-start gap-3 px-5 py-3.5">
                  <span className="mt-0.5 shrink-0">
                    <StatusBadge value={alert.niveau} kind="alerte" dot />
                  </span>
                  <p className="min-w-0 flex-1 text-sm leading-relaxed text-body">
                    {messageAlerte(alert.message)}
                  </p>
                  <time className="shrink-0 text-xs tabular-nums text-body-faint">
                    {alert.timestamp
                      ? new Date(alert.timestamp).toLocaleString('fr-FR')
                      : ''}
                  </time>
                </li>
              ))}
            </ul>
          ) : (
            <p className="px-5 py-8 text-center text-sm text-body-faint">
              Aucune alerte ouverte.
            </p>
          )}
        </Card>
      </div>

      <p className="mt-5 text-xs text-body-faint">
        Dernière actualisation&nbsp;: {heure(snapshot?.last_update) || '—'}
      </p>
    </section>
  );
}
