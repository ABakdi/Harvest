import { maxFileBytes, openFile, sealFile } from '@harvest/contracts';
import { ApiError, api } from '@/lib/api';
import { getMeta, setMeta, type HarvestDB } from './db';
import type { Writer } from './writer';
import type { Keyring } from '../sync/keyring';

/** The file routes, as this browser needs them ([[Sync-API]], files). */
export type FileRemote = Pick<typeof api, 'file' | 'filesMissing' | 'putFile'> & Partial<Pick<typeof api, 'forgetFile'>>;

/** The two tables whose rows name a file. */
export type FileTable = 'memories' | 'note_attachments';

/** A file made in this browser that the server may not have yet. */
export interface PendingUpload {
  table: FileTable;
  uuid: string;
  sha256: string;
  /**
   * The row already names this file, but nothing says the server has
   * it: an archive brought it in. It is asked about like any other, and
   * its row is left as it is once the server has it.
   */
  check?: boolean;
}

const uploadsKey = 'fileUploads';

/**
 * Every row whose file is still only in this browser, by uuid: its
 * hash, which the row itself carries only once the server has it.
 */
export async function localFileHashes(db: HarvestDB): Promise<Map<string, string>> {
  const waiting = (await getMeta<PendingUpload[]>(db, uploadsKey)) ?? [];
  return new Map(waiting.map((entry) => [entry.uuid, entry.sha256]));
}

/** How many files one pass carries, as on the phone (`FileSync.batch`). */
const uploadBatch = 20;

/** A file past the server's 25 MB, refused before it is kept. */
export class FileTooLargeError extends Error {
  override readonly name = 'FileTooLargeError';

  constructor(readonly bytes: number) {
    super(`A file may be ${maxFileBytes} bytes; this one is ${bytes}`);
  }
}

/** What one upload pass did. */
export interface UploadReport {
  uploaded: number;
  /** Rows that now carry their file's hash. */
  stamped: number;
  /** Files still only in this browser. */
  waiting: number;
  quotaExceeded: boolean;
}

/** Why files are not leaving this browser, when something says so. */
export type FileProblem = 'quota' | null;

/**
 * Why a file could not be had here ([[Gallery]] G9): the server does
 * not have it yet (*still on the phone*), this browser has no sync PIN
 * to open it, or asking for it failed — no connection, too slow, or
 * bytes that are not the file — and it is worth trying again.
 */
export type FileMiss = 'onPhone' | 'locked' | 'failed';

/** How long a file may take to arrive before it counts as failed. */
export const fileFetchTimeoutMs = 30_000;

/**
 * Pictures and recordings, fetched by the name of their own bytes and
 * sent the same way ([[Sync-API]], files).
 *
 * What comes back is opened with the private tier's key and hashed
 * again: bytes that do not hash to the name they came under are not
 * the file the row means, and are thrown away rather than shown.
 *
 * What is made here is kept here first (W1): the bytes go into the same
 * store a fetched file lands in, and the row waits with no hash until
 * the server has them. Like the phone's `FileSync`, a row is stamped
 * only once the file is there to be fetched, so another device never
 * asks for a name nobody has uploaded. A file never holds up a row.
 */
export class FileStore {
  private readonly pending = new Map<string, Promise<Blob | FileMiss>>();
  private readonly listeners = new Set<() => void>();
  private uploading: Promise<UploadReport> | null = null;
  private again: Promise<UploadReport> | null = null;
  private problemNow: FileProblem = null;
  /** How long a fetch may take; a test shortens it. */
  timeoutMs = fileFetchTimeoutMs;

  constructor(
    private readonly db: HarvestDB,
    private readonly keyring: Keyring,
    private readonly salt: () => string,
    private readonly writer: Writer | null = null,
    private readonly remote: FileRemote = api,
  ) {}

  /** The file, from this browser or the server; null when it cannot be had. */
  async get(sha256: string): Promise<Blob | null> {
    const found = await this.find(sha256);
    return typeof found === 'string' ? null : found;
  }

