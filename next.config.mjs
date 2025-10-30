/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  reactStrictMode: true,
  images: { unoptimized: true },
  experimental: { appDir: true },
  i18n: {
    locales: ['en', 'zh'],
    defaultLocale: 'zh',
    localeDetection: false
  },
  webpack: (config) => {
    config.resolve.fallback = { ...config.resolve.fallback, fs: false, net: false, tls: false };
    config.resolve.alias = {
      ...config.resolve.alias,
      'pino-pretty': false,
      '@react-native-async-storage/async-storage': false
    };
    return config;
  }
};
export default nextConfig;
