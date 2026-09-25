import { DownloadIcon, FileArchiveIcon, FolderOpenIcon, KeyRoundIcon, Loader2Icon } from 'lucide-react';
import { useId, useRef, useState, type ChangeEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { useHarvest, useSyncStatus } from '../context';
import { ArchiveInvalid, ArchiveLimits, exportIncludesPlacesKey, type ArchiveProblem } from '../data/archive';
import type { ArchiveProgress } from '../data/export';
import type { ArchiveBundle, ImportPreview, ImportProgress } from '../data/import';
import { useSetting } from '../hooks';
import { PassphrasePrompt } from './passphrase-prompt';

/**
 * "My data" (Business Rules #11): the archive out, and an archive back
 * in, as the phone's Settings has them ([[ADR-007-Archive-Format]]).
 *
 * The zip and spreadsheet code is only loaded when one of the buttons
 * is pressed, so it costs the rest of the app nothing.
 */

type ExportState =
  | { kind: 'idle' }
  | { kind: 'running'; progress: ArchiveProgress | null }
  | { kind: 'saved'; name: string; sealed: number; missing: number }
  | { kind: 'stopped' }
  | { kind: 'failed' };

type ImportState =
  | { kind: 'idle' }
  | { kind: 'reading' }
  | { kind: 'ready'; name: string; bundle: ArchiveBundle; preview: ImportPreview }
  | { kind: 'applying'; progress: ImportProgress | null }
  | { kind: 'done'; preview: ImportPreview }
  | { kind: 'failed'; problem: ArchiveProblem | null };

function totals(preview: ImportPreview) {
  let added = 0;
  let updated = 0;
  let skipped = 0;
  for (const count of Object.values(preview.tables)) {
    added += count.added;
    updated += count.updated;
    skipped += count.skipped;
  }
  return { added, updated, skipped };
}

/** Hands the bytes to the browser as a download. */
function save(bytes: Uint8Array<ArrayBuffer>, name: string) {
  const url = URL.createObjectURL(new Blob([bytes], { type: 'application/zip' }));
  const link = document.createElement('a');
  link.href = url;
  link.download = name;
  document.body.append(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 60_000);
}

function Progress({ fraction, label }: { fraction: number | null; label: string }) {
  return (
    <div
      className="h-2 overflow-hidden rounded-full bg-muted"
      role="progressbar"
      aria-label={label}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={fraction === null ? undefined : Math.round(fraction * 100)}
    >
      <div
        className={fraction === null ? 'h-full w-1/3 animate-pulse rounded-full bg-primary' : 'h-full rounded-full bg-primary transition-[width]'}
        style={fraction === null ? undefined : { width: `${fraction * 100}%` }}
      />
    </div>
  );
}

function ExportPart() {
  const { t } = useTranslation();
  const harvest = useHarvest();
  const status = useSyncStatus();
  const id = useId();
  const placesOn = useSetting('features.places') === 'true';
  const includePlaces = useSetting(exportIncludesPlacesKey) !== 'false';
  const [state, setState] = useState<ExportState>({ kind: 'idle' });
  const [unlocking, setUnlocking] = useState(false);
  const cancelled = useRef(false);
  const running = state.kind === 'running';

  const setIncludePlaces = (on: boolean) =>
    void harvest.writer.run((tx) => tx.put('kv_settings', { key: exportIncludesPlacesKey, valueJson: JSON.stringify(on), updatedAt: tx.now() }));

  async function run() {
    if (running) return;
    cancelled.current = false;
    setState({ kind: 'running', progress: null });
    try {
      const { buildArchive, ArchiveCancelled } = await import('../data/export');
      try {
        const built = await buildArchive(harvest.db, (hash) => harvest.files.get(hash), {
          now: harvest.clock(),
          includePlaces,
          onProgress: (progress) => setState({ kind: 'running', progress }),
          cancelled: () => cancelled.current,
        });
        save(built.bytes as Uint8Array<ArrayBuffer>, built.fileName);
        setState({ kind: 'saved', name: built.fileName, sealed: built.sealed, missing: built.missingFiles });
      } catch (error) {
        setState(error instanceof ArchiveCancelled ? { kind: 'stopped' } : { kind: 'failed' });
      }
    } catch {
      setState({ kind: 'failed' });
    }
  }

  const progress = state.kind === 'running' ? state.progress : null;
  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-start gap-3">
        <FileArchiveIcon className="mt-0.5 size-5 shrink-0 text-muted-foreground" aria-hidden />
        <div className="flex flex-col gap-1">
          <h3 className="font-bold">{t('data.export.title')}</h3>
          <p className="text-sm text-muted-foreground">{t('data.export.body')}</p>
        </div>
      </div>
      {placesOn && (
        <div className="flex items-center justify-between gap-3">
          <div className="flex flex-col">
            <Label htmlFor={`${id}-places`}>{t('data.export.includePlaces')}</Label>
            <span id={`${id}-places-hint`} className="text-xs text-muted-foreground">
              {t('data.export.includePlacesHint')}
            </span>
          </div>
          <Switch
            id={`${id}-places`}
            aria-describedby={`${id}-places-hint`}
            checked={includePlaces}
            disabled={running}
            onCheckedChange={setIncludePlaces}
          />
        </div>
      )}
      {status.sealed > 0 && (
        <div className="flex flex-col gap-2 rounded-lg bg-muted/60 p-3 text-sm sm:flex-row sm:items-center sm:justify-between">
          <span>{t('data.export.sealed', { count: status.sealed })}</span>
          <Button variant="outline" size="sm" className="shrink-0" onClick={() => setUnlocking(true)}>
            <KeyRoundIcon />
            {t('settings.enterPassphrase')}
          </Button>
        </div>
      )}
      <div className="flex flex-wrap items-center gap-2">
        <Button onClick={() => void run()} disabled={running}>
          {running ? <Loader2Icon className="animate-spin" /> : <DownloadIcon />}
          {running ? t('data.export.running') : t('data.export.action')}
        </Button>
        {running && (
          <Button variant="ghost" onClick={() => (cancelled.current = true)}>
            {t('common.cancel')}
          </Button>
        )}
      </div>
      {running && (
        <div className="flex flex-col gap-1">
          <Progress fraction={progress && progress.total > 0 ? progress.done / progress.total : null} label={t('data.export.running')} />
          <span className="text-xs text-muted-foreground tabular">
            {progress ? t('data.progress', { done: progress.done, total: progress.total }) : t('data.export.preparing')}
          </span>
        </div>
      )}
      <div role="status" aria-live="polite" className="flex flex-col gap-1 text-sm font-semibold empty:hidden">
        {state.kind === 'saved' && (
          <>
            <span>{t('data.export.saved', { name: state.name })}</span>
            {state.missing > 0 && <span className="font-normal text-muted-foreground">{t('data.export.missing', { count: state.missing })}</span>}
            {state.sealed > 0 && <span className="font-normal text-muted-foreground">{t('data.export.sealed', { count: state.sealed })}</span>}
          </>
        )}
        {state.kind === 'stopped' && <span>{t('data.export.stopped')}</span>}
        {state.kind === 'failed' && <span className="text-destructive">{t('data.export.failed')}</span>}
      </div>
      {unlocking && (
        <Dialog open onOpenChange={(open) => !open && setUnlocking(false)}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>{t('passphrase.title')}</DialogTitle>
              <DialogDescription className="sr-only">{t('passphrase.lead')}</DialogDescription>
            </DialogHeader>
            <PassphrasePrompt onUnlocked={() => setUnlocking(false)} />
          </DialogContent>
        </Dialog>
      )}
    </div>
  );
}

