'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';

import { apiRequest } from './api';
import { Icon } from './icons';
import { homeHref } from './navigation';
import { ThemeToggleStandalone } from './theme-toggle';

export function LoginForm() {
  const router = useRouter();
  const [mode, setMode] = useState('login'); // 'login' | 'reset'
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [busy, setBusy] = useState(false);

  async function onLogin(event) {
    event.preventDefault();
    setError('');
    setBusy(true);
    const form = new FormData(event.currentTarget);

    try {
      const payload = await apiRequest('/api/login/', {
        method: 'POST',
        body: JSON.stringify({
          username: String(form.get('username') || '').trim(),
          password: String(form.get('password') || ''),
        }),
      });

      // À la première connexion, le mot de passe doit être changé avant
      // d'accéder au reste de l'application. Sinon : le premier écran que
      // son rôle autorise réellement — la surveillance était imposée à
      // tous, y compris aux rôles qui n'y ont pas accès.
      window.location.assign(
        payload.user?.first_login ? '/profile/' : homeHref(payload.user),
      );
    } catch (err) {
      setError(
        err.status === 401
          ? "Nom d'utilisateur ou mot de passe incorrect."
          : err.message || 'La connexion a échoué.',
      );
      setBusy(false);
    }
  }

  async function onReset(event) {
    event.preventDefault();
    setError('');
    setBusy(true);
    const form = new FormData(event.currentTarget);

    try {
      await apiRequest('/password-reset/', {
        method: 'POST',
        body: JSON.stringify({ email: String(form.get('email') || '').trim() }),
      });
    } catch {
      /* La réponse est volontairement neutre : ne pas révéler si l'adresse existe. */
    }
    setNotice(
      "Si un compte correspond à cette adresse, un lien de réinitialisation vient d'être envoyé.",
    );
    setBusy(false);
  }

  const field =
    'mt-1.5 w-full rounded-lg border border-line bg-surface px-3 py-2.5 text-sm text-body ' +
    'placeholder:text-body-faint focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/30';

  return (
    <div className="grid min-h-screen lg:grid-cols-[1fr_1.1fr]">
      <aside className="relative hidden flex-col justify-between bg-brand-900 p-12 lg:flex">
        <Link href="/" className="flex items-center gap-2.5">
          <span className="grid h-8 w-8 place-items-center rounded-lg bg-white/10 text-white">
            <Icon name="activity" />
          </span>
          <span className="font-serif text-[17px] font-semibold tracking-tight text-white">
            Dialyse&nbsp;Manager
          </span>
        </Link>

        <div className="max-w-sm">
          <p className="font-serif text-[1.7rem] leading-snug text-white">
            La surveillance de l&apos;unité, sur un seul écran.
          </p>
          <p className="mt-4 text-[15px] leading-relaxed text-brand-100">
            Paramètres relevés en continu, alertes dès qu&apos;un seuil est dépassé,
            dossier de séance constitué au fil de l&apos;eau.
          </p>
        </div>

        <p className="text-xs text-brand-200">Accès réservé au personnel de l&apos;unité.</p>
      </aside>

      <main className="flex flex-col px-5 py-8 sm:px-10">
        <div className="flex items-center justify-between lg:justify-end">
          <Link href="/" className="flex items-center gap-2.5 lg:hidden">
            <span className="grid h-8 w-8 place-items-center rounded-lg bg-brand-700 text-white">
              <Icon name="activity" />
            </span>
            <span className="font-serif text-[17px] font-semibold tracking-tight">
              Dialyse&nbsp;Manager
            </span>
          </Link>
          <ThemeToggleStandalone />
        </div>

        <div className="mx-auto flex w-full max-w-sm flex-1 flex-col justify-center py-10">
          {mode === 'login' ? (
            <>
              <h1 className="font-serif text-[1.6rem] leading-snug tracking-tight text-body">Connexion</h1>
              <p className="mt-2 text-sm leading-relaxed text-body-soft">
                Utilisez le compte fourni par l&apos;administrateur de votre service.
              </p>

              {error && (
                <div
                  role="alert"
                  className="mt-6 flex items-start gap-2.5 rounded-lg border border-critical/30 bg-critical-soft p-3.5 text-sm text-body"
                >
                  <span className="mt-0.5 shrink-0 text-critical">
                    <Icon name="alert-circle" className="h-4 w-4" />
                  </span>
                  <span>{error}</span>
                </div>
              )}

              <form onSubmit={onLogin} className="mt-7 space-y-5">
                <div>
                  <label htmlFor="username" className="block text-sm font-medium text-body">
                    Nom d&apos;utilisateur
                  </label>
                  <input id="username" name="username" type="text" required autoFocus
                         autoComplete="username" className={field} />
                </div>

                <div>
                  <div className="flex items-baseline justify-between">
                    <label htmlFor="password" className="block text-sm font-medium text-body">
                      Mot de passe
                    </label>
                    <button type="button" onClick={() => { setMode('reset'); setError(''); }}
                            className="text-xs text-brand-600 hover:underline dark:text-brand-400">
                      Mot de passe oublié&nbsp;?
                    </button>
                  </div>
                  <input id="password" name="password" type="password" required
                         autoComplete="current-password" className={field} />
                </div>

                <button type="submit" disabled={busy}
                        className="w-full rounded-lg bg-brand-700 px-4 py-2.5 text-sm font-medium text-white
                                   hover:bg-brand-800 focus:outline-none focus:ring-2 focus:ring-brand-500/40
                                   disabled:opacity-60">
                  {busy ? 'Connexion…' : 'Se connecter'}
                </button>

                <p className="text-xs leading-relaxed text-body-faint">
                  À la première connexion, vous devrez choisir un nouveau mot de passe
                  avant d&apos;accéder au système.
                </p>
              </form>
            </>
          ) : (
            <>
              <h2 className="font-serif text-[1.45rem] leading-snug tracking-tight text-body">
                Réinitialiser le mot de passe
              </h2>
              <p className="mt-2 text-sm leading-relaxed text-body-soft">
                Indiquez l&apos;adresse e-mail de votre compte. Vous recevrez un lien
                valable trente minutes.
              </p>

              {notice && (
                <div className="mt-6 rounded-lg border border-line bg-surface-sunken p-3.5 text-sm text-body">
                  {notice}
                </div>
              )}

              <form onSubmit={onReset} className="mt-7 space-y-5">
                <div>
                  <label htmlFor="email" className="block text-sm font-medium text-body">
                    Adresse e-mail
                  </label>
                  <input id="email" name="email" type="email" required autoComplete="email"
                         placeholder="prenom.nom@exemple.fr" className={field} />
                </div>

                <button type="submit" disabled={busy}
                        className="w-full rounded-lg bg-brand-700 px-4 py-2.5 text-sm font-medium text-white
                                   hover:bg-brand-800 disabled:opacity-60">
                  {busy ? 'Envoi…' : 'Envoyer le lien'}
                </button>

                <button type="button" onClick={() => { setMode('login'); setNotice(''); }}
                        className="w-full text-center text-sm text-body-soft hover:text-body">
                  Retour à la connexion
                </button>
              </form>
            </>
          )}
        </div>

        <p className="mx-auto w-full max-w-sm text-xs text-body-faint">
          <Link href="/" className="hover:text-body-soft">← Retour à l&apos;accueil</Link>
        </p>
      </main>
    </div>
  );
}
