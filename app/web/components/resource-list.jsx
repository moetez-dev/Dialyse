'use client';

/* Liste de référentiel (patients, générateurs, docteurs, infirmiers).
 *
 * La version précédente était écrite contre une feuille de styles qui
 * n'existe plus : `page-heading`, `eyebrow`, `resource-table`,
 * `button-primary`… aucune de ces classes n'a de règle, si bien que les
 * quatre écrans s'affichaient en HTML brut, pour tous les rôles. Tout passe
 * désormais par les composants et les jetons communs. */

import Link from 'next/link';
import { useEffect, useRef, useState } from 'react';

import { apiRequest } from './api';
import { Icon } from './icons';
import { Button, DataTable, EmptyState, PageHeader, StatusBadge } from './ui';

function formatCell(value, kind) {
  if (value === null || value === undefined || value === '') return '—';
  if (kind === 'date') {
    const date = new Date(value);
    return Number.isNaN(date.valueOf()) ? String(value) : date.toLocaleDateString('fr-FR');
  }
  if (typeof value === 'boolean') return value ? 'Oui' : 'Non';
  return String(value);
}

function cellValue(row, column) {
  if (column.key === 'full_name') {
    return [row.first_name, row.last_name].filter(Boolean).join(' ') || row.username;
  }
  if (column.key === 'staff_status') {
    return row.status_label || (row.etat ? 'Actif' : 'Inactif');
  }
  return row[column.key];
}

function canCreate(role, roles) {
  if (!roles?.length) return true;
  return roles.includes((role || '').trim().toLowerCase());
}

