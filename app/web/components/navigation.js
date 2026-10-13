/* Définition de la navigation, reprise de core/navigation.py côté Django.
   Une entrée n'est affichée que si l'utilisateur possède la capacité associée,
   afin de ne jamais proposer un lien menant à un refus d'accès.

   Les `href` sont les URL réellement servies, et non les URL françaises
   visées à terme : côté Django la barre latérale passe par reverse(), elle
   ne pouvait donc pas se tromper, alors que cette copie pointait vers
   /surveillance/, /alertes/, /infirmiers/… qu'aucune route ne sert — sept
   des dix liens répondaient 404 pour tous les rôles.
   `external: true` marque un écran encore rendu par Django : <Link> fait
   une navigation côté client, qui ne peut pas aboutir hors des routes Next. */

export const NAV = [
  {
    group: 'Soins',
    items: [
      { label: 'Tableau de bord', href: '/monitoring/dashboard/', icon: 'layout-dashboard', cap: 'canViewAdminDashboard' },
      { label: 'Surveillance', clinical: true, href: '/monitoring/surveillance/', icon: 'monitor-heart', cap: null },
      { label: 'Alertes', clinical: true, href: '/monitoring/alerts-history/', external: true, icon: 'alert-triangle', cap: null },
      { label: 'Séances', clinical: true, href: '/seances/', external: true, icon: 'calendar', cap: null },
      { label: 'Historique des séances', clinical: true, href: '/monitoring/seances-history/', external: true, icon: 'clock', cap: null },
    ],
  },
  {
    group: 'Référentiel',
    items: [
      { label: 'Patients', clinical: true, href: '/patients/', icon: 'users', cap: null },
      { label: 'Machines', href: '/machines/', icon: 'waves', cap: 'canManageMachines' },
      { label: 'Appareils de lecture', href: '/machines/raspi/', external: true, icon: 'camera', cap: 'canManageDevices' },
    ],
  },
  {
    group: 'Personnel',
    items: [
      { label: 'Docteurs', href: '/docteurs/', icon: 'stethoscope', cap: 'canManageDoctors' },
      { label: 'Infirmiers', href: '/nurses/', icon: 'user', cap: 'canManageNurses' },
    ],
  },
];

const ADMIN = 'admin';
const DOCTEUR = 'docteur';
const INFIRMIER = 'infirmier';
// Le technicien entretient le parc et ne voit aucune donnée patient.
const TECHNICIEN = 'technicien';

/** Capacités dérivées du rôle, insensibles à la casse comme côté Django. */
export function capabilities(user) {
  const slug = (user?.role || '').trim().toLowerCase();
  const isAdmin = slug === ADMIN;
  const isDocteur = slug === DOCTEUR;
  const isInfirmier = slug === INFIRMIER;
  const isTechnicien = slug === TECHNICIEN;

  return {
    slug,
    roleLabel: slug ? slug.charAt(0).toUpperCase() + slug.slice(1) : 'Utilisateur',
    isAdmin,
    isDocteur,
    isInfirmier,
    isTechnicien,
    // Un rôle hors de ceux-là n'est reconnu par aucune vue.
    isKnownRole: [ADMIN, DOCTEUR, INFIRMIER, TECHNICIEN].includes(slug),
    canViewAdminDashboard: isAdmin,
    canManageDevices: isAdmin || isTechnicien,
    // Capacités énumérées et non écrites en négatif : `!isInfirmier` aurait
    // accordé au technicien la gestion du personnel soignant.
    canManageMachines: isAdmin || isInfirmier || isTechnicien,
    canManageDoctors: isAdmin,
    canManageNurses: isAdmin || isDocteur,
    canAddMachine: isAdmin || isTechnicien,
    canAddStaff: isAdmin,
    canCreateSession: isAdmin || isDocteur,
    // Surveillance, alertes, séances, patients : le soin.
    canViewClinical: isAdmin || isDocteur || isInfirmier,
  };
}

export function navFor(user) {
  const caps = capabilities(user);
  if (!caps.isKnownRole) return [];

  return NAV.map((group) => ({
    group: group.group,
    items: group.items.filter(
      (item) => (!item.cap || caps[item.cap]) && (!item.clinical || caps.canViewClinical),
    ),
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
  [/^\/monitoring\/surveillance/, 'canViewClinical'],
  [/^\/monitoring\/alerts-history/, 'canViewClinical'],
  [/^\/monitoring\/seances-history/, 'canViewClinical'],
  [/^\/seances/, 'canViewClinical'],
  [/^\/patients/, 'canViewClinical'],
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

/** Premier écran accessible à cet utilisateur.
 *
 *  La connexion renvoyait tout le monde vers la surveillance, y compris les
 *  rôles qui n'y ont pas accès : le technicien se connectait pour atterrir
 *  sur un refus d'accès. */
export function homeHref(user) {
  const groups = navFor(user);
  return groups[0]?.items[0]?.href || '/profile/';
}
