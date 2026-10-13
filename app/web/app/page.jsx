import Link from 'next/link';

export default function HomePage() {
  return (
    <main className="landing-page">
      <section className="landing-card">
        <div className="brand-mark" aria-hidden="true">D</div>
        <p className="eyebrow">PLATEFORME DE SUPERVISION</p>
        <h1>Dialyse Manager</h1>
        <p className="landing-copy">
          Suivez les séances, les générateurs et les paramètres en temps réel
          depuis un espace de travail sécurisé.
        </p>
        <div className="landing-actions">
          <Link className="button button-primary" href="/connexion">Se connecter</Link>
          <Link className="button button-secondary" href="/monitoring/surveillance">Ouvrir la surveillance</Link>
        </div>
        <div className="landing-status"><span /> API Django connectée via le même domaine</div>
      </section>
    </main>
  );
}
