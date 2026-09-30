import type { AdminReport, AdminReports, ReportBody } from '@harvest/contracts';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Toaster } from 'sonner';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ReportProblemDialog } from '@/app/components/report-problem';
import { audioTypeOf, reportBodyOf, reportProblems, type ReportFile } from '@/app/data/report';
import { appVersion } from '@/app/data/news';
import { Reports, type ReportsApi } from '@/app/screens/admin-reports';
import { PrivacyPage } from '@/pages/site/privacy';
import i18n from '@/i18n';
import { api, ApiError, resetApiForTests } from '@/lib/api';

/** *Report a problem* and the admin's Reports tab ([[Admin]], F12-5). */

globalThis.ResizeObserver ??= class {
  observe() {}
  unobserve() {}
  disconnect() {}
} as unknown as typeof ResizeObserver;

let urls = 0;
beforeEach(() => {
  urls = 0;
  vi.stubGlobal('URL', Object.assign(URL, { createObjectURL: vi.fn(() => `blob:test/${++urls}`), revokeObjectURL: vi.fn() }));
});

afterEach(async () => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
  resetApiForTests();
  await i18n.changeLanguage('en');
});

const blob = (size: number, type = 'image/jpeg') => new Blob([new Uint8Array(size)], { type });
const file = (kind: ReportFile['kind'], size: number, type = kind === 'image' ? 'image/jpeg' : 'audio/webm'): ReportFile => ({
  kind,
  type,
  blob: blob(size, type),
  url: 'blob:x',
});

describe('what a report may carry', () => {
  it('needs words, up to 5,000 of them', () => {
    expect(reportProblems('  ', [])).toEqual(['text']);
    expect(reportProblems('x'.repeat(5001), [])).toEqual(['text']);
    expect(reportProblems('The keyboard hides the button', [])).toEqual([]);
  });

  it('takes four pictures and one recording, each under its size, and all under the whole', () => {
    const text = 'It broke';
    expect(reportProblems(text, [file('image', 10), file('image', 10), file('image', 10), file('image', 10), file('audio', 10)])).toEqual([]);
    expect(reportProblems(text, Array.from({ length: 5 }, () => file('image', 10)))).toContain('images');
    expect(reportProblems(text, [file('audio', 10), file('audio', 10)])).toContain('audio');
    expect(reportProblems(text, [file('image', 5 * 1024 * 1024 + 1)])).toContain('imageTooLarge');
    expect(reportProblems(text, [file('audio', 10 * 1024 * 1024 + 1)])).toContain('audioTooLarge');
    const big = Array.from({ length: 4 }, () => file('image', 5 * 1024 * 1024));
    expect(reportProblems(text, [...big, file('audio', 2 * 1024 * 1024)])).toContain('tooLarge');
  });

  it('names an audio file the way the server does, and refuses the rest', () => {
    expect(audioTypeOf('audio/webm;codecs=opus')).toBe('audio/webm');
    expect(audioTypeOf('audio/x-m4a')).toBe('audio/mp4');
    expect(audioTypeOf('audio/x-wav')).toBe('audio/wav');
    expect(audioTypeOf('audio/mpeg')).toBe('audio/mpeg');
    expect(audioTypeOf('audio/flac')).toBeNull();
    expect(audioTypeOf('video/mp4')).toBeNull();
  });

  it('becomes a body the contract takes: web, the build’s version, pictures always as JPEG', async () => {
    const body = await reportBodyOf('  It broke  ', [file('image', 3), file('audio', 3, 'audio/ogg;codecs=opus')]);
    expect(body).toEqual({
      text: 'It broke',
      platform: 'web',
      appVersion,
      attachments: [
        { kind: 'image', type: 'image/jpeg', data: 'AAAA' },
        { kind: 'audio', type: 'audio/ogg', data: 'AAAA' },
      ],
    });
  });
});

