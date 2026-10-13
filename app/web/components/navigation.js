/* Définition de la navigation, reprise de core/navigation.py côté Django.
   Une entrée n'est affichée que si l'utilisateur possède la capacité associée,
   afin de ne jamais proposer un lien menant à un refus d'accès. */

export const NAV = [
  {
    group: 'Soins',
    items: [
      { label: 'Tableau de bord', href: '/tableau-de-bord', icon: 'layout-dashboard', cap: 'canViewAdminDashboard' },
      { label: 'Surveillance', href: '/surveillance', icon: 'monitor-heart', cap: null },
      { label: 'Alertes', href: '/alertes', icon: 'alert-triangle', cap: null },
      { label: 'Séances', href: '/seances', icon: 'calendar', cap: null },
      { label: 'Historique des séances', href: '/seances/historique', icon: 'clock', cap: null },
    ],
  },
  {
    group: 'Référentiel',
    items: [
      { label: 'Patients', href: '/patients', icon: 'users', cap: null },
      { label: 'Machines', href: '/machines', icon: 'waves', cap: 'canManageMachines' },
      { label: 'Appareils de lecture', href: '/machines/appareils', icon: 'camera', cap: 'canManageDevices' },
    ],
  },
  {
    group: 'Personnel',
    items: [
      { label: 'Docteurs', href: '/docteurs', icon: 'stethoscope', cap: 'canManageDoctors' },
      { label: 'Infirmiers', href: '/infirmiers', icon: 'user', cap: 'canManageNurses' },
    ],
  },
];

const ADMIN = 'admin';
const DOCTEUR = 'docteur';
const INFIRMIER = 'infirmier';

/** Capacités dérivées du rôle, insensibles à la casse comme côté Django. */
export function capabilities(user) {
  const slug = (user?.role || '').trim().toLowerCase();
  const isAdmin = slug === ADMIN;
  const isDocteur = slug === DOCTEUR;
  const isInfirmier = slug === INFIRMIER;

  return {
    slug,
    roleLabel: slug ? slug.charAt(0).toUpperCase() + slug.slice(1) : 'Utilisateur',
    isAdmin,
    isDocteur,
    isInfirmier,
    // Un rôle hors de ces trois-là n'est reconnu par aucune vue.
    isKnownRole: [ADMIN, DOCTEUR, INFIRMIER].includes(slug),
    canViewAdminDashboard: isAdmin,
    canManageDevices: isAdmin,
    canManageMachines: !isDocteur,
    canManageDoctors: isAdmin,
    canManageNurses: !isInfirmier,
    canAddMachine: isAdmin,
    canAddStaff: isAdmin,
    canCreateSession: isAdmin || isDocteur,
  };
}

export function navFor(user) {
  const caps = capabilities(user);
  if (!caps.isKnownRole) return [];

  return NAV.map((group) => ({
    group: group.group,
    items: group.items.filter((item) => !item.cap || caps[item.cap]),
  })).filter((group) => group.items.length > 0);
}

/* ---------------------------------------------------------------------------
 * Autorisation par route.
 *
 * Les gabarits Django étaient protégés par @role_required ; les pages React
 * servies par Next ne passent pas par ces vues. Sans cette table, n'importe
 * quel compte authentifié — y compris un rôle que l'application ne reconnaît
 * pas — pouvait ouvrir /patients, /machines, /docteurs ou le tableau de bord.
 * Les règles reprennent exactement celles des vues Django.
 * ------------------------------------------------------------------------- */
const ROUTE_CAPABILITIES = [
  [/^\/tableau-de-bord/, 'canViewAdminDashboard'],
  [/^\/monitoring\/dashboard/, 'canViewAdminDashboard'],
  [/^\/machines\/appareils/, 'canManageDevices'],
  [/^\/machines\/raspi/, 'canManageDevices'],
  [/^\/machines/, 'canManageMachines'],
  [/^\/docteurs/, 'canManageDoctors'],
  [/^\/infirmiers/, 'canManageNurses'],
  [/^\/nurses/, 'canManageNurses'],
];

/** Capacité exigée pour ce chemin, ou null si la route est ouverte à tous
 *  les rôles reconnus. */
export function routeCapability(pathname) {
  const match = ROUTE_CAPABILITIES.find(([pattern]) => pattern.test(pathname));
  return match ? match[1] : null;
}

/** L'utilisateur peut-il ouvrir ce chemin ? */
export function canAccessRoute(user, pathname) {
  const caps = capabilities(user);
  // Le profil reste accessible à tous : c'est la seule page utile à un compte
  // dont le rôle n'est associé à aucun accès.
  if (pathname.startsWith('/profil') || pathname.startsWith('/profile')) return true;
  if (!caps.isKnownRole) return false;
  const needed = routeCapability(pathname);
  return !needed || Boolean(caps[needed]);
}