function ImportPart() {
  const { t } = useTranslation();
  const { writer, files } = useHarvest();
  const id = useId();
  const input = useRef<HTMLInputElement>(null);
  const [state, setState] = useState<ImportState>({ kind: 'idle' });
  const busy = state.kind === 'reading' || state.kind === 'applying';

  async function choose(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file || busy) return;
    // Weighed before it is read: a file too big to hold is refused unread.
    if (file.size > ArchiveLimits.archiveBytes) {
      setState({ kind: 'failed', problem: 'tooLarge' });
      return;
    }
    setState({ kind: 'reading' });
    try {
      const { openArchive, previewImport } = await import('../data/import');
      const bundle = openArchive(new Uint8Array(await file.arrayBuffer()));
      const preview = await previewImport(writer, bundle);
      setState({ kind: 'ready', name: file.name, bundle, preview });
    } catch (error) {
      setState({ kind: 'failed', problem: error instanceof ArchiveInvalid ? error.problem : null });
    }
  }

  async function apply(bundle: ArchiveBundle) {
    setState({ kind: 'applying', progress: null });
    try {
      const { applyImport } = await import('../data/import');
      const preview = await applyImport(writer, bundle, {
        onProgress: (progress) => setState({ kind: 'applying', progress }),
        files,
      });
      setState({ kind: 'done', preview });
    } catch {
      setState({ kind: 'failed', problem: null });
    }
  }

  const progress = state.kind === 'applying' ? state.progress : null;
  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-start gap-3">
        <FolderOpenIcon className="mt-0.5 size-5 shrink-0 text-muted-foreground" aria-hidden />
        <div className="flex flex-col gap-1">
          <h3 id={`${id}-title`} className="font-bold">
            {t('data.import.title')}
          </h3>
          <p className="text-sm text-muted-foreground">{t('data.import.body')}</p>
        </div>
      </div>
      <input
        ref={input}
        id={`${id}-file`}
        type="file"
        accept=".zip,application/zip"
        className="sr-only"
        tabIndex={-1}
        aria-labelledby={`${id}-title`}
        onChange={(event) => void choose(event)}
      />
      <div>
        <Button variant="outline" disabled={busy} onClick={() => input.current?.click()}>
          {busy ? <Loader2Icon className="animate-spin" /> : <FolderOpenIcon />}
          {state.kind === 'applying' ? t('data.import.applying') : state.kind === 'reading' ? t('data.import.reading') : t('data.import.action')}
        </Button>
      </div>
      {state.kind === 'applying' && (
        <div className="flex flex-col gap-1">
          <Progress fraction={progress ? progress.done / progress.total : null} label={t('data.import.applying')} />
          {progress && (
            <span className="text-xs text-muted-foreground tabular">{t('data.progress', { done: progress.done, total: progress.total })}</span>
          )}
        </div>
      )}
      {state.kind === 'ready' && (
        <PreviewPanel
          name={state.name}
          preview={state.preview}
          onCancel={() => setState({ kind: 'idle' })}
          onConfirm={() => void apply(state.bundle)}
        />
      )}
      <div role="status" aria-live="polite" className="flex flex-col gap-1 text-sm font-semibold empty:hidden">
        {state.kind === 'done' && (
          <>
            <span>{t('data.import.done', totals(state.preview))}</span>
            {totals(state.preview).skipped > 0 && (
              <span className="font-normal text-muted-foreground">{t('data.import.skipped', { count: totals(state.preview).skipped })}</span>
            )}
          </>
        )}
        {state.kind === 'failed' && <span className="text-destructive">{t(`data.import.${state.problem ?? 'failed'}`)}</span>}
      </div>
    </div>
  );
}

