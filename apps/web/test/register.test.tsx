import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { resetApiForTests } from '@/lib/api';
import { RegisterPage } from '@/pages/auth/register';
import i18n from '@/i18n';

function renderRegister() {
  const router = createMemoryRouter([{ path: '/register', element: <RegisterPage /> }], {
    initialEntries: ['/register'],
  });
  render(
    <QueryClientProvider client={new QueryClient()}>
      <RouterProvider router={router} />
    </QueryClientProvider>,
  );
}

afterEach(() => {
  vi.restoreAllMocks();
  resetApiForTests();
});

describe('sign up', () => {
  it('asks for the name before the password, never right after it', () => {
    renderRegister();
    const fields = screen.getAllByRole('textbox').concat(screen.getByLabelText(i18n.t('auth.password')));
    const name = screen.getByLabelText(i18n.t('auth.displayName'));
    const password = screen.getByLabelText(i18n.t('auth.password'));
    expect(fields.length).toBeGreaterThan(1);
    expect(name.compareDocumentPosition(password) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
  });

  it('refuses a name that is the password, before sending anything', async () => {
    const fetch = vi.spyOn(globalThis, 'fetch');
    renderRegister();
    await userEvent.type(screen.getByLabelText(i18n.t('auth.displayName')), 'Tamarind-orchard-7');
    await userEvent.type(screen.getByLabelText(i18n.t('auth.email')), 'maya@example.com');
    await userEvent.type(screen.getByLabelText(i18n.t('auth.password')), 'Tamarind-orchard-7');
    await userEvent.click(screen.getByRole('button', { name: i18n.t('auth.createAccount') }));
    expect(await screen.findByText(i18n.t('form.error.nameIsPassword'))).toBeInTheDocument();
    expect(fetch).not.toHaveBeenCalled();
  });
});
