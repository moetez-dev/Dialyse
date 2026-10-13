const djangoOrigin = process.env.DJANGO_API_ORIGIN || 'http://127.0.0.1:8000';

/** @type {import('next').NextConfig} */
const nextConfig = {
  async rewrites() {
    return {
      beforeFiles: [
        {
          source: '/api/:path*',
          destination: `${djangoOrigin}/api/:path*`,
        },
        {
          source: '/media/:path*',
          destination: `${djangoOrigin}/media/:path*`,
        },
      ],
      fallback: [
        {
          source: '/:path*',
          destination: `${djangoOrigin}/:path*`,
        },
      ],
    };
  },
};

module.exports = nextConfig;