describe('the report form', () => {
  function renderForm(send: (body: ReportBody) => Promise<unknown>, encode = vi.fn((_: Blob) => Promise.resolve(blob(7, 'image/jpeg')))) {
    render(
      <>
        <ReportProblemDialog open onOpenChange={() => undefined} send={send} encode={encode} />
        <Toaster />
      </>,
    );
    return encode;
  }

  it('sends the picture drawn again, never the file as it was picked', async () => {
    const user = userEvent.setup();
    const send = vi.fn((_: ReportBody) => Promise.resolve({ id: 'r1' }));
    const reencoded = new Blob([new Uint8Array([1, 2, 3])], { type: 'image/jpeg' });
    const encode = renderForm(send, vi.fn(() => Promise.resolve(reencoded)));
    // A photo straight off a camera, with its metadata in its bytes.
    const original = new File([new Uint8Array([0xff, 0xd8, 0xff, 0xe1, 9, 9, 9, 9])], 'IMG_0001.jpg', { type: 'image/jpeg' });
    await user.upload(screen.getByLabelText('Pictures to add'), original);
    await screen.findByRole('img', { name: 'Picture 1' });
    expect(encode).toHaveBeenCalledWith(original);
    await user.type(screen.getByLabelText('What happened'), 'The export froze');
    await user.click(screen.getByRole('button', { name: 'Send the report' }));
    await waitFor(() => expect(send).toHaveBeenCalledTimes(1));
    const body = send.mock.calls[0]![0];
    expect(body.attachments).toEqual([{ kind: 'image', type: 'image/jpeg', data: btoa(String.fromCharCode(1, 2, 3)) }]);
    expect(await screen.findByText('Thank you. The report is on its way.')).toBeInTheDocument();
  });

  it('says what is wrong before sending anything, and says plainly how it goes', async () => {
    const user = userEvent.setup();
    const send = vi.fn(() => Promise.resolve({ id: 'r1' }));
    renderForm(send);
    expect(screen.getByText(/not your name, not your account\. It is not end-to-end encrypted/)).toBeInTheDocument();
    expect(screen.getByText(/where and when it was taken stays on your device/)).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Send the report' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('Write what happened');
    expect(send).not.toHaveBeenCalled();
  });

  it('tells how long to wait when there were too many, and keeps what was written', async () => {
    const user = userEvent.setup();
    renderForm(() => Promise.reject(new ApiError(429, 'rate_limited', 'Slow down', [], 600)));
    await user.type(screen.getByLabelText('What happened'), 'Again');
    await user.click(screen.getByRole('button', { name: 'Send the report' }));
    expect(await screen.findByText('Too many reports from here just now. Try again in 10 minutes.')).toBeInTheDocument();
    expect(screen.getByLabelText('What happened')).toHaveValue('Again');
  });

  it('says so when a picture cannot be read', async () => {
    const user = userEvent.setup();
    renderForm(() => Promise.resolve({}), vi.fn(() => Promise.reject(new Error('HEIC'))));
    await user.upload(screen.getByLabelText('Pictures to add'), new File([new Uint8Array(4)], 'a.heic', { type: 'image/heic' }));
    expect(await screen.findByText(/could not be read here/)).toBeInTheDocument();
  });
});

describe('the report on the wire', () => {
  it('never carries the session, even for someone signed in', async () => {
    const fetch = vi.fn((input: RequestInfo | URL, init?: RequestInit) => {
      void input;
      void init;
      return Promise.resolve(Response.json({ id: 'r1' }, { status: 201 }));
    });
    vi.stubGlobal('fetch', fetch);
    await api.report({ text: 'Hello', platform: 'web', appVersion: '3.3.0', attachments: [] });
    const [url, init] = fetch.mock.calls[0]!;
    expect(url as string).toMatch(/\/v1\/reports$/);
    expect((init!.headers as Record<string, string>).authorization).toBeUndefined();
    expect(init!.method).toBe('POST');
  });
});

