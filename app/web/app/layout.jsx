import './globals.css';

export const metadata = {
  title: 'Dialyse Manager',
  description:
    "Dialyse Manager relève en continu les paramètres de chaque générateur, signale un écart dès qu'il apparaît et constitue le dossier de séance.",
};

// Applique le thème avant le premier rendu : sans cela, une page sombre
// clignote en clair le temps que React s'hydrate.
const themeScript = `(function(){try{var t=localStorage.getItem("theme");if(!t){t=window.matchMedia("(prefers-color-scheme: dark)").matches?"dark":"light";}if(t==="dark"){document.documentElement.classList.add("dark");}}catch(e){}})();`;

export default function RootLayout({ children }) {
  return (
    <html lang="fr" className="h-full" suppressHydrationWarning>
      <head>
        <meta name="color-scheme" content="light dark" />
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=Source+Serif+4:opsz,wght@8..60,400;8..60,600&display=swap"
        />
      </head>
      <body className="min-h-full bg-canvas text-body antialiased">{children}</body>
    </html>
  );
}