  /** The file, or why it cannot be had here ([[Gallery]] G9). */
  async find(sha256: string): Promise<Blob | FileMiss> {
    const held = await this.db.files.get(sha256);
    if (held) return held.blob;
    const running = this.pending.get(sha256);
    if (running) return running;
    const fetching = this.fetch(sha256).finally(() => this.pending.delete(sha256));
    this.pending.set(sha256, fetching);
    return fetching;
  }

  private async fetch(sha256: string): Promise<Blob | FileMiss> {
    const key = await this.keyring.key(this.salt());
    if (!key) return 'locked';
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      // A request that never answers would leave a frame loading for
      // good: past the timeout it is a failure, with *Try again*.
      const late = new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error('timeout')), this.timeoutMs);
      });
      const { sealed, iv } = await Promise.race([this.remote.file(sha256), late]);
      const plain = await openFile(key, sha256, { iv, ct: sealed });
      const bytes = plain.slice().buffer;
      if ((await sha256Of(bytes)) !== sha256) return 'failed';
      const blob = new Blob([bytes]);
      await this.db.files.put({ sha256, blob, fetchedAt: new Date().toISOString() });
      return blob;
    } catch (failure) {
      // The server has no such file: the phone has not sent it yet.
      if (failure instanceof ApiError && failure.status === 404) return 'onPhone';
      // No connection, too slow, or not ours to open.
      return 'failed';
    } finally {
      clearTimeout(timer);
    }
  }

  // ------------------------------------------------------------ keeping

  /**
   * Keeps a new file in this browser, by the name of its bytes, and
   * says what that name is. Past 25 MB it is refused here, since the
   * server would refuse it anyway ([[Sync-API]], files).
   */
  async keep(blob: Blob): Promise<{ sha256: string; size: number }> {
    if (blob.size > maxFileBytes) throw new FileTooLargeError(blob.size);
    const bytes = await blob.arrayBuffer();
    const sha256 = await sha256Of(bytes);
    await this.db.files.put({ sha256, blob: new Blob([bytes], { type: blob.type }), fetchedAt: new Date().toISOString() });
    return { sha256, size: bytes.byteLength };
  }

  /** Marks [uuid]'s file as one to send; the row is written by its repository. */
  async queue(table: FileTable, uuid: string, sha256: string): Promise<void> {
    await this.db.transaction('rw', this.db.meta, async () => {
      const list = await this.waiting();
      await setMeta(this.db, uploadsKey, [...list.filter((entry) => entry.uuid !== uuid), { table, uuid, sha256 }]);
    });
  }

  /**
   * Marks many files at once as ones to send: what an archive brings in
   * is a file the server may never have seen, as the phone's pass would
   * find it on disk and ask about it (`FileSync._locals`).
   */
  async queueAll(entries: PendingUpload[]): Promise<void> {
    if (entries.length === 0) return;
    const uuids = new Set(entries.map((entry) => entry.uuid));
    await this.db.transaction('rw', this.db.meta, async () => {
      const list = await this.waiting();
      await setMeta(this.db, uploadsKey, [...list.filter((entry) => !uuids.has(entry.uuid)), ...entries]);
    });
  }

  /** The hash of a file made here that its row does not carry yet. */
  async localHash(uuid: string): Promise<string | null> {
    return (await this.waiting()).find((entry) => entry.uuid === uuid)?.sha256 ?? null;
  }

  /** Every row whose file is still only in this browser, by uuid. */
  localHashes(): Promise<Map<string, string>> {
    return localFileHashes(this.db);
  }

  /**
   * Forgets [sha256]'s bytes in this browser when no row that is left
   * names them: what emptying a trash does to the file (G5). The copy on
   * the server is the account's, and goes with it.
   */
  async release(uuid: string, sha256: string | null): Promise<void> {
    await this.db.transaction('rw', this.db.meta, async () => {
      const list = await this.waiting();
      await setMeta(
        this.db,
        uploadsKey,
        list.filter((entry) => entry.uuid !== uuid),
      );
    });
    if (!sha256) return;
    const [memories, attachments, waiting] = await Promise.all([
      this.db.rows('memories').toArray(),
      this.db.rows('note_attachments').toArray(),
      this.waiting(),
    ]);
    const named =
      memories.some((row) => row.fileHash === sha256) ||
      attachments.some((row) => row.fileHash === sha256) ||
      waiting.some((entry) => entry.sha256 === sha256);
    if (!named) await this.db.files.delete(sha256);
  }

  /**
   * A row another device purged is gone here too: its bytes go with it
   * unless another row still names them, and when no row here names the
   * hash, the server is told it can let the file go (Q5-23). A `409`
   * there means another row on the server still names it, and it stays.
   */
  async releasePurged(table: string, row: Record<string, unknown>): Promise<void> {
    if (table !== 'memories' && table !== 'note_attachments') return;
    const sha256 = typeof row.fileHash === 'string' ? row.fileHash : null;
    await this.release(String(row.uuid), sha256);
    if (!sha256 || !this.remote.forgetFile) return;
    const [memories, attachments] = await Promise.all([
      this.db.rows('memories').toArray(),
      this.db.rows('note_attachments').toArray(),
    ]);
    if (memories.some((one) => one.fileHash === sha256) || attachments.some((one) => one.fileHash === sha256)) return;
    await this.remote.forgetFile(sha256);
  }

  /**
   * Lets go of bytes no row names any more: a recording whose note was
   * emptied from the trash, a picture purged elsewhere (Q5-23). Only
   * bytes kept here for an hour or more go, so a file kept a moment
   * before its row is written is never swept from under it.
   */
  async sweepOrphans(): Promise<number> {
    const [memories, attachments, waiting, held] = await Promise.all([
      this.db.rows('memories').toArray(),
      this.db.rows('note_attachments').toArray(),
      this.waiting(),
      this.db.files.toArray(),
    ]);
    const named = new Set<string>();
    for (const row of memories) if (row.fileHash) named.add(row.fileHash);
    for (const row of attachments) if (row.fileHash) named.add(row.fileHash);
    for (const entry of waiting) named.add(entry.sha256);
    const hourAgo = Date.now() - 60 * 60_000;
    const orphans = held
      .filter((file) => !named.has(file.sha256) && Date.parse(file.fetchedAt) < hourAgo)
      .map((file) => file.sha256);
    if (orphans.length > 0) await this.db.files.bulkDelete(orphans);
    return orphans.length;
  }

  /**
   * After a new key, every file this browser holds is asked about again
   * and sent sealed under it: the server may have none of them any more
   * ([[Accounts]], start over).
   */
  async requeueHeld(): Promise<void> {
    const [memories, attachments] = await Promise.all([
      this.db.rows('memories').toArray(),
      this.db.rows('note_attachments').toArray(),
    ]);
    const entries: PendingUpload[] = [];
    for (const [table, rows] of [
      ['memories', memories],
      ['note_attachments', attachments],
    ] as const) {
      for (const row of rows) {
        if (!row.fileHash || row.deletedAt !== null) continue;
        if (!(await this.db.files.get(row.fileHash))) continue;
        entries.push({ table, uuid: row.uuid, sha256: row.fileHash, check: true });
      }
    }
    await this.queueAll(entries);
  }

  private async waiting(): Promise<PendingUpload[]> {
    return (await getMeta<PendingUpload[]>(this.db, uploadsKey)) ?? [];
  }

  // ------------------------------------------------------------ sending

  get problem(): FileProblem {
    return this.problemNow;
  }

  /** Hears the upload's problem change, for the screens that show it. */
  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  private setProblem(problem: FileProblem): void {
    if (problem === this.problemNow) return;
    this.problemNow = problem;
    for (const listener of this.listeners) listener();
  }

  /**
   * One pass at a time. A call during a pass gets one more pass after
   * it, so a file kept while a pass was running is never left behind.
   */
  upload(): Promise<UploadReport> {
    if (this.uploading) {
      this.again ??= this.uploading.then(() => {
        this.again = null;
        return this.upload();
      });
      return this.again;
    }
    const run = this.uploadOnce().finally(() => {
      this.uploading = null;
    });
    this.uploading = run;
    return run;
  }

  /**
   * Asks what the server lacks, sends it sealed, and stamps the rows
   * (`FileSync._upload`). Files go sealed or not at all, so nothing
   * moves before the passphrase is set. A file that fails stays here
   * and is tried on the next pass.
   */
  private async uploadOnce(): Promise<UploadReport> {
    const report: UploadReport = { uploaded: 0, stamped: 0, waiting: 0, quotaExceeded: false };
    const list = await this.waiting();
    if (list.length === 0) return report;

    // Rows gone for good take their entry with them; a row in the trash
    // keeps it, and is sent if it comes back.
    const live: PendingUpload[] = [];
    const dropped = new Set<string>();
    // Rows that already carry the name, and only need the file sent.
    const named = new Set<string>();
    for (const entry of list) {
      const row = await this.db.rows(entry.table).get(entry.uuid);
      const held = await this.db.files.get(entry.sha256);
      if (!row || !held || (row.fileHash === entry.sha256 && !entry.check)) dropped.add(entry.uuid);
      // Past 25 MB the server refuses it: it stays here, and only here.
      else if (row.deletedAt === null && held.blob.size <= maxFileBytes) {
        live.push(entry);
        if (row.fileHash === entry.sha256) named.add(entry.uuid);
      }
    }
    if (dropped.size > 0) await this.forgetEntries(dropped);
    report.waiting = list.length - dropped.size;

    const key = await this.keyring.key(this.salt());
    if (!key || !this.writer || live.length === 0) return report;

    const taken = live.slice(0, uploadBatch);
    const hashes = [...new Set(taken.map((entry) => entry.sha256))];
    // Whatever reaches the server counts, even when a later file fails.
    const held = new Set<string>();
    try {
      const { missing } = await this.remote.filesMissing(hashes);
      const wanted = new Set(missing);
      for (const hash of hashes) if (!wanted.has(hash)) held.add(hash);
      for (const hash of missing) {
        const file = await this.db.files.get(hash);
        if (!file) continue;
        try {
          const bytes = new Uint8Array(await file.blob.arrayBuffer());
          const sealed = await sealFile(key, hash, bytes);
          await this.remote.putFile(hash, sealed.sealed, sealed.iv, bytes.byteLength);
          held.add(hash);
          report.uploaded += 1;
        } catch (error) {
          // No room is everyone's problem; anything else is this file's,
          // and the others still go (Q5-06).
          if (error instanceof ApiError && error.code === 'quota_exceeded') throw error;
        }
      }
      this.setProblem(null);
    } catch (error) {
      // An account with no room left is said out loud; anything else
      // (offline, a server hiccup) is simply tried again next time.
      if (error instanceof ApiError && error.code === 'quota_exceeded') {
        report.quotaExceeded = true;
        this.setProblem('quota');
      }
    }

    // Stamped whether or not this browser did the sending: the server
    // has the file either way, and the hash is what says so. The clock
    // moves so the row travels again and wins over its older copy.
    const done = taken.filter((entry) => held.has(entry.sha256));
    if (done.length > 0) {
      await this.writer.run(async (tx) => {
        for (const entry of done) {
          if (named.has(entry.uuid)) continue;
          await tx.patch(entry.table, entry.uuid, { fileHash: entry.sha256, updatedAt: tx.now() });
        }
      });
      await this.forgetEntries(new Set(done.map((entry) => entry.uuid)));
      report.stamped = done.length;
      report.waiting -= done.length;
    }
    return report;
  }

  private async forgetEntries(uuids: Set<string>): Promise<void> {
    await this.db.transaction('rw', this.db.meta, async () => {
      const list = await this.waiting();
      await setMeta(
        this.db,
        uploadsKey,
        list.filter((entry) => !uuids.has(entry.uuid)),
      );
    });
  }

  /**
   * Sends what is waiting after every sync and as soon as the
   * passphrase is entered, the two moments the phone's file pass runs.
   */
  follow(engine: { status: { lastSyncedAt: string | null }; subscribe(listener: () => void): () => void }): () => void {
    let last = engine.status.lastSyncedAt;
    const kick = () => void this.upload().catch(() => undefined);
    const offSync = engine.subscribe(() => {
      if (engine.status.lastSyncedAt === last) return;
      last = engine.status.lastSyncedAt;
      kick();
      void this.sweepOrphans().catch(() => undefined);
    });
    const offUnlock = this.keyring.onUnlock(kick);
    kick();
    return () => {
      offSync();
      offUnlock();
    };
  }
}

/** The name a file's bytes give themselves. */
export async function sha256Of(bytes: ArrayBuffer): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}