describe('the Reports tab', () => {
  const report = (id: string, fields: Partial<AdminReport> = {}): AdminReport => ({
    id,
    text: `First line of ${id}\nSecond line`,
    platform: 'android',
    appVersion: '3.3.0',
    status: 'new',
    createdAt: '2026-09-30T08:00:00.000Z',
    attachments: [
      { id: 'a'.repeat(24), kind: 'image', type: 'image/jpeg', bytes: 2048 },
      { id: 'b'.repeat(24), kind: 'audio', type: 'audio/mp4', bytes: 4096 },
    ],
    ...fields,
  });

  function fakeReports(pages: AdminReports[]): ReportsApi & { [K in keyof ReportsApi]: ReturnType<typeof vi.fn> } {
    let page = 0;
    return {
      adminReports: vi.fn((query: { cursor?: string } = {}) => Promise.resolve(query.cursor ? pages[++page] ?? pages[0]! : pages[(page = 0)]!)),
      setReportStatus: vi.fn((id: string, status: AdminReport['status']) => Promise.resolve(report(id, { status }))),
      deleteReport: vi.fn(() => Promise.resolve()),
      reportAttachment: vi.fn(() => Promise.resolve(new Blob([new Uint8Array(3)], { type: 'image/jpeg' }))),
    };
  }

  function renderTab(source: ReportsApi) {
    render(
      <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
        <Reports source={source} />
        <Toaster />
      </QueryClientProvider>,
    );
  }

  it('lists them newest first, opens one to read it with its files, and marks it read', async () => {
    const user = userEvent.setup();
    const source = fakeReports([{ reports: [report('r2'), report('r1', { status: 'done', attachments: [] })], next: null, unread: 1 }]);
    renderTab(source);
    const first = await screen.findByRole('button', { name: /First line of r2/ });
    expect(first).toHaveAttribute('aria-expanded', 'false');
    await user.click(first);
    expect(source.setReportStatus).toHaveBeenCalledWith('r2', 'read');
    expect(await screen.findByRole('img', { name: 'Picture from a report' })).toBeInTheDocument();
    expect(screen.getByLabelText('Recording')).toBeInTheDocument();
    expect(source.reportAttachment).toHaveBeenCalledWith('r2', 'a'.repeat(24));
    expect(source.reportAttachment).toHaveBeenCalledWith('r2', 'b'.repeat(24));
    // A report already done is not marked read by opening it.
    await user.click(screen.getByRole('button', { name: /First line of r1/ }));
    expect(source.setReportStatus).toHaveBeenCalledTimes(1);
    await user.click(within(screen.getAllByRole('listitem')[0]!).getByRole('button', { name: 'Done' }));
    expect(source.setReportStatus).toHaveBeenLastCalledWith('r2', 'done');
  });

  it('deletes one only once asked twice, and pages with Show more', async () => {
    const user = userEvent.setup();
    const source = fakeReports([
      { reports: [report('r3')], next: 'c'.repeat(24), unread: 2 },
      { reports: [report('r2')], next: null, unread: 2 },
    ]);
    renderTab(source);
    await user.click(await screen.findByRole('button', { name: /First line of r3/ }));
    await user.click(screen.getByRole('button', { name: 'Delete' }));
    expect(source.deleteReport).not.toHaveBeenCalled();
    const confirm = await screen.findByRole('alertdialog');
    await user.click(within(confirm).getByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(source.deleteReport).toHaveBeenCalledWith('r3'));
    await user.click(screen.getByRole('button', { name: 'Show more' }));
    expect(await screen.findByRole('button', { name: /First line of r2/ })).toBeInTheDocument();
  });
});

describe('the privacy page', () => {
  it('says what a report carries, and that it is not encrypted end to end', () => {
    render(<PrivacyPage />);
    expect(screen.getByRole('heading', { name: 'A report of a problem, when you send one' })).toBeInTheDocument();
    expect(screen.getByText(/pictures are saved again on your device first/)).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'Reports of problems' })).toBeInTheDocument();
  });
});
