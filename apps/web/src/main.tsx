import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { createBrowserRouter, RouterProvider } from 'react-router';
import { UpdatePrompt } from '@/components/update-prompt';
import { Toaster } from '@/components/ui/sonner';
import '@/i18n';
import './index.css';
import { listenForInstallPrompt } from '@/lib/pwa';
import { startTheme } from '@/lib/theme';
import { routes } from './router';

startTheme();
listenForInstallPrompt();

// Only the online calls go through the query cache (auth, account,
// releases); the app's data is read live from IndexedDB instead.
const queryClient = new QueryClient({
  defaultOptions: { queries: { refetchOnWindowFocus: false, retry: 1 } },
});
const router = createBrowserRouter(routes);

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
      <Toaster position="bottom-center" />
      <UpdatePrompt />
    </QueryClientProvider>
  </StrictMode>,
);
