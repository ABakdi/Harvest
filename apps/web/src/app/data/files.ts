import { fileNameOf, maxFileBytes, openFileAny, sealFileV3 } from '@harvest/contracts';
import { background } from '@/lib/actions';
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
  /** An upload was refused for a stale key epoch; the key here was forgotten. */
  keyChanged?: boolean;
}

/**
 * The types a file here may carry (S6-17): what a picture, a clip or a
 * recording plays as, never a page or an image that runs script. The
 * bytes say which; a file that is none of these stays untyped.
 */
const playableTypes = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
  'image/heic',
  'video/mp4',
  'video/webm',
  'video/quicktime',
  'audio/mp4',
  'audio/mpeg',
  'audio/ogg',
  'audio/webm',
  'audio/wav',
  'audio/aac',
]);

const untyped = 'application/octet-stream';

/** The type [bytes] play as, from their first bytes, or [claimed] when that is one of ours. */
export function playableType(bytes: Uint8Array, claimed = ''): string {
  const at = (offset: number, text: string) =>
    [...text].every((char, i) => bytes[offset + i] === char.charCodeAt(0));
  const own = claimed.split(';')[0]!.trim().toLowerCase();
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'image/jpeg';
  if (bytes[0] === 0x89 && at(1, 'PNG')) return 'image/png';
  if (at(0, 'GIF8')) return 'image/gif';
  if (at(0, 'RIFF') && at(8, 'WEBP')) return 'image/webp';
  if (at(0, 'RIFF') && at(8, 'WAVE')) return 'audio/wav';
  if (at(0, 'OggS')) return 'audio/ogg';
  if (bytes[0] === 0x1a && bytes[1] === 0x45 && bytes[2] === 0xdf && bytes[3] === 0xa3) {
    return own.startsWith('audio/') ? 'audio/webm' : 'video/webm';
  }
  if (at(4, 'ftyp')) {
    if (at(8, 'heic') || at(8, 'heix') || at(8, 'mif1')) return 'image/heic';
    if (at(8, 'M4A ') || own === 'audio/mp4' || own === 'audio/x-m4a') return 'audio/mp4';
    if (at(8, 'qt  ')) return 'video/quicktime';
    return 'video/mp4';
  }
  if (at(0, 'ID3')) return 'audio/mpeg';
  return playableTypes.has(own) ? own : untyped;
}

/**
 * Why files are not leaving this browser, when something says so: the
 * account has no room, or a file keeps failing to go (Q6-14).
 */
export type FileProblem = 'quota' | 'failing' | null;

/** Failed sends of one file before it is said out loud. */
export const failuresBeforeSaying = 3;

