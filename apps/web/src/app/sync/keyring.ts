import {
  deriveSyncBase,
  fileNameKeyOf,
  opensKeyCheck,
  pinProofOf,
  pinVerifierOf,
  sealKeyCheck,
  syncKeyBitsOf,
  syncKeyFromBits,
  type KeyCheck,
  type SyncKeySet,
  type SyncKeyState,
  type UnlockResult,
} from '@harvest/contracts';
import { getMeta, metaKeys, setMeta, type HarvestDB } from '../data/db';

interface StoredKey {
  key: CryptoKey;
  /** The HMAC key a file's name on the server is drawn with (`fileNameOf`). */
  nameKey: CryptoKey;
  /** The salt it was derived with: a key for another account is no key. */
  salt: string;
  /** The key epoch it belongs to (`sync-key.ts`): named on every sealed write. */
  epoch: number;
  /** This key's own id, so a tab never forgets a newer key another tab kept. */
  id: string;
  v: 4;
}

/** The keys a secret opens: the row and file key, and the name key, both kept only as CryptoKeys. */
async function keysOf(base: Uint8Array, keyShare: string): Promise<{ key: CryptoKey; nameKey: CryptoKey }> {
  const bits = await syncKeyBitsOf(base, keyShare);
  try {
    return { key: await syncKeyFromBits(bits), nameKey: await fileNameKeyOf(bits) };
  } finally {
    bits.fill(0);
  }
}

/** The key routes, as the keyring needs them ([[Sync-API]], sync key). */
export interface SyncKeyRemote {
  syncKey(): Promise<SyncKeyState>;
  /** Throws on a wrong proof (403 `wrong_pin`), past the limit (429), with no PIN set (409). */
  unlockSyncKey(proof: string): Promise<UnlockResult>;
  /** The epoch, or null when another device set a PIN first. */
  setSyncKey(verifier: string, check: KeyCheck): Promise<SyncKeySet | null>;
  startOverSyncKey(password: string): Promise<void>;
}

/**
 * A secret the account refused: not the account's PIN, or, with
 * [chosenElsewhere], another device chose the PIN a moment before.
 * Nothing was kept, and nothing was sealed with it.
 */
export class WrongPassphraseError extends Error {
  override readonly name = 'WrongPassphraseError';

  constructor(
    message: string,
    readonly chosenElsewhere = false,
    /** Wrong tries the server still allows before its pause. */
    readonly triesLeft: number | null = null,
  ) {
    super(message);
  }
}

/** Too many wrong PINs: the server takes no more for [retryAfter] seconds. */
export class PinLimitedError extends Error {
  override readonly name = 'PinLimitedError';

  constructor(readonly retryAfter: number | null) {
    super('Too many wrong PINs');
  }
}

/** The PIN was started over meanwhile: none is set, and this device chooses. */
export class PinStartedOverError extends Error {
  override readonly name = 'PinStartedOverError';
}

/** Tabs of this browser tell each other when the key changes (Q6-05). */
export const keyChannelName = 'harvest-key';

