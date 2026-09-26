import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { refreshSession, resetApiForTests } from '@/lib/api';
import { LoginPage } from '@/pages/auth/login';
import { testUser } from './helpers';

function renderLogin() {
  const router = createMemoryRouter(
    [
      { path: '/login', element: <LoginPage /> },
      { path: '/app/*', element: <p>the app</p> },
    ],
    { initialEntries: ['/login?next=/app/granary'] },
  );
  render(
    <QueryClientProvider client={new QueryClient()}>
      <RouterProvider router={router} />
    </QueryClientProvider>,
  );
  return router;
}

afterEach(() => {
  vi.restoreAllMocks();
  resetApiForTests();
});

describe('sign in', () => {
  it('checks the fields with the contract before sending anything', async () => {
    const fetch = vi.spyOn(globalThis, 'fetch');
    renderLogin();
    await userEvent.type(screen.getByLabelText('Email'), 'not-an-email');
    await userEvent.click(screen.getByRole('button', { name: 'Sign in' }));
    expect(await screen.findByText('That is not an email address')).toBeInTheDocument();
    expect(screen.getByLabelText('Email')).toHaveAttribute('aria-invalid', 'true');
    expect(fetch).not.toHaveBeenCalled();
  });

  it('signs in as a web client and goes where it was asked', async () => {
    const fetch = vi
      .spyOn(globalThis, 'fetch')
      .mockResolvedValue(Response.json({ accessToken: 'token', expiresIn: 900, user: testUser }));
    const router = renderLogin();
    await userEvent.type(screen.getByLabelText('Email'), ' Farmer@Example.com ');
    await userEvent.type(screen.getByLabelText('Password'), 'a long enough password');
    await userEvent.click(screen.getByRole('button', { name: 'Sign in' }));

    expect(await screen.findByText('the app')).toBeInTheDocument();
    expect(router.state.location.pathname).toBe('/app/granary');
    const [url, init] = fetch.mock.calls[0]!;
    expect(url).toBe('/v1/auth/login');
    expect(init?.credentials).toBe('include');
    expect(JSON.parse(init?.body as string)).toMatchObject({
      email: 'farmer@example.com',
      password: 'a long enough password',
      client: 'web',
    });
  });

  it('says only that the pair is wrong', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      Response.json({ error: { code: 'unauthorized', message: 'Wrong email or password' } }, { status: 401 }),
    );
    renderLogin();
    await userEvent.type(screen.getByLabelText('Email'), 'farmer@example.com');
    await userEvent.type(screen.getByLabelText('Password'), 'wrong');
    await userEvent.click(screen.getByRole('button', { name: 'Sign in' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('That email and password do not match.');
  });
});

describe('the session', () => {
  it('refreshes once however many callers ask at the same time', async () => {
    const fetch = vi
      .spyOn(globalThis, 'fetch')
      .mockImplementation(() => Promise.resolve(Response.json({ accessToken: 'fresh', expiresIn: 900, user: testUser })));
    const results = await Promise.all([refreshSession(), refreshSession(), refreshSession()]);
    expect(fetch).toHaveBeenCalledTimes(1);
    expect(results.every((result) => result?.accessToken === 'fresh')).toBe(true);
  });

  it('serializes refreshes across tabs with a Web Lock', async () => {
    const request = vi.fn((_name: string, callback: () => Promise<unknown>) => callback());
    Object.defineProperty(navigator, 'locks', { value: { request }, configurable: true });
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(Response.json({ accessToken: 'fresh', expiresIn: 900, user: testUser }));
    await refreshSession();
    expect(request).toHaveBeenCalledWith('harvest-refresh', expect.any(Function));
    Reflect.deleteProperty(navigator, 'locks');
  });

  it('answers null, not an error, when there is no session', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      Response.json({ error: { code: 'unauthorized', message: 'no' } }, { status: 401 }),
    );
    expect(await refreshSession()).toBeNull();
  });
});
