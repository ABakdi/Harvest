/**
 * A path a row names inside the device's own storage (a memory's
 * `path`, a recording's `storedPath`): relative, forward slashes, no
 * `.`/`..`/empty segment, nothing a device joining it onto its storage
 * directory could turn into a path outside it (S6-08). The phone
 * (`GalleryStorage.isSafeRelative`) and the web (`archive.ts`) hold the
 * same rule.
 */
export function isSafeRelativePath(relative: string): boolean {
  if (relative === '' || relative.length > 512) return false;
  if (relative.includes('\\') || relative.includes(':')) return false;
  if (relative.startsWith('/')) return false;
  return relative.split('/').every((segment) => segment !== '' && segment !== '.' && segment !== '..');
}

/** The columns that name such a path, by table. */
export const storagePathColumns: Readonly<Record<string, string>> = {
  memories: 'path',
  note_attachments: 'storedPath',
};