export function ResourceList({
  title,
  description,
  endpoint,
  columns,
  createEndpoint,
  createFields = [],
  addHref,
  addLabel = 'Ajouter',
  createRoles,
  detailPath,
  searchable = false,
}) {
  const [rows, setRows] = useState([]);
  const [role, setRole] = useState('');
  const [term, setTerm] = useState('');
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [createOpen, setCreateOpen] = useState(false);
  const [creating, setCreating] = useState(false);
  const [createError, setCreateError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');
  const [refreshKey, setRefreshKey] = useState(0);
  const submitting = useRef(false);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    const suffix = query ? `?search=${encodeURIComponent(query)}` : '';
    Promise.all([apiRequest(`${endpoint}${suffix}`), apiRequest('/api/profile/')])
      .then(([result, profile]) => {
        if (!alive) return;
        setRows(Array.isArray(result.data) ? result.data : []);
        setRole(profile.data?.role || '');
        setError('');
      })
      .catch((cause) => {
        if (!alive) return;
        setRows([]);
        // Une liste vide et un refus d'accès ne se ressemblent pas : le
        // message doit dire lequel des deux s'est produit.
        setError(
          cause.status === 403
            ? "Votre rôle n'a pas accès à ces données."
            : cause.message || 'Le chargement des données a échoué.',
        );
      })
      .finally(() => alive && setLoading(false));
    return () => {
      alive = false;
    };
  }, [endpoint, query, refreshKey]);

  function submitSearch(event) {
    event.preventDefault();
    setQuery(term.trim());
  }

  async function submitCreate(event) {
    event.preventDefault();
    if (submitting.current) return;
    submitting.current = true;
    setCreating(true);
    setCreateError('');

    try {
      const form = event.currentTarget;
      const payload = Object.fromEntries(new FormData(form));
      const result = await apiRequest(createEndpoint, {
        method: 'POST',
        body: JSON.stringify(payload),
      });
      const temporaryPassword = result.temporary_password
        ? ` Mot de passe provisoire : ${result.temporary_password}`
        : '';
      setSuccessMessage(`Création effectuée avec succès.${temporaryPassword}`);
      setCreateOpen(false);
      setRefreshKey((key) => key + 1);
    } catch (cause) {
      setCreateError(cause.message || 'La création a échoué.');
    } finally {
      submitting.current = false;
      setCreating(false);
    }
  }

  const showAdd = addHref && canCreate(role, createRoles);

  return (
    <section>
      <PageHeader
        title={title}
        subtitle={description}
        actions={
          showAdd && (createEndpoint ? (
            <Button
              type="button"
              variant="primary"
              onClick={() => {
                setCreateError('');
                setSuccessMessage('');
                setCreateOpen(true);
              }}
            >
              <Icon name="plus" className="h-4 w-4" />
              {addLabel}
            </Button>
          ) : (
            <Button as={Link} href={addHref} variant="primary">
              <Icon name="plus" className="h-4 w-4" />
              {addLabel}
            </Button>
          ))
        }
      />

      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-body-soft">
          {loading
            ? 'Chargement…'
            : `${rows.length} résultat${rows.length === 1 ? '' : 's'}`}
        </p>

        {searchable && (
          <form onSubmit={submitSearch} className="flex items-center gap-2">
            <label htmlFor="resource-search" className="sr-only">
              Rechercher parmi&nbsp;: {title.toLowerCase()}
            </label>
            <input
              id="resource-search"
              value={term}
              onChange={(event) => setTerm(event.target.value)}
              placeholder="Rechercher…"
              className="w-56 rounded-lg border border-line bg-surface px-3 py-2 text-sm text-body
                         placeholder:text-body-faint focus:border-brand-500 focus:outline-none
                         focus:ring-2 focus:ring-brand-500/30"
            />
            <Button type="submit">Rechercher</Button>
          </form>
        )}
      </div>

      {error && (
        <div
          role="alert"
          className="mb-4 flex items-start gap-2.5 rounded-lg border border-critical/30 bg-critical-soft p-3.5 text-sm text-body"
        >
          <span className="mt-0.5 shrink-0 text-critical">
            <Icon name="alert-circle" className="h-4 w-4" />
          </span>
          <span>{error}</span>
        </div>
      )}

      {successMessage && (
        <div
          role="status"
          className="mb-4 rounded-lg border border-stable/30 bg-stable-soft p-3.5 text-sm text-body"
        >
          {successMessage}
        </div>
      )}

      {createOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/25 p-4 backdrop-blur-sm">
          <section
            role="dialog"
            aria-modal="true"
            aria-labelledby="resource-create-title"
            className="max-h-[90vh] w-full max-w-md overflow-y-auto rounded-xl bg-surface shadow-xl"
          >
            <header className="flex items-center justify-between border-b border-line p-5">
              <h2 id="resource-create-title" className="text-lg font-semibold text-body">
                {addLabel}
              </h2>
              <Button
                type="button"
                variant="ghost"
                disabled={creating}
                onClick={() => setCreateOpen(false)}
              >
                Fermer
              </Button>
            </header>

            <form onSubmit={submitCreate} className="space-y-4 p-5">
              {createError && (
                <div
                  role="alert"
                  className="rounded-lg border border-critical/30 bg-critical-soft p-3 text-sm text-body"
                >
                  {createError}
                </div>
              )}

              {createFields.map((field) => (
                <div key={field.name}>
                  <label
                    htmlFor={`create-${field.name}`}
                    className="mb-1 block text-sm text-body-soft"
                  >
                    {field.label}
                  </label>
                  {field.options ? (
                    <select
                      id={`create-${field.name}`}
                      name={field.name}
                      required={field.required}
                      defaultValue={field.options[0]?.[0] || ''}
                      className="w-full rounded-lg border border-line bg-surface px-3 py-2 text-sm text-body focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/30"
                    >
                      {field.options.map(([value, label]) => (
                        <option key={value} value={value}>
                          {label}
                        </option>
                      ))}
                    </select>
                  ) : field.multiline ? (
                    <textarea
                      id={`create-${field.name}`}
                      name={field.name}
                      required={field.required}
                      maxLength={field.maxLength}
                      rows={3}
                      className="w-full rounded-lg border border-line bg-surface px-3 py-2 text-sm text-body focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/30"
                    />
                  ) : (
                    <input
                      id={`create-${field.name}`}
                      name={field.name}
                      type={field.type || 'text'}
                      required={field.required}
                      maxLength={field.maxLength}
                      autoComplete={field.type === 'email' ? 'email' : 'off'}
                      className="w-full rounded-lg border border-line bg-surface px-3 py-2 text-sm text-body focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/30"
                    />
                  )}
                </div>
              ))}

              <div className="flex justify-end gap-2 border-t border-line pt-4">
                <Button
                  type="button"
                  disabled={creating}
                  onClick={() => setCreateOpen(false)}
                >
                  Annuler
                </Button>
                <Button type="submit" variant="primary" disabled={creating}>
                  {creating ? 'Enregistrement…' : 'Enregistrer'}
                </Button>
              </div>
            </form>
          </section>
        </div>
      )}

      {!loading && !error && rows.length === 0 ? (
        <EmptyState
          icon="users"
          title="Aucun résultat"
          body={
            query
              ? `Aucune entrée ne correspond à « ${query} ».`
              : 'Cette liste est encore vide.'
          }
          action={
            query ? (
              <Button onClick={() => { setTerm(''); setQuery(''); }}>
                Effacer la recherche
              </Button>
            ) : undefined
          }
        />
      ) : (
        <DataTable columns={columns.map((column) => ({ label: column.label }))}>
          {loading
            ? Array.from({ length: 4 }, (_, index) => (
                <tr key={`skeleton-${index}`}>
                  {columns.map((column) => (
                    <td key={column.key} className="px-4 py-3">
                      <span className="block h-3.5 w-24 animate-pulse rounded bg-surface-sunken" />
                    </td>
                  ))}
                </tr>
              ))
            : rows.map((row, index) => {
                const id = row.id ?? row.uuid ?? row.username ?? index;
                const href = detailPath
                  ? detailPath.replace('{id}', encodeURIComponent(String(id)))
                  : null;
                return (
                  <tr key={id} className="hover:bg-surface-sunken">
                    {columns.map((column, columnIndex) => {
                      const value = cellValue(row, column);
                      const content =
                        column.kind === 'status' ? (
                          <StatusBadge value={value} kind={column.statusKind || 'seance'} />
                        ) : (
                          formatCell(value, column.kind)
                        );
                      return (
                        <td key={column.key} className="px-4 py-3 text-body">
                          {columnIndex === 0 && href ? (
                            <Link
                              href={href}
                              className="font-medium text-brand-700 hover:underline dark:text-brand-300"
                            >
                              {content}
                            </Link>
                          ) : (
                            content
                          )}
                        </td>
                      );
                    })}
                  </tr>
                );
              })}
        </DataTable>
      )}
    </section>
  );
}
