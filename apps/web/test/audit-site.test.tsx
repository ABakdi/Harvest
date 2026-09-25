import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { routes } from '@/router';

function renderAt(path: string) {
  const router = createMemoryRouter(routes, { initialEntries: [path] });
  render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <RouterProvider router={router} />
    </QueryClientProvider>,
  );
}

const stable = {
  tag: 'v2.0.0',
  name: 'Harvest 2.0.0',
  publishedAt: '2026-09-15T12:00:00Z',
  htmlUrl: 'https://github.com/ABakdi/Harvest/releases/tag/v2.0.0',
  notes: null,
  apk: { name: 'harvest-2.0.0.apk', url: 'https://example/harvest.apk', size: 48_000_000, sha256: null },
};

afterEach(() => {
  vi.restoreAllMocks();
});

describe('the download page and a beta', () => {
  it('mentions the newest beta beside the release, with its own link', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      Response.json({
        ...stable,
        prerelease: {
          ...stable,
          tag: 'v3.0.0-beta.2',
          name: 'Harvest 3.0.0 beta 2',
          htmlUrl: 'https://github.com/ABakdi/Harvest/releases/tag/v3.0.0-beta.2',
          apk: { name: 'harvest-3.0.0-beta.2.apk', url: 'https://example/beta.apk', size: 1, sha256: null },
        },
      }),
    );
    renderAt('/download');
    expect(await screen.findByRole('heading', { name: 'A beta, v3.0.0-beta.2, is out' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /download harvest-3.0.0-beta.2.apk/i })).toHaveAttribute('href', 'https://example/beta.apk');
    // The release itself is still the one offered first.
    expect(screen.getByRole('link', { name: /download harvest-2.0.0.apk/i })).toHaveAttribute('href', 'https://example/harvest.apk');
  });

  it('says nothing of a beta when there is none, or the server is older', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(Response.json(stable));
    renderAt('/download');
    expect(await screen.findByRole('link', { name: /download harvest-2.0.0.apk/i })).toBeInTheDocument();
    expect(screen.queryByText(/a beta/i)).toBeNull();
  });
});

describe('the reset page', () => {
  it('drops the server’s old answer once I edit or try again', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      Response.json({ error: { code: 'invalid', message: 'bad token' } }, { status: 400 }),
    );
    renderAt('/reset/some-token');
    const user = userEvent.setup();
    const password = await screen.findByLabelText('New password');
    await user.type(password, 'a long enough password');
    await user.type(screen.getByLabelText('The same, again'), 'a long enough password');
    await user.click(screen.getByRole('button', { name: 'Set the password' }));
    const failure = await screen.findByRole('alert');
    expect(failure).toBeInTheDocument();

    // A new try the form itself refuses: the old server error must not stay.
    await user.clear(screen.getByLabelText('The same, again'));
    await user.type(screen.getByLabelText('The same, again'), 'something else');
    await user.click(screen.getByRole('button', { name: 'Set the password' }));
    await waitFor(() => expect(failure).not.toBeInTheDocument());
    expect(screen.getByText('The two do not match')).toBeInTheDocument();
  });
});
