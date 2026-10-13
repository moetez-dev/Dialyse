import Link from 'next/link';

import { Icon } from '../components/icons';
import { ThemeToggleStandalone } from '../components/theme-toggle';

const PARAMETRES = [
  ['Débit sang', 'Qb', "Le débit de la pompe. Une baisse signale souvent un problème d'abord vasculaire."],
  ['Pression artérielle', 'PA', "Pression à l'aspiration. Une valeur trop négative traduit une aiguille mal positionnée."],
  ['Pression veineuse', 'PV', 'Pression au retour. Sa montée accompagne une coagulation du circuit.'],
  ['Pression transmembranaire', 'PTM', "L'indicateur de l'état du dialyseur. Sa dérive annonce un encrassement."],
  ['Ultrafiltration', 'UF', "Volume soustrait et débit de soustraction, suivis par rapport à l'objectif de séance."],
  ['Héparine', null, "Débit d'anticoagulation, tracé avec le reste de la séance."],
];

const LECTURE = [
  ['Capture', "Le boîtier photographie l'écran du générateur toutes les 20 à 60 secondes."],
  ['Lecture', 'Un modèle de vision extrait les six paramètres affichés.'],
  ['Vérification', 'Toute valeur hors limites physiologiques est écartée plutôt que devinée.'],
  ['Enregistrement', "La mesure rejoint la séance, avec la photo d'origine en justificatif."],
];

const DEROULE = [
  ['Avant la séance', "Poids d'entrée, tension, objectif d'ultrafiltration, durée et seuils propres au patient. Le poste et le générateur sont affectés depuis le planning."],
  ['Pendant la séance', "Les paramètres arrivent en continu sur l'écran de surveillance. L'équipe voit l'ensemble des postes et traite les alertes à mesure."],
  ['À la fin', "Poids de sortie, perte réelle, incidents et observations. L'écart avec l'objectif d'ultrafiltration est calculé."],
  ['Le compte rendu', 'Courbes des paramètres, alertes survenues et données de séance, rassemblées dans un rapport imprimable versé au dossier du patient.'],
];

const POSTES = [
  { nom: 'Poste 1', patient: 'M. Khelifi — 2 h 40 restantes', etat: 'Stable', tone: 'stable',
    valeurs: [['Qb', '300'], ['PA', '−120'], ['PV', '140'], ['PTM', '165'], ['UF', '1 420'], ['Hép.', '2,5']] },
  { nom: 'Poste 2', patient: 'Mme Brahmi — 1 h 05 restantes', etat: 'PTM élevée', tone: 'critical', alerte: 'PTM',
    valeurs: [['Qb', '280'], ['PA', '−145'], ['PV', '178'], ['PTM', '252'], ['UF', '2 050'], ['Hép.', '3,0']] },
  { nom: 'Poste 3', patient: 'M. Saïdi — 3 h 15 restantes', etat: 'Stable', tone: 'stable',
    valeurs: [['Qb', '320'], ['PA', '−98'], ['PV', '132'], ['PTM', '148'], ['UF', '640'], ['Hép.', '2,0']] },
  { nom: 'Poste 4', patient: 'Mme Ferchichi — 0 h 20 restantes', etat: 'À surveiller', tone: 'warning', alerte: 'PA',
    valeurs: [['Qb', '250'], ['PA', '−168'], ['PV', '155'], ['PTM', '190'], ['UF', '2 780'], ['Hép.', '2,5']] },
];

const TONE_RING = {
  stable: 'border-line',
  warning: 'border-warning/40',
  critical: 'border-critical/40 ring-1 ring-critical/15',
};

const TONE_PILL = {
  stable: 'bg-stable-soft text-stable',
  warning: 'bg-warning-soft text-warning',
  critical: 'bg-critical-soft text-critical',
};

const TONE_VALUE = { warning: 'font-semibold text-warning', critical: 'font-semibold text-critical' };

