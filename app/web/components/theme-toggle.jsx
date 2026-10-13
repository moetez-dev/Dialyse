'use client';

import { useEffect, useState } from 'react';

import { Icon } from './icons';

/** Bascule clair/sombre pour les pages hors espace de travail. */
export function ThemeToggleStandalone() {
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
      /* navigation privée : le choix ne survivra pas au rechargement */
    }
    setDark(next);
  }

  return (
    <button
      type="button"
      onClick={toggle}
      aria-label="Changer de thème"
      className="grid h-9 w-9 place-items-center rounded-lg border border-line text-body-soft hover:bg-surface-sunken hover:text-body"
    >
      <Icon name={dark ? 'sun' : 'moon'} />
    </button>
  );
}
