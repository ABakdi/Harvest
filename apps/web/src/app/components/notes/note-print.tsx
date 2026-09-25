import { useEffect } from 'react';
import { createPortal } from 'react-dom';
import { useTranslation } from 'react-i18next';
import { formatDate } from '@/lib/format';
import { Markdown } from '@/lib/markdown';
import { safeFileName } from '../../data/archive';
import type { NoteRow } from '../../data/notes';

/** The name the browser offers when the page is saved as a PDF (`pdfFileName`). */
export function pdfTitle(note: Pick<NoteRow, 'title'>, untitled: string): string {
  return safeFileName(note.title.trim() || untitled);
}

/** Only the note is printed: the app around it is not the page anyone asked for. */
const printStyle = `
@media screen { .harvest-print { display: none; } }
@media print {
  body > *:not(.harvest-print) { display: none !important; }
  .harvest-print { display: block; color: #000; background: #fff; padding: 0; }
  @page { size: A4; margin: 18mm 17mm; }
}`;

/**
 * A note as a page somebody else can read (the phone's `noteToPdf`):
 * the markdown rendered rather than dumped, under its title with the
 * folder and the day. The browser's own print dialog saves it as a PDF;
 * nothing is sent anywhere to make it.
 */
export function NotePrint({ note, onDone }: { note: NoteRow; onDone: () => void }) {
  const { t, i18n } = useTranslation();
  const title = note.title.trim() || t('notes.untitled');
  const when = formatDate(note.updatedAt, { dateStyle: 'long' });
  const subtitle = note.folder ? `${note.folder} · ${when}` : when;

  useEffect(() => {
    const before = document.title;
    document.title = pdfTitle(note, t('notes.untitled'));
    // After the portal has painted, so the dialog prints this page.
    const timer = setTimeout(() => {
      try {
        window.print();
      } finally {
        document.title = before;
        onDone();
      }
    }, 50);
    return () => {
      clearTimeout(timer);
      document.title = before;
    };
  }, [note, onDone, t]);

  return createPortal(
    <div className="harvest-print" dir={i18n.dir()} data-testid="note-print">
      <style>{printStyle}</style>
      <h1 className="text-3xl font-extrabold">{title}</h1>
      <p className="mb-4 text-sm text-neutral-600">{subtitle}</p>
      <Markdown source={note.body} />
    </div>,
    document.body,
  );
}
