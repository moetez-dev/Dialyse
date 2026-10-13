const djangoOrigin = process.env.DJANGO_API_ORIGIN || 'http://127.0.0.1:8000';

/** @type {import('next').NextConfig} */
const nextConfig = {
  // Django sert ses URL avec une barre oblique finale et renvoie une 301 quand
  // elle manque (APPEND_SLASH). Les réécritures de Next suppriment cette barre
  // en capturant :path*, ce qui provoquait une boucle de redirection sur /api/.
  // Conserver la barre aligne les deux interfaces sur la même convention.
  trailingSlash: true,

  async rewrites() {
    return {
      beforeFiles: [
        // La variante avec barre finale doit précéder l'autre : `:path*` ne
        // capture pas la barre, et Django redirige (301) toute URL qui en
        // manque, ce qui bouclait sur /api/.
        { source: '/api/:path*/', destination: `${djangoOrigin}/api/:path*/` },
        { source: '/api/:path*', destination: `${djangoOrigin}/api/:path*` },
        { source: '/media/:path*', destination: `${djangoOrigin}/media/:path*` },
      ],
      // Tout ce que Next ne sert pas encore reste rendu par Django : la
      // migration peut donc se faire écran par écran sans rien casser.
      fallback: [
        { source: '/:path*/', destination: `${djangoOrigin}/:path*/` },
        { source: '/:path*', destination: `${djangoOrigin}/:path*` },
      ],
    };
  },
};

module.exports = nextConfig;
