import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import type { ReactNode } from 'react';
import { createMemoryRouter, MemoryRouter, RouterProvider } from 'react-router';
import { Toaster } from 'sonner';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { ExpenseEditor } from '@/app/components/expense-editor';
import { SearchDialog } from '@/app/components/search-dialog';
import { WeightEditor } from '@/app/components/weight-editor';
import { HarvestContext } from '@/app/context';
import { recordKeyOf } from '@/app/data/db';
import { DialogsProvider } from '@/app/dialogs';
import { FieldScreen } from '@/app/screens/field';
import { GymPanel } from '@/app/screens/gym';
import { MoneyRuleError } from '@/app/data/vault';
import { ErrorScreen, RouteErrorScreen, ScreenErrorBoundary } from '@/components/error-screen';
import { background, describeFailure, runAction } from '@/lib/actions';
import { flushPendingEdits, registerPendingEdit } from '@/lib/pending-edits';
import { isChunkLoadError } from '@/lib/reload';
import { useDocumentTitle } from '@/lib/title';
import { FakeServer } from './fake-server';
import { device, testUser } from './helpers';

type Device = Awaited<ReturnType<typeof device>>;

// Radix's switch measures itself; jsdom has nothing to measure with.
globalThis.ResizeObserver ??= class {
  observe() {}
  unobserve() {}
  disconnect() {}
};

function show(h: Device, ui: ReactNode) {
  return render(
    <HarvestContext.Provider value={h}>
      <MemoryRouter>{ui}</MemoryRouter>
      <Toaster />
    </HarvestContext.Provider>,
  );
}

afterEach(() => {
  vi.restoreAllMocks();
});

describe('a screen that breaks (Q6-04)', () => {
  function Boom(): ReactNode {
    throw new Error('render bug in a card');
  }

  it('shows words and a way back at the route, never the stack', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    const router = createMemoryRouter([{ path: '/', element: <Boom />, errorElement: <RouteErrorScreen /> }]);
    render(<RouterProvider router={router} />);
    expect(await screen.findByRole('heading', { name: 'Something went wrong' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Reload' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Go back' })).toBeInTheDocument();
    expect(document.body.textContent).not.toContain('render bug in a card');
  });

  it('keeps the rest of the shell when one screen breaks, and tries again on the next screen', () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    const view = render(
      <div>
        <nav>tabs</nav>
        <ScreenErrorBoundary resetKey="/a">
          <Boom />
        </ScreenErrorBoundary>
      </div>,
    );
    expect(screen.getByText('tabs')).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'Something went wrong' })).toBeInTheDocument();
    view.rerender(
      <div>
        <nav>tabs</nav>
        <ScreenErrorBoundary resetKey="/b">
          <p>the next screen</p>
        </ScreenErrorBoundary>
      </div>,
    );
    expect(screen.getByText('the next screen')).toBeInTheDocument();
  });

  it('tells a missing chunk after a deploy apart, and says a new version is waiting', () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    const error = new TypeError('Failed to fetch dynamically imported module: http://x/assets/granary-old.js');
    expect(isChunkLoadError(error)).toBe(true);
    expect(isChunkLoadError(new Error('Cannot read properties of undefined'))).toBe(false);
    // Asked to reload once already this minute: shown, not looped.
    sessionStorage.setItem('harvest.chunkReloadAt', String(Date.now()));
    render(<ErrorScreen error={error} />);
    expect(screen.getByRole('heading', { name: 'Harvest was updated' })).toBeInTheDocument();
  });
});

describe('actions that fail say so (Q6-10)', () => {
  it('puts a money rule into words, and a full store too', () => {
    expect(describeFailure(new MoneyRuleError('overdraw'))).not.toBe('That did not save. Try again.');
    const full = new DOMException('The quota has been exceeded.', 'QuotaExceededError');
    expect(describeFailure(full)).toMatch(/no room left/);
    expect(describeFailure(new Error('anything else'))).toBe('That did not save. Try again.');
  });

  it('shows a toast when a tap fails, and runs what follows a success', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    render(<Toaster />);
    runAction(() => Promise.reject(new Error('refused')));
    expect(await screen.findByText('That did not save. Try again.')).toBeInTheDocument();
    const then = vi.fn();
    runAction(() => Promise.resolve(42), { then });
    await waitFor(() => expect(then).toHaveBeenCalledWith(42));
  });

  it('keeps background failures in the console, not floating away', async () => {
    const logged = vi.spyOn(console, 'error').mockImplementation(() => {});
    background(Promise.reject(new Error('sync kick failed')));
    await waitFor(() => expect(logged).toHaveBeenCalled());
  });
});

describe('saving before a reload (Q6-09, Q6-22)', () => {
  it('runs every editor’s save even when one fails, and says whether all saved', async () => {
    const saved: string[] = [];
    const offA = registerPendingEdit(() => Promise.reject(new Error('disk')));
    const offB = registerPendingEdit(() => {
      saved.push('note');
    });
    expect(await flushPendingEdits()).toBe(false);
    expect(saved).toEqual(['note']);
    offA();
    expect(await flushPendingEdits()).toBe(true);
    offB();
  });
});

