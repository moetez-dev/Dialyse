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
