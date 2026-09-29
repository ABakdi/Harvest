import { act, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import { InstallButton } from '@/components/install-button';
import { listenForInstallPrompt } from '@/lib/pwa';

describe('installing the app', () => {
  it('says the app is on its way once the install is accepted, instead of seeming to do nothing', async () => {
    listenForInstallPrompt();
    render(
      <MemoryRouter>
        <InstallButton />
      </MemoryRouter>,
    );
    // The browser offers the install (Android Chrome, desktop Chromium).
    const offer = Object.assign(new Event('beforeinstallprompt', { cancelable: true }), {
      prompt: () => Promise.resolve(),
      userChoice: Promise.resolve({ outcome: 'accepted' as const }),
    });
    act(() => {
      window.dispatchEvent(offer);
    });
    await userEvent.click(await screen.findByRole('button', { name: 'Install Harvest' }));
    expect(await screen.findByRole('status')).toHaveTextContent('Harvest will appear on your home screen');
  });
});