describe('the tab’s title (W6-11)', () => {
  function Titled({ route, screen: own }: { route: string; screen?: string }) {
    useDocumentTitle(route, 0);
    return own ? <Screen title={own} /> : null;
  }
  function Screen({ title }: { title: string }) {
    useDocumentTitle(title);
    return null;
  }

  it('names the route, and a screen’s own name outweighs it', () => {
    const view = render(<Titled route="Granary" />);
    expect(document.title).toBe('Granary · Harvest');
    view.rerender(<Titled route="Records" screen="Groceries" />);
    expect(document.title).toBe('Groceries · Harvest');
    view.unmount();
    expect(document.title).toBe('Harvest');
  });
});

describe('records keyed as the contract keys them (Q6-22)', () => {
  it('follows each table’s own key', () => {
    expect(recordKeyOf('streaks', { scope: 'global' })).toBe('global');
    expect(recordKeyOf('kv_settings', { key: 'features.notes' })).toBe('features.notes');
    expect(recordKeyOf('training_maxes', { programUuid: 'p', exerciseId: '0025' })).toBe('p/0025');
    expect(recordKeyOf('notes', { uuid: 'n1' })).toBe('n1');
  });
});

describe('amounts and weights past the shared bounds (W6-15)', () => {
  it('says a huge expense back once before logging it', async () => {
    const h = await device(new FakeServer());
    await h.keyring.unlock('a long passphrase', testUser.syncSalt, 1);
    show(h, <ExpenseEditor expense={null} onClose={() => {}} />);
    await userEvent.type(await screen.findByLabelText('Amount'), '99999999999');
    await userEvent.click(screen.getByRole('button', { name: 'Log it' }));
    expect(await screen.findByText(/That's DA99,999,999,999\. Log it\?/)).toBeInTheDocument();
    expect(await h.db.rows('expenses').count()).toBe(0);
    await userEvent.click(screen.getByRole('button', { name: 'Yes, log it' }));
    await waitFor(async () => expect(await h.db.rows('expenses').count()).toBe(1));
  });

  it('refuses a weight outside 20–400 kg', async () => {
    const h = await device(new FakeServer());
    show(h, <WeightEditor weight={null} unit="kg" onClose={() => {}} />);
    const field = await screen.findByLabelText(/Weight/);
    await userEvent.type(field, '900');
    expect(await screen.findByText(/outside 20–400 kg/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Save' })).toBeDisabled();
    fireEvent.submit(field.closest('form')!);
    expect(await h.db.rows('body_weights').count()).toBe(0);
  });
});

describe('search (W6-18)', () => {
  it('finds a list item, and leads to its list', async () => {
    const h = await device(new FakeServer());
    await h.lists.ensureBuiltIns();
    const [list] = await h.db.rows('lists').toArray();
    await h.lists.addItem(list!.uuid, { title: 'Olive oil from the market' });
    show(h, <SearchDialog open onOpenChange={() => {}} />);
    await userEvent.type(await screen.findByRole('combobox', { name: 'Search' }), 'olive');
    const hit = await screen.findByRole('option', { name: /Olive oil from the market/ });
    expect(within(hit).getByText('Olive oil from the market')).toHaveAttribute('dir', 'auto');
  });
});

describe('the field at phone width (W6-10)', () => {
  it('opens on the rank and its bar, and shows no streak that is not running', async () => {
    const phone = vi.spyOn(window, 'matchMedia').mockImplementation(
      (query: string) =>
        ({
          matches: query.includes('48rem'),
          media: query,
          onchange: null,
          addEventListener: () => {},
          removeEventListener: () => {},
          addListener: () => {},
          removeListener: () => {},
          dispatchEvent: () => false,
        }) as MediaQueryList,
    );
    const h = await device(new FakeServer());
    await h.seeds.plant({ type: 'habit', title: 'Walk', schedule: { type: 'daily' } });
    render(
      <HarvestContext.Provider value={h}>
        <MemoryRouter initialEntries={['/app/field']}>
          <DialogsProvider>
            <FieldScreen tab="today" />
          </DialogsProvider>
        </MemoryRouter>
      </HarvestContext.Provider>,
    );
    expect(await screen.findByText('Sprout')).toBeInTheDocument();
    expect(screen.getByRole('progressbar')).toBeInTheDocument();
    const row = (await screen.findByRole('link', { name: 'Walk' })).closest('li')!;
    expect(within(row).queryByText(/^Streak:/)).toBeNull();
    phone.mockRestore();
  });
});

describe('the gym with no program (W6-19)', () => {
  it('offers a new program, and nothing to start', async () => {
    const h = await device(new FakeServer());
    show(h, <GymPanel />);
    expect(await screen.findByText('No programs yet')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Start a session' })).toBeNull();
    expect(screen.getAllByRole('button', { name: 'New program' }).length).toBeGreaterThan(0);
  });
});
