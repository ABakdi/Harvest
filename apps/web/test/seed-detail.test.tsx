import { HarvestDay } from '@harvest/core';
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router';
import { describe, expect, it } from 'vitest';
import { SeedNoteDialog } from '@/app/components/seed-note-dialog';
import { HarvestContext, type Harvest } from '@/app/context';
import { completedDaysRun, notesFor, readSeedStory } from '@/app/data/seed-notes';
import { DialogsProvider } from '@/app/dialogs';
import { SeedScreen } from '@/app/screens/seed';
import { FakeServer } from './fake-server';
import { device } from './helpers';

const today = HarvestDay.parse('2026-09-19');
const yesterday = today.previous;

function renderSeed(h: Harvest, uuid: string) {
  render(
    <HarvestContext.Provider value={h}>
      <MemoryRouter initialEntries={[`/app/field/seed/${uuid}`]}>
        <DialogsProvider>
          <Routes>
            <Route path="/app/field/seed/:uuid" element={<SeedScreen />} />
          </Routes>
        </DialogsProvider>
      </MemoryRouter>
    </HarvestContext.Provider>,
  );
}

describe('seed notes', () => {
  it('keeps one note per seed per day: a second write edits it', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'project', title: 'Read', totalTarget: 300, dailyCommitment: 10 });
    await h.seedNotes.write(seed.uuid, today, 'page 120');
    await h.seedNotes.write(seed.uuid, today, '  page 143  ');
    const notes = await notesFor(h.db, seed.uuid);
    expect(notes).toHaveLength(1);
    expect(notes[0]).toMatchObject({ harvestDay: today.key, body: 'page 143' });
  });

  it('removes the day’s note when it is emptied, and the removal travels', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'habit', title: 'Walk', schedule: { type: 'daily' } });
    await h.seedNotes.write(seed.uuid, today, 'around the lake');
    await h.seedNotes.write(seed.uuid, today, '   ');
    expect(await notesFor(h.db, seed.uuid)).toEqual([]);
    const outbox = await h.db.outbox.toArray();
    expect(outbox.some((entry) => entry.table === 'seed_notes' && entry.op === 'delete')).toBe(true);
  });

  it('caps a note at the phone’s five hundred characters', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'habit', title: 'Walk', schedule: { type: 'daily' } });
    await h.seedNotes.write(seed.uuid, today, 'x'.repeat(620));
    expect((await notesFor(h.db, seed.uuid))[0]?.body).toHaveLength(500);
  });

  it('quotes the last note above today’s when writing', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'project', title: 'Read', totalTarget: 300, dailyCommitment: 10 });
    await h.seedNotes.write(seed.uuid, yesterday, 'Stopped on page 143');
    render(
      <HarvestContext.Provider value={h}>
        <SeedNoteDialog seed={seed} onClose={() => {}} />
      </HarvestContext.Provider>,
    );
    expect(await screen.findByText('Stopped on page 143')).toBeInTheDocument();
    const box = screen.getByLabelText(/Note for/);
    expect(box).toHaveValue('');
    await userEvent.type(box, 'Page 178');
    await userEvent.click(screen.getByRole('button', { name: 'Save' }));
    const notes = await notesFor(h.db, seed.uuid);
    expect(notes.map((note) => [note.harvestDay, note.body])).toEqual([
      [today.key, 'Page 178'],
      [yesterday.key, 'Stopped on page 143'],
    ]);
  });
});

describe('the seed’s story', () => {
  it('counts the run of consecutive days back from the newest', () => {
    const days = ['2026-09-19', '2026-09-18', '2026-09-18', '2026-09-17', '2026-09-15'].map((key) => HarvestDay.parse(key));
    expect(completedDaysRun(days)).toBe(3);
    expect(completedDaysRun([])).toBe(0);
  });

  it('merges check-ins and notes into one timeline, newest first', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'project', title: 'Read', totalTarget: 300, dailyCommitment: 10 });
    await h.checkIns.checkIn(seed, yesterday, 12);
    await h.checkIns.checkIn(seed, today, 5);
    await h.checkIns.checkIn(seed, today, 3);
    await h.seedNotes.write(seed.uuid, today.next, 'tomorrow’s plan');

    const story = await readSeedStory(h.db, seed.uuid);
    expect(story.timeline.map((entry) => [entry.day.key, entry.quantity, entry.note])).toEqual([
      ['2026-09-20', 0, 'tomorrow’s plan'],
      ['2026-09-19', 8, null],
      ['2026-09-18', 12, null],
    ]);
    expect(story.total).toBe(20);
    expect(story.daysLogged).toBe(2);
    // A project has no stored streak: the history's own run speaks.
    expect(story.current).toBe(2);
  });

  it('shows the streak, the strip and the history on the screen', async () => {
    const h = await device(new FakeServer());
    const seed = await h.seeds.plant({ type: 'habit', title: 'Walk', schedule: { type: 'daily' } });
    await h.checkIns.checkIn(seed, today);
    await h.seedNotes.write(seed.uuid, today, 'around the lake');
    renderSeed(h, seed.uuid);

    expect(await screen.findByRole('heading', { name: 'Walk' })).toBeInTheDocument();
    const hero = screen.getByRole('region', { name: 'Streak' });
    expect(within(hero).getAllByText('1 day').length).toBeGreaterThan(0);
    expect(screen.getByRole('img', { name: '1 active day in the last eight weeks' })).toBeInTheDocument();
    expect(screen.getByText('Checked in')).toBeInTheDocument();
    expect(screen.getByText('around the lake')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /Focus timer/ })).toHaveAttribute('href', `/app/field/focus?seed=${seed.uuid}`);
  });

  it('says so when the seed is gone', async () => {
    const h = await device(new FakeServer());
    renderSeed(h, crypto.randomUUID());
    expect(await screen.findByText('This seed is gone')).toBeInTheDocument();
  });
});
