import { deriveSyncKeyV2, opensKeyCheck, sealKeyCheck, type KeyCheck, type SyncKeyResult } from '@harvest/contracts';
import { getMeta, metaKeys, setMeta, type HarvestDB } from '../data/db';

interface StoredKey {
  key: CryptoKey;
  /** The salt it was derived with: a key for another account is no key. */
  salt: string;
  /** Version 2 ([[Sync-API]]): a key kept by 3.0.0 is not one to use. */
  v: 2;
}

/** The key routes, as the keyring needs them ([[Sync-API]], sync key). */
export interface SyncKeyRemote {
  syncKey(): Promise<SyncKeyResult>;
  /** Null when this check is now the account's; the stored one when another device chose first. */
  putKeyCheck(check: KeyCheck): Promise<KeyCheck | null>;
  startOverSyncKey(password: string): Promise<void>;
}

/**
 * A secret the account's key check refused: not the account's PIN, or,
 * with [chosenElsewhere], another device chose the PIN a moment before.
 * Nothing was kept, and nothing was sealed with it.
 */
export class WrongPassphraseError extends Error {
  override readonly name = 'WrongPassphraseError';

  constructor(
    message: string,
    readonly chosenElsewhere = false,
  ) {
    super(message);
  }
}

/**
 * Where this browser keeps the private tier's key: in IndexedDB, as a
 * non-extractable CryptoKey, so the PIN is typed once per browser and
 * the key itself can never be read back out. The scheme is the
 * contract's version 2 (`deriveSyncKeyV2`, `sealRowV2`, `openRowV2`),
 * the same on the phone: the secret is never sent and never stored.
 *
 * Whether a secret is the account's is the account's key check to say,
 * on the server, never a guess from what this browser happens to have
 * pulled ([[Accounts]]): with no check stored, this browser chooses the
 * PIN and stores its check before it seals anything; with one, a PIN is
 * kept only if it opens it.
 */
export class Keyring {
  private cached: CryptoKey | null | undefined;
  private readonly listeners = new Set<() => void>();

  /**
   * Run once a new key is kept, before anything else hears of it: what
   * this browser holds goes up again under it (the engine's
   * `privateTierOpened`).
   */
  onNewKey: (() => Promise<void>) | null = null;

  constructor(
    private readonly db: HarvestDB,
    private readonly remote: SyncKeyRemote,
  ) {}

  async key(salt: string | null): Promise<CryptoKey | null> {
    if (this.cached !== undefined) return this.cached;
    const stored = await getMeta<StoredKey>(this.db, metaKeys.privateKeyV2);
    this.cached = stored && stored.v === 2 && (salt === null || stored.salt === salt) ? stored.key : null;
    return this.cached;
  }

  /** The account's salt, key share and check, as the server has them now. */
  share(): Promise<SyncKeyResult> {
    return this.remote.syncKey();
  }

  /**
   * Derives the key from [secret], checks it against the account's key
   * check (storing this one's when there is none) and keeps it. Throws
   * [WrongPassphraseError] with nothing kept when it is not the account's.
   */
  async unlock(secret: string, _salt?: string, iterations?: number): Promise<void> {
    const share = await this.remote.syncKey();
    const key = await deriveSyncKeyV2(
      secret,
      share.salt,
      share.keyShare,
      iterations === undefined ? {} : { iterations },
    );
    if (share.check) {
      if (!(await opensKeyCheck(key, share.check))) {
        throw new WrongPassphraseError('The sync secret does not open the key check');
      }
    } else {
      const first = await this.remote.putKeyCheck((await sealKeyCheck(key)) as KeyCheck);
      if (first && !(await opensKeyCheck(key, first))) {
        throw new WrongPassphraseError('Another device chose the sync PIN first', true);
      }
    }
    await this.db.meta.delete(metaKeys.privateKey);
    await setMeta(this.db, metaKeys.privateKeyV2, { key, salt: share.salt, v: 2 } satisfies StoredKey);
    this.cached = key;
    await this.onNewKey?.();
    this.tell();
  }

  /**
   * Whether the key kept here still opens the account's check. When it
   * does not — the PIN was started over on another device — it is
   * forgotten and the answer is false. Null with no key here, or no
   * answer from the server.
   */
  async stillTheAccounts(salt: string | null): Promise<boolean | null> {
    const key = await this.key(salt);
    if (!key) return null;
    let share: SyncKeyResult;
    try {
      share = await this.remote.syncKey();
    } catch {
      return null;
    }
    if (share.check && (await opensKeyCheck(key, share.check))) return true;
    await this.clear();
    return false;
  }

  /**
   * Starts the PIN over with the account's password: the check, the
   * share, every private row and file on the server go, and the key here
   * with them. The next PIN is chosen ([[Accounts]], start over).
   */
  async startOver(password: string): Promise<void> {
    await this.remote.startOverSyncKey(password);
    await this.clear();
  }

  /** Called when the key arrives, and when it is forgotten. */
  onUnlock(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  forget(): void {
    this.cached = undefined;
  }

  /**
   * Forgets the key on this browser ([[Accounts]], the account circle):
   * what is already open here stays, and new private writes wait for
   * the sync PIN again, as on a browser that never had it.
   */
  async clear(): Promise<void> {
    await this.db.meta.bulkDelete([metaKeys.privateKey, metaKeys.privateKeyV2]);
    this.cached = null;
    this.tell();
  }

  private tell(): void {
    for (const listener of this.listeners) listener();
  }
}
