'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { apiRequest } from './api';

const groups = [
  { label: 'SOINS', links: [
    ['Surveillance', '/monitoring/surveillance/'],
    ['Tableau de bord', '/monitoring/dashboard/'],
    ['Séances', '/seances/'],
    ['Historique des séances', '/monitoring/seances-history/'],
    ['Alertes', '/monitoring/alerts-history/'],
  ] },
  { label: 'RÉFÉRENTIEL', links: [
    ['Patients', '/patients/'],
    ['Générateurs', '/machines/'],
    ['Appareils de lecture', '/machines/raspi/'],
  ] },
  { label: 'ÉQUIPE', links: [
    ['Docteurs', '/docteurs/'],
    ['Infirmiers', '/nurses/'],
  ] },
];

function canSeeLink(role, href) {
  const normalized = (role || '').trim().toLowerCase();
  if (href === '/monitoring/dashboard/') return normalized === 'admin';
  if (href === '/machines/') return ['admin', 'infirmier'].includes(normalized);
  if (href === '/machines/raspi/') return normalized === 'admin';
  if (href === '/docteurs/') return normalized === 'admin';
  if (href === '/nurses/') return ['admin', 'docteur'].includes(normalized);
  return true;
}

export function WorkspaceShell({ children }) {
  const pathname = usePathname();
  const router = useRouter();
  const [user, setUser] = useState(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let alive = true;
    apiRequest('/api/profile/')
      .then((payload) => {
        if (!alive) return;
        setUser(payload.data);
        if (payload.data?.first_login && pathname !== '/profile') {
          router.replace('/profile/');
        } else if (pathname === '/monitoring/dashboard' && (payload.data?.role || '').trim().toLowerCase() !== 'admin') {
          router.replace('/error/');
        }
      })
      .catch((error) => {
        if (alive && error.status === 401) router.replace('/connexion/');
      })
      .finally(() => alive && setReady(true));
    return () => { alive = false; };
  }, [pathname, router]);

  async function logout() {
    try {
      await apiRequest('/api/logout/', { method: 'POST' });
    } finally {
      router.replace('/connexion/');
      router.refresh();
    }
  }

  if (!ready || !user) {
    return <main className="workspace-loading"><span className="spinner" /> Chargement de votre espace…</main>;
  }

  return (
    <div className="workspace">
      <aside className="sidebar">
        <Link className="sidebar-brand" href="/">
          <span className="brand-mark brand-mark-small">D</span>
          <span><strong>Dialyse</strong><small>MANAGER</small></span>
        </Link>
        <nav aria-label="Navigation principale">
          {groups.map((group) => (
            <div className="nav-group" key={group.label}>
              <p>{group.label}</p>
              {group.links.filter(([, href]) => canSeeLink(user.role, href)).map(([label, href]) => (
                <Link className={pathname === href.replace(/\/$/, '') ? 'nav-link nav-link-active' : 'nav-link'} href={href} key={href}>
                  <span className="nav-dot" aria-hidden="true" />{label}
                </Link>
              ))}
            </div>
          ))}
        </nav>
        <div className="sidebar-user">
          <div className="avatar">{(user.username || 'U').slice(0, 1).toUpperCase()}</div>
          <div className="sidebar-user-copy"><strong>{user.username}</strong><span>{user.role}</span></div>
          <button className="logout-button" type="button" onClick={logout} aria-label="Se déconnecter">↗</button>
        </div>
      </aside>
      <main className="workspace-main">
        <header className="topbar">
          <div><span className="topbar-kicker">ESPACE DE SOINS</span><strong>{user.username}</strong></div>
          <span className="connection-pill"><i /> Connecté</span>
        </header>
        <div className="page-content">{children}</div>
      </main>
    </div>
  );
}
