import { LoginForm } from '../../components/login-form';

export const metadata = {
  title: 'Connexion | Dialyse Manager',
};

export default function LoginPage() {
  return (
    <main className="login-page">
      <section className="login-panel">
        <div className="brand-mark" aria-hidden="true">D</div>
        <p className="eyebrow">ESPACE DE SOINS</p>
        <h1>Connexion</h1>
        <p className="muted">Connectez-vous avec votre compte Dialyse Manager.</p>
        <LoginForm />
        <p className="login-help">Besoin d’aide ? Contactez l’administrateur de votre établissement.</p>
      </section>
      <aside className="login-aside">
        <p className="eyebrow">SUIVI CLINIQUE</p>
        <h2>Une vision claire de chaque séance.</h2>
        <p>Patients, générateurs et alertes réunis dans un espace de travail conçu pour les équipes de soins.</p>
      </aside>
    </main>
  );
}
