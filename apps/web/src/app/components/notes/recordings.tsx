import { useLiveQuery } from 'dexie-react-hooks';
import { DownloadIcon, MicIcon, SparklesIcon } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { useHarvest } from '../../context';
import { audioEmbedsIn, type AttachmentRow } from '../../data/attachments';
import { useRowFile } from '../gallery/memory-media';

/** `mm:ss`, as the recorder's clock shows it. */
export function formatClock(ms: number): string {
  const seconds = Math.max(0, Math.floor(ms / 1000));
  return `${String(Math.floor(seconds / 60)).padStart(2, '0')}:${String(seconds % 60).padStart(2, '0')}`;
}

/**
 * One recording, playable and downloadable, or a line saying it is on
 * another device when its file has not reached this browser. Transcribe
 * is offered only for a file that is here (N10).
 */
export function RecordingPlayer({
  attachment,
  onTranscribe,
}: {
  attachment: AttachmentRow;
  onTranscribe?: ((attachment: AttachmentRow) => void) | undefined;
}) {
  const { t } = useTranslation();
  const { url } = useRowFile(attachment.uuid, attachment.fileHash);
  return (
    <li className="flex flex-wrap items-center gap-2 rounded-xl border bg-card p-2 ps-3">
      <MicIcon className="size-4 shrink-0 text-muted-foreground" aria-hidden />
      <div className="flex min-w-0 flex-1 flex-col">
        <span className="truncate text-sm font-semibold" dir="auto">
          {attachment.fileName}
        </span>
        {attachment.durationMs !== null && (
          <span className="text-xs text-muted-foreground tabular">{formatClock(attachment.durationMs)}</span>
        )}
      </div>
      {url ? (
        <>
          <audio src={url} controls preload="metadata" className="h-9 w-full max-w-72" aria-label={attachment.fileName} />
          <Button asChild variant="ghost" size="icon-sm">
            <a href={url} download={attachment.fileName} aria-label={t('voice.download', { name: attachment.fileName })}>
              <DownloadIcon />
            </a>
          </Button>
          {onTranscribe && (
            <Button
              variant="ghost"
              size="icon-sm"
              aria-label={t('voice.transcribe', { name: attachment.fileName })}
              title={t('assist.actions.transcribe')}
              onClick={() => onTranscribe(attachment)}
            >
              <SparklesIcon />
            </Button>
          )}
        </>
      ) : url === null ? (
        <span className="text-xs text-muted-foreground">{t('voice.missing')}</span>
      ) : null}
    </li>
  );
}

/**
 * A note's recordings, in the order its body embeds them and only
 * while it does: the embed line is the truth (N7).
 */
export function Recordings({
  noteUuid,
  body,
  onTranscribe,
}: {
  noteUuid: string;
  body: string;
  /** Offered on each recording when the server's assist can transcribe. */
  onTranscribe?: ((attachment: AttachmentRow) => void) | undefined;
}) {
  const { t } = useTranslation();
  const { db } = useHarvest();
  const rows = useLiveQuery(
    () => db.rows('note_attachments').where('noteUuid').equals(noteUuid).toArray(),
    [db, noteUuid],
  );
  if (!rows) return null;
  const byName = new Map(rows.map((row) => [row.fileName.toLowerCase(), row]));
  const seen = new Set<string>();
  const shown: AttachmentRow[] = [];
  for (const name of audioEmbedsIn(body)) {
    const row = byName.get(name.toLowerCase());
    if (!row || seen.has(row.uuid)) continue;
    seen.add(row.uuid);
    shown.push(row);
  }
  if (shown.length === 0) return null;
  return (
    <section aria-labelledby={`recordings-${noteUuid}`} className="flex flex-col gap-2">
      <h2 id={`recordings-${noteUuid}`} className="text-sm font-extrabold">
        {t('voice.recordings')}
      </h2>
      <ul className="flex flex-col gap-2">
        {shown.map((row) => (
          <RecordingPlayer key={row.uuid} attachment={row} onTranscribe={onTranscribe} />
        ))}
      </ul>
    </section>
  );
}
