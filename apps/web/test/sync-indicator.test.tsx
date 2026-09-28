import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { SyncIndicator } from '@/app/components/sync-indicator';
import { HarvestContext } from '@/app/context';
import { FakeServer } from './fake-server';
import { device, syncing } from './helpers';

/** What the top bar says about sync (Phase 7: nothing syncs without the PIN). */
describe('the sync indicator', () => {
  it('never says synced while the sync PIN is missing', async () => {
    const h = await device(new FakeServer());
    render(
      <HarvestContext.Provider value={h}>
        <SyncIndicator />
      </HarvestContext.Provider>,
    );
    expect(await screen.findByText('Waiting for your sync PIN')).toBeInTheDocument();
  });

  it('says how long ago it synced once the PIN is in', async () => {
    const server = new FakeServer();
    const h = await syncing(server);
    await h.engine.sync();
    render(
      <HarvestContext.Provider value={h}>
        <SyncIndicator />
      </HarvestContext.Provider>,
    );
    expect(await screen.findByText(/^Synced/)).toBeInTheDocument();
    expect(screen.queryByText('Waiting for your sync PIN')).toBeNull();
  });
});
