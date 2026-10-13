'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { apiRequest } from './api';

function formatCell(value, kind) {
  if (value === null || value === undefined || value === '') return '—';
  if (kind === 'date') {
    const date = new Date(value);
    return Number.isNaN(date.valueOf()) ? String(value) : date.toLocaleDateString('fr-FR');
  }
  if (kind === 'status') return String(value);
  if (typeof value === 'boolean') return value ? 'Oui' : 'Non';
  return String(value);
}

function canCreate(role, roles) {
  if (!roles?.length) return true;
  return roles.includes((role || '').trim().toLowerCase());
}

export function ResourceList({
  title,
  eyebrow,
  description,
  endpoint,
  columns,
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

  useEffect(() => {
    let alive = true;
    setLoading(true);
    const suffix = query ? `?search=${encodeURIComponent(query)}` : '';
    Promise.all([
      apiRequest(`${endpoint}${suffix}`),
      apiRequest('/api/profile/'),
    ])
      .then(([result, profile]) => {
        if (!alive) return;
        setRows(Array.isArray(result.data) ? result.data : []);
        setRole(profile.data?.role || '');
        setError('');
      })
      .catch((cause) => alive && setError(cause.message || 'Impossible de charger les données.'))
      .finally(() => alive && setLoading(false));
    return () => { alive = false; };
  }, [endpoint, query]);

  function submitSearch(event) {
    event.preventDefault();
    setQuery(term.trim());
  }

  return (
    <section>
      <div className="page-heading">
        <div><p className="eyebrow">{eyebrow}</p><h1>{title}</h1><p className="muted">{description}</p></div>
        {addHref && canCreate(role, createRoles) && <Link className="button button-primary" href={addHref}>＋ {addLabel}</Link>}
      </div>
      {error && <div className="notice notice-error" role="alert">{error}</div>}
      <div className="resource-toolbar">
        <span>{loading ? 'Chargement…' : `${rows.length} résultat${rows.length === 1 ? '' : 's'}`}</span>
        {searchable && (
          <form className="search-form" onSubmit={submitSearch}>
            <input aria-label={`Rechercher ${title.toLowerCase()}`} value={term} onChange={(event) => setTerm(event.target.value)} placeholder="Rechercher…" />
            <button className="button button-secondary" type="submit">Rechercher</button>
          </form>
        )}
      </div>
      <div className="resource-table-wrap">
        <table className="resource-table">
          <thead><tr>{columns.map((column) => <th key={column.key}>{column.label}</th>)}</tr></thead>
          <tbody>
            {!loading && rows.map((row, index) => {
              const id = row.id ?? row.uuid ?? row.username ?? index;
              const href = detailPath ? detailPath.replace('{id}', encodeURIComponent(String(id))) : null;
              return (
                <tr key={id}>
                  {columns.map((column, columnIndex) => {
                    let value = row[column.key];
                    if (column.key === 'full_name') value = [row.first_name, row.last_name].filter(Boolean).join(' ');
                    if (column.key === 'staff_status') value = row.status_label || (row.etat ? 'Actif' : 'Inactif');
                    const content = formatCell(value, column.kind);
                    return <td key={column.key}>{columnIndex === 0 && href ? <Link className="table-link" href={href}>{content}</Link> : content}</td>;
                  })}
                </tr>
              );
            })}
            {!loading && !rows.length && <tr><td className="table-empty" colSpan={columns.length}>{error ? 'Les données ne sont pas disponibles.' : 'Aucun résultat.'}</td></tr>}
          </tbody>
        </table>
      </div>
    </section>
  );
}