function toBase64(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

interface Answer {
  status?: number;
  code?: string;
  triesLeft?: number | null;
  retryAfter?: number | null;
}

function statusOf(error: unknown): Answer {
  return typeof error === 'object' && error !== null ? error : {};
}

/**
 * Where this browser keeps the private tier's key: in IndexedDB, as a
 * non-extractable CryptoKey with its epoch, so the PIN is typed once per
 * browser and the key itself can never be read back out. Beside it is
 * the name key files are named with on the server (Phase 7); a key kept
 * by 3.1, which has none, is not used, and the PIN is asked once more.
 * The scheme is the contract's (`deriveSyncBase`, `pinProofOf`,
 * `syncKeyBitsOf`, `fileNameKeyOf`), the same on the phone: the secret
 * is never sent and never stored.
 *
 * Whether a secret is the account's is the server's to say, online,
 * with a limit on tries ([[Accounts]], S6-04): the key share is handed
 * over only for the PIN's proof. Every tab of the browser hears when
 * the key is kept or forgotten, and none forgets a key newer than the
 * one it was using (Q6-05).
 */
export class Keyring {
  private cached: StoredKey | null | undefined;
  private readonly listeners = new Set<() => void>();
  private readonly channel: BroadcastChannel | null =
    typeof BroadcastChannel === 'function' ? new BroadcastChannel(keyChannelName) : null;

  /**
   * Run once a new key is kept, before anything else hears of it: what
   * this browser holds goes up again under it (the engine's
   * `privateTierOpened`).
   */
  onNewKey: (() => Promise<void>) | null = null;

  constructor(
    private readonly db: HarvestDB,
    private readonly remote: SyncKeyRemote,
  ) {
    // Another tab kept or forgot a key: read the store again.
    this.channel?.addEventListener('message', () => {
      this.cached = undefined;
      this.tell();
    });
  }

  private async stored(): Promise<StoredKey | null> {
    if (this.cached !== undefined) return this.cached;
    const stored = await getMeta<StoredKey>(this.db, metaKeys.privateKeyV4);
    this.cached = stored && stored.v === 4 ? stored : null;
    return this.cached;
  }

  async key(salt: string | null): Promise<CryptoKey | null> {
    const stored = await this.stored();
    return stored && (salt === null || stored.salt === salt) ? stored.key : null;
  }

  /** The key a file's name on the server is drawn with, beside [key]. */
  async nameKey(salt: string | null): Promise<CryptoKey | null> {
    const stored = await this.stored();
    return stored && (salt === null || stored.salt === salt) ? stored.nameKey : null;
  }

  /** The epoch the key here belongs to, or null with no key. */
  async epoch(): Promise<number | null> {
    return (await this.stored())?.epoch ?? null;
  }

  /** The account's salt, epoch and whether a PIN is set, as the server has them now. */
  state(): Promise<SyncKeyState> {
    return this.remote.syncKey();
  }

  /**
   * Proves [secret] to the server and keeps the key it opens.
   *
   * Entering: the PIN's proof goes up, and the key share comes back only
   * for the right one; a wrong one throws [WrongPassphraseError] with the
   * tries left, past the limit [PinLimitedError], and nothing is kept.
   * Choosing (no PIN set yet): the verifier and the key check go up first;
   * when another device set a PIN meanwhile, this secret is tried against
   * theirs.
   */
  async unlock(secret: string, _salt?: string, iterations?: number): Promise<void> {
    const state = await this.remote.syncKey();
    const base = await deriveSyncBase(secret, state.salt, iterations === undefined ? {} : { iterations });
    const proof = await pinProofOf(base);
    let keys: { key: CryptoKey; nameKey: CryptoKey } | null = null;
    let epoch = state.epoch;
    const choosing = state.state === 'none';
    if (state.state === 'none') {
      keys = await keysOf(base, state.keyShare);
      const set = await this.remote.setSyncKey(await pinVerifierOf(proof), (await sealKeyCheck(keys.key)) as KeyCheck);
      if (set) epoch = set.epoch;
      else keys = null;
    }
    if (!keys) {
      let opened: UnlockResult;
      try {
        opened = await this.remote.unlockSyncKey(toBase64(proof));
      } catch (error) {
        const { status, code, triesLeft, retryAfter } = statusOf(error);
        if (code === 'wrong_pin') {
          throw new WrongPassphraseError('Not the account’s PIN', choosing, triesLeft ?? null);
        }
        if (status === 429) throw new PinLimitedError(retryAfter ?? null);
        if (status === 409) throw new PinStartedOverError('No PIN is set any more');
        throw error;
      }
      keys = await keysOf(base, opened.keyShare);
      // Belt and braces: the key must open the account's check too.
      if (!(await opensKeyCheck(keys.key, opened.check))) {
        throw new WrongPassphraseError('The key does not open the key check');
      }
      epoch = opened.epoch;
    }
    base.fill(0);
    await this.db.meta.bulkDelete([metaKeys.privateKey, metaKeys.privateKeyV2, metaKeys.privateKeyV3]);
    const stored: StoredKey = { ...keys, salt: state.salt, epoch, id: crypto.randomUUID(), v: 4 };
    await setMeta(this.db, metaKeys.privateKeyV4, stored);
    this.cached = stored;
    await this.onNewKey?.();
    this.announce();
  }

  /**
   * Whether the key kept here is still the account's: the account's epoch
   * against the key's, one small request. When it is not — the PIN was
   * started over on another device — the key is forgotten and the answer
   * is false. Null with no key here, or no answer from the server.
   */
  async stillTheAccounts(salt: string | null): Promise<boolean | null> {
    const stored = await this.stored();
    if (!stored || (salt !== null && stored.salt !== salt)) return null;
    let state: SyncKeyState;
    try {
      state = await this.remote.syncKey();
    } catch {
      return null;
    }
    if (state.state === 'set' && state.epoch === stored.epoch) return true;
    return !(await this.forgetIfStill(stored.id));
  }

  /**
   * The server refused a sealed write for a stale epoch: the key [id]
   * names (the one the write was sealed with) goes, unless another tab
   * has kept a newer one meanwhile. True when it went.
   */
  async forgetIfStill(id?: string): Promise<boolean> {
    const current = await getMeta<StoredKey>(this.db, metaKeys.privateKeyV4);
    if (current && id !== undefined && current.id !== id) {
      // A newer key, kept by another tab: this one never wipes it.
      this.cached = current.v === 4 ? current : null;
      return false;
    }
    await this.clear();
    return true;
  }

  /** The id of the key kept here now, to name it when forgetting it later. */
  async keyId(): Promise<string | null> {
    return (await this.stored())?.id ?? null;
  }

  /**
   * Starts the PIN over with the account's password: the verifier, the
   * check, the share, every private row and file on the server go, and
   * the key here with them. The next PIN is chosen ([[Accounts]], start over).
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
   * the sync PIN again, as on a browser that never had it. Every tab
   * hears of it.
   */
  async clear(): Promise<void> {
    await this.db.meta.bulkDelete([
      metaKeys.privateKey,
      metaKeys.privateKeyV2,
      metaKeys.privateKeyV3,
      metaKeys.privateKeyV4,
    ]);
    this.cached = null;
    this.announce();
  }

  private announce(): void {
    this.channel?.postMessage('changed');
    this.tell();
  }

  private tell(): void {
    for (const listener of this.listeners) listener();
  }
}
