/**
 * Editors with unsaved typing register a flush here, so a reload the
 * update toast asks for saves first (W4: an update never costs an edit).
 */
const flushers = new Set<() => Promise<void> | void>();

export function registerPendingEdit(flush: () => Promise<void> | void): () => void {
  flushers.add(flush);
  return () => flushers.delete(flush);
}

export async function flushPendingEdits(): Promise<void> {
  await Promise.all(
    [...flushers].map(async (flush) => {
      await flush();
    }),
  );
}