/** How long a file that failed waits before the next try: doubling, up to an hour. */
export function retryAfterMs(failures: number): number {
  return Math.min(60_000 * 2 ** Math.max(0, failures - 1), 3_600_000);
}

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
 * Pictures and recordings, known here by the hash of their own bytes
 * and on the server by a keyed hash of it (`fileNameOf`, Phase 7), so
 * the server cannot tell which files an account holds ([[Sync-API]],
 * files). A file still stored under its plain hash, from before, is
 * fetched by that name when the keyed one is not there yet.
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
  /** Files whose sending failed, by hash: how often, and when to try again. */
  private readonly failures = new Map<string, { count: number; nextAt: number }>();
  /** The clock the back-off reads; a test moves it. */
  now: () => number = () => Date.now();
  /** Told when an upload was refused for a stale key epoch (S6-07). */
  onKeyChanged: (() => void) | null = null;

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
    const nameKey = await this.keyring.nameKey(this.salt());
    if (!key || !nameKey) return 'locked';
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      // A request that never answers would leave a frame loading for
      // good: past the timeout it is a failure, with *Try again*.
      const late = new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error('timeout')), this.timeoutMs);
      });
      const plain = await Promise.race([this.download(key, nameKey, sha256), late]);
      const bytes = plain.slice().buffer;
      if ((await sha256Of(bytes)) !== sha256) return 'failed';
      const blob = new Blob([bytes], { type: playableType(new Uint8Array(bytes, 0, Math.min(bytes.byteLength, 16))) });
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

  /**
   * A file's bytes from the server, opened: under its keyed name, or,
   * not there yet, under the plain hash it was stored by before Phase 7.
   */
  private async download(key: CryptoKey, nameKey: CryptoKey, sha256: string): Promise<Uint8Array> {
    const name = await fileNameOf(nameKey, sha256);
    try {
      const { sealed, iv } = await this.remote.file(name);
      return await openFileAny(key, name, { iv, ct: sealed });
    } catch (failure) {
      if (!(failure instanceof ApiError) || failure.status !== 404) throw failure;
      const { sealed, iv } = await this.remote.file(sha256);
      return await openFileAny(key, sha256, { iv, ct: sealed });
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
    const type = playableType(new Uint8Array(bytes, 0, Math.min(bytes.byteLength, 16)), blob.type);
    await this.db.files.put({ sha256, blob: new Blob([bytes], { type }), fetchedAt: new Date().toISOString() });
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
    const waiting = await this.waiting();
    if (!(await this.named(sha256)) && !waiting.some((entry) => entry.sha256 === sha256)) {
      await this.db.files.delete(sha256);
    }
  }

  /** Whether a row here names [sha256]: two indexed counts (Q6-22). */
  private async named(sha256: string): Promise<boolean> {
    const [memories, attachments] = await Promise.all([
      this.db.rows('memories').where('fileHash').equals(sha256).count(),
      this.db.rows('note_attachments').where('fileHash').equals(sha256).count(),
    ]);
    return memories + attachments > 0;
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
    if (await this.named(sha256)) return;
    const nameKey = await this.keyring.nameKey(this.salt());
    if (nameKey) await this.remote.forgetFile(await fileNameOf(nameKey, sha256));
    // A copy from before Phase 7, under the plain hash, goes too.
    await this.remote.forgetFile(sha256);
  }

  /**
   * Lets go of bytes no row names any more: a recording whose note was
   * emptied from the trash, a picture purged elsewhere (Q5-23). Only
   * bytes kept here for an hour or more go, so a file kept a moment
   * before its row is written is never swept from under it.
   */
  async sweepOrphans(): Promise<number> {
    // Only what has been here an hour is weighed, and each by its own two
    // indexed counts rather than a read of every row (Q6-22).
    const hourAgo = new Date(Date.now() - 60 * 60_000).toISOString();
    const old = await this.db.files.filter((file) => file.fetchedAt < hourAgo).primaryKeys();
    if (old.length === 0) return 0;
    const waiting = new Set((await this.waiting()).map((entry) => entry.sha256));
    const orphans: string[] = [];
    for (const sha256 of old) {
      if (!waiting.has(sha256) && !(await this.named(sha256))) orphans.push(sha256);
    }
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
      // A file asked about again goes even from the trash, which can
      // give its row back.
      else if ((row.deletedAt === null || entry.check) && held.blob.size <= maxFileBytes) {
        live.push(entry);
        if (row.fileHash === entry.sha256) named.add(entry.uuid);
      }
    }
    if (dropped.size > 0) await this.forgetEntries(dropped);
    report.waiting = list.length - dropped.size;

    const key = await this.keyring.key(this.salt());
    const nameKey = await this.keyring.nameKey(this.salt());
    const keyEpoch = await this.keyring.epoch();
    const keyId = await this.keyring.keyId();
    if (!key || !nameKey || keyEpoch === null || !this.writer || live.length === 0) return report;

    // A file that failed waits its turn, so one bad file is not re-read,
    // sealed and sent on every sync (Q6-14).
    const due = live.filter((entry) => (this.failures.get(entry.sha256)?.nextAt ?? 0) <= this.now());
    const taken = due.slice(0, uploadBatch);
    if (taken.length === 0) return report;
    const hashes = [...new Set(taken.map((entry) => entry.sha256))];
    // Asked about and sent under their names on the server, never their hashes.
    const hashOf = new Map<string, string>();
    for (const hash of hashes) hashOf.set(await fileNameOf(nameKey, hash), hash);
    // Whatever reaches the server counts, even when a later file fails.
    const held = new Set<string>();
    try {
      const { missing } = await this.remote.filesMissing([...hashOf.keys()]);
      const wanted = new Set(missing.map((name) => hashOf.get(name)));
      for (const hash of hashes) if (!wanted.has(hash)) held.add(hash);
      for (const name of missing) {
        const hash = hashOf.get(name);
        if (!hash) continue;
        const file = await this.db.files.get(hash);
        if (!file) continue;
        try {
          const bytes = new Uint8Array(await file.blob.arrayBuffer());
          const sealed = await sealFileV3(key, name, bytes);
          // The sealed length, less the tag: the padded length, not the file's.
          await this.remote.putFile(name, sealed.sealed, sealed.iv, sealed.sealed.byteLength - 16, keyEpoch);
          held.add(hash);
          this.failures.delete(hash);
          report.uploaded += 1;
        } catch (error) {
          // No room is everyone's problem; anything else is this file's,
          // and the others still go (Q5-06).
          if (error instanceof ApiError && error.code === 'quota_exceeded') throw error;
          // Sealed under a key started over elsewhere: nothing more goes up
          // under it, and the PIN is asked for again (S6-07).
          if (error instanceof ApiError && error.code === 'key_changed') {
            report.keyChanged = true;
            await this.keyring.forgetIfStill(keyId ?? undefined);
            this.onKeyChanged?.();
            break;
          }
          const count = (this.failures.get(hash)?.count ?? 0) + 1;
          this.failures.set(hash, { count, nextAt: this.now() + retryAfterMs(count) });
          console.warn(`[files] could not send ${hash.slice(0, 12)} (${count})`, error);
        }
      }
      const failing = [...this.failures.values()].some((failure) => failure.count >= failuresBeforeSaying);
      this.setProblem(failing ? 'failing' : null);
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

  /**
   * Phase 7's move for files (M7.1, M7.2): every file a row here names
   * that the server does not hold under its keyed name yet is fetched
   * from its old name when this browser does not have it, and queued to
   * go again under the new one. Answers whether every such file is
   * either here, queued, or already there.
   */
  async migrateLegacy(): Promise<boolean> {
    const nameKey = await this.keyring.nameKey(this.salt());
    if (!nameKey) return false;
    const rows: { table: FileTable; uuid: string; sha256: string }[] = [];
    for (const table of ['memories', 'note_attachments'] as const) {
      for (const row of await this.db.rows(table).toArray()) {
        if (row.fileHash) rows.push({ table, uuid: row.uuid, sha256: row.fileHash });
      }
    }
    if (rows.length === 0) return true;
    const byName = new Map<string, string>();
    for (const { sha256 } of rows) byName.set(await fileNameOf(nameKey, sha256), sha256);
    const names = [...byName.keys()];
    const missing = new Set<string>();
    // The server takes a few hundred names a question.
    for (let start = 0; start < names.length; start += 500) {
      const answer = await this.remote.filesMissing(names.slice(start, start + 500));
      for (const name of answer.missing) missing.add(byName.get(name)!);
    }
    if (missing.size === 0) return true;
    let settled = true;
    const entries: PendingUpload[] = [];
    for (const row of rows) {
      if (!missing.has(row.sha256)) continue;
      // Not here: fetched under the old name, opened and kept, to go again.
      if (!(await this.db.files.get(row.sha256))) {
        const found = await this.find(row.sha256);
        // On the server under neither name: nothing there to lose, and
        // the device that has it sends it under the new one.
        if (found === 'onPhone') continue;
        if (typeof found === 'string') {
          settled = false;
          continue;
        }
      }
      entries.push({ ...row, check: true });
    }
    await this.queueAll(entries);
    return settled;
  }

  /**
   * Sends every file that waits, pass after pass, and says whether none
   * is left: what the one-time sealing waits for before the server is
   * told everything went up (`SyncEngine`).
   */
  async settle(): Promise<boolean> {
    let migrated: boolean;
    try {
      migrated = await this.migrateLegacy();
    } catch {
      return false;
    }
    for (;;) {
      const before = await this.sendable();
      if (before === 0) return migrated;
      const report = await this.upload();
      if (report.quotaExceeded || report.keyChanged) return false;
      if ((await this.sendable()) >= before) return false;
    }
  }

  /** How many waiting files could still go: past 25 MB, one never will. */
  private async sendable(): Promise<number> {
    let count = 0;
    for (const entry of await this.waiting()) {
      const held = await this.db.files.get(entry.sha256);
      if (!held || held.blob.size <= maxFileBytes) count += 1;
    }
    return count;
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
      background(this.sweepOrphans());
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
