'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';

import { apiRequest } from './api';
import { Icon } from './icons';
import { canAccessRoute, capabilities, homeHref, navFor } from './navigation';

function ThemeToggle() {
  const [dark, setDark] = useState(false);

  useEffect(() => {
    setDark(document.documentElement.classList.contains('dark'));
  }, []);

  function toggle() {
    const next = !dark;
    document.documentElement.classList.toggle('dark', next);
    try {
      localStorage.setItem('theme', next ? 'dark' : 'light');
    } catch {
      /* navigation privée : le thème ne survivra pas au rechargement */
    }
    setDark(next);
  }

  return (
    <button
      type="button"
      onClick={toggle}
      aria-label="Changer de thème"
      className="grid h-9 w-9 place-items-center rounded-lg text-body-soft hover:bg-surface-sunken hover:text-body"
    >
      <Icon name={dark ? 'sun' : 'moon'} />
    </button>
  );
}

function AccessDenied({ role, home }) {
  return (
    <div className="mx-auto max-w-lg rounded-card border border-line bg-surface">
      <header className="flex items-center justify-between border-b border-line px-5 py-4">
        <h1 className="font-medium text-body">Accès refusé</h1>
        <span className="rounded-full bg-critical-soft px-2.5 py-0.5 text-xs font-medium text-critical">
          403
        </span>
      </header>
      <div className="p-5">
        <p className="text-sm leading-relaxed text-body-soft">
          Votre compte ({role}) n'a pas accès à cette page. Si vous pensez qu'il
          s'agit d'une erreur, contactez l'administrateur du service.
        </p>
        <div className="mt-5 flex flex-wrap gap-2.5">
          <a
            href={home}
            className="rounded-lg bg-brand-700 px-4 py-2 text-sm font-medium text-white hover:bg-brand-800"
          >
            Aller à mon premier écran
          </a>
          <a
            href="/profile/"
            className="rounded-lg border border-line px-4 py-2 text-sm text-body-soft hover:bg-surface-sunken hover:text-body"
          >
            Mon profil
          </a>
        </div>
      </div>
    </div>
  );
}

export function WorkspaceShell({ children }) {
  const pathname = usePathname();
  const router = useRouter();
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [sidebarOpen, setSidebarOpen] = useState(false);

  useEffect(() => {
    let cancelled = false;
    apiRequest('/api/profile/')
      .then((payload) => {
        if (!cancelled) setUser(payload.data || payload.user || payload);
      })
      .catch(() => {
        if (!cancelled) router.replace('/connexion');
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [router]);

  // Le volet se referme à chaque navigation sur petit écran.
  useEffect(() => setSidebarOpen(false), [pathname]);

  const caps = capabilities(user);
  const groups = navFor(user);
  // Les vues Django refusaient déjà ces chemins ; les pages React ne passent
  // pas par elles, la règle doit donc être rejouée ici.
  const allowed = canAccessRoute(user, pathname);

  async function logout() {
    try {
      await apiRequest('/api/logout/', { method: 'POST' });
    } catch {
      /* la session est de toute façon abandonnée côté client */
    }
    router.replace('/connexion');
  }

  if (loading) {
    return (
      <div className="grid min-h-screen place-items-center bg-canvas">
        <p className="text-sm text-body-faint">Chargement…</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-canvas text-body">
      <header className="sticky top-0 z-40 h-navbar border-b border-line bg-surface">
        <div className="flex h-full items-center gap-3 px-4">
          {groups.length > 0 && (
            <button
              type="button"
              onClick={() => setSidebarOpen((open) => !open)}
              aria-label="Ouvrir la navigation"
              className="grid h-9 w-9 shrink-0 place-items-center rounded-lg text-body-soft hover:bg-surface-sunken hover:text-body lg:hidden"
            >
              <Icon name="menu" className="h-5 w-5" />
            </button>
          )}

          <Link href="/" className="flex min-w-0 items-center gap-2.5">
            <span className="grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-brand-700 text-white">
              <Icon name="activity" />
            </span>
            <span className="min-w-0 truncate font-serif text-[17px] font-semibold tracking-tight text-body">
              Dialyse&nbsp;Manager
            </span>
          </Link>

          <div className="ml-auto flex items-center gap-2">
            <ThemeToggle />

            {user && (
              <>
                <Link
                  href="/profile/"
                  className="flex items-center gap-2.5 rounded-lg px-2 py-1.5 hover:bg-surface-sunken"
                >
                  <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-surface-sunken text-body-soft">
                    <Icon name="user" className="h-4 w-4" />
                  </span>
                  <span className="hidden text-left leading-tight sm:block">
                    <span className="block text-sm font-medium text-body">{user.username}</span>
                    <span className="block text-xs text-body-faint">{caps.roleLabel}</span>
                  </span>
                </Link>

                <button
                  type="button"
                  onClick={logout}
                  className="flex items-center gap-2 rounded-lg border border-line px-3 py-2 text-sm text-body-soft hover:bg-surface-sunken hover:text-body"
                >
                  <Icon name="log-out" className="h-4 w-4" />
                  <span className="hidden sm:inline">Déconnexion</span>
                </button>
              </>
            )}
          </div>
        </div>
      </header>

      <div className="flex">
        {groups.length > 0 && (
          <>
            <aside
              className={`fixed left-0 top-navbar z-30 h-[calc(100vh-var(--spacing-navbar))] w-64 shrink-0
                          overflow-y-auto border-r border-line bg-surface transition-transform duration-300
                          lg:sticky lg:translate-x-0 ${sidebarOpen ? 'translate-x-0' : '-translate-x-full'}`}
            >
              <nav className="space-y-6 p-4" aria-label="Navigation principale">
                {groups.map((group) => (
                  <div key={group.group}>
                    <p className="px-3 pb-2 text-xs font-medium tracking-wide text-body-faint">
                      {group.group}
                    </p>
                    <ul className="space-y-0.5">
                      {group.items.map((item) => {
                        const base = item.href.replace(/\/$/, '');
                        const here = pathname.replace(/\/$/, '');
                        const active = here === base || here.startsWith(`${base}/`);
                        const Tag = item.external ? 'a' : Link;
                        return (
                          <li key={item.href}>
                            <Tag
                              href={item.href}
                              aria-current={active ? 'page' : undefined}
                              className={`flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors ${
                                active
                                  ? 'bg-brand-50 font-medium text-brand-800 dark:bg-brand-950 dark:text-brand-200'
                                  : 'text-body-soft hover:bg-surface-sunken hover:text-body'
                              }`}
                            >
                              <Icon name={item.icon} className="h-[18px] w-[18px] shrink-0" />
                              <span className="truncate">{item.label}</span>
                            </Tag>
                          </li>
                        );
                      })}
                    </ul>
                  </div>
                ))}
              </nav>
            </aside>

            {sidebarOpen && (
              <div
                className="fixed inset-0 z-20 bg-ink-950/40 lg:hidden"
                onClick={() => setSidebarOpen(false)}
              />
            )}
          </>
        )}

        <main className="min-w-0 flex-1 p-4 lg:p-6">
          {allowed ? children : <AccessDenied role={caps.roleLabel} home={homeHref(user)} />}
        </main>
      </div>
    </div>
  );
}
