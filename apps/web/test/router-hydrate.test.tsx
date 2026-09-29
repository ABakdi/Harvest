import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen } from '@testing-library/react';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { routes } from '@/router';

afterEach(() => {
  vi.restoreAllMocks();
});

describe('a page whose code loads on demand', () => {
  it('has a fallback while it arrives, so opening it directly warns of nothing (Q6-19)', async () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => undefined);
    const router = createMemoryRouter(routes, { initialEntries: ['/login'], hydrationData: {} });
    render(
      <QueryClientProvider client={new QueryClient()}>
        <RouterProvider router={router} />
      </QueryClientProvider>,
    );
    expect(await screen.findByRole('button', { name: /sign in/i })).toBeInTheDocument();
    const said = warn.mock.calls.map((call) => String(call[0]));
    expect(said.filter((line) => line.includes('HydrateFallback'))).toEqual([]);
  });
});
