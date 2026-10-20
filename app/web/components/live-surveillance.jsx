'use client';

import { useEffect, useRef, useState } from 'react';

import { apiRequest } from './api';
import { Icon } from './icons';
import { Badge, Card, EmptyState, PageHeader, StatCard, StatusBadge } from './ui';

// Cadence d'interrogation du flux de surveillance.
//
// Elle suit la cadence d'acquisition réelle : le délai d'envoi d'image
// configuré sur la séance (`debit`, 20/30/60 s). Interroger toutes les
// 10 s alors que le générateur n'émet que toutes les 60 s ne produisait
// qu'un rafraîchissement d'écran sans nouvelle donnée (A-13).
const REFRESH_MS = 10000;
const MIN_REFRESH_MS = 5000;
const MAX_REFRESH_MS = 60000;

/** Une source est-elle synthétique ? (miroir de monitoring/provenance.py) */
function isSimulatedSource(source) {
  if (!source) return false;
  const norm = String(source).trim().toLowerCase();
  if (norm === 'simulation' || norm === 'telemetry_sim' || norm === 'simulateur') return true;
  return norm.includes('simul') || norm.includes('_sim') || norm.includes('sim_');
}

function formatMetricValue(value, unit) {
  if (value == null || value === '') return 'Non disponible';
  const numericValue = Number(value);
  if (!Number.isFinite(numericValue)) return 'Non disponible';
  const formatted = new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 1 }).format(numericValue);
  return `${formatted}${unit ? ` ${unit}` : ''}`;
}

function formatTimeWithMinutes(totalMinutes) {
  const numericMinutes = Number(totalMinutes);
  if (totalMinutes == null || !Number.isFinite(numericMinutes)) return 'Non disponible';
  const total = Math.max(0, numericMinutes);
  const hours = Math.floor(total / 60);
  const minutes = total % 60;
  return `${hours}h ${minutes.toString().padStart(2, '0')}`;
}

function formatDateTime(value) {
  if (!value) return 'Date inconnue';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Date inconnue';
  return date.toLocaleString('fr-FR');
}

function formatHour(value) {
  if (!value) return 'Non disponible';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Non disponible';
  return date.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
}

function severityBadgeValue(level) {
  const normalized = (level || '').toUpperCase();
  if (normalized === 'HIGH' || normalized === 'CRITIQUE' || normalized === 'CRITICAL' || normalized === 'SEVERE' || normalized === 'RED') return 'HIGH';
  if (normalized === 'MEDIUM' || normalized === 'YELLOW' || normalized === 'ATTENTION' || normalized === 'ALERTE' || normalized === 'WARNING' || normalized === 'WARN') return 'MEDIUM';
  if (normalized === 'LOW' || normalized === 'INFO') return 'LOW';
  return level || '';
}

function alertLabel(level) {
  const normalized = (level || '').toUpperCase();
  if (normalized === 'HIGH' || normalized === 'RED' || normalized === 'CRITIQUE' || normalized === 'CRITICAL' || normalized === 'SEVERE') return 'Critique';
  if (normalized === 'MEDIUM' || normalized === 'YELLOW' || normalized === 'ATTENTION' || normalized === 'ALERTE' || normalized === 'WARNING' || normalized === 'WARN') return 'Avertissement';
  if (normalized === 'LOW' || normalized === 'INFO') return 'Information';
  return 'Gravité inconnue';
}

function sessionStatusLabel(status) {
  return {
    critical: 'Critique',
    warning: 'Avertissement',
    stable: 'Stable',
    information: 'Information',
    unknown: 'Statut inconnu',
  }[status] || 'Statut inconnu';
}

function sessionStatusTone(status) {
  return {
    critical: 'crit',
    warning: 'warn',
    stable: 'ok',
    information: 'info',
    unknown: 'neutral',
  }[status] || 'neutral';
}

const PARAMETER_LABELS = {
  Debit_sang: 'Débit sanguin',
  Taux_UF: 'Taux d’ultrafiltration',
  PA: 'PA (circuit)',
  PTM: 'PTM',
  PV: 'PV (circuit)',
  Volume_UF: 'Volume UF',
  Heparine: 'Héparine',
};

