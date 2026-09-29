import type { StoredTable } from '../db';
import { spec, uuidOf, text, at, updated, type Spec } from './sheet-spec';

/** Records: the notes and the albums (their files are planned apart). */
export const recordSheets: Spec<StoredTable>[] = [
  spec({
    sheet: 'notes',
    table: 'notes',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now, bodies }) => ({
      uuid: row.Uuid,
      title: row.Title ?? '',
      folder: row.Folder ?? '',
      // The `.md` wins over the cell: the vault may have been edited in
      // a text editor, and rule N4 says that has to survive.
      body: bodies.get(row.File ?? '') ?? row.Body ?? '',
      createdAt: at(row.CreatedAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
  spec({
    sheet: 'albums',
    table: 'albums',
    keyOf: uuidOf,
    stamp: updated,
    build: (row, { now }) => ({
      uuid: row.Uuid,
      name: row.Name ?? '',
      scheduleJson: text(row.ScheduleJson),
      remindAt: text(row.RemindAt),
      note: text(row.Note),
      createdAt: at(row.CreatedAt) ?? now,
      updatedAt: at(row.UpdatedAt) ?? now,
      deletedAt: at(row.DeletedAt),
    }),
  }),
];
