import { Blob as NodeBlob } from 'node:buffer';
import { HarvestDay } from '@harvest/core';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes, useLocation } from 'react-router';
import { beforeAll, describe, expect, it, vi } from 'vitest';
import { HarvestContext } from '@/app/context';
import { readAlbumsDue } from '@/app/data/gallery';
import { featureKeys } from '@/app/data/settings';
import { DialogsProvider } from '@/app/dialogs';
import { FieldScreen } from '@/app/screens/field';
import { FakeServer } from './fake-server';
import { device } from './helpers';

/**
 * Gallery rule G3 on the web's field: a scheduled album is a seed, due
 * like a habit, and its check-in is today's picture.
 */

beforeAll(() => {
  // jsdom's Blob does not survive IndexedDB's structured clone; Node's does.
  vi.stubGlobal('Blob', NodeBlob);
});

type Harvest = Awaited<ReturnType<typeof device>>;

/** Found patiently: the whole suite runs these side by side. */
const patient = { timeout: 5000 };

// The pinned clock's day is a Saturday.
const today = HarvestDay.of(new Date('2026-09-19T12:00:00.000Z'));

function picture(): Blob {
  return new Blob([new Uint8Array(64).fill(5)], { type: 'image/jpeg' });
}

function Where() {
  const location = useLocation();
  return <p data-testid="where">{`${location.pathname}${location.search}`}</p>;
}

function renderField(h: Harvest) {
  render(
    <HarvestContext.Provider value={h}>
      <MemoryRouter initialEntries={['/app/field']}>
        <DialogsProvider>
          <Routes>
            <Route path="/app/field" element={<FieldScreen tab="today" />} />
            <Route path="/app/records/gallery" element={<Where />} />
          </Routes>
        </DialogsProvider>
      </MemoryRouter>
    </HarvestContext.Provider>,
  );
}

async function albums(h: Harvest) {
  // A minute apart, so they stand in the order they were made.
  const later = () => h.clock.advance(60_000);
  const face = await h.gallery.createAlbum({ name: 'Face', schedule: { type: 'daily' }, remindAt: null, note: 'Same light' });
  later();
  await h.gallery.createAlbum({ name: 'Mondays', schedule: { type: 'weekly', weekdays: new Set([1]) }, remindAt: null, note: null });
  await h.gallery.createAlbum({ name: 'Shoebox', schedule: null, remindAt: null, note: null });
  later();
  const twice = await h.gallery.createAlbum({ name: 'Twice', schedule: { type: 'timesPerWeek', times: 2 }, remindAt: null, note: null });
  later();
  const once = await h.gallery.createAlbum({ name: 'Once', schedule: { type: 'timesPerWeek', times: 1 }, remindAt: null, note: null });
  // Once this week already: its quota is met, so it rests.
  await h.gallery.addMemory(once, { blob: picture(), kind: 'photo', extension: '.jpg', day: today.addDays(-3) });
  await h.gallery.addMemory(twice, { blob: picture(), kind: 'photo', extension: '.jpg', day: today.addDays(-3) });
  // A gym program's album rides on the gym seed, even one given a
  // schedule before it was bound.
  const program = await h.programs.createProgram('Push');
  await h.programs.plant(program.uuid, { title: 'Gym', timesPerWeek: 3, album: true });
  const bound = (await h.db.rows('programs').get(program.uuid))!.albumUuid!;
  await h.gallery.updateAlbum(bound, { name: 'Lifts', schedule: { type: 'daily' }, remindAt: null, note: null });
  return face;
}

describe('scheduled albums on the field (G3)', () => {
  it('lists what is due today by the habit rule, and nothing else', async () => {
    const h = await device(new FakeServer());
    await albums(h);
    const due = await readAlbumsDue(h.db, today);
    expect(due.map((entry) => entry.album.name)).toEqual(['Face', 'Twice']);
    expect(due.find((entry) => entry.album.name === 'Twice')?.doneDaysThisWeek).toBe(1);
    // Nothing is due before the album was made.
    expect(await readAlbumsDue(h.db, today.addDays(-1))).toEqual([]);
  });

  it('stays off the field while the gallery is off', async () => {
    const h = await device(new FakeServer());
    await albums(h);
    await h.seeds.plant({ type: 'habit', title: 'Read', schedule: { type: 'daily' } });
    renderField(h);
    expect(await screen.findByText('Read', {}, patient)).toBeInTheDocument();
    expect(screen.queryByText('Face')).not.toBeInTheDocument();
  });

  it('opens the capture for today’s picture, and once it is in, leads to the album', async () => {
    const h = await device(new FakeServer());
    await h.settings.setBool(featureKeys.gallery, true);
    const face = await albums(h);
    renderField(h);

    const add = await screen.findByRole('button', { name: 'Add today’s picture to “Face”' }, patient);
    expect(screen.getByText('Same light')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Add today’s picture to “Twice”' })).toBeInTheDocument();
    for (const name of ['Mondays', 'Shoebox', 'Once', 'Lifts']) expect(screen.queryByText(name)).not.toBeInTheDocument();

    await userEvent.click(add);
    const capture = await screen.findByRole('dialog', {}, patient);
    expect(within(capture).getByText('Add to Face')).toBeInTheDocument();
    await userEvent.keyboard('{Escape}');

    // The picture is the check-in: paid as a habit's, and the crop is done.
    await h.gallery.addMemory(face, { blob: picture(), kind: 'photo', extension: '.jpg' });
    const open = await screen.findByRole('button', { name: 'Open “Face”, today’s picture is in' }, patient);
    expect(within(open.closest('li')!).getByLabelText('Streak: 1 day')).toBeInTheDocument();
    await userEvent.click(open);
    await waitFor(() => expect(screen.getByTestId('where')).toHaveTextContent(`/app/records/gallery?album=${face.uuid}`), patient);
  });
});
