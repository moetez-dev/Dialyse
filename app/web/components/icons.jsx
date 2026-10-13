/* Jeu d'icônes de l'interface, repris du tag {% icon %} des pages Django pour
   que les deux interfaces montrent exactement les mêmes pictogrammes. */

const paths = {
  activity: <path d="M13 10V3L4 14h7v7l9-11h-7z" />,
  'layout-dashboard': (
    <>
      <rect x="3" y="3" width="7" height="9" rx="1.5" />
      <rect x="14" y="3" width="7" height="5" rx="1.5" />
      <rect x="14" y="12" width="7" height="9" rx="1.5" />
      <rect x="3" y="16" width="7" height="5" rx="1.5" />
    </>
  ),
  'monitor-heart': (
    <>
      <rect x="2" y="4" width="20" height="13" rx="2" />
      <path d="M6 11h3l1.5-2.5L13 14l1.5-3H18" />
      <path d="M9 21h6M12 17v4" />
    </>
  ),
  'alert-triangle': (
    <>
      <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
      <path d="M12 9v4M12 17h.01" />
    </>
  ),
  'alert-circle': (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 8v5M12 16h.01" />
    </>
  ),
  calendar: (
    <>
      <rect x="3" y="5" width="18" height="16" rx="2" />
      <path d="M3 10h18M8 3v4M16 3v4" />
    </>
  ),
  clock: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7v5l3 2" />
    </>
  ),
  users: (
    <>
      <path d="M16 20v-1a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v1" />
      <circle cx="9" cy="7" r="4" />
      <path d="M22 20v-1a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" />
    </>
  ),
  user: (
    <>
      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
      <circle cx="12" cy="7" r="4" />
    </>
  ),
  waves: (
    <path d="M2 7c1.5 0 1.5 1.5 3 1.5S6.5 7 8 7s1.5 1.5 3 1.5S12.5 7 14 7s1.5 1.5 3 1.5S18.5 7 20 7M2 12c1.5 0 1.5 1.5 3 1.5S6.5 12 8 12s1.5 1.5 3 1.5S12.5 12 14 12s1.5 1.5 3 1.5S18.5 12 20 12M2 17c1.5 0 1.5 1.5 3 1.5S6.5 17 8 17s1.5 1.5 3 1.5S12.5 17 14 17s1.5 1.5 3 1.5S18.5 17 20 17" />
  ),
  camera: (
    <>
      <rect x="2" y="7" width="20" height="14" rx="2" />
      <path d="M16.5 7l-.94-1.88A2 2 0 0 0 13.76 4h-3.52a2 2 0 0 0-1.8 1.12L7.5 7" />
      <circle cx="12" cy="14" r="3.5" />
    </>
  ),
  stethoscope: (
    <>
      <path d="M6 3v5a4 4 0 0 0 8 0V3" />
      <path d="M4.5 3h3M12.5 3h3" />
      <path d="M10 12v2a6 6 0 0 0 12 0v-1" />
      <circle cx="19" cy="9" r="2" />
    </>
  ),
  'log-out': (
    <>
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
      <path d="M16 17l5-5-5-5M21 12H9" />
    </>
  ),
  menu: <path d="M4 6h16M4 12h16M4 18h16" />,
  sun: (
    <>
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41" />
    </>
  ),
  moon: <path d="M21 12.79A9 9 0 1 1 11.21 3a7 7 0 0 0 9.79 9.79z" />,
  check: <path d="M20 6 9 17l-5-5" />,
  search: (
    <>
      <circle cx="11" cy="11" r="7" />
      <path d="m20 20-3.5-3.5" />
    </>
  ),
};

export function Icon({ name, className = 'h-[18px] w-[18px]' }) {
  const body = paths[name];
  if (!body) return null;
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {body}
    </svg>
  );
}
