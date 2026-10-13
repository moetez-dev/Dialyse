import './globals.css';

export const metadata = {
  title: 'Dialyse Manager',
  description: 'Plateforme de supervision des séances et générateurs de dialyse.',
};

export default function RootLayout({ children }) {
  return (
    <html lang="fr">
      <body>{children}</body>
    </html>
  );
}