export default function HomePage() {
  return (
    <>
      <header className="sticky top-0 z-40 border-b border-line bg-surface/90 backdrop-blur">
        <div className="mx-auto flex h-14 max-w-6xl items-center gap-4 px-5">
          <Link href="/" className="flex items-center gap-2.5">
            <span className="grid h-8 w-8 place-items-center rounded-lg bg-brand-700 text-white">
              <Icon name="activity" />
            </span>
            <span className="font-serif text-[17px] font-semibold tracking-tight text-body">
              Dialyse&nbsp;Manager
            </span>
          </Link>

          <nav className="ml-auto hidden items-center gap-7 text-sm text-body-soft md:flex">
            <a href="#surveillance" className="hover:text-body">Surveillance</a>
            <a href="#alertes" className="hover:text-body">Alertes</a>
            <a href="#lecture" className="hover:text-body">Lecture des écrans</a>
            <a href="#seance" className="hover:text-body">Déroulé d&apos;une séance</a>
          </nav>

          <div className="ml-auto md:ml-0"><ThemeToggleStandalone /></div>

          <Link
            href="/connexion"
            className="rounded-lg bg-brand-700 px-4 py-2 text-sm font-medium text-white hover:bg-brand-800"
          >
            Se connecter
          </Link>
        </div>
      </header>

      {/* ───────────── hero ───────────── */}
      <section className="border-b border-line bg-surface">
        <div className="mx-auto grid max-w-6xl gap-14 px-5 py-16 lg:grid-cols-[1fr_1.05fr] lg:items-center lg:py-24">
          <div className="max-w-xl">
            <h1 className="font-serif text-[2.1rem] leading-[1.12] tracking-tight text-body sm:text-[2.9rem]">
              Surveiller douze postes sans quitter le chevet du patient.
            </h1>
            <p className="mt-6 text-[17px] leading-relaxed text-body-soft">
              Dialyse Manager relève en continu les paramètres de chaque générateur,
              signale un écart dès qu&apos;il apparaît, et constitue le dossier de séance
              pendant que vous soignez.
            </p>
            <div className="mt-9 flex flex-wrap items-center gap-3">
              <Link
                href="/connexion"
                className="rounded-lg bg-brand-700 px-5 py-2.5 text-sm font-medium text-white hover:bg-brand-800"
              >
                Se connecter
              </Link>
              <a
                href="#surveillance"
                className="rounded-lg border border-line px-5 py-2.5 text-sm font-medium text-body hover:bg-surface-sunken"
              >
                Comment ça fonctionne
              </a>
            </div>
            <p className="mt-7 max-w-md text-sm leading-relaxed text-body-faint">
              Conçu pour les unités d&apos;hémodialyse : un poste de surveillance partagé
              par l&apos;équipe soignante, alimenté directement par les générateurs.
            </p>
          </div>

          <div className="rounded-card border border-line bg-canvas p-4 shadow-sm sm:p-5">
            <div className="mb-4 flex items-center justify-between px-1">
              <div className="flex items-center gap-2 text-sm font-medium text-body">
                <span className="relative flex h-2 w-2">
                  <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-stable opacity-60 motion-reduce:hidden" />
                  <span className="relative inline-flex h-2 w-2 rounded-full bg-stable" />
                </span>
                Salle A — 4 postes actifs
              </div>
              <span className="text-xs tabular-nums text-body-faint">mise à jour il y a 2&nbsp;s</span>
            </div>

            <div className="grid gap-3 sm:grid-cols-2">
              {POSTES.map((poste) => (
                <article key={poste.nom} className={`rounded-lg border bg-surface p-4 ${TONE_RING[poste.tone]}`}>
                  <div className="flex items-baseline justify-between">
                    <span className="font-medium text-body">{poste.nom}</span>
                    <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${TONE_PILL[poste.tone]}`}>
                      {poste.etat}
                    </span>
                  </div>
                  <p className="mt-0.5 text-xs text-body-faint">{poste.patient}</p>
                  <dl className="mt-3 grid grid-cols-3 gap-y-2 text-sm tabular-nums">
                    {poste.valeurs.map(([cle, valeur]) => (
                      <div key={cle}>
                        <dt className="text-xs text-body-faint">{cle}</dt>
                        <dd className={poste.alerte === cle ? TONE_VALUE[poste.tone] : 'text-body'}>{valeur}</dd>
                      </div>
                    ))}
                  </dl>
                </article>
              ))}
            </div>

            <p className="mt-4 px-1 text-xs text-body-faint">
              Exemple de l&apos;écran de surveillance. Les valeurs proviennent des générateurs.
            </p>
          </div>
        </div>
      </section>

      {/* ───────────── le constat ───────────── */}
      <section className="border-b border-line">
        <div className="mx-auto max-w-6xl px-5 py-16 lg:py-20">
          <div className="grid gap-10 lg:grid-cols-[0.9fr_1.1fr] lg:gap-16">
            <h2 className="font-serif text-[1.65rem] leading-snug tracking-tight text-body sm:text-[2rem]">
              Entre deux relevés, une unité fonctionne à l&apos;aveugle.
            </h2>
            <div className="space-y-5 text-[15.5px] leading-relaxed text-body-soft">
              <p>
                Les paramètres sont notés toutes les trente minutes, à la main, sur une
                feuille par patient. Entre deux passages, une chute de pression
                artérielle ou une montée de PTM n&apos;est vue qu&apos;au relevé suivant.
              </p>
              <p>
                Les feuilles sont ensuite retranscrites dans le dossier. Le temps passé
                à recopier est du temps pris sur la surveillance, et chaque
                retranscription est une occasion d&apos;erreur.
              </p>
              <p className="text-body">
                Dialyse Manager supprime le relevé manuel : les valeurs arrivent seules,
                en continu, et le dossier se remplit au fil de la séance.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ───────────── surveillance ───────────── */}
      <section id="surveillance" className="scroll-mt-16 border-b border-line bg-surface">
        <div className="mx-auto max-w-6xl px-5 py-16 lg:py-20">
          <h2 className="max-w-2xl font-serif text-[1.65rem] leading-snug tracking-tight text-body sm:text-[2rem]">
            Les six paramètres qui comptent, relevés en continu
          </h2>
          <p className="mt-4 max-w-2xl text-[15.5px] leading-relaxed text-body-soft">
            Chaque poste remonte ses valeurs toutes les vingt à soixante secondes,
            selon le rythme configuré pour la séance. Les valeurs hors limites
            physiologiques sont écartées avant d&apos;entrer au dossier.
          </p>

          <dl className="mt-10 grid gap-x-10 gap-y-7 sm:grid-cols-2 lg:grid-cols-3">
            {PARAMETRES.map(([nom, sigle, description]) => (
              <div key={nom} className="border-t border-line pt-4">
                <dt className="font-medium text-body">
                  {nom} {sigle && <span className="text-body-faint">({sigle})</span>}
                </dt>
                <dd className="mt-1.5 text-sm leading-relaxed text-body-soft">{description}</dd>
              </div>
            ))}
          </dl>
        </div>
      </section>

      {/* ───────────── alertes ───────────── */}
      <section id="alertes" className="scroll-mt-16 border-b border-line">
        <div className="mx-auto grid max-w-6xl gap-12 px-5 py-16 lg:grid-cols-2 lg:items-start lg:gap-16 lg:py-20">
          <div>
            <h2 className="font-serif text-[1.65rem] leading-snug tracking-tight text-body sm:text-[2rem]">
              Une alerte quand c&apos;est utile, pas à chaque mesure
            </h2>
            <div className="mt-5 space-y-5 text-[15.5px] leading-relaxed text-body-soft">
              <p>
                Les seuils sont définis séance par séance, pas une fois pour toute
                l&apos;unité : la pression veineuse acceptable d&apos;un patient ne l&apos;est pas
                forcément pour son voisin.
              </p>
              <p>
                Quand un paramètre sort de ses limites, l&apos;alerte est levée une fois,
                puis mise en sourdine quinze minutes pour ce même paramètre. Une
                dérive lente ne produit pas cinquante notifications identiques.
              </p>
              <p>
                Chaque alerte est acquittée puis résolue par un soignant identifié,
                et reste consultable dans l&apos;historique de la séance.
              </p>
            </div>
          </div>

          <div className="rounded-card border border-line bg-surface p-5">
            <p className="mb-4 text-sm font-medium text-body">Fil d&apos;alertes</p>
            <ul className="space-y-3">
              <li className="flex gap-3 rounded-lg border border-critical/30 bg-critical-soft/60 p-3.5">
                <span className="mt-0.5 text-critical"><Icon name="alert-triangle" className="h-4 w-4" /></span>
                <div className="min-w-0">
                  <p className="text-sm font-medium text-body">PTM à 252 mmHg — Poste 2</p>
                  <p className="mt-0.5 text-xs text-body-soft">Au-dessus du seuil critique de 240. Vérifier le dialyseur.</p>
                  <p className="mt-1.5 text-xs tabular-nums text-body-faint">il y a 40 s · non acquittée</p>
                </div>
              </li>
              <li className="flex gap-3 rounded-lg border border-warning/30 bg-warning-soft/60 p-3.5">
                <span className="mt-0.5 text-warning"><Icon name="alert-circle" className="h-4 w-4" /></span>
                <div className="min-w-0">
                  <p className="text-sm font-medium text-body">PA à −168 mmHg — Poste 4</p>
                  <p className="mt-0.5 text-xs text-body-soft">Approche du seuil. Contrôler la position de l&apos;aiguille.</p>
                  <p className="mt-1.5 text-xs tabular-nums text-body-faint">il y a 6 min · acquittée</p>
                </div>
              </li>
              <li className="flex gap-3 rounded-lg border border-line p-3.5">
                <span className="mt-0.5 text-stable"><Icon name="check" className="h-4 w-4" /></span>
                <div className="min-w-0">
                  <p className="text-sm font-medium text-body">Débit sang rétabli — Poste 1</p>
                  <p className="mt-0.5 text-xs text-body-soft">Retour dans les limites après repositionnement.</p>
                  <p className="mt-1.5 text-xs tabular-nums text-body-faint">il y a 22 min · résolue</p>
                </div>
              </li>
            </ul>
          </div>
        </div>
      </section>

      {/* ───────────── lecture des écrans ───────────── */}
      <section id="lecture" className="scroll-mt-16 border-b border-line bg-surface">
        <div className="mx-auto max-w-6xl px-5 py-16 lg:py-20">
          <h2 className="max-w-2xl font-serif text-[1.65rem] leading-snug tracking-tight text-body sm:text-[2rem]">
            Les générateurs n&apos;ont pas besoin d&apos;être connectés
          </h2>
          <p className="mt-4 max-w-2xl text-[15.5px] leading-relaxed text-body-soft">
            Un boîtier placé devant la machine photographie son écran à intervalle
            régulier. Les valeurs sont lues sur l&apos;image, vérifiées, puis enregistrées.
            Aucune modification du générateur, aucun remplacement de parc.
          </p>

          <ol className="mt-10 grid gap-8 md:grid-cols-4">
            {LECTURE.map(([titre, description], index) => (
              <li key={titre}>
                <span className="font-serif text-2xl tabular-nums text-brand-600">{index + 1}</span>
                <h3 className="mt-1.5 font-medium text-body">{titre}</h3>
                <p className="mt-1.5 text-sm leading-relaxed text-body-soft">{description}</p>
              </li>
            ))}
          </ol>

          <p className="mt-9 max-w-2xl rounded-lg border border-line bg-canvas p-4 text-sm leading-relaxed text-body-soft">
            Une valeur douteuse n&apos;est jamais inventée : elle est laissée vide et
            signalée comme telle. Le dossier distingue toujours ce qui a été lu de ce
            qui ne l&apos;a pas été.
          </p>
        </div>
      </section>

      {/* ───────────── déroulé ───────────── */}
      <section id="seance" className="scroll-mt-16 border-b border-line">
        <div className="mx-auto max-w-6xl px-5 py-16 lg:py-20">
          <h2 className="max-w-2xl font-serif text-[1.65rem] leading-snug tracking-tight text-body sm:text-[2rem]">
            Du branchement au compte rendu
          </h2>
          <ol className="mt-10 overflow-hidden rounded-card border border-line">
            {DEROULE.map(([titre, description], index) => (
              <li
                key={titre}
                className={`grid gap-2 bg-surface p-5 sm:grid-cols-[13rem_1fr] sm:gap-8 ${
                  index > 0 ? 'border-t border-line' : ''
                }`}
              >
                <h3 className="font-medium text-body">{titre}</h3>
                <p className="text-sm leading-relaxed text-body-soft">{description}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      {/* ───────────── pour qui ───────────── */}
      <section className="border-b border-line bg-surface">
        <div className="mx-auto max-w-6xl px-5 py-16 lg:py-20">
          <h2 className="font-serif text-[1.65rem] leading-snug tracking-tight text-body sm:text-[2rem]">
            Trois usages, un même dossier
          </h2>
          <div className="mt-9 grid gap-x-10 gap-y-8 md:grid-cols-3">
            {[
              ['Infirmiers', "L'état de tous les postes sur un écran, les alertes à traiter en tête de liste, et plus de feuille à recopier en fin de poste."],
              ['Néphrologues', "L'historique complet d'un patient, séance par séance, avec les courbes et les incidents, consultable sans ressortir les feuilles papier."],
              ['Encadrement', "L'occupation des postes, l'état du parc de générateurs et l'activité de l'équipe, suivis au jour le jour."],
            ].map(([titre, texte]) => (
              <div key={titre} className="border-t-2 border-brand-600 pt-4">
                <h3 className="font-medium text-body">{titre}</h3>
                <p className="mt-2 text-sm leading-relaxed text-body-soft">{texte}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ───────────── accès ───────────── */}
      <section className="border-b border-line">
        <div className="mx-auto max-w-6xl px-5 py-16 lg:py-20">
          <div className="rounded-card border border-line bg-brand-900 px-6 py-12 text-center sm:px-12">
            <h2 className="mx-auto max-w-xl font-serif text-[1.6rem] leading-snug tracking-tight text-white sm:text-[1.9rem]">
              Votre unité est déjà configurée&nbsp;?
            </h2>
            <p className="mx-auto mt-4 max-w-md text-[15px] leading-relaxed text-brand-100">
              Connectez-vous avec le compte fourni par l&apos;administrateur de votre
              service. Les comptes sont créés en interne, il n&apos;y a pas d&apos;inscription.
            </p>
            <Link
              href="/connexion"
              className="mt-7 inline-block rounded-lg bg-white px-6 py-2.5 text-sm font-medium text-brand-900 hover:bg-brand-50"
            >
              Se connecter
            </Link>
          </div>
        </div>
      </section>

      <footer className="bg-surface">
        <div className="mx-auto flex max-w-6xl flex-col gap-4 px-5 py-9 text-sm text-body-faint sm:flex-row sm:items-center">
          <div className="flex items-center gap-2.5">
            <span className="grid h-7 w-7 place-items-center rounded-md bg-brand-700 text-white">
              <Icon name="activity" className="h-4 w-4" />
            </span>
            <span className="font-medium text-body-soft">Dialyse Manager</span>
          </div>
          <p className="sm:ml-auto">Système de surveillance des séances d&apos;hémodialyse.</p>
        </div>
      </footer>
    </>
  );
}