/** What the archive would do, per sheet, before anything is written (ADR-007 rule 6). */
function PreviewPanel({
  name,
  preview,
  onCancel,
  onConfirm,
}: {
  name: string;
  preview: ImportPreview;
  onCancel: () => void;
  onConfirm: () => void;
}) {
  const { t } = useTranslation();
  const total = totals(preview);
  // Sheets that would do nothing are left out: a preview is for reading.
  const changed = Object.entries(preview.tables).filter(([, count]) => count.added > 0 || count.updated > 0);
  return (
    <div className="flex flex-col gap-3 rounded-xl bg-muted/60 p-4">
      <div className="flex min-w-0 flex-col gap-0.5">
        <span className="truncate font-extrabold" dir="auto">
          {name}
        </span>
        <span className="text-sm">{t('data.import.summary', total)}</span>
        {preview.files > 0 && (
          <span className="text-xs text-muted-foreground">
            {preview.newFiles === 0
              ? t('data.import.filesNone', { files: preview.files })
              : t('data.import.files', { count: preview.newFiles, files: preview.files })}
          </span>
        )}
        {total.skipped > 0 && <span className="text-xs text-muted-foreground">{t('data.import.skipped', { count: total.skipped })}</span>}
      </div>
      {changed.length === 0 ? (
        <p className="text-sm text-muted-foreground">{t('data.import.nothingToDo')}</p>
      ) : (
        <ul className="flex flex-col gap-1 border-t pt-2 text-sm">
          {changed.map(([sheet, count]) => (
            <li key={sheet} className="flex items-center justify-between gap-3">
              <span>{t(`data.sheet.${sheet}`, { defaultValue: sheet })}</span>
              <span className="text-xs text-muted-foreground tabular" aria-hidden dir="ltr">
                {t('data.import.rowCounts', { added: count.added, updated: count.updated })}
              </span>
              <span className="sr-only">{t('data.import.rowCountsLabel', { added: count.added, updated: count.updated })}</span>
            </li>
          ))}
        </ul>
      )}
      <p className="text-xs text-muted-foreground">{t('data.import.neverDeletes')}</p>
      <div className="flex flex-wrap justify-end gap-2">
        <Button variant="ghost" onClick={onCancel}>
          {t('common.cancel')}
        </Button>
        <Button onClick={onConfirm} disabled={changed.length === 0}>
          {t('data.import.confirm')}
        </Button>
      </div>
    </div>
  );
}

/** The "My data" section of Settings. */
export function DataCard() {
  const { t } = useTranslation();
  const id = useId();
  return (
    <section aria-labelledby={id} className="flex flex-col gap-5 rounded-2xl border bg-card p-5">
      <h2 id={id} className="text-lg font-extrabold">
        {t('data.title')}
      </h2>
      <ExportPart />
      <div className="border-t" aria-hidden />
      <ImportPart />
    </section>
  );
}