export function LiveSurveillance() {
  const [snapshot, setSnapshot] = useState(null);
  const [error, setError] = useState('');
  const [actionError, setActionError] = useState('');
  const [stale, setStale] = useState(false);
  const [pendingAction, setPendingAction] = useState(null);
  const [refreshVersion, setRefreshVersion] = useState(0);
  const refreshMsRef = useRef(REFRESH_MS);

  useEffect(() => {
    let alive = true;
    let timer = null;

    async function refresh() {
      try {
        const data = await apiRequest('/api/monitoring/live/');
        if (!alive) return;
        setSnapshot(data);
        setError('');
        setStale(false);

        // La cadence suit l'intervalle d'acquisition le plus court des
        // séances actives : interroger plus vite n'apporterait aucune
        // donnée supplémentaire.
        const debits = (data.sessions || [])
          .map((session) => Number(session.debit))
          .filter((value) => Number.isFinite(value) && value > 0);
        const cadence = debits.length ? Math.min(...debits) * 1000 : REFRESH_MS;
        refreshMsRef.current = Math.max(MIN_REFRESH_MS, Math.min(MAX_REFRESH_MS, cadence));
      } catch (cause) {
        if (!alive) return;
        setStale(true);
        setError(
          cause.status === 403
            ? "Votre rôle n'a pas accès à la surveillance."
            : cause.message || 'Le flux de mesures est interrompu.',
        );
      } finally {
        if (alive) {
          timer = window.setTimeout(refresh, refreshMsRef.current);
        }
      }
    }

    refresh();
    return () => {
      alive = false;
      if (timer) window.clearTimeout(timer);
    };
  }, [refreshVersion]);

  async function updateAlertStatus(alert, action) {
    setPendingAction(`${alert.id}:${action}`);
    setActionError('');
    try {
      await apiRequest(`/api/alerts/${encodeURIComponent(alert.id)}/${action}/`, {
        method: 'POST',
      });
      setRefreshVersion((version) => version + 1);
    } catch (cause) {
      setActionError(cause.message || 'Impossible de mettre à jour cette alerte.');
    } finally {
      setPendingAction(null);
    }
  }

  const sessions = snapshot?.sessions || [];
  const alerts = snapshot?.alerts || [];
  const kpis = snapshot?.kpis;
  const activeAlertsCount = snapshot?.active_alerts_count ?? alerts.length;
  const activePatientsCount = snapshot?.active_patients_count ?? sessions.length;

  const summaryCards = [
    { label: 'Sessions actives', value: kpis?.active_sessions ?? '—', hint: 'Séances réellement en cours', icon: 'activity', tone: 'brand' },
    { label: 'Machines disponibles', value: kpis ? `${kpis.available_machines}/${kpis.total_machines}` : '—', hint: 'Libres et opérationnelles / total', icon: 'monitor-heart', tone: 'ok' },
    { label: 'Alertes critiques', value: kpis?.critical_alerts ?? '—', hint: 'Actives, non résolues', icon: 'alert-circle', tone: 'crit' },
    { label: 'Avertissements', value: kpis?.warning_alerts ?? '—', hint: 'Actifs, non résolus', icon: 'alert-triangle', tone: 'warn' },
    { label: 'Patients stables', value: kpis?.stable_patients ?? '—', hint: 'Mesure disponible, sans alerte active', icon: 'check', tone: 'ok' },
  ];

  return (
    <section>
      <PageHeader
        title="Surveillance"
        subtitle="Synthèse des séances actives, des paramètres en temps réel et des alertes ouvertes."
        actions={
          <span
            className={`inline-flex items-center gap-2 rounded-full px-3 py-1.5 text-xs font-medium ${
              stale ? 'bg-critical-soft text-critical' : 'bg-stable-soft text-stable'
            }`}
          >
            <span className={`h-1.5 w-1.5 rounded-full ${stale ? 'bg-critical' : 'animate-pulse bg-stable'}`} />
            {stale ? 'Flux interrompu' : `Temps réel · ${Math.round(refreshMsRef.current / 1000)}s`}
          </span>
        }
      />

      {error && (
        <div role="alert" className="mb-5 flex items-start gap-2.5 rounded-lg border border-critical/30 bg-critical-soft p-3.5 text-sm text-body">
          <span className="mt-0.5 shrink-0 text-critical"><Icon name="alert-circle" className="h-4 w-4" /></span>
          <span>{error}</span>
        </div>
      )}
      {actionError && (
        <div role="alert" className="mb-5 rounded-lg border border-critical/30 bg-critical-soft p-3.5 text-sm text-body">
          {actionError}
        </div>
      )}

      <div className="mb-6 grid gap-4 md:grid-cols-2 xl:grid-cols-5">
        {summaryCards.map((card) => (
          <StatCard
            key={card.label}
            label={card.label}
            value={card.value}
            hint={card.hint}
            icon={card.icon}
            tone={card.tone}
          />
        ))}
      </div>

      {!snapshot && !error ? (
        <div className="rounded-card border border-line bg-surface p-6 text-sm text-body-soft">
          <span className="inline-flex items-center gap-2">
            <span className="h-4 w-4 animate-spin rounded-full border-2 border-brand-700 border-t-transparent" aria-hidden="true" />
            Chargement de la surveillance en cours…
          </span>
        </div>
      ) : !snapshot ? (
        <EmptyState
          icon="monitor-heart"
          title="Surveillance indisponible"
          body="Les données médicales ne sont pas accessibles. Réessayez lorsque la connexion sera rétablie."
        />
      ) : (
        <div className="grid gap-6 xl:grid-cols-[1.6fr_1fr]">
          <div className="space-y-4">
            <div className="flex items-baseline justify-between">
              <h2 className="font-medium text-body">Patients sous surveillance</h2>
              <span className="text-sm text-body-faint">{activePatientsCount} patient{activePatientsCount === 1 ? '' : 's'}</span>
            </div>

            {sessions.length > 0 ? (
              sessions.map((session) => {
                const metricEntries = [
                  ['Débit sanguin', session.metrics?.Debit_sang, 'mL/min'],
                  ['Taux UF', session.metrics?.Taux_UF, 'mL/h'],
                  ['PA (circuit)', session.metrics?.PA, 'mmHg'],
                  ['PV (circuit)', session.metrics?.PV, 'mmHg'],
                  ['PTM', session.metrics?.PTM, 'mmHg'],
                  ['Volume UF', session.metrics?.Volume_UF, 'mL'],
                  ['Héparine', session.metrics?.Heparine, 'UI/h'],
                ];
                const progress = Number.isFinite(session.progress)
                  ? Math.min(100, Math.max(0, session.progress))
                  : null;

                return (
                  <article key={session.seance_id} className="overflow-hidden rounded-card border border-line bg-surface">
                    <header className="flex items-start justify-between gap-3 border-b border-line px-5 py-4">
                      <div className="min-w-0">
                        <div className="flex items-center gap-2">
                          <p className="truncate font-medium text-body">{session.patient || 'Patient non identifié'}</p>
                          {session.age != null && <span className="text-xs text-body-faint">{session.age} ans</span>}
                        </div>
                        <p className="mt-1 text-xs text-body-faint">
                          {session.room || 'Salle non renseignée'} · {session.machine || 'Machine non renseignée'}
                        </p>
                        <p className="mt-1 text-xs font-medium text-body-soft">Séance en cours</p>
                        {session.is_stale && (
                          <p className="mt-1 text-xs font-medium text-warning">
                            Séance hors délai : la durée prévue est dépassée et la séance n'a pas été close.
                          </p>
                        )}
                        {session.source && (
                          <p className="mt-1 text-xs text-body-faint">
                            Source des relevés :{' '}
                            {isSimulatedSource(session.source)
                              ? 'simulateur (données synthétiques)'
                              : session.source}
                          </p>
                        )}
                      </div>
                      <div className="flex flex-col items-end gap-1.5">
                        <Badge label={sessionStatusLabel(session.status)} tone={sessionStatusTone(session.status)} dot />
                        {isSimulatedSource(session.source) && (
                          <Badge label="Données simulées" tone="warn" />
                        )}
                      </div>
                    </header>

                    <div className="px-5 py-4">
                      <div className="mb-4 flex flex-wrap items-center justify-between gap-3 text-sm">
                        <div>
                          <span className="text-body-faint">Temps écoulé</span>
                          <p className="font-medium text-body">{formatTimeWithMinutes(session.elapsed_minutes)}</p>
                        </div>
                        <div className="text-right">
                          <span className="text-body-faint">Temps restant</span>
                          <p className="font-medium text-body">{formatTimeWithMinutes(session.remaining_minutes)}</p>
                        </div>
                      </div>

                      <div className="mb-4">
                        <div className="mb-2 flex items-center justify-between text-xs text-body-faint">
                          <span>Progression de la séance</span>
                          <span>{progress == null ? 'Non disponible' : `${progress}%`}</span>
                        </div>
                        <div
                          className="h-2.5 overflow-hidden rounded-full bg-surface-sunken"
                          role="progressbar"
                          aria-label="Progression de la séance"
                          aria-valuemin={0}
                          aria-valuemax={100}
                          aria-valuenow={progress ?? undefined}
                        >
                          <div
                            className={`h-full rounded-full ${
                              session.status === 'critical' ? 'bg-critical' : session.status === 'warning' ? 'bg-warning' : 'bg-stable'
                            }`}
                            style={{ width: `${progress ?? 0}%` }}
                          />
                        </div>
                      </div>

                      <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
                        {metricEntries.map(([label, value, unit]) => (
                          <div key={label} className="rounded-lg bg-surface-sunken px-3 py-2.5">
                            <p className="text-[11px] uppercase tracking-[0.08em] text-body-faint">{label}</p>
                            <p className="mt-1 text-base font-semibold tabular-nums text-body">
                              {formatMetricValue(value, unit)}
                            </p>
                          </div>
                        ))}
                      </div>
                    </div>

                    <footer className="border-t border-line px-5 py-3 text-xs text-body-faint">
                      {session.has_valid_measurement
                        ? `Dernière mesure : ${formatHour(session.timestamp)} · ${session.source || 'source inconnue'}`
                        : 'Aucune mesure valide disponible pour cette séance.'}
                    </footer>
                  </article>
                );
              })
            ) : (
              <EmptyState
                icon="monitor-heart"
                title="Aucune séance active"
                body="Les patients sous surveillance apparaîtront ici lorsqu'une séance sera en cours."
              />
            )}
          </div>

          <aside className="space-y-4">
            <Card
              title="Alertes actives"
              actions={
                <span className="text-sm text-body-faint">
                  {alerts.length === activeAlertsCount
                    ? `${alerts.length} alerte${alerts.length === 1 ? '' : 's'}`
                    : `${alerts.length} récentes / ${activeAlertsCount} actives`}
                </span>
              }
              padded={false}
            >
              {alerts.length > 0 ? (
                <ul className="divide-y divide-line">
                  {alerts.map((alert) => {
                    const guidance = alert.ai_guidance || {};
                    const recommendations = Array.isArray(guidance.recommendations) ? guidance.recommendations : [];
                    return (
                      <li key={alert.id} className="px-5 py-4">
                        <div className="mb-2 flex items-start justify-between gap-3">
                          <div>
                            <p className="text-sm font-medium text-body">{alert.patient || 'Patient non identifié'}</p>
                            <p className="text-xs text-body-faint">{alert.machine || 'Machine non renseignée'}</p>
                          </div>
                          <div className="flex shrink-0 flex-col items-end gap-1.5">
                            {alert.is_simulated && <Badge label="Simulation" tone="warn" />}
                            {!alert.is_clinical && !alert.is_simulated && (
                              <Badge label="Origine inconnue" tone="warn" />
                            )}
                            <StatusBadge value={severityBadgeValue(alert.niveau)} kind="alerte" dot />
                            <Badge
                              label={alert.status === 'ACK' ? 'Acquittée' : 'Active'}
                              tone={alert.status === 'ACK' ? 'warn' : 'neutral'}
                            />
                          </div>
                        </div>

                        <div className="space-y-2 text-sm text-body-soft">
                          <p>
                            <span className="font-medium text-body">Paramètre :</span> {PARAMETER_LABELS[alert.parameter] || 'Paramètre non disponible'}
                          </p>
                          <p>
                            <span className="font-medium text-body">Valeur enregistrée :</span> {formatMetricValue(alert.value, alert.unit)}
                          </p>
                          <p>
                            <span className="font-medium text-body">Seuil déclencheur :</span> {alert.reference || 'Non disponible'}
                          </p>
                        </div>

                        <p className="mt-3 rounded-lg border border-line bg-surface-sunken px-3 py-2 text-sm text-body">
                          {alert.message || 'Alerte sans message détaillé.'}
                        </p>

                        <div className="mt-3 rounded-lg border border-line bg-surface-sunken p-3">
                          <div className="mb-2 flex items-center justify-between gap-2">
                            <p className="text-xs font-semibold uppercase tracking-[0.08em] text-brand-700 dark:text-brand-200">
                              Aide contextuelle
                            </p>
                            <span className="text-right text-[10px] text-body-soft">{guidance.source || 'Source non disponible'}</span>
                          </div>
                          {guidance.urgent_escalation && (
                            <p className="mb-2 rounded-md bg-critical-soft px-2.5 py-2 text-xs font-semibold text-critical">
                              Alerte critique : appliquer immédiatement le protocole d’escalade local, sans attendre ces conseils.
                            </p>
                          )}
                          {guidance.status === 'ready' ? (
                            <>
                              <p className="mb-2 text-sm text-body-soft">{guidance.cause || 'Cause non identifiée.'}</p>
                              {recommendations.length > 0 && (
                                <ul className="list-disc space-y-1 pl-5 text-sm text-body">
                                  {recommendations.map((item) => (
                                    <li key={item}>{item}</li>
                                  ))}
                                </ul>
                              )}
                              <p className="mt-2 text-xs text-body-soft">
                                Aide à la vérification uniquement; elle ne remplace pas le jugement soignant ni le protocole validé.
                              </p>
                            </>
                          ) : (
                            <p className="text-sm text-body-soft">
                              Données de mesure indisponibles pour cette alerte : aucun conseil
                              automatique ne peut lui être rattaché. Vérifiez la mesure et le
                              protocole clinique local.
                            </p>
                          )}
                        </div>

                        <div className="mt-3 flex items-center justify-between text-[11px] text-body-faint">
                          <span>{alertLabel(alert.niveau)} · {alert.status === 'ACK' ? 'Acquittée' : 'Active'}</span>
                          <time>{formatDateTime(alert.timestamp)}</time>
                        </div>
                        <div className="mt-3 flex flex-wrap justify-end gap-2">
                          {alert.status === 'NEW' && (
                            <button
                              type="button"
                              disabled={pendingAction != null}
                              onClick={() => updateAlertStatus(alert, 'ack')}
                              className="rounded-lg border border-line px-3 py-1.5 text-xs font-medium text-body hover:bg-surface-sunken disabled:cursor-wait disabled:opacity-60"
                            >
                              {pendingAction === `${alert.id}:ack` ? 'Acquittement…' : 'Acquitter'}
                            </button>
                          )}
                          <button
                            type="button"
                            disabled={pendingAction != null}
                            onClick={() => updateAlertStatus(alert, 'resolve')}
                            className="rounded-lg bg-brand-700 px-3 py-1.5 text-xs font-medium text-white hover:bg-brand-800 disabled:cursor-wait disabled:opacity-60"
                          >
                            {pendingAction === `${alert.id}:resolve` ? 'Résolution…' : 'Résoudre'}
                          </button>
                        </div>
                      </li>
                    );
                  })}
                </ul>
              ) : (
                <div className="px-5 py-10 text-center text-sm text-body-faint">
                  Aucune alerte ouverte pour le moment.
                </div>
              )}
            </Card>
          </aside>
        </div>
      )}

      <p className="mt-5 text-xs text-body-faint">
        Dernière actualisation : {snapshot?.last_update ? formatDateTime(snapshot.last_update) : '—'}
      </p>
    </section>
  );
}
