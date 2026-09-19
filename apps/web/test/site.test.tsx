import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { act, render, screen } from '@testing-library/react';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { listenForInstallPrompt } from '@/lib/pwa';
import { routes } from '@/router';
import en from '@/i18n/en.json';
import ar from '@/i18n/ar.json';

function renderAt(path: string) {
  const router = createMemoryRouter(routes, { initialEntries: [path] });
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  render(
    <QueryClientProvider client={client}>
      <RouterProvider router={router} />
    </QueryClientProvider>,
  );
  return router;
}

beforeAll(() => {
  listenForInstallPrompt();
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe('the home page', () => {
  it('says what Harvest is, and offers the app both ways', async () => {
    renderAt('/');
    expect(await screen.findByRole('heading', { level: 1, name: /grow the life/i })).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'What Harvest is' })).toBeInTheDocument();
    expect(screen.getAllByRole('link', { name: /get the android app/i })[0]).toHaveAttribute('href', '/download');
    expect(screen.getAllByRole('link', { name: /open harvest in the browser/i })[0]).toHaveAttribute('href', '/app');
  });

  it('turns the browser button into Install once the browser offers it', async () => {
    renderAt('/');
    await screen.findByRole('heading', { level: 1 });
    const prompt = Object.assign(new Event('beforeinstallprompt'), {
      prompt: vi.fn(() => Promise.resolve()),
      userChoice: Promise.resolve({ outcome: 'dismissed' as const }),
    });
    act(() => {
      window.dispatchEvent(prompt);
    });
    expect(screen.getAllByRole('button', { name: /install harvest/i }).length).toBeGreaterThan(0);
  });

  it('never opens the local store (W3)', async () => {
    const open = vi.spyOn(indexedDB, 'open');
    renderAt('/');
    await screen.findByRole('heading', { level: 1 });
    renderAt('/privacy');
    await screen.findByRole('heading', { name: 'What leaves your device' });
    expect(open).not.toHaveBeenCalled();
  });
});

describe('the download page', () => {
  it('shows the release, its checksum and its notes', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      Response.json({
        tag: 'v2.0.0',
        name: 'Harvest 2.0.0',
        publishedAt: '2026-09-15T12:00:00Z',
        htmlUrl: 'https://github.com/ABakdi/Harvest/releases/tag/v2.0.0',
        notes: '## Phase 4\n- the gym',
        apk: { name: 'harvest-2.0.0.apk', url: 'https://example/harvest.apk', size: 48_000_000, sha256: 'ab'.repeat(32) },
      }),
    );
    renderAt('/download');
    expect(await screen.findByText('ab'.repeat(32))).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /download harvest-2.0.0.apk/i })).toHaveAttribute('href', 'https://example/harvest.apk');
    expect(screen.getByText('the gym')).toBeInTheDocument();
  });

  it('says so, gracefully, when the list is unavailable', async () => {
    vi.spyOn(globalThis, 'fetch').mockImplementation(() =>
      Promise.resolve(Response.json({ error: { code: 'unavailable', message: 'down' } }, { status: 503 })),
    );
    renderAt('/download');
    // The page asks twice before it gives up.
    expect(await screen.findByText(/not answering right now/i, {}, { timeout: 5000 })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /all releases on github/i })).toBeInTheDocument();
  });
});

describe('the strings', () => {
  const keys = (tree: object, prefix = ''): string[] =>
    Object.entries(tree).flatMap(([key, value]) =>
      typeof value === 'string'
        ? [`${prefix}${key}`.replace(/_(zero|one|two|few|many|other)$/, '')]
        : keys(value as object, `${prefix}${key}.`),
    );

  it('are the same set in English and Arabic', () => {
    expect([...new Set(keys(ar))].sort()).toEqual([...new Set(keys(en))].sort());
  });
});
