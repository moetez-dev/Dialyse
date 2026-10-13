/* Primitives d'interface, équivalentes aux balises {% ui_* %} des gabarits
   Django : même marquage, mêmes jetons, pour que les écrans migrés soient
   indiscernables de ceux qui ne le sont pas encore. */

import { Icon } from './icons';

const TONE_CLASSES = {
  neutral: 'bg-idle-soft text-idle',
  brand: 'bg-brand-50 text-brand-800 dark:bg-brand-950 dark:text-brand-200',
  ok: 'bg-stable-soft text-stable',
  warn: 'bg-warning-soft text-warning',
  crit: 'bg-critical-soft text-critical',
  info: 'bg-brand-50 text-brand-700 dark:bg-brand-950 dark:text-brand-300',
};

const VALUE_CLASSES = {
  neutral: 'text-body',
  brand: 'text-brand-700 dark:text-brand-300',
  ok: 'text-stable',
  warn: 'text-warning',
  crit: 'text-critical',
  info: 'text-brand-700 dark:text-brand-300',
};

// Les statuts sont stockés en texte libre et dans deux vocabulaires concurrents
// pour les alertes ; la correspondance vit ici, en un seul endroit.
const SEANCE_TONE = {
  planifiée: 'info',
  'en cours': 'brand',
  terminée: 'ok',
  annulée: 'neutral',
  difficile: 'warn',
};

const MACHINE_TONE = {
  prete: 'ok',
  reserve: 'info',
  maintenance: 'warn',
  'hors service': 'crit',
  inactive: 'neutral',
};

const ALERTE_TONE = {
  high: 'crit', red: 'crit', critique: 'crit',
  medium: 'warn', yellow: 'warn', alerte: 'warn',
  low: 'info', info: 'info',
  new: 'crit', ack: 'warn', resolved: 'ok',
};

const ALERTE_LABEL = {
  high: 'Critique', red: 'Critique', critique: 'Critique',
  medium: 'Avertissement', yellow: 'Avertissement', alerte: 'Avertissement',
  low: 'Information', info: 'Information',
  new: 'Nouvelle', ack: 'Acquittée', resolved: 'Résolue',
};

const MACHINE_LABEL = {
  prete: 'Prête', reserve: 'Réservée', maintenance: 'Maintenance',
  'hors service': 'Hors service', inactive: 'Inactive',
};

// Les comptes du personnel n'ont que deux états.
const STAFF_TONE = { actif: 'ok', inactif: 'neutral' };

const TONE_MAPS = {
  seance: SEANCE_TONE, machine: MACHINE_TONE,
  alerte: ALERTE_TONE, staff: STAFF_TONE,
};
const LABEL_MAPS = { seance: {}, machine: MACHINE_LABEL, alerte: ALERTE_LABEL, staff: {} };

export function toneFor(value, kind = 'seance') {
  const key = (value || '').trim().toLowerCase();
  return TONE_MAPS[kind]?.[key] || 'neutral';
}

export function Badge({ label, tone = 'neutral', dot = false }) {
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium ${
        TONE_CLASSES[tone] || TONE_CLASSES.neutral
      }`}
    >
      {dot && <span className="h-1.5 w-1.5 rounded-full bg-current" />}
      {label}
    </span>
  );
}

/** Pastille pour une valeur de statut venue de la base. */
export function StatusBadge({ value, kind = 'seance', dot = false }) {
  const key = (value || '').trim().toLowerCase();
  const label = LABEL_MAPS[kind]?.[key] || (value ? value.charAt(0).toUpperCase() + value.slice(1) : '—');
  return <Badge label={label} tone={toneFor(value, kind)} dot={dot} />;
}

export function StatCard({ label, value, hint, unit, icon, tone = 'neutral' }) {
  return (
    <div className="rounded-card border border-line bg-surface p-4">
      <div className="flex items-start justify-between gap-3">
        <p className="text-sm text-body-soft">{label}</p>
        {icon && (
          <span className="shrink-0 text-body-faint">
            <Icon name={icon} className="h-4 w-4" />
          </span>
        )}
      </div>
      <p className={`mt-2 text-2xl font-semibold tabular-nums ${VALUE_CLASSES[tone] || VALUE_CLASSES.neutral}`}>
        {value ?? '—'}
        {unit && <span className="ml-1 text-sm font-normal text-body-faint">{unit}</span>}
      </p>
      {hint && <p className="mt-1 text-xs text-body-faint">{hint}</p>}
    </div>
  );
}

export function PageHeader({ title, subtitle, actions }) {
  return (
    <div className="mb-6 flex flex-wrap items-start justify-between gap-4">
      <div>
        <h1 className="font-serif text-2xl tracking-tight text-body">{title}</h1>
        {subtitle && <p className="mt-1 text-sm text-body-soft">{subtitle}</p>}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
    </div>
  );
}

export function Card({ title, subtitle, actions, padded = true, children }) {
  return (
    <section className="rounded-card border border-line bg-surface">
      {title && (
        <header className="flex items-center justify-between gap-3 border-b border-line px-5 py-4">
          <div>
            <h2 className="font-medium text-body">{title}</h2>
            {subtitle && <p className="mt-0.5 text-sm text-body-soft">{subtitle}</p>}
          </div>
          {actions}
        </header>
      )}
      <div className={padded ? 'p-5' : undefined}>{children}</div>
    </section>
  );
}

export function EmptyState({ title, body, icon = 'calendar', action }) {
  return (
    <div className="flex flex-col items-center rounded-card border border-dashed border-line px-6 py-12 text-center">
      <span className="text-body-faint">
        <Icon name={icon} className="h-7 w-7" />
      </span>
      <p className="mt-3 font-medium text-body">{title}</p>
      {body && <p className="mt-1 max-w-sm text-sm leading-relaxed text-body-soft">{body}</p>}
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}

export function DataTable({ columns, children, empty }) {
  return (
    <div className="overflow-x-auto rounded-card border border-line bg-surface">
      <table className="w-full text-left text-sm">
        <thead className="border-b border-line bg-surface-sunken text-xs text-body-soft">
          <tr>
            {columns.map((col) => (
              <th
                key={typeof col === 'string' ? col : col.label}
                scope="col"
                className={`px-4 py-3 font-medium ${
                  typeof col !== 'string' && col.align === 'right' ? 'text-right' : ''
                }`}
              >
                {typeof col === 'string' ? col : col.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-line">{children}</tbody>
      </table>
      {empty && <p className="px-4 py-6 text-center text-sm text-body-faint">{empty}</p>}
    </div>
  );
}

export function Button({ as: As = 'button', variant = 'secondary', children, ...rest }) {
  const styles = {
    primary: 'bg-brand-700 text-white hover:bg-brand-800',
    secondary: 'border border-line text-body hover:bg-surface-sunken',
    ghost: 'text-body-soft hover:bg-surface-sunken hover:text-body',
  };
  return (
    <As
      className={`inline-flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium ${
        styles[variant] || styles.secondary
      }`}
      {...rest}
    >
      {children}
    </As>
  );
}
