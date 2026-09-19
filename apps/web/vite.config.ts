import { fileURLToPath } from 'node:url';
import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';
import { defineConfig } from 'vitest/config';

const here = (path: string) => fileURLToPath(new URL(path, import.meta.url));

// Where the dev server sends /v1. The web talks to the API on its own
// origin, so the refresh cookie (SameSite=Strict, path /v1/auth) works
// on a laptop exactly as it does behind the production proxy.
const apiTarget = process.env.HARVEST_API_URL ?? 'http://localhost:4000';

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    VitePWA({
      // An update waits for my say-so (W4): the toast offers a reload,
      // nothing reloads a page with a half-written note on it.
      registerType: 'prompt',
      injectRegister: false,
      includeAssets: ['favicon.svg', 'icons/apple-touch-icon.png'],
      manifest: {
        id: '/app',
        name: 'Harvest',
        short_name: 'Harvest',
        description: 'Habits, projects and to-dos as seeds on a field. Local-first.',
        start_url: '/app',
        scope: '/',
        display: 'standalone',
        theme_color: '#1F8A46',
        background_color: '#FBF4E4',
        icons: [
          { src: '/icons/icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
          { src: '/icons/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
          { src: '/icons/maskable-192.png', sizes: '192x192', type: 'image/png', purpose: 'maskable' },
          { src: '/icons/maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
          { src: '/favicon.svg', sizes: 'any', type: 'image/svg+xml', purpose: 'any' },
        ],
      },
      workbox: {
        // The shell only. Data lives in IndexedDB, and the API is never
        // cached: a stale answer from /v1 is worse than no answer.
        globPatterns: ['**/*.{js,css,html,svg,png,woff2,webmanifest}'],
        navigateFallback: '/index.html',
        navigateFallbackDenylist: [/^\/v1\//],
        runtimeCaching: [],
        cleanupOutdatedCaches: true,
      },
      devOptions: { enabled: false },
    }),
  ],
  resolve: {
    alias: {
      '@': here('./src'),
      // The shared packages are compiled from source, so the web never
      // runs against a stale build of the rules it shares with the phone.
      '@harvest/contracts': here('../../packages/contracts/src/index.ts'),
      '@harvest/core': here('../../packages/core/src/index.ts'),
    },
  },
  server: {
    port: 5173,
    strictPort: true,
    proxy: {
      '/v1': { target: apiTarget, changeOrigin: false },
    },
  },
  preview: {
    port: 4173,
    proxy: {
      '/v1': { target: apiTarget, changeOrigin: false },
    },
  },
  build: {
    target: 'es2022',
    sourcemap: true,
    rollupOptions: {
      output: {
        // React and the router change far less often than the app, so
        // they get a chunk of their own that stays cached across updates.
        manualChunks(id) {
          if (/node_modules\/(\.pnpm\/)?(react|react-dom|scheduler|react-router)[@/]/.test(id)) return 'react';
          return undefined;
        },
      },
    },
  },
  test: {
    environment: 'jsdom',
    include: ['test/**/*.test.{ts,tsx}'],
    setupFiles: ['test/setup.ts'],
    testTimeout: 30_000,
  },
});
